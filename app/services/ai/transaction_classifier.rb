module Ai
  class TransactionClassifier
    def initialize(model: nil, user: Current.user, rulebook: TransactionClassification::Rulebook.new, catalog: TransactionClassification::PublicMerchantCatalog.new)
      @model = model
      @user = user
      @classifier = TransactionClassification::MerchantClassifier.new(user:, rulebook:, catalog:)
    end

    def classify_all(scope = ExpenseTransaction.unclassified.recent)
      scope.find_each { |transaction| classify(transaction) }
    end

    def classify(transaction)
      return if transaction.classification_source == "manual"

      result = rule_based_classification(transaction)
      result = llm_classification(transaction) if result[:category] == "Uncategorized" && result[:source] == "rules" && Ai::Controls.enabled?(:classification)
      result ||= rule_based_classification(transaction)
      apply_result(transaction, result)
    end

    private

    attr_reader :model, :user, :classifier

    def llm_classification(transaction)
      response = Ai::RubyLlmClient.new(feature: :classification, model:).ask(prompt_for(transaction), schema: TransactionClassificationSchema)
      content = response.parsed

      {
        category: content.fetch("category"),
        confidence: content.fetch("confidence").to_d,
        reason: content.fetch("reason"),
        source: "ai"
      }
    rescue StandardError => error
      Rails.logger.warn("RubyLLM classification failed for transaction #{transaction.id}: #{error.class}: #{error.message}")
      nil
    end

    def prompt_for(transaction)
      categories = category_scope.by_name.pluck(:name).join(", ")

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
      result = classifier.call(description: transaction.description, direction: transaction.direction)

      {
        category: result.category_name,
        confidence: result.confidence,
        reason: result.reason,
        source: result.source
      }
    end

    def apply_result(transaction, result)
      transaction.with_lock do
        return if transaction.classification_source == "manual"

        category = category_scope.find_or_create_by!(name: result[:category]) do |record|
          record.color = CategoryColor.pick(result[:category])
        end

        transaction.update!(
          category:,
          classification_confidence: result[:confidence],
          classification_reason: result[:reason],
          classification_source: result[:source],
          classified_at: Time.current
        )
      end
    end

    def category_scope
      (user || Current.user) ? Category.where(user_id: (user || Current.user).id) : Category.all
    end
  end
end
