require "test_helper"

class SubcategoriesControllerTest < ActionDispatch::IntegrationTest
  test "lists subcategories" do
    sign_in_as users(:one)

    get subcategories_path

    assert_response :success
    assert_includes inertia_props["subcategories"].map { |subcategory| subcategory["name"] }, "Gift"
  end

  test "creates subcategory" do
    sign_in_as users(:one)

    assert_difference -> { TransactionSubcategory.count } do
      post subcategories_path, params: { transaction_subcategory: { name: "Tax", color: "#0f766e" } }
    end

    assert_redirected_to subcategories_path
  end
end
