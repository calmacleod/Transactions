require "test_helper"

class AiControlsControllerTest < ActionDispatch::IntegrationTest
  test "shows AI settings and usage visibility" do
    sign_in_as users(:one)
    AiRequest.create!(feature: "chat", model: "test-model", successful: true)
    Model.create!(provider: "openai", model_id: "visible-model", name: "Visible Model", user_selectable: true)

    get admin_ai_controls_path

    assert_response :success
    assert_equal "gpt-5-nano", inertia_props["settings"]["model"]
    assert_equal 1, inertia_props["usage"]["month_count"]
    assert_equal [ "visible-model" ], inertia_props["selectable_models"].map { |model| model["model_id"] }
  end

  test "updates AI controls" do
    sign_in_as users(:one)

    patch admin_ai_controls_path,
      params: {
        ai_settings: {
          model: "gpt-5-mini",
          classification_enabled: "false",
          insights_enabled: "true",
          chat_enabled: "false",
          monthly_request_limit: "12"
        }
      }

    assert_redirected_to admin_ai_controls_path
    assert_equal "gpt-5-mini", AiSetting.get("model")
    assert_equal false, AiSetting.enabled?("classification_enabled")
    assert_equal "12", AiSetting.get("monthly_request_limit")
  end

  test "redirects regular users" do
    sign_in_as users(:two)

    get admin_ai_controls_path

    assert_redirected_to root_path
  end
end
