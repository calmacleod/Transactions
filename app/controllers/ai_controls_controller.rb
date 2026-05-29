class AiControlsController < ApplicationController
  before_action :require_admin_user

  def show
    render inertia: ai_controls_props
  end

  def update
    settings_params.each do |key, value|
      AiSetting.set(key, value)
    end

    redirect_to admin_ai_controls_path, notice: "AI controls updated."
  end

  private

  def ai_controls_props
    requests = AiRequest.recent.limit(20)
    this_month = AiRequest.this_month
    selectable_models = Model.user_selectable.ordered.limit(20)

    {
      settings: AiSetting.values,
      selectable_models: selectable_models.map { |model| model_option_props(model) },
      provider_status: {
        configured: Ai::Controls.provider_configured?,
        openai: ENV["OPENAI_API_KEY"].present?,
        anthropic: ENV["ANTHROPIC_API_KEY"].present?,
        gemini: ENV["GEMINI_API_KEY"].present?
      },
      usage: {
        month_count: this_month.count,
        month_success_count: this_month.successful.count,
        estimated_cost_label: money_from_microdollars(ai_request_microdollars(this_month)),
        monthly_request_limit: Ai::Controls.monthly_request_limit,
        remaining_requests: remaining_requests(this_month.count)
      },
      feature_statuses: %i[classification insights chat].map do |feature|
        {
          feature: feature.to_s,
          enabled: Ai::Controls.enabled?(feature),
          setting_key: Ai::Controls::FEATURES.fetch(feature),
          request_count: this_month.where(feature: feature.to_s).count
        }
      end,
      recent_requests: requests.map { |request| request_props(request) },
      actions: {
        update: admin_ai_controls_path
      }
    }
  end

  def settings_params
    params.require(:ai_settings).permit(:model, :classification_model, :insights_model, :chat_model, :classification_enabled, :insights_enabled, :chat_enabled, :monthly_request_limit)
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
      input_tokens: request.input_tokens,
      output_tokens: request.output_tokens,
      estimated_cost_label: money_from_microdollars(request_microdollars(request)),
      error_message: request.error_message,
      created_at_label: request.created_at.strftime("%b %-d, %H:%M")
    }
  end

  def request_microdollars(request)
    request.estimated_cost_microdollars.to_i.positive? ? request.estimated_cost_microdollars : request.estimated_cost_cents.to_i * 10_000
  end
end
