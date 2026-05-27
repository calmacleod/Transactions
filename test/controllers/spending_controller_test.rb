require "test_helper"

class SpendingControllerTest < ActionDispatch::IntegrationTest
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
end
