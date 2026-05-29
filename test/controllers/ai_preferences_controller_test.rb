require "test_helper"

class AiPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "shows simple user AI settings with usage and curated model options" do
    sign_in_as users(:two)
    visible_model = Model.create!(
      provider: "openai",
      model_id: "visible-model",
      name: "Visible Model",
      capabilities: [ "tools", "structured_output" ],
      modalities: { input: [ "text" ], output: [ "text" ] },
      pricing: { text_tokens: { standard: { input_per_million: 1.0, output_per_million: 2.0 } } },
      user_selectable: true
    )
    Model.create!(provider: "openai", model_id: "hidden-model", name: "Hidden Model")
    AiRequest.create!(feature: "chat", model: visible_model.model_id, estimated_cost_microdollars: 1_250, user: users(:two))

    get ai_preferences_path

    assert_response :success
    assert_equal visible_model.model_id, inertia_props["selected_model"]
    assert_equal [ visible_model.model_id ], inertia_props["selectable_models"].map { |model| model["model_id"] }
    assert_equal 1, inertia_props.dig("usage", "month_count")
    assert_equal "$0.00", inertia_props.dig("usage", "estimated_cost_label")
    assert_equal [ visible_model.model_id ], inertia_props["recent_requests"].map { |request| request["model"] }
  end

  test "updates preferred model when it is user selectable" do
    sign_in_as users(:two)
    model = Model.create!(provider: "openai", model_id: "visible-model", name: "Visible Model", user_selectable: true)

    patch ai_preferences_path, params: { user: { preferred_ai_model: model.model_id } }

    assert_redirected_to ai_preferences_path
    assert_equal model.model_id, users(:two).reload.preferred_ai_model
  end

  test "rejects model preferences that are not user selectable" do
    sign_in_as users(:two)
    Model.create!(provider: "openai", model_id: "hidden-model", name: "Hidden Model")

    patch ai_preferences_path, params: { user: { preferred_ai_model: "hidden-model" } }

    assert_redirected_to ai_preferences_path
    assert_nil users(:two).reload.preferred_ai_model
    assert_equal "Preferred ai model must be available for users", flash[:alert]
  end
end
