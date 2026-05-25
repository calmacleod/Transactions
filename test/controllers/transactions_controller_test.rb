require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "filters transactions by start and end date" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "2026-05-21", end_date: "2026-05-21" }

    assert_response :success
    assert_includes response.body, "Showing transactions"
    assert_includes response.body, "May 21, 2026"
    assert_includes response.body, "NEIGHBOURHOOD RESTAURANT"
    assert_no_match "LOCAL GROCERY MARKET", response.body
  end

  test "ignores invalid date filters" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "not-a-date" }

    assert_response :success
  end
end
