require "test_helper"

class AiRubyLlmClientTest < ActiveSupport::TestCase
  FakeChat = Struct.new(:response, :instructions, :tools, :schema, keyword_init: true) do
    def with_instructions(value)
      self.instructions = value
      self
    end

    def with_tools(*values)
      self.tools = values
      self
    end

    def with_schema(value)
      self.schema = value
      self
    end

    def ask(_prompt)
      response
    end
  end

  setup do
    @old_openai_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    Model.create!(
      provider: "openai",
      model_id: "integration-model",
      name: "Integration Model",
      capabilities: Model::APP_CAPABILITIES,
      modalities: { input: [ "text" ], output: [ "text" ] }
    )
  end

  teardown do
    @old_openai_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = @old_openai_key
  end

  test "configures RubyLLM chat and records normalized response usage" do
    cost = Struct.new(:total).new(0.001)
    response = Struct.new(:content, :input_tokens, :output_tokens, :cost).new({ "category" => "Pets" }, 12, 4, cost)
    chat = FakeChat.new(response:)
    selected_model = nil
    selected_provider = nil

    with_ruby_llm_chat(->(model:, provider:) { selected_model = model; selected_provider = provider; chat }) do
      result = Ai::RubyLlmClient.new(feature: :classification, model: "integration-model").ask(
        "Classify this",
        schema: TransactionClassificationSchema
      )

      assert_equal response, result
    end

    assert_equal "integration-model", selected_model
    assert_equal "openai", selected_provider
    assert_equal TransactionClassificationSchema, chat.schema
    assert_match "personal finance assistant", chat.instructions

    request = AiRequest.order(:id).last
    assert_equal "classification", request.feature
    assert_equal 12, request.input_tokens
    assert_equal 4, request.output_tokens
    assert_equal 1_000, request.estimated_cost_microdollars
    assert_predicate request, :successful?
  end

  test "rejects an explicit model that does not meet feature requirements" do
    Model.create!(
      provider: "openai",
      model_id: "tools-only",
      name: "Tools Only",
      capabilities: [ "function_calling" ],
      modalities: { input: [ "text" ], output: [ "text" ] }
    )

    assert_raises(Ai::Controls::ModelUnavailableError) do
      Ai::RubyLlmClient.new(feature: :classification, model: "tools-only")
    end
  end

  private

  def with_ruby_llm_chat(replacement)
    original = RubyLLM.method(:chat)
    RubyLLM.define_singleton_method(:chat, &replacement)
    yield
  ensure
    RubyLLM.define_singleton_method(:chat, original)
  end
end
