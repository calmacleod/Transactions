class RubyLlmModelImporter
  def self.ensure_loaded!
    return unless model_table_ready?
    return if Model.exists?

    load_cached!
  end

  def self.load_cached!
    RubyLLM.models.load_from_json!
    Model.save_to_database
  end

  def self.refresh!
    Model.refresh!
  end

  def self.model_table_ready?
    ActiveRecord::Base.connection.data_source_exists?("models")
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end
end
