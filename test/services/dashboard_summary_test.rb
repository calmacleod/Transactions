require "test_helper"

class DashboardSummaryTest < ActiveSupport::TestCase
  test "memoizes dashboard metrics and aggregates trends without loading transaction records" do
    summary = DashboardSummary.new(
      range: Date.new(2026, 5, 1)..Date.new(2026, 5, 31),
      user: users(:one)
    )
    transaction_queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      transaction_queries << payload[:sql] if payload[:sql].include?('"expense_transactions"')
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      2.times do
        assert_equal 13_153, summary.total_spend_cents
        assert_equal 2, summary.transaction_count
        assert_equal 2, summary.expense_count
        assert_equal 4, summary.month_trend.size
        assert summary.month_to_month_delta.key?(:cents)
      end
    end

    assert_equal 2, transaction_queries.count { |sql| sql.match?(/COUNT\(\*\)/) }
    assert_equal 2, transaction_queries.count { |sql| sql.match?(/SUM\("expense_transactions"\."amount_cents"\)/) }
    assert transaction_queries.none? { |sql| sql.match?(/SELECT "expense_transactions"\.\*/) }
  end
end
