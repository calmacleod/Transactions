require "test_helper"

class RubyLlmConfigurationTest < ActiveSupport::TestCase
  test "selects the new acts_as API before the Rails application initializes" do
    application_config = Rails.root.join("config/application.rb").read
    initializer_config = Rails.root.join("config/initializers/ruby_llm.rb").read

    api_selection = application_config.index("config.use_new_acts_as = true")
    application_definition = application_config.index("module Transactions")

    assert api_selection, "Expected config/application.rb to select RubyLLM's new acts_as API"
    assert_operator api_selection, :<, application_definition
    refute_includes initializer_config, "use_new_acts_as"
  end

  test "loads model registry behavior from the new Active Record integration" do
    assert_includes ActiveRecord::Base.ancestors, RubyLLM::ActiveRecord::ActsAs
    assert_respond_to Model, :save_to_database
    assert_respond_to Model.new, :to_llm
  end
end
