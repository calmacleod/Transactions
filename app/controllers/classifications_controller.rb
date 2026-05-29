class ClassificationsController < ApplicationController
  def create
    if (active_run = current_user.classification_runs.active.latest.first)
      redirect_to root_path, alert: "Classification is already #{active_run.status}."
      return
    end

    classification_run = current_user.classification_runs.create!(total_count: current_user.expense_transactions.unclassified.count)
    job = ClassifyTransactionsJob.perform_later(classification_run.id, nil, current_user.id)
    classification_run.update!(active_job_id: job.job_id)

    redirect_to root_path, notice: "Queued fast classification for #{classification_run.total_count} unclassified transactions."
  end
end
