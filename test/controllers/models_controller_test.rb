require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "loads and lists RubyLLM models" do
    sign_in_as users(:one)
    Model.delete_all

    get models_path

    assert_response :success
    assert_operator Model.count, :>, 0
    props = inertia_props
    assert_operator props["models"].size, :>, 0
    assert_operator props["stats"]["available_models"], :>, 0
  end

  test "refreshes RubyLLM models" do
    sign_in_as users(:one)

    assert_enqueued_with(job: RefreshRubyLlmModelsJob) do
      post models_path
    end

    assert_redirected_to models_path
  end

  test "updates model favorite status" do
    sign_in_as users(:one)
    model = Model.create!(provider: "openai", model_id: "favorite-model", name: "Favorite Model")

    patch model_path(model), params: { model: { favorite: "true" } }

    assert_redirected_to models_path
    assert_equal true, model.reload.favorite?
  end
end
