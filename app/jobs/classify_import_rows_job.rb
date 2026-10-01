class ClassifyImportRowsJob < ApplicationJob
  queue_as :default

  def perform(import_batch_id, user_id = nil)
    user = User.find_by(id: user_id)
    scope = user ? ImportBatch.where(user_id: user.id) : ImportBatch.all
    import_batch = scope.find(import_batch_id)
    classifier = ImportPreviewClassifier.new(user: import_batch.user)

    import_batch.import_rows.includes(:category).ordered.find_each do |row|
      result = classifier.call(row)
      row.update!(
        category_id: result.category&.id,
        classification_status: "classified",
        classification_confidence: result.confidence,
        classification_reason: result.reason,
        classification_source: result.source,
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
