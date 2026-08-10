module TransactionClassification
  class Rulebook
    Rule = Data.define(:category_name, :pattern, :confidence) do
      def matches?(description)
        pattern.respond_to?(:call) ? pattern.call(description) : pattern.match?(description)
      end
    end

    Result = Data.define(:category_name, :confidence, :reason, :rule)

    RULES = [
      Rule.new(category_name: "Subscriptions", pattern: /ai service|openai|chatgpt|anthropic|claude|cursor|perplexity|github copilot|netflix|spotify|crunchyroll|disney\+|prime video|youtube premium|google \*cloud|google \*google one|google one|dropbox|icloud|adobe|canva|figma|namecheap|godaddy|hover\.com|porkbun|cloudflare/i, confidence: 0.65),
      Rule.new(category_name: "Groceries", pattern: /supermarket|grocery|wal-mart|walmart|t&t|farm boy|loblaw|metro|food basics|costco/i, confidence: 0.65),
      Rule.new(category_name: "Restaurants", pattern: /restaurant|pub|tim hortons|coffee|cafe|dairy|kitchen|pizza|thirst/i, confidence: 0.65),
      Rule.new(category_name: "Shopping", pattern: /amazon|amzn|dollarama|marketplace|store|mktp/i, confidence: 0.65),
      Rule.new(category_name: "Pets", pattern: /pet valu|petsmart|pet supply|veterinary|vet /i, confidence: 0.65),
      Rule.new(category_name: "Entertainment", pattern: /theatre|cinema|spotify|netflix|concert|ticket/i, confidence: 0.65),
      Rule.new(category_name: "Transportation", pattern: /uber|lyft|presto|parking|shell|esso|petro|gas/i, confidence: 0.65),
      Rule.new(category_name: "Health", pattern: /pharmacy|drug|medical|dental|clinic/i, confidence: 0.65),
      Rule.new(category_name: "Home", pattern: /home depot|canadian tire|ikea|hydro|enbridge|internet|bell|rogers/i, confidence: 0.65),
      Rule.new(category_name: "Travel", pattern: /hotel|air canada|westjet|airbnb|booking/i, confidence: 0.65)
    ].freeze

    PAYMENT_PATTERN = /payment thank you|paiemen t merci|payment/i

    def initialize(rules: RULES)
      @rules = rules
    end

    def call(description:, direction:)
      description = description.to_s
      return credit_result(description) unless direction.to_s == "debit"

      rule = rules.find { |candidate| candidate.matches?(description) }
      return Result.new(category_name: rule.category_name, confidence: rule.confidence, reason: "Matched local merchant rules.", rule:) if rule

      Result.new(category_name: "Uncategorized", confidence: 0.25, reason: "No local merchant rule matched.", rule: nil)
    end

    private

    attr_reader :rules

    def credit_result(description)
      if PAYMENT_PATTERN.match?(description)
        Result.new(category_name: "Payments", confidence: 1.0, reason: "Credit card payment; excluded from expense totals.", rule: nil)
      else
        Result.new(category_name: "Refunds & Credits", confidence: 0.8, reason: "Credit or refund; excluded from expense totals.", rule: nil)
      end
    end
  end
end
