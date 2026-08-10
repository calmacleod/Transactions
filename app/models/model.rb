class Model < ApplicationRecord
  acts_as_model

  APP_CAPABILITIES = %w[function_calling structured_output].freeze

  scope :ordered, -> { order(favorite: :desc, provider: :asc, name: :asc) }
  scope :user_selectable, -> { where(user_selectable: true) }
  scope :by_provider, ->(provider) { provider.present? ? where(provider:) : all }
  scope :matching, ->(query) {
    next all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    where("model_id LIKE :query OR name LIKE :query OR family LIKE :query", query: pattern)
  }

  validate :user_selectable_requires_app_capabilities

  def input_modalities
    Array(modalities&.fetch("input", nil) || modalities&.fetch(:input, nil))
  end

  def output_modalities
    Array(modalities&.fetch("output", nil) || modalities&.fetch(:output, nil))
  end

  def supports_capability?(capability)
    capabilities.include?(capability.to_s)
  end

  def supports_text_chat?
    input_modalities.include?("text") && output_modalities.include?("text")
  end

  def supports_feature?(feature)
    supports_text_chat? && Ai::Controls.required_capabilities(feature).all? { |capability| supports_capability?(capability) }
  end

  def supports_app_features?
    supports_text_chat? && APP_CAPABILITIES.all? { |capability| supports_capability?(capability) }
  end

  private

  def user_selectable_requires_app_capabilities
    return unless user_selectable?
    return if supports_app_features?

    errors.add(:user_selectable, "requires text input/output, function calling, and structured output")
  end
end
