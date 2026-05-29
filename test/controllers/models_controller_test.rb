require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "loads and lists RubyLLM models" do
    sign_in_as users(:one)
    Model.delete_all

    get admin_models_path

    assert_response :success
    assert_operator Model.count, :>, 0
    props = inertia_props
    assert_operator props["models"].size, :>, 0
    assert_operator props["stats"]["available_models"], :>, 0
  end

  test "sorts models by requested field and direction" do
    sign_in_as users(:one)
    Model.delete_all
    Model.create!(provider: "openai", model_id: "beta-model", name: "Beta Model")
    Model.create!(provider: "anthropic", model_id: "alpha-model", name: "Alpha Model")

    get admin_models_path, params: { sort: "model", direction: "asc" }

    assert_response :success
    assert_equal [ "Alpha Model", "Beta Model" ], inertia_props["models"].map { |model| model["name"] }
    assert_equal({ "field" => "model", "direction" => "asc" }, inertia_props["sort"])
  end

  test "sorts models by price without raw SQL ordering" do
    sign_in_as users(:one)
    Model.delete_all
    Model.create!(
      provider: "openai",
      model_id: "expensive-model",
      name: "Expensive Model",
      pricing: { text_tokens: { standard: { input_per_million: 8.0 } } }
    )
    Model.create!(
      provider: "anthropic",
      model_id: "cheap-model",
      name: "Cheap Model",
      pricing: { text_tokens: { standard: { input_per_million: 1.5 } } }
    )

    get admin_models_path, params: { sort: "price", direction: "asc" }

    assert_response :success
    assert_equal [ "Cheap Model", "Expensive Model" ], inertia_props["models"].map { |model| model["name"] }
    assert_equal({ "field" => "price", "direction" => "asc" }, inertia_props["sort"])
  end

  test "refreshes RubyLLM models immediately with feedback" do
    sign_in_as users(:one)
    Model.delete_all

    with_model_refresh(-> { Model.create!(provider: "openai", model_id: "fresh-model", name: "Fresh Model") }) do
      post admin_models_path
    end

    assert_redirected_to admin_models_path
    assert_equal "Model registry refreshed. 1 models available (+1).", flash[:notice]
  end

  test "shows feedback when model refresh fails" do
    sign_in_as users(:one)

    with_model_refresh(-> { raise "provider unavailable" }) do
      post admin_models_path
    end

    assert_redirected_to admin_models_path
    assert_equal "Model refresh failed: provider unavailable", flash[:alert]
  end

  test "updates model curation flags" do
    sign_in_as users(:one)
    model = Model.create!(provider: "openai", model_id: "favorite-model", name: "Favorite Model")

    patch admin_model_path(model), params: { model: { favorite: "true", user_selectable: "true" } }

    assert_redirected_to admin_models_path
    assert_equal true, model.reload.favorite?
    assert_equal true, model.user_selectable?
  end

  test "redirects regular users" do
    sign_in_as users(:two)

    get admin_models_path

    assert_redirected_to root_path
  end

  private

  def with_model_refresh(replacement)
    RubyLlmModelImporter.singleton_class.alias_method :refresh_without_test!, :refresh!
    RubyLlmModelImporter.define_singleton_method(:refresh!, &replacement)
    yield
  ensure
    RubyLlmModelImporter.singleton_class.alias_method :refresh!, :refresh_without_test!
    RubyLlmModelImporter.singleton_class.remove_method :refresh_without_test!
  end
end
