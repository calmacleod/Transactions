require "test_helper"

class AiControlsTest < ActiveSupport::TestCase
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
    AiSetting.set("model", "default-model")
    AiSetting.set("chat_model", "chat-model")

    assert_equal "chat-model", Ai::Controls.model_for(:chat)
    assert_equal "default-model", Ai::Controls.model_for(:insights)
  end

  test "uses a user's selected model when admins have made it selectable" do
    Model.create!(provider: "openai", model_id: "user-model", name: "User Model", user_selectable: true)
    users(:two).update!(preferred_ai_model: "user-model")
    AiSetting.set("chat_model", "chat-model")

    assert_equal "user-model", Ai::Controls.model_for(:chat, user: users(:two))
  end

  test "ignores user model preferences that are no longer selectable" do
    model = Model.create!(provider: "openai", model_id: "temporary-model", name: "Temporary Model", user_selectable: true)
    users(:two).update!(preferred_ai_model: "temporary-model")
    model.update!(user_selectable: false)
    AiSetting.set("chat_model", "chat-model")

    assert_equal "chat-model", Ai::Controls.model_for(:chat, user: users(:two))
  end
end
