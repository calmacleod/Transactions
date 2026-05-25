class ClassificationsController < ApplicationController
  def create
    if (active_run = ClassificationRun.active.latest.first)
      @classification_run = active_run

      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Classification is already #{active_run.status}."
          render :create, status: :conflict
        end
        format.html { redirect_to root_path, alert: "Classification is already #{active_run.status}." }
      end

      return
    end

    @classification_run = ClassificationRun.create!(total_count: ExpenseTransaction.unclassified.count)
    job = ClassifyTransactionsJob.perform_later(@classification_run.id)
    @classification_run.update!(active_job_id: job.job_id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Queued fast classification for #{@classification_run.total_count} unclassified transactions."
      end
      format.html { redirect_to root_path, notice: "Queued fast classification for #{@classification_run.total_count} unclassified transactions." }
    end
  end
end
