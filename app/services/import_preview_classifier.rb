class ImportPreviewClassifier
  MERCHANT_REASON = "Matched a previously classified transaction from the same merchant."

  Result = Data.define(:category, :confidence, :reason)

  def initialize(user:, rulebook: TransactionClassification::Rulebook.new)
    @user = user
    @rulebook = rulebook
  end

  def call(import_row)
    if import_row.classified?
      return Result.new(category: import_row.category, confidence: import_row.classification_confidence || 0.9, reason: import_row.classification_reason.presence || MERCHANT_REASON)
    end

    merchant_match = category_from_merchant_history(import_row.description)
    return Result.new(category: merchant_match, confidence: 0.9, reason: MERCHANT_REASON) if merchant_match

    category_name, confidence, reason = category_from_rules(import_row)
    Result.new(category: ensure_category(category_name), confidence:, reason:)
  end

  private

  attr_reader :user, :rulebook

  def category_from_merchant_history(description)
    merchant_key = normalized_merchant(description)
    return if merchant_key.blank?

    transaction_scope.includes(:category).where.not(category_id: nil).recent.limit(1_000).each do |transaction|
      return transaction.category if merchant_matches?(merchant_key, normalized_merchant(transaction.description))
    end

    nil
  end

  def merchant_matches?(import_key, existing_key)
    return false if import_key.blank? || existing_key.blank?
    return true if import_key == existing_key

    shorter, longer = [ import_key, existing_key ].sort_by(&:length)
    shorter.length >= 8 && longer.start_with?(shorter)
  end

  def category_from_rules(import_row)
    result = rulebook.call(description: import_row.description, direction: import_row.direction)
    [ result.category_name, result.confidence, result.reason ]
  end

  def ensure_category(name)
    category_scope.find_or_create_by!(name:) do |category|
      category.color = CategoryColor.pick(name)
    end
  end

  def category_scope
    user&.categories || Category.all
  end

  def transaction_scope
    user&.expense_transactions || ExpenseTransaction.all
  end

  def normalized_merchant(description)
    ExpenseTransaction.new(description:).merchant_name.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end
end
