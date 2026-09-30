class ImportPreviewClassifier
  Result = Data.define(:category, :confidence, :reason, :source)

  def initialize(user:, rulebook: TransactionClassification::Rulebook.new, catalog: TransactionClassification::PublicMerchantCatalog.new)
    @user = user
    @classifier = TransactionClassification::MerchantClassifier.new(user:, rulebook:, catalog:)
  end

  def call(import_row)
    if import_row.classified?
      return Result.new(category: import_row.category, confidence: import_row.classification_confidence || 0.8,
        reason: import_row.classification_reason.presence || "Preserved the category already assigned to this row.", source: import_row.classification_source || "legacy")
    end

    result = classifier.call(description: import_row.description, direction: import_row.direction)
    Result.new(category: ensure_category(result.category_name), confidence: result.confidence, reason: result.reason, source: result.source)
  end

  private

  attr_reader :user, :classifier

  def ensure_category(name)
    category_scope.find_or_create_by!(name:) do |category|
      category.color = CategoryColor.pick(name)
    end
  end

  def category_scope
    Category.where(user:)
  end
end
