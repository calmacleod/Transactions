class AiPreferencesController < ApplicationController
  def show
    this_month = current_user.ai_requests.this_month
    selectable_models = Model.user_selectable.ordered.limit(20)
    selected_model = current_user.preferred_ai_model.presence || selectable_models.first&.model_id

    render inertia: {
      selected_model:,
      selectable_models: selectable_models.map { |model| model_option_props(model) },
      usage: {
        month_count: this_month.count,
        month_success_count: this_month.successful.count,
        estimated_cost_label: money_from_microdollars(ai_request_microdollars(this_month)),
        monthly_request_limit: Ai::Controls.monthly_request_limit,
        remaining_requests: remaining_requests(this_month.count)
      },
      recent_requests: this_month.recent.limit(10).map { |request| request_props(request) },
      actions: {
        update: ai_preferences_path
      }
    }
  end

  def update
    current_user.update!(ai_preferences_params)

    redirect_to ai_preferences_path, notice: "AI settings updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to ai_preferences_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def ai_preferences_params
    params.require(:user).permit(:preferred_ai_model)
  end

  def remaining_requests(month_count)
    limit = Ai::Controls.monthly_request_limit
    return nil if limit.zero?

    [ limit - month_count, 0 ].max
  end

  def request_props(request)
    {
      id: request.id,
      feature: request.feature,
      model: request.model,
      successful: request.successful,
      estimated_cost_label: money_from_microdollars(request_microdollars(request)),
      created_at_label: request.created_at.strftime("%b %-d, %H:%M")
    }
  end

  def request_microdollars(request)
    request.estimated_cost_microdollars.to_i.positive? ? request.estimated_cost_microdollars : request.estimated_cost_cents.to_i * 10_000
  end
end
