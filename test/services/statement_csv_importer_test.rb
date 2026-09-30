require "test_helper"
require "stringio"

class StatementCsvImporterTest < ActiveSupport::TestCase
  test "previews headerless statement rows without creating transactions" do
    csv = StringIO.new(<<~CSV)
      2026-05-22,"SAMPLE ONLINE STORE TORONTO, ON",17.24,,1111********2222
      2026-05-20,"SAMPLE REFUND",,4.99,1111********2222
    CSV

    assert_no_difference -> { ExpenseTransaction.count } do
      batch = StatementCsvImporter.new(io: csv, filename: "sample.csv", user: users(:one)).preview

      assert_equal "preview", batch.status
      assert_equal 2, batch.rows_count
      assert_equal 2, batch.transactions_count
      assert_equal [ "SAMPLE ONLINE STORE TORONTO, ON", "SAMPLE REFUND" ], batch.import_rows.ordered.pluck(:description)
    end
  end

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

  test "commits edited preview rows with manual categories" do
    batch = users(:one).import_batches.create!(filename: "edited.csv", imported_at: Time.current, status: "preview")
    rows = [
      {
        occurred_on: "2026-05-22",
        description: "Edited merchant",
        amount: "19.99",
        direction: "debit",
        card_last4: "4444",
        category_id: categories(:restaurants).id
      }
    ]

    assert_difference -> { ExpenseTransaction.count }, 1 do
      StatementCsvImporter.new(io: StringIO.new, filename: "edited.csv", user: users(:one)).commit(batch:, rows:)
    end

    transaction = ExpenseTransaction.find_by!(description: "Edited merchant")
    assert_equal categories(:restaurants), transaction.category
    assert_equal "manual", transaction.classification_source
    assert_equal 1999, transaction.amount_cents
    assert_equal "complete", batch.reload.status
    assert_equal 1, batch.import_rows.count
  end

  test "committing automatic suggestions preserves provenance and does not train manual history" do
    importer = StatementCsvImporter.new(io: StringIO.new("2026-05-22,BULK BARN #041,17.24,,2222\n"), filename: "automatic.csv", user: users(:one))
    batch = importer.preview
    ClassifyImportRowsJob.perform_now(batch.id, users(:one).id)
    row = batch.import_rows.first

    importer.commit(batch:, rows: [ row.transaction_attributes.merge(id: row.id) ])

    transaction = batch.expense_transactions.first
    assert_equal "public", transaction.classification_source
    assert_equal row.classification_reason, transaction.classification_reason
    assert_equal row.classification_confidence, transaction.classification_confidence
    assert_equal row.classified_at, transaction.classified_at
    assert_equal "classified", batch.import_rows.first.classification_status
  end

  test "changing a preview category records a manual choice for future imports" do
    importer = StatementCsvImporter.new(io: StringIO.new("2026-05-22,BULK BARN #041,17.24,,2222\n"), filename: "manual.csv", user: users(:one))
    batch = importer.preview
    ClassifyImportRowsJob.perform_now(batch.id, users(:one).id)
    row = batch.import_rows.first

    importer.commit(batch:, rows: [ row.transaction_attributes.merge(id: row.id, category_id: categories(:restaurants).id) ])

    assert_equal "manual", batch.expense_transactions.first.classification_source
    assert_equal "manual", batch.import_rows.first.classification_status
    result = ImportPreviewClassifier.new(user: users(:one)).call(ImportRow.new(description: "BULK BARN #095", direction: "debit"))
    assert_equal categories(:restaurants), result.category
    assert_equal "history", result.source
  end

  test "explicit manual selection is preserved even if it equals the automatic category" do
    importer = StatementCsvImporter.new(io: StringIO.new("2026-05-22,BULK BARN #041,17.24,,2222\n"), filename: "manual.csv", user: users(:one))
    batch = importer.preview
    ClassifyImportRowsJob.perform_now(batch.id, users(:one).id)
    row = batch.import_rows.first

    importer.commit(batch:, rows: [ row.transaction_attributes.merge(id: row.id, manually_classified: true) ])

    assert_equal "manual", batch.expense_transactions.first.classification_source
  end
end
