module Ai
  class TransactionChat
    def initialize(model: Ai::Controls.model)
      @model = model
    end

    def call(question:, transactions:, filters: {})
      return disabled_response unless Ai::Controls.enabled?(:chat)

      payload = summary_payload(transactions)
      response = RubyLLM.chat(model:).ask(<<~PROMPT)
        You are helping with personal accounting and spending review.
        Answer the user's question using only the filtered transaction summary below.
        Be concise, include dollar amounts when relevant, and say when the data does not support an answer.

        Filters: #{JSON.pretty_generate(filters)}
        Summary: #{JSON.pretty_generate(payload)}
        Question: #{question}
      PROMPT

      Ai::Controls.record(feature: :chat, model:, response:)
      { answer: response.content.to_s, source: "ai" }
    rescue StandardError => error
      Rails.logger.warn("RubyLLM transaction chat failed: #{error.class}: #{error.message}")
      Ai::Controls.record(feature: :chat, model:, successful: false, error:)
      { answer: "I could not complete the AI chat request. Check the AI controls page for provider and request-limit status.", source: "automatic" }
    end

    private

    attr_reader :model

    def disabled_response
      { answer: "AI chat is disabled, over the monthly request limit, or no provider key is configured.", source: "automatic" }
    end

    def summary_payload(transactions)
      records = transactions.limit(500).to_a
      expenses = records.select(&:expense?)

      {
        transaction_count: records.size,
        expense_total_cents: expenses.sum(&:amount_cents),
        credit_total_cents: records.reject(&:expense?).sum(&:amount_cents),
        date_range: {
          start: records.map(&:occurred_on).min,
          end: records.map(&:occurred_on).max
        },
        category_totals: expenses.group_by { |transaction| transaction.category&.name || "Uncategorized" }
                                 .transform_values { |items| items.sum(&:amount_cents) },
        subcategory_totals: subcategory_totals(expenses),
        merchants: expenses.group_by { |transaction| normalized_merchant(transaction.description) }
                          .transform_values { |items| { count: items.size, cents: items.sum(&:amount_cents) } }
                          .sort_by { |_merchant, item| -item[:cents] }
                          .first(25)
                          .to_h,
        sample_transactions: records.first(50).map do |transaction|
          {
            date: transaction.occurred_on,
            description: transaction.description,
            amount_cents: transaction.amount_cents,
            direction: transaction.direction,
            category: transaction.category&.name,
            subcategories: transaction.subcategories.map(&:name),
            notes: transaction.notes
          }
        end
      }
    end

    def normalized_merchant(description)
      description.split(/\s{2,}| #|\*/).first.to_s.downcase.squish
    end

    def subcategory_totals(transactions)
      totals = Hash.new(0)

      transactions.each do |transaction|
        subcategories = transaction.subcategories.to_a
        if subcategories.any?
          subcategories.each { |subcategory| totals[subcategory.name] += transaction.amount_cents }
        else
          totals["None"] += transaction.amount_cents
        end
      end

      totals
    end
  end
end
