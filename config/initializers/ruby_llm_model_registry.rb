Rails.application.config.after_initialize do
  next unless Rails.env.development? || Rails.env.production?

  RubyLlmModelImporter.load_cached! if RubyLlmModelImporter.model_table_ready?
end
