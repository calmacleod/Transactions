require "test_helper"

class OfflineControllerTest < ActionDispatch::IntegrationTest
  test "offline page requires authentication" do
    get offline_path

    assert_redirected_to new_session_path
  end

  test "offline page exposes snapshot path" do
    sign_in_as users(:one)

    get offline_path

    assert_response :success
    assert_equal "offline/show", inertia_page.fetch("component")
    assert_equal offline_snapshot_path(format: :json), inertia_props.fetch("snapshot_path")
  end

  test "snapshot returns read only app data for the current user" do
    sign_in_as users(:one)

    get offline_snapshot_path(format: :json)

    assert_response :success
    snapshot = JSON.parse(response.body)
    pages = snapshot.fetch("pages")

    assert_equal %w[dashboard transactions spending budgets insights subcategories], pages.keys
    assert_equal transactions_path, snapshot.dig("paths", "transactions")
    assert_equal [ "NEIGHBOURHOOD RESTAURANT", "LOCAL GROCERY MARKET" ], pages.dig("transactions", "transactions").map { |transaction| transaction.fetch("description") }
    assert_equal 2, pages.dig("transactions", "pagination", "count")
    assert_equal "Showing offline snapshot", pages.dig("transactions", "date_summary")
    assert pages.dig("dashboard", "metrics", "total_spend_label").present?
    assert pages.dig("spending", "monthly_totals").any?
    assert pages.dig("budgets", "categories").any?
    assert pages.dig("subcategories", "subcategories").any?

    refute pages.dig("transactions", "transactions").first.key?("update_path")
    refute pages.dig("budgets", "categories").first.key?("update_path")
    refute pages.dig("subcategories", "subcategories").first.key?("destroy_path")
  end
end
