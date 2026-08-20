require "ruby_llm"
require "ruby_llm/schema"

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.openai_api_base = ENV["OPENAI_API_BASE"] if ENV["OPENAI_API_BASE"].present?
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.default_model = ENV.fetch("RUBYLLM_MODEL", "gpt-5-nano")
end
