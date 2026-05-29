class ClassifyTransactionsJob < ApplicationJob
  queue_as :default

  def perform(classification_run_id, transaction_ids = nil, user_id = nil)
    run = ClassificationRun.find(classification_run_id)
    user = User.find_by(id: user_id) || run.user
    scope = if transaction_ids.present?
      (user&.expense_transactions || ExpenseTransaction.all).where(id: transaction_ids)
    else
      (user&.expense_transactions || ExpenseTransaction.all).unclassified
    end

    TransactionClassification::FastPass.new(run:).call(scope)
  end
end
