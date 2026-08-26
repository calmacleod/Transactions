require "test_helper"

class WeeklySpendingSummaryTest < ActiveSupport::TestCase
  test "builds an eight-week trend with empty weeks and a completed-week comparison" do
    travel_to Date.new(2026, 5, 29) do
      summary = WeeklySpendingSummary.new(user: users(:one))

      trend = summary.trend

      assert_equal 8, trend.size
      assert_equal [ "Apr 6", "Apr 13", "Apr 20", "Apr 27", "May 4", "May 11", "May 18", "May 25" ], trend.pluck(:label)
      assert_equal 13_153, trend.find { |week| week[:label] == "May 18" }[:cents]
      assert_equal 0, trend.find { |week| week[:label] == "May 11" }[:cents]
      assert_equal true, trend.last[:current_week]
      assert_equal({ start_date: "2026-05-25", end_date: "2026-05-29", direction: "debit" }, trend.last[:filters])
      assert_equal({ cents: 13_153, percent: 0 }, summary.completed_week_delta)
    end
  end
end
