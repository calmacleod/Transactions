module Ai
  class Controls
    class ModelUnavailableError < StandardError; end

    FEATURES = {
      classification: "classification_enabled",
      insights: "insights_enabled",
      chat: "chat_enabled"
    }.freeze
    FEATURE_CAPABILITIES = {
      classification: %w[structured_output],
      insights: %w[structured_output],
      chat: %w[function_calling]
    }.freeze
    PROVIDER_API_KEYS = {
      "anthropic" => "ANTHROPIC_API_KEY",
      "gemini" => "GEMINI_API_KEY",
      "openai" => "OPENAI_API_KEY"
    }.freeze

    def self.model
      AiSetting.get("model")
    end

    def self.model_for(feature, user: Current.user, requested: nil)
      model_record_for(feature, user:, requested:)&.model_id
    end

    def self.model_record_for(feature, user: Current.user, requested: nil)
      feature = feature.to_sym

      return eligible_model(requested, feature) if requested.present?

      preferred_model = user&.preferred_ai_model
      preferred = eligible_model(preferred_model, feature, user_selectable: true)
      return preferred if preferred

      configured_model_ids(feature).each do |model_id|
        configured = eligible_model(model_id, feature)
        return configured if configured
      end

      available_models_for(feature).first
    end

    def self.model_for!(feature, user: Current.user, requested: nil)
      model_record_for!(feature, user:, requested:).model_id
    end

    def self.model_record_for!(feature, user: Current.user, requested: nil)
      model_record_for(feature, user:, requested:) || raise(ModelUnavailableError, "No configured RubyLLM model supports #{feature}")
    end

    def self.available_models_for(feature, scope: Model.all)
      unambiguous_models(scope.ordered.select { |candidate| candidate.supports_feature?(feature) && provider_configured?(candidate.provider) })
    end

    def self.selectable_models
      candidates = Model.user_selectable.ordered.select { |candidate| candidate.supports_app_features? && provider_configured?(candidate.provider) }
      unambiguous_models(candidates)
    end

    def self.required_capabilities(feature)
      FEATURE_CAPABILITIES.fetch(feature.to_sym)
    end

    def self.enabled?(feature)
      return false unless provider_configured?
      return false unless AiSetting.enabled?(FEATURES.fetch(feature))
      return false if model_for(feature).blank?

      monthly_request_limit.zero? || AiRequest.this_month.count < monthly_request_limit
    end

    def self.provider_configured?(provider = nil)
      return PROVIDER_API_KEYS.values.any? { |key| ENV[key].present? } if provider.blank?

      key = PROVIDER_API_KEYS[provider.to_s]
      key.present? && ENV[key].present?
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
        error_message: error&.message,
        user: Current.user
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

    def self.configured_model_ids(feature)
      feature_setting = AiSetting.find_by(key: "#{feature}_model")&.value.presence

      [
        feature_setting,
        ENV["RUBYLLM_#{feature.to_s.upcase}_MODEL"].presence,
        model,
        ENV["RUBYLLM_MODEL"].presence,
        RubyLLM.config.default_model
      ].compact_blank.uniq
    end
    private_class_method :configured_model_ids

    def self.eligible_model(model_id, feature, user_selectable: false)
      return if model_id.blank?

      candidates = Model.where(model_id:).select do |candidate|
        (!user_selectable || candidate.user_selectable?) && candidate.supports_feature?(feature) && provider_configured?(candidate.provider)
      end

      candidates.one? ? candidates.first : nil
    end
    private_class_method :eligible_model

    def self.unambiguous_models(models)
      models.group_by(&:model_id).values.filter_map { |matches| matches.first if matches.one? }
    end
    private_class_method :unambiguous_models
  end
end
