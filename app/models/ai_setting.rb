class AiSetting < ApplicationRecord
  DEFAULTS = {
    "model" => ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano"),
    "classification_model" => ENV.fetch("RUBYLLM_CLASSIFICATION_MODEL", ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano")),
    "insights_model" => ENV.fetch("RUBYLLM_INSIGHTS_MODEL", ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano")),
    "chat_model" => ENV.fetch("RUBYLLM_CHAT_MODEL", ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano")),
    "classification_enabled" => "true",
    "insights_enabled" => "true",
    "chat_enabled" => "true",
    "monthly_request_limit" => "100"
  }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key:)&.value.presence || DEFAULTS.fetch(key)
  end

  def self.enabled?(key)
    ActiveModel::Type::Boolean.new.cast(get(key))
  end

  def self.set(key, value)
    find_or_initialize_by(key:).tap do |setting|
      setting.value = value
      setting.save!
    end
  end

  def self.values
    DEFAULTS.keys.index_with do |key|
      if key.end_with?("_model")
        find_by(key:)&.value.presence || ENV["RUBYLLM_#{key.delete_suffix('_model').upcase}_MODEL"].presence || get("model")
      else
        get(key)
      end
    end
  end
end
