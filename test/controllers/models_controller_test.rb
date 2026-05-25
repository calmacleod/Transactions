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

    singleton = RubyLlmModelImporter.singleton_class
    singleton.alias_method :refresh_without_test!, :refresh!
    RubyLlmModelImporter.define_singleton_method(:refresh!) { true }

    post models_path

    assert_redirected_to models_path
  ensure
    singleton&.alias_method :refresh!, :refresh_without_test!
    singleton&.remove_method :refresh_without_test!
  end
end
