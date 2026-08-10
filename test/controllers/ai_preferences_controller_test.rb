require "test_helper"

class AiPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_openai_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
  end

  teardown do
    @old_openai_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = @old_openai_key
  end

  test "shows simple user AI settings with usage and curated model options" do
    sign_in_as users(:two)
    visible_model = Model.create!(
      provider: "openai",
      model_id: "visible-model",
      name: "Visible Model",
      capabilities: Model::APP_CAPABILITIES,
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
    assert_equal "<$0.01", inertia_props.dig("usage", "estimated_cost_label")
    assert_equal [ visible_model.model_id ], inertia_props["recent_requests"].map { |request| request["model"] }
  end

  test "shows cent-level usage once estimated cost crosses a cent" do
    sign_in_as users(:two)
    create_selectable_model("visible-model")
    AiRequest.create!(feature: "chat", model: "visible-model", estimated_cost_microdollars: 20_000, user: users(:two))

    get ai_preferences_path

    assert_response :success
    assert_equal "$0.02", inertia_props.dig("usage", "estimated_cost_label")
  end

  test "updates preferred model when it is user selectable" do
    sign_in_as users(:two)
    model = create_selectable_model("visible-model")

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
    assert_equal "Preferred ai model must uniquely identify a user-selectable text model with tools and structured output", flash[:alert]
  end


  private

  def create_selectable_model(model_id)
    Model.create!(
      provider: "openai",
      model_id:,
      name: model_id.titleize,
      capabilities: Model::APP_CAPABILITIES,
      modalities: { input: [ "text" ], output: [ "text" ] },
      user_selectable: true
    )
  end
end
