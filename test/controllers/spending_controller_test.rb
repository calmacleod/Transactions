require "test_helper"

class SpendingControllerTest < ActionDispatch::IntegrationTest
  test "shows recent weekly spending with transaction drill-downs" do
    sign_in_as users(:one)

    travel_to Date.new(2026, 5, 29) do
      get spending_path
    end

    assert_response :success
    assert_equal 8, inertia_props["week_trend"].size
    assert_equal "$131.53", inertia_props["week_trend"][-2]["amount_label"]
    assert_equal transactions_path(start_date: "2026-05-18", end_date: "2026-05-24", direction: "debit"), inertia_props["week_trend"][-2]["filters_path"]
    assert_equal "$131.53", inertia_props.dig("completed_week_delta", "label")
  end

  test "shows monthly totals and category history for all recorded months" do
    sign_in_as users(:one)

    get spending_path

    assert_response :success
    props = inertia_props
    assert_equal [ "May 2026" ], props["months"].map { |month| month["label"] }
    assert_equal [ "2026" ], props["months"].map { |month| month["year"] }
    assert_equal 13_153, props["monthly_totals"].first["cents"]
    assert_includes props["category_rows"].map { |row| row["category"]["name"] }, "Groceries"
    assert_includes props["category_rows"].map { |row| row["category"]["name"] }, "Restaurants"
  end

  test "aggregates category history without loading every transaction record" do
    sign_in_as users(:one)
    ExpenseTransaction.create!(
      user: users(:one),
      occurred_on: Date.new(2026, 4, 12),
      description: "Uncategorized historical expense",
      amount_cents: 3210,
      direction: "debit",
      external_id: "uncategorized-history-row",
      raw_data: {}
    )

    transaction_queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      transaction_queries << payload[:sql] if payload[:sql].include?('"expense_transactions"')
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get spending_path
    end

    assert_response :success
    uncategorized = inertia_props["category_rows"].find { |row| row.dig("category", "name") == "Uncategorized" }
    assert_equal 3210, uncategorized["total_cents"]
    assert transaction_queries.none? { |sql| sql.match?(/SELECT "expense_transactions"\.\*/) }
  end
end
