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
    assert_equal 2, transaction_queries.count { |sql| sql.match?(/SUM\((?:"expense_transactions"\.)?"?amount_cents"?\)/) }
    assert transaction_queries.none? { |sql| sql.match?(/SELECT "expense_transactions"\.\*/) }
  end

  test "category day and merchant summaries aggregate expenses without instantiating transactions" do
    user = users(:one)
    user.expense_transactions.create!(occurred_on: Date.new(2026, 5, 23), description: "LOCAL GROCERY MARKET #123", amount_cents: 1000, direction: "debit", external_id: "summary-unclassified")
    user.expense_transactions.create!(occurred_on: Date.new(2026, 5, 23), description: "LOCAL GROCERY MARKET", amount_cents: 9000, direction: "credit", external_id: "summary-credit")
    summary = DashboardSummary.new(range: Date.new(2026, 5, 1)..Date.new(2026, 5, 31), user:)
    loaded_transactions = 0
    callback = ->(*arguments) { loaded_transactions += arguments.last[:record_count] if arguments.last[:class_name] == "ExpenseTransaction" }

    ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      categories = summary.category_totals
      assert_equal 14_153, categories.sum { |category| category[:cents] }
      assert_equal 3, categories.sum { |category| category[:count] }
      unclassified = categories.find { |category| category[:category_id].nil? }
      assert_equal 1000, unclassified[:cents]
      assert_equal "unclassified", unclassified.dig(:filters, :classified)
      assert_equal 7, summary.day_of_week_totals.size
      assert_equal 14_153, summary.day_of_week_totals.sum { |day| day[:cents] }
      merchant = summary.top_merchants.find { |item| item[:merchant] == "local grocery market" }
      assert_equal 6879, merchant[:cents]
      assert_equal 2, merchant[:count]
    end

    assert_equal 0, loaded_transactions
  end
end
