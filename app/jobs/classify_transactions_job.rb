class ClassifyTransactionsJob < ApplicationJob
  queue_as :default

  def perform(transaction_ids = nil)
    scope = transaction_ids.present? ? ExpenseTransaction.where(id: transaction_ids) : ExpenseTransaction.unclassified

    Ai::TransactionClassifier.new.classify_all(scope)
  end
end
