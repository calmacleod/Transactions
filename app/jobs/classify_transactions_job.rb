class ClassifyTransactionsJob < ApplicationJob
  queue_as :default

  def perform(classification_run_id, transaction_ids = nil)
    run = ClassificationRun.find(classification_run_id)
    scope = transaction_ids.present? ? ExpenseTransaction.where(id: transaction_ids) : ExpenseTransaction.unclassified

    TransactionClassification::FastPass.new(run:).call(scope)
  end
end
