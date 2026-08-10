require "test_helper"

class AiControlsTest < ActiveSupport::TestCase
  setup do
    @old_openai_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
  end

  teardown do
    @old_openai_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = @old_openai_key
  end

  test "estimates request cost from model pricing" do
    Model.create!(
      provider: "openai",
      model_id: "priced-model",
      name: "Priced model",
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 3.0
          }
        }
      }
    )

    cents = Ai::Controls.estimated_cost_cents("priced-model", 500_000, 250_000)

    assert_equal 125, cents
  end

  test "reads token counts and cost directly from RubyLLM message responses" do
    cost = Struct.new(:total).new(0.00125)
    response = Struct.new(:input_tokens, :output_tokens, :cost).new(500_000, 250_000, cost)

    assert_equal 500_000, Ai::Controls.token_count(response, :input_tokens)
    assert_equal 250_000, Ai::Controls.token_count(response, :output_tokens)
    assert_equal 1_250, Ai::Controls.estimated_cost_microdollars("any-model", response)
  end

  test "resolves feature specific models with default fallback" do
    create_chat_model("default-model")
    create_chat_model("chat-model")
    AiSetting.set("model", "default-model")
    AiSetting.set("chat_model", "chat-model")

    assert_equal "chat-model", Ai::Controls.model_for(:chat)
    assert_equal "default-model", Ai::Controls.model_for(:insights)
  end

  test "uses a user's selected model when admins have made it selectable" do
    create_chat_model("user-model", user_selectable: true)
    create_chat_model("chat-model")
    users(:two).update!(preferred_ai_model: "user-model")
    AiSetting.set("chat_model", "chat-model")

    assert_equal "user-model", Ai::Controls.model_for(:chat, user: users(:two))
  end

  test "ignores user model preferences that are no longer selectable" do
    model = create_chat_model("temporary-model", user_selectable: true)
    create_chat_model("chat-model")
    users(:two).update!(preferred_ai_model: "temporary-model")
    model.update!(user_selectable: false)
    AiSetting.set("chat_model", "chat-model")

    assert_equal "chat-model", Ai::Controls.model_for(:chat, user: users(:two))
  end

  test "falls back when a selected model lacks a feature capability" do
    create_chat_model("tools-only", capabilities: [ "function_calling" ], user_selectable: false)
    create_chat_model("structured-model")
    AiSetting.set("classification_model", "tools-only")
    AiSetting.set("model", "structured-model")

    assert_equal "structured-model", Ai::Controls.model_for(:classification)
  end

  test "does not select a model whose provider has no configured key" do
    Model.create!(
      provider: "anthropic",
      model_id: "anthropic-model",
      name: "Anthropic Model",
      capabilities: Model::APP_CAPABILITIES,
      modalities: text_modalities
    )
    AiSetting.set("chat_model", "anthropic-model")

    assert_nil Ai::Controls.model_for(:chat)
  end

  test "raises a clear error when no model is eligible" do
    error = assert_raises(Ai::Controls::ModelUnavailableError) { Ai::Controls.model_for!(:chat) }

    assert_match "No configured RubyLLM model supports chat", error.message
  end

  test "rejects an ambiguous model id when multiple configured providers expose it" do
    old_anthropic_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    create_chat_model("shared-model")
    Model.create!(
      provider: "anthropic",
      model_id: "shared-model",
      name: "Shared Model",
      capabilities: Model::APP_CAPABILITIES,
      modalities: text_modalities
    )
    AiSetting.set("chat_model", "shared-model")

    assert_nil Ai::Controls.model_for(:chat)
  ensure
    old_anthropic_key.nil? ? ENV.delete("ANTHROPIC_API_KEY") : ENV["ANTHROPIC_API_KEY"] = old_anthropic_key
  end

  private

  def create_chat_model(model_id, capabilities: Model::APP_CAPABILITIES, user_selectable: false)
    Model.create!(
      provider: "openai",
      model_id:,
      name: model_id.titleize,
      capabilities:,
      modalities: text_modalities,
      user_selectable:
    )
  end

  def text_modalities
    { input: [ "text" ], output: [ "text" ] }
  end
end
