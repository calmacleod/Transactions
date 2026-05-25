require "test_helper"

class AiTransactionClassifierTest < ActiveSupport::TestCase
  test "falls back to local merchant rules without provider keys" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 22),
        description: "PET SUPPLY",
        amount_cents: 7446,
        direction: "debit",
        card_last4: "2222",
        source: "test",
        external_id: "pet-valu-row"
      )

      Ai::TransactionClassifier.new.classify(transaction)

      assert_equal "Pets", transaction.reload.category.name
      assert_equal 0.65.to_d, transaction.classification_confidence
      assert_match "local merchant rules", transaction.classification_reason
    end
  end

  test "classifies credit card payments separately from expenses" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 19),
        description: "CARD PAYMENT RECEIVED",
        amount_cents: 97069,
        direction: "credit",
        card_last4: "2222",
        source: "test",
        external_id: "payment-row"
      )

      Ai::TransactionClassifier.new.classify(transaction)

      assert_equal "Payments", transaction.reload.category.name
      assert_equal 1.0.to_d, transaction.classification_confidence
      assert_match "excluded from expense totals", transaction.classification_reason
    end
  end

  test "classifies recurring digital services as subscriptions" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 7),
        description: "AI SERVICE MONTHLY PLAN",
        amount_cents: 15368,
        direction: "debit",
        card_last4: "2222",
        source: "test",
        external_id: "openai-subscription-row"
      )

      Ai::TransactionClassifier.new.classify(transaction)

      assert_equal "Subscriptions", transaction.reload.category.name
      assert_equal 0.65.to_d, transaction.classification_confidence
    end
  end

  private

  def without_ai_keys
    old_values = ENV.values_at("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("ANTHROPIC_API_KEY")
    ENV.delete("GEMINI_API_KEY")
    yield
  ensure
    %w[OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY].zip(old_values).each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
