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
    assert_match "local merchant rules", transaction.classification_reason
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

  test "uses manual history while preserving manually classified rows" do
    manual = expense_transactions(:grocery)
    manual.update!(description: "BULK BARN #041", classification_source: "manual", category: categories(:restaurants))
    transaction = users(:one).expense_transactions.create!(occurred_on: Date.new(2026, 5, 22), description: "BULK BARN #095",
      amount_cents: 1000, direction: "debit", external_id: "fast-pass-history")
    run = users(:one).classification_runs.create!

    TransactionClassification::FastPass.new(run:).call(users(:one).expense_transactions.where(id: [ manual.id, transaction.id ]))

    assert_equal 1, run.reload.total_count
    assert_equal categories(:restaurants), transaction.reload.category
    assert_equal "history", transaction.classification_source
    assert_equal "manual", manual.reload.classification_source
  end

  test "does not overwrite a manual choice made while classification is running" do
    transaction = users(:one).expense_transactions.create!(occurred_on: Date.new(2026, 5, 22), description: "UNIQUE MERCHANT",
      amount_cents: 1000, direction: "debit", external_id: "fast-pass-concurrent-manual")
    rulebook = Object.new
    restaurant_id = categories(:restaurants).id
    rulebook.define_singleton_method(:call) do |**|
      transaction.update!(ExpenseTransaction.manual_classification_attributes(restaurant_id))
      TransactionClassification::Rulebook::Result.new(category_name: "Groceries", confidence: 0.65, reason: "Automatic", rule: nil)
    end
    run = users(:one).classification_runs.create!

    TransactionClassification::FastPass.new(run:, rulebook:).call(users(:one).expense_transactions.where(id: transaction.id))

    assert_equal categories(:restaurants), transaction.reload.category
    assert_equal "manual", transaction.classification_source
    assert_equal 0, run.reload.classified_count
    assert_equal 1, run.processed_count
  end
end
