module Ai
  class InsightGenerator
    def initialize(model: ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano"))
      @model = model
    end

    def call(start_date: 30.days.ago.to_date, end_date: Date.current)
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
        Generate 4 concise, useful personal finance insights from this transaction summary.
        Focus on where spending is concentrated, which flexible categories to cut, repeated merchant habits,
        weekday frequency patterns, and realistic savings recommendations.
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

      insights.first(4)
    end

    def summary_payload(transactions)
      expense_transactions = transactions.select(&:expense?)

      {
        period: {
          start_date: transactions.minimum(:occurred_on),
          end_date: transactions.maximum(:occurred_on)
        },
        transaction_count: transactions.size,
        expense_total_cents: expense_transactions.sum(&:amount_cents),
        credit_total_cents: transactions.reject(&:expense?).sum(&:amount_cents),
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
