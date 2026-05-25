class ClassificationRunsController < ApplicationController
  def show
    @classification_run = ClassificationRun.find(params[:id])
    render partial: "classification_runs/classification_run", locals: { classification_run: @classification_run }
  end

  def cancel
    classification_run = ClassificationRun.find(params[:id])
    classification_run.request_cancel!
    classification_run.cancel! if discard_queued_job(classification_run)

    redirect_to root_path, notice: "Classification stop requested."
  end

  private

  def discard_queued_job(classification_run)
    return unless classification_run.active_job_id.present?

    solid_queue_job = SolidQueue::Job.find_by(active_job_id: classification_run.active_job_id)
    return false unless solid_queue_job&.ready_execution.present?

    solid_queue_job.discard
    true
  rescue NameError, ActiveRecord::StatementInvalid
    false
  end
end
