module Ai
  class InsightGenerator
    def initialize(model: ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano"))
      @model = model
    end

    def call(start_date: 4.months.ago.to_date.beginning_of_month, end_date: Date.current)
      transactions = ExpenseTransaction.includes(:category).between(start_date, end_date)
      payload = summary_payload(transactions)
      insights = llm_insights(payload) if ai_configured?
      insights = fallback_insights(payload) if insights.blank?

      Insight.where(starts_on: start_date, ends_on: end_date).delete_all
      insights.map do |attributes|
        Insight.create!(
          title: attributes.fetch(:title),
          body: attributes.fetch(:body),
          severity: attributes.fetch(:severity, "info"),
          starts_on: start_date,
          ends_on: end_date,
          payload:
        )
      end
    end

    private

    attr_reader :model

    def ai_configured?
      ENV.values_at("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY").any?(&:present?)
    end

    def llm_insights(payload)
      response = RubyLLM.chat(model:).with_schema(ExpenseInsightsSchema).ask(<<~PROMPT)
        Generate 4 to 8 concise, useful personal finance insights from this recent transaction summary.
        Always include the four standard angles when the data supports them: category concentration,
        flexible cutback opportunities, repeat merchant habits, and weekday frequency patterns.
        Add any other materially useful observations you see, especially month-to-month changes,
        spikes, drops, new recurring spend, and realistic savings recommendations.
        Ignore long-term yearly trends. Focus on the last few months and current month-to-month variation.
        Data: #{JSON.pretty_generate(payload)}
      PROMPT

      response.content.fetch("insights").map do |insight|
        insight.symbolize_keys.slice(:title, :body, :severity)
      end
    rescue StandardError => error
      Rails.logger.warn("RubyLLM insight generation failed: #{error.class}: #{error.message}")
      nil
    end

    def fallback_insights(payload)
      insights = []
      categorized_totals = payload[:category_totals].except("Uncategorized")
      top_category = categorized_totals.max_by { |_category, cents| cents }
      top_discretionary = categorized_totals.slice("Restaurants", "Shopping", "Subscriptions", "Entertainment", "Travel")
                                           .max_by { |_category, cents| cents }
      top_merchant = payload[:merchant_totals].max_by { |_merchant, cents| cents }
      busiest_day = payload[:weekday_totals].max_by { |_day, totals| totals[:count] }

      if top_category
        insights << {
          title: "#{top_category.first} leads spending",
          body: "#{top_category.first} accounts for #{money(top_category.second)} of #{money(payload[:expense_total_cents])} in expenses for this period.",
          severity: "info"
        }
      end

      if top_discretionary
        savings = (top_discretionary.second * 0.20).round
        insights << {
          title: "Best cutback target: #{top_discretionary.first}",
          body: "A 20% reduction in #{top_discretionary.first.downcase} spending would save about #{money(savings)} for this period.",
          severity: "warning"
        }
      end

      if top_merchant
        insights << {
          title: "Largest merchant: #{top_merchant.first.titleize}",
          body: "Transactions at #{top_merchant.first.titleize} total #{money(top_merchant.second)}. Consider setting a cap for this merchant next month.",
          severity: "warning"
        }
      end

      if busiest_day
        insights << {
          title: "#{busiest_day.first} has the most purchases",
          body: "#{busiest_day.second[:count]} purchases landed on #{busiest_day.first}, totaling #{money(busiest_day.second[:cents])}. This can reveal recurring routines worth reviewing.",
          severity: "info"
        }
      end

      insights << {
        title: "#{payload[:transaction_count]} transactions imported",
        body: "Add an AI provider key for RubyLLM-generated narratives, or keep using the local rules for deterministic category and savings recommendations.",
        severity: "success"
      } if insights.size < 4

      insights.first(6)
    end

    def summary_payload(transactions)
      transaction_records = transactions.to_a
      expense_transactions = transaction_records.select(&:expense?)
      month_groups = expense_transactions.group_by { |transaction| transaction.occurred_on.beginning_of_month }
      category_month_groups = expense_transactions.group_by { |transaction| transaction.category&.name || "Uncategorized" }

      {
        period: {
          start_date: transaction_records.map(&:occurred_on).min,
          end_date: transaction_records.map(&:occurred_on).max
        },
        generated_on: Date.current,
        transaction_count: transaction_records.size,
        expense_total_cents: expense_transactions.sum(&:amount_cents),
        credit_total_cents: transaction_records.reject(&:expense?).sum(&:amount_cents),
        month_totals: month_groups.sort.to_h.transform_keys { |month| month.strftime("%Y-%m") }
                                  .transform_values { |items| items.sum(&:amount_cents) },
        category_month_totals: category_month_groups.transform_values do |items|
          items.group_by { |transaction| transaction.occurred_on.beginning_of_month }
               .sort.to_h
               .transform_keys { |month| month.strftime("%Y-%m") }
               .transform_values { |month_items| month_items.sum(&:amount_cents) }
        end,
        category_totals: expense_transactions.group_by { |transaction| transaction.category&.name || "Uncategorized" }
                                             .transform_values { |items| items.sum(&:amount_cents) },
        merchant_totals: expense_transactions.group_by { |transaction| normalized_merchant(transaction.description) }
                                             .transform_values { |items| items.sum(&:amount_cents) },
        weekday_totals: expense_transactions.group_by { |transaction| transaction.occurred_on.strftime("%A") }
                                            .transform_values { |items| { count: items.size, cents: items.sum(&:amount_cents) } }
      }
    end

    def normalized_merchant(description)
      description.split(/\s{2,}| #|\*/).first.to_s.downcase.squish
    end

    def money(cents)
      "$#{format('%.2f', cents.to_d / 100)}"
    end
  end
end
