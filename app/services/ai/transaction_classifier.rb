module Ai
  class TransactionClassifier
    CATEGORY_RULES = {
      "Subscriptions" => /ai service|openai|chatgpt|anthropic|claude|cursor|perplexity|github copilot|netflix|spotify|crunchyroll|disney\+|prime video|youtube premium|google \*cloud|google \*google one|google one|dropbox|icloud|adobe|canva|figma|namecheap|godaddy|hover\.com|porkbun|cloudflare/i,
      "Groceries" => /supermarket|grocery|wal-mart|walmart|t&t|farm boy|loblaw|metro|food basics|costco/i,
      "Restaurants" => /restaurant|pub|tim hortons|coffee|cafe|dairy|kitchen|pizza|thirst/i,
      "Shopping" => /amazon|amzn|dollarama|marketplace|store|mktp/i,
      "Pets" => /pet valu|petsmart|pet supply|veterinary|vet /i,
      "Entertainment" => /theatre|cinema|spotify|netflix|concert|ticket/i,
      "Transportation" => /uber|lyft|presto|parking|shell|esso|petro|gas/i,
      "Health" => /pharmacy|drug|medical|dental|clinic/i,
      "Home" => /home depot|canadian tire|ikea|hydro|enbridge|internet|bell|rogers/i,
      "Travel" => /hotel|air canada|westjet|airbnb|booking/i
    }.freeze

    def initialize(model: ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano"))
      @model = model
    end

    def classify_all(scope = ExpenseTransaction.unclassified.recent)
      scope.find_each { |transaction| classify(transaction) }
    end

    def classify(transaction)
      result = credit_classification(transaction) unless transaction.expense?
      result ||= llm_classification(transaction) if ai_configured?
      result ||= rule_based_classification(transaction)
      apply_result(transaction, result)
    end

    private

    attr_reader :model

    def ai_configured?
      ENV.values_at("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY").any?(&:present?)
    end

    def llm_classification(transaction)
      response = RubyLLM.chat(model:).with_schema(TransactionClassificationSchema).ask(prompt_for(transaction))
      content = response.content

      {
        category: content.fetch("category"),
        confidence: content.fetch("confidence").to_d,
        reason: content.fetch("reason")
      }
    rescue StandardError => error
      Rails.logger.warn("RubyLLM classification failed for transaction #{transaction.id}: #{error.class}: #{error.message}")
      nil
    end

    def prompt_for(transaction)
      categories = Category.by_name.pluck(:name).join(", ")

      <<~PROMPT
        Classify this credit card transaction for a personal expense tracker.
        Use one of these existing categories when possible: #{categories}.
        If none fits, choose a concise category name suitable for budgeting.

        Date: #{transaction.occurred_on}
        Description: #{transaction.description}
        Amount: #{transaction.amount}
        Direction: #{transaction.direction}
      PROMPT
    end

    def rule_based_classification(transaction)
      category_name = CATEGORY_RULES.find { |_name, pattern| transaction.description.match?(pattern) }&.first || "Uncategorized"

      {
        category: category_name,
        confidence: category_name == "Uncategorized" ? 0.25 : 0.65,
        reason: "Matched local merchant rules. Add an AI provider key to enable RubyLLM classification."
      }
    end

    def credit_classification(transaction)
      if transaction.description.match?(/payment thank you|paiemen t merci|payment/i)
        {
          category: "Payments",
          confidence: 1.0,
          reason: "Credit card payment; excluded from expense totals."
        }
      else
        {
          category: "Refunds & Credits",
          confidence: 0.8,
          reason: "Credit or refund; excluded from expense totals."
        }
      end
    end

    def apply_result(transaction, result)
      category = Category.find_or_create_by!(name: result[:category]) do |record|
        record.color = CategoryColor.pick(result[:category])
      end

      transaction.update!(
        category:,
        classification_confidence: result[:confidence],
        classification_reason: result[:reason],
        classified_at: Time.current
      )
    end
  end
end
