class ClassificationRunsController < ApplicationController
  def show
    @classification_run = ClassificationRun.find(params[:id])
    render partial: "classification_runs/classification_run_frame", locals: { classification_run: @classification_run }
  end

  def cancel
    @classification_run = ClassificationRun.find(params[:id])
    @classification_run.request_cancel!
    @classification_run.cancel! if discard_queued_job(@classification_run)

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "Classification stop requested." }
      format.html { redirect_to root_path, notice: "Classification stop requested." }
    end
  end

  def dismiss
    @classification_run = ClassificationRun.find(params[:id])
    session[:dismissed_classification_run_id] = @classification_run.id

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Classification dismissed." }
    end
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
