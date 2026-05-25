class ClassificationsController < ApplicationController
  def create
    scope = ExpenseTransaction.unclassified
    count = scope.count
    Ai::TransactionClassifier.new.classify_all(scope)

    redirect_to root_path, notice: "Classified #{count} transactions."
  end
end
