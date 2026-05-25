require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "loads and lists RubyLLM models" do
    sign_in_as users(:one)
    Model.delete_all

    get models_path

    assert_response :success
    assert_operator Model.count, :>, 0
    assert_includes response.body, "RubyLLM Models"
    assert_includes response.body, "Available models"
  end

  test "refreshes RubyLLM models" do
    sign_in_as users(:one)

    assert_enqueued_with(job: RefreshRubyLlmModelsJob) do
      post models_path
    end

    assert_redirected_to models_path
  end
end
