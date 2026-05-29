class ImportBatchChannel < ApplicationCable::Channel
  def subscribed
    batch = current_user.import_batches.find_by(id: params[:import_batch_id])

    if batch.present?
      stream_for batch
    else
      reject
    end
  end

  def self.broadcast_row(row)
    broadcast_to(row.import_batch, {
      type: "row_classified",
      row: {
        id: row.id,
        category_id: row.category_id,
        category: category_payload(row.category),
        classification_status: row.classification_status,
        classification_confidence: row.classification_confidence&.to_f,
        classification_reason: row.classification_reason
      }
    })
  end

  def self.category_payload(category)
    return { id: nil, name: "Unclassified", color: "#71717a" } if category.blank?

    {
      id: category.id,
      name: category.name,
      color: category.color.presence || "#52525b",
      monthly_budget_cents: category.monthly_budget_cents
    }
  end
end
