class Model < ApplicationRecord
  acts_as_model

  scope :ordered, -> { order(:provider, :name) }
  scope :by_provider, ->(provider) { provider.present? ? where(provider:) : all }
  scope :matching, ->(query) {
    next all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    where("model_id LIKE :query OR name LIKE :query OR family LIKE :query", query: pattern)
  }

  def input_modalities
    Array(modalities&.fetch("input", nil) || modalities&.fetch(:input, nil))
  end

  def output_modalities
    Array(modalities&.fetch("output", nil) || modalities&.fetch(:output, nil))
  end
end
