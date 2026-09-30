class InsightTransaction < ApplicationRecord
  include UserOwned

  belongs_to :insight
  belongs_to :expense_transaction

  def self.recent_for_insights(insight_ids, limit:)
    ranked = where(insight_id: insight_ids).joins(:expense_transaction).select(
      "insight_transactions.id, ROW_NUMBER() OVER (PARTITION BY insight_transactions.insight_id ORDER BY expense_transactions.occurred_on DESC, expense_transactions.id DESC) AS evidence_rank"
    )
    limited_ids = from("(#{ranked.to_sql}) AS ranked").select("ranked.id").where("evidence_rank <= ?", limit)

    where(id: limited_ids).includes(expense_transaction: [ :category, :subcategories ])
  end
end
