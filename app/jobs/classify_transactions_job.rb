class ClassifyTransactionsJob < ApplicationJob
  queue_as :default

  def perform(classification_run_id, transaction_ids = nil, user_id = nil)
    run = ClassificationRun.find(classification_run_id)
    user = User.find_by(id: user_id) || run.user
    transactions = user ? ExpenseTransaction.where(user_id: user.id) : ExpenseTransaction.all
    scope = if transaction_ids.present?
      transactions.where(id: transaction_ids)
    else
      transactions.unclassified
    end

    TransactionClassification::FastPass.new(run:).call(scope)
  end
end
