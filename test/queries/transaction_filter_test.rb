require "test_helper"

class TransactionFilterTest < ActiveSupport::TestCase
  test "filters by quick range" do
    filter = TransactionFilter.new("quick_range" => "month_to_date")

    assert_equal Date.current.beginning_of_month, filter.start_date
    assert_equal Date.current, filter.end_date
  end

  test "filters by day of week" do
    result = TransactionFilter.new("day_of_week" => "4").call.to_a

    assert_includes result, expense_transactions(:restaurant)
    assert_not_includes result, expense_transactions(:grocery)
  end

  test "filters by amount range and search text" do
    result = TransactionFilter.new("query" => "restaurant", "min_amount" => "70", "max_amount" => "80").call.to_a

    assert_equal [ expense_transactions(:restaurant) ], result
  end
end
