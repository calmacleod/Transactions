class RubyLlmModelImporter
  def self.ensure_loaded!
    return unless model_table_ready?
    return if Model.exists?

    load_cached!
  end

  def self.load_cached!
    RubyLLM.models.load_from_json
    save_models!
  end

  def self.refresh!
    RubyLLM.models.refresh
    save_models!
  end

  def self.save_models!
    attributes = RubyLLM.models.map do |model|
      {
        model_id: model.id,
        provider: model.provider,
        name: model.name,
        family: model.family,
        model_created_at: model.created_at,
        context_window: model.context_window,
        max_output_tokens: model.max_output_tokens,
        knowledge_cutoff: model.knowledge_cutoff,
        modalities: model.modalities.to_h,
        capabilities: model.capabilities,
        pricing: model.pricing.to_h,
        metadata: model.metadata
      }
    end
    Model.upsert_all(attributes, unique_by: %i[provider model_id]) if attributes.any?
  end
  private_class_method :save_models!

  def self.model_table_ready?
    ActiveRecord::Base.connection.data_source_exists?("models")
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end
end
