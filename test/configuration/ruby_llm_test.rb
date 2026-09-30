require "test_helper"

class RubyLlmConfigurationTest < ActiveSupport::TestCase
  test "uses RubyLLM 2 without legacy Active Record configuration" do
    application_config = Rails.root.join("config/application.rb").read
    initializer_config = Rails.root.join("config/initializers/ruby_llm.rb").read

    refute_includes application_config, "use_new_acts_as"
    refute_includes initializer_config, "use_new_acts_as"
  end

  test "keeps the application model catalog and registry cache local" do
    assert_instance_of RubyLLM::Models::Registry::FileStore, RubyLLM.config.model_registry_store
    assert_equal Rails.root.join("storage/ruby_llm_models.json").to_s, RubyLLM.config.model_registry_file
    assert_equal 1.0, Model.new(pricing: { text_tokens: { standard: { input_per_million: 1.0 } } }).price(:input)
  end
end
