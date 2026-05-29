class ClassificationRunsController < ApplicationController
  def show
    classification_run = current_user.classification_runs.find(params[:id])

    respond_to do |format|
      format.json { render json: { classification_run: classification_run_props(classification_run) } }
      format.html { render inertia: "classification_runs/show", props: { classification_run: classification_run_props(classification_run) } }
    end
  end

  def cancel
    classification_run = current_user.classification_runs.find(params[:id])
    classification_run.request_cancel!
    classification_run.cancel! if discard_queued_job(classification_run)

    redirect_to root_path, notice: "Classification stop requested."
  end

  def dismiss
    classification_run = current_user.classification_runs.find(params[:id])
    session[:dismissed_classification_run_id] = classification_run.id

    redirect_to root_path, notice: "Classification dismissed."
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
