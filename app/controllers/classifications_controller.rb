class ClassificationsController < ApplicationController
  def create
    if (active_run = ClassificationRun.where(user_id: current_user.id).active.latest.first)
      redirect_to root_path, alert: "Classification is already #{active_run.status}."
      return
    end

    classification_run = ClassificationRun.create!(user_id: current_user.id, total_count: ExpenseTransaction.where(user_id: current_user.id).unclassified.count)
    job = ClassifyTransactionsJob.perform_later(classification_run.id, nil, current_user.id)
    classification_run.update!(active_job_id: job.job_id)

    redirect_to root_path, notice: "Queued fast classification for #{classification_run.total_count} unclassified transactions."
  end
end
