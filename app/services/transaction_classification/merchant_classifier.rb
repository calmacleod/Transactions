module TransactionClassification
  class MerchantClassifier
    MerchantClassificationResult = Data.define(:category_name, :confidence, :reason, :source)
    Result = MerchantClassificationResult

    def initialize(user:, rulebook: Rulebook.new, catalog: PublicMerchantCatalog.new)
      @user = user
      @rulebook = rulebook
      @catalog = catalog
    end

    def call(description:, direction:)
      # Merchant spending preferences must never turn payments/refunds into expenses.
      return rules_result(description, direction) unless direction.to_s == "debit"

      public_match = catalog.call(description)
      key = merchant_key(description, public_match)
      history = manual_history[key].presence || legacy_history[key]
      if history&.one?
        category_name = history.first
        manual = manual_history[key].present?
        return TransactionClassification::MerchantClassifier::MerchantClassificationResult.new(
          category_name:, confidence: manual ? 0.95 : 0.8,
          reason: manual ? "Matched your manual category for this merchant." : "Matched a previously saved category; original classification source is unknown.",
          source: "history"
        )
      end

      if public_match
        return TransactionClassification::MerchantClassifier::MerchantClassificationResult.new(category_name: public_match.category_name, confidence: 0.8,
          reason: "Matched #{public_match.name} to a merchant type using the OpenStreetMap Name Suggestion Index.", source: "public")
      end

      rules_result(description, direction)
    end

    private

    attr_reader :user, :rulebook, :catalog

    def merchant_key(description, public_match = catalog.call(description))
      public_match&.identity.present? ? "brand:#{public_match.identity}" : MerchantName.normalize(description)
    end

    def manual_history
      load_history unless @manual_history
      @manual_history
    end

    def legacy_history
      load_history unless @legacy_history
      @legacy_history
    end

    def load_history
      @manual_history = {}
      @legacy_history = {}
      ExpenseTransaction.where(user:, direction: "debit", classification_source: %w[manual legacy])
        .joins(:category).where(categories: { user_id: user&.id })
        .pluck(:description, "categories.name", :classification_source).each do |description, category_name, source|
          next if source == "legacy" && category_name == "Uncategorized"

          key = merchant_key(description)
          next if key.blank?

          history = source == "manual" ? @manual_history : @legacy_history
          (history[key] ||= Set.new) << category_name
        end
    end

    def rules_result(description, direction)
      result = rulebook.call(description:, direction:)
      TransactionClassification::MerchantClassifier::MerchantClassificationResult.new(category_name: result.category_name, confidence: result.confidence, reason: result.reason, source: "rules")
    end
  end
end
