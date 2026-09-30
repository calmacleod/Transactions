require "test_helper"

class InsightTransactionTest < ActiveSupport::TestCase
  test "loads only the most recent evidence for each requested insight" do
    user = users(:one)
    insights = 2.times.map do |index|
      user.insights.create!(title: "Evidence #{index}", body: "Evidence", action: "Review", severity: "info")
    end
    transactions = 30.times.map do |index|
      user.expense_transactions.create!(occurred_on: Date.new(2026, 5, 1) + index / 2, description: "Evidence #{index}", amount_cents: 1000, direction: "debit", external_id: "bounded-evidence-#{index}")
    end
    insights.each { |insight| insight.expense_transactions = transactions }
    loaded_transactions = 0
    callback = ->(*arguments) { loaded_transactions += arguments.last[:record_count] if arguments.last[:class_name] == "ExpenseTransaction" }

    evidence = ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      InsightTransaction.recent_for_insights(insights.map(&:id), limit: 25).to_a
    end

    assert_equal 50, evidence.size
    assert_operator loaded_transactions, :<=, 50
    evidence.group_by(&:insight_id).each_value do |links|
      assert_equal transactions.last(25).map(&:id).sort, links.map(&:expense_transaction_id).sort
      assert links.all? { |link| link.association(:expense_transaction).loaded? }
      assert links.all? { |link| link.expense_transaction.association(:subcategories).loaded? }
    end
    assert_empty InsightTransaction.recent_for_insights([], limit: 25)
    assert_empty InsightTransaction.recent_for_insights(insights.map(&:id), limit: 0)
  end
end
