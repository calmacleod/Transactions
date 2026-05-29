require "test_helper"
require "stringio"

class StatementCsvImporterTest < ActiveSupport::TestCase
  test "imports headerless statement rows" do
    csv = StringIO.new(<<~CSV)
      2026-05-22,"SAMPLE ONLINE STORE TORONTO, ON",17.24,,1111********2222
      2026-05-20,"SAMPLE REFUND",,4.99,1111********2222
    CSV

    batch = StatementCsvImporter.new(io: csv, filename: "sample.csv", user: users(:one)).call

    assert_equal "complete", batch.status
    assert_equal 2, batch.rows_count
    assert_equal 2, batch.transactions_count

    purchase = ExpenseTransaction.find_by!(description: "SAMPLE ONLINE STORE TORONTO, ON")
    assert_equal Date.new(2026, 5, 22), purchase.occurred_on
    assert_equal 1724, purchase.amount_cents
    assert_equal "debit", purchase.direction
    assert_equal "2222", purchase.card_last4

    refund = ExpenseTransaction.find_by!(description: "SAMPLE REFUND")
    assert_equal 499, refund.amount_cents
    assert_equal "credit", refund.direction
  end

  test "does not duplicate an imported row" do
    csv = "2026-05-22,\"SAMPLE ONLINE STORE TORONTO, ON\",17.24,,1111********2222\n"

    assert_difference -> { ExpenseTransaction.count }, 1 do
      StatementCsvImporter.new(io: StringIO.new(csv), filename: "sample.csv", user: users(:one)).call
    end

    assert_no_difference -> { ExpenseTransaction.count } do
      StatementCsvImporter.new(io: StringIO.new(csv), filename: "sample.csv", user: users(:one)).call
    end
  end

  test "matches existing transactions by natural fields without moving their original import batch" do
    original_batch = import_batches(:statement)
    transaction = ExpenseTransaction.create!(
      occurred_on: Date.new(2026, 5, 22),
      description: "SAMPLE ONLINE STORE TORONTO, ON",
      amount_cents: 1724,
      direction: "debit",
      card_last4: "2222",
      source: "statement_csv",
      external_id: "legacy-id",
      import_batch: original_batch,
      user: users(:one)
    )

    csv = "2026-05-22,\"SAMPLE ONLINE STORE TORONTO, ON\",17.24,,1111********2222\n"

    assert_no_difference -> { ExpenseTransaction.count } do
      batch = StatementCsvImporter.new(io: StringIO.new(csv), filename: "reimport.csv", user: users(:one)).call
      assert_equal 0, batch.transactions_count
    end

    assert_equal original_batch, transaction.reload.import_batch
    assert_equal "legacy-id", transaction.external_id
  end
end
