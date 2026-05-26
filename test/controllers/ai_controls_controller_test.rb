require "test_helper"

class AiControlsControllerTest < ActionDispatch::IntegrationTest
  test "shows AI settings and usage visibility" do
    sign_in_as users(:one)
    AiRequest.create!(feature: "chat", model: "test-model", successful: true)

    get ai_controls_path

    assert_response :success
    assert_equal "gpt-5-nano", inertia_props["settings"]["model"]
    assert_equal 1, inertia_props["usage"]["month_count"]
  end

  test "updates AI controls" do
    sign_in_as users(:one)

    patch ai_controls_path,
      params: {
        ai_settings: {
          model: "gpt-5-mini",
          classification_enabled: "false",
          insights_enabled: "true",
          chat_enabled: "false",
          monthly_request_limit: "12"
        }
      }

    assert_redirected_to ai_controls_path
    assert_equal "gpt-5-mini", AiSetting.get("model")
    assert_equal false, AiSetting.enabled?("classification_enabled")
    assert_equal "12", AiSetting.get("monthly_request_limit")
  end
end
