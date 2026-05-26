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
end
