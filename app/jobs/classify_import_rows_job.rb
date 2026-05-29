class ClassifyImportRowsJob < ApplicationJob
  queue_as :default

  def perform(import_batch_id, user_id = nil)
    user = User.find_by(id: user_id)
    batch = (user&.import_batches || ImportBatch.all).find(import_batch_id)
    classifier = ImportPreviewClassifier.new(user: batch.user)

    batch.import_rows.includes(:category).ordered.find_each do |row|
      result = classifier.call(row)
      row.update!(
        category: result.category,
        classification_status: "classified",
        classification_confidence: result.confidence,
        classification_reason: result.reason,
        classified_at: Time.current
      )
      ImportBatchChannel.broadcast_row(row.reload)
    rescue StandardError => error
      row.update!(
        classification_status: "failed",
        classification_reason: error.message
      )
      ImportBatchChannel.broadcast_row(row.reload)
    end
  end
end
