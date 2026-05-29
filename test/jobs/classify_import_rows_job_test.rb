require "test_helper"

class ClassifyImportRowsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "classifies import rows and broadcasts row updates" do
    batch = users(:one).import_batches.create!(filename: "preview.csv", status: "preview")
    row = batch.import_rows.create!(
      user: users(:one),
      row_number: 1,
      occurred_on: Date.new(2026, 5, 22),
      description: "TIM HORTONS #6445 ORLEANS, ON",
      amount_cents: 192,
      direction: "debit",
      card_last4: "2222",
      source: StatementCsvImporter::SOURCE,
      external_id: "preview-classify-row"
    )

    assert_broadcasts ImportBatchChannel.broadcasting_for(batch), 1 do
      ClassifyImportRowsJob.perform_now(batch.id, users(:one).id)
    end

    assert_equal categories(:restaurants), row.reload.category
    assert_equal "classified", row.classification_status
    assert_match "local merchant rules", row.classification_reason
  end
end
