require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  test "shows category budgets and month usage" do
    sign_in_as users(:one)

    get budgets_path, params: { month: "2026-05" }

    assert_response :success
    groceries = inertia_props["categories"].find { |category| category["name"] == "Groceries" }
    assert_equal 5_879, groceries["spent_cents"]
    assert_equal "800.00", groceries["monthly_budget"]
  end

  test "updates category monthly budget" do
    sign_in_as users(:one)

    patch budget_path(categories(:groceries)), params: { category: { monthly_budget: "725.50" } }

    assert_redirected_to budgets_path
    assert_equal 72_550, categories(:groceries).reload.monthly_budget_cents
  end
end
