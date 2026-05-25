class ClassificationsController < ApplicationController
  def create
    count = ExpenseTransaction.unclassified.count
    ClassifyTransactionsJob.perform_later

    redirect_to root_path, notice: "Queued classification for #{count} unclassified transactions."
  end
end
