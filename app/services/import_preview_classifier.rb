class ImportPreviewClassifier
  CATEGORY_RULES = TransactionClassification::FastPass::CATEGORY_RULES
  MERCHANT_REASON = "Matched a previously classified transaction from the same merchant."
  LOCAL_RULE_REASON = "Matched local merchant rules during import preview."
  UNCATEGORIZED_REASON = "No merchant history or local rule matched during import preview."
  PAYMENT_REASON = "Credit card payment; excluded from expense totals."
  CREDIT_REASON = "Credit or refund; excluded from expense totals."

  Result = Data.define(:category, :confidence, :reason)

  def initialize(user:)
    @user = user
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

  attr_reader :user

  def category_from_merchant_history(description)
    merchant_key = normalized_merchant(description)
    return if merchant_key.blank?

    transaction_scope.where.not(category_id: nil).recent.limit(1_000).each do |transaction|
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
    return credit_category(import_row) unless import_row.direction == "debit"

    category_name = CATEGORY_RULES.find { |_name, pattern| import_row.description.match?(pattern) }&.first

    if category_name
      [ category_name, 0.65, LOCAL_RULE_REASON ]
    else
      [ "Uncategorized", 0.25, UNCATEGORIZED_REASON ]
    end
  end

  def credit_category(import_row)
    if import_row.description.match?(/payment thank you|paiemen t merci|payment/i)
      [ "Payments", 1.0, PAYMENT_REASON ]
    else
      [ "Refunds & Credits", 0.8, CREDIT_REASON ]
    end
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
