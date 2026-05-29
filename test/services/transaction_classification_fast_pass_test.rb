require "test_helper"

class TransactionClassificationFastPassTest < ActiveSupport::TestCase
  test "classifies a batch without calling AI" do
    transaction = ExpenseTransaction.create!(
      occurred_on: Date.new(2026, 5, 22),
      description: "PET SUPPLY",
      amount_cents: 7446,
      direction: "debit",
      card_last4: "2222",
      source: "test",
      external_id: "fast-pass-pet-row",
      user: users(:one)
    )
    run = users(:one).classification_runs.create!

    TransactionClassification::FastPass.new(run:).call(ExpenseTransaction.where(id: transaction.id))

    assert_equal "complete", run.reload.status
    assert_equal 1, run.total_count
    assert_equal 1, run.processed_count
    assert_equal 1, run.rule_based_count
    assert_equal 0, run.ai_count
    assert_equal "Pets", transaction.reload.category.name
    assert_match "fast classification pass", transaction.classification_reason
  end

  test "stops before processing the next batch when cancellation is requested" do
    transaction = ExpenseTransaction.create!(
      occurred_on: Date.new(2026, 5, 22),
      description: "PET SUPPLY",
      amount_cents: 7446,
      direction: "debit",
      card_last4: "2222",
      source: "test",
      external_id: "fast-pass-cancel-row",
      user: users(:one)
    )
    run = users(:one).classification_runs.create!(cancel_requested_at: Time.current)

    TransactionClassification::FastPass.new(run:).call(ExpenseTransaction.where(id: transaction.id))

    assert_equal "canceled", run.reload.status
    assert_equal 0, run.processed_count
    assert_nil transaction.reload.category
  end
end
