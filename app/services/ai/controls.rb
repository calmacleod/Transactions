module Ai
  class Controls
    FEATURES = {
      classification: "classification_enabled",
      insights: "insights_enabled",
      chat: "chat_enabled"
    }.freeze

    def self.model
      AiSetting.get("model")
    end

    def self.model_for(feature)
      key = "#{feature}_model"
      configured = AiSetting.find_by(key:)&.value.presence
      return configured if configured.present?

      ENV["RUBYLLM_#{feature.to_s.upcase}_MODEL"].presence || model
    end

    def self.enabled?(feature)
      return false unless provider_configured?
      return false unless AiSetting.enabled?(FEATURES.fetch(feature))

      monthly_request_limit.zero? || AiRequest.this_month.count < monthly_request_limit
    end

    def self.provider_configured?
      ENV.values_at("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY").any?(&:present?)
    end

    def self.monthly_request_limit
      AiSetting.get("monthly_request_limit").to_i.clamp(0, 100_000)
    end

    def self.record(feature:, model:, response: nil, successful: true, error: nil)
      input_tokens = token_count(response, :input_tokens)
      output_tokens = token_count(response, :output_tokens)

      AiRequest.create!(
        feature: feature.to_s,
        model:,
        input_tokens:,
        output_tokens:,
        estimated_cost_cents: estimated_cost_cents(model, input_tokens, output_tokens),
        estimated_cost_microdollars: estimated_cost_microdollars(model, response, input_tokens, output_tokens),
        successful:,
        error_message: error&.message
      )
    end

    def self.estimated_cost_cents(model_id, input_tokens, output_tokens)
      (estimated_cost_microdollars(model_id, nil, input_tokens, output_tokens) / 10_000.0).round
    end

    def self.estimated_cost_microdollars(model_id, response = nil, input_tokens = nil, output_tokens = nil)
      response_cost = response_cost_microdollars(response)
      return response_cost if response_cost.present?
      return 0 if model_id.blank? || input_tokens.blank? && output_tokens.blank?

      model = Model.find_by(model_id:)
      if model.present?
        input_per_million = model.input_price_per_million
        output_per_million = model.output_price_per_million
      end

      pricing = model&.pricing || {}
      standard = pricing.dig("text_tokens", "standard") || pricing.dig(:text_tokens, :standard) || {}
      input_per_million ||= standard["input_per_million"] || standard[:input_per_million]
      output_per_million ||= standard["output_per_million"] || standard[:output_per_million]
      return 0 if input_per_million.blank? && output_per_million.blank?

      dollars = (input_tokens.to_i / 1_000_000.0) * input_per_million.to_f
      dollars += (output_tokens.to_i / 1_000_000.0) * output_per_million.to_f
      (dollars * 1_000_000).round
    end

    def self.token_count(response, key)
      return response.public_send(key) if response&.respond_to?(key)

      usage = response&.respond_to?(:usage) ? response.usage : nil
      return if usage.blank?

      usage.respond_to?(key) ? usage.public_send(key) : usage[key.to_s] || usage[key]
    end

    def self.response_cost_microdollars(response)
      return unless response&.respond_to?(:cost)

      total = response.cost&.total
      return if total.blank?

      (total.to_d * 1_000_000).round
    rescue StandardError
      nil
    end
  end
end
