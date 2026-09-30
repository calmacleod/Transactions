require "ruby_llm"
require "schematist"

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.openai_api_base = ENV["OPENAI_API_BASE"] if ENV["OPENAI_API_BASE"].present?
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.default_model = ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano")
  config.model_registry_file = Rails.root.join("storage/ruby_llm_models.json").to_s
  # Chats, usage, and the curated model catalog use application-owned tables.
  config.model_registry_store = RubyLLM::Models::Registry::FileStore.new(config.model_registry_file)
end
