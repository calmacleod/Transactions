require "test_helper"

class InsightTest < ActiveSupport::TestCase
  test "can reference supporting transactions" do
    insight = Insight.create!(
      title: "Restaurants increased",
      body: "Restaurant spending was higher this month.",
      action: "Review restaurant purchases.",
      kind: "category_shift",
      severity: "warning",
      expense_transactions: [ expense_transactions(:restaurant) ]
    )

    assert_equal [ expense_transactions(:restaurant) ], insight.expense_transactions.to_a
  end
end
