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
    ExpenseTransactionSubcategory.create!(
      user: users(:one),
      expense_transaction: expense_transactions(:grocery),
      transaction_subcategory: transaction_subcategories(:work)
    )
    users(:one).insights.create!(
      title: "Groceries are trending",
      body: "Grocery spending is up.",
      action: "Review grocery purchases.",
      kind: "category_shift",
      severity: "info",
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      expense_transactions: [ expense_transactions(:grocery) ]
    )
    users(:one).insights.create!(
      title: "Restaurants are notable",
      body: "Restaurant spending is notable.",
      action: "Review restaurant purchases.",
      kind: "merchant_frequency",
      severity: "warning",
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      expense_transactions: [ expense_transactions(:restaurant) ]
    )

    get offline_snapshot_path(format: :json)

    assert_response :success
    snapshot = JSON.parse(response.body)
    pages = snapshot.fetch("pages")

    assert_equal %w[dashboard transactions spending budgets insights subcategories], pages.keys
    assert_equal transactions_path, snapshot.dig("paths", "transactions")
    assert_equal [ "NEIGHBOURHOOD RESTAURANT", "LOCAL GROCERY MARKET" ], pages.dig("transactions", "transactions").map { |transaction| transaction.fetch("description") }
    subcategory_names = pages.dig("transactions", "transactions").index_by { |transaction| transaction.fetch("description") }.transform_values do |transaction|
      transaction.fetch("subcategories").map { |subcategory| subcategory.fetch("name") }
    end
    assert_equal [ "Gift" ], subcategory_names.fetch("NEIGHBOURHOOD RESTAURANT")
    assert_equal [ "Work" ], subcategory_names.fetch("LOCAL GROCERY MARKET")
    assert_equal 2, pages.dig("transactions", "pagination", "count")
    assert_equal "Showing offline snapshot", pages.dig("transactions", "date_summary")
    assert pages.dig("dashboard", "metrics", "total_spend_label").present?
    assert pages.dig("spending", "monthly_totals").any?
    assert pages.dig("budgets", "categories").any?
    insight_transactions = pages.dig("insights", "insights").flat_map { |insight| insight.fetch("transactions") }
    assert_includes insight_transactions.map { |transaction| transaction.fetch("description") }, "LOCAL GROCERY MARKET"
    assert_includes insight_transactions.map { |transaction| transaction.fetch("description") }, "NEIGHBOURHOOD RESTAURANT"
    assert pages.dig("subcategories", "subcategories").any?

    refute pages.dig("transactions", "transactions").first.key?("update_path")
    refute pages.dig("budgets", "categories").first.key?("update_path")
    refute pages.dig("subcategories", "subcategories").first.key?("destroy_path")
  end
end
