class ClassificationsController < ApplicationController
  def create
    if (active_run = ClassificationRun.active.latest.first)
      redirect_to root_path, alert: "Classification is already #{active_run.status}."
      return
    end

    run = ClassificationRun.create!(total_count: ExpenseTransaction.unclassified.count)
    job = ClassifyTransactionsJob.perform_later(run.id)
    run.update!(active_job_id: job.job_id)

    redirect_to root_path, notice: "Queued fast classification for #{run.total_count} unclassified transactions."
  end
end
