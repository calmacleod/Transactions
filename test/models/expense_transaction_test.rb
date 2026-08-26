require "test_helper"

class ExpenseTransactionTest < ActiveSupport::TestCase
  test "groups spending into Monday-based weeks" do
    ExpenseTransaction.create!(
      user: users(:one),
      occurred_on: Date.new(2026, 5, 17),
      description: "SUNDAY PURCHASE",
      amount_cents: 111,
      direction: "debit",
      external_id: "sunday-week-boundary",
      raw_data: {}
    )
    ExpenseTransaction.create!(
      user: users(:one),
      occurred_on: Date.new(2026, 5, 18),
      description: "MONDAY PURCHASE",
      amount_cents: 222,
      direction: "debit",
      external_id: "monday-week-boundary",
      raw_data: {}
    )

    totals = users(:one).expense_transactions.expenses.group_by_week

    assert_equal 111, totals.fetch(Date.new(2026, 5, 11))
    assert_equal 13_375, totals.fetch(Date.new(2026, 5, 18))
  end

  test "merchant name keeps the merchant while hiding raw descriptor details" do
    transaction = ExpenseTransaction.new(description: "COFFEE HOUSE  #1234 TORONTO ON")

    assert_equal "COFFEE HOUSE", transaction.merchant_name
    assert_equal "1234 TORONTO ON", transaction.description_detail
  end

  test "merchant name falls back to full description when no descriptor delimiter is present" do
    transaction = ExpenseTransaction.new(description: "NEIGHBOURHOOD RESTAURANT")

    assert_equal "NEIGHBOURHOOD RESTAURANT", transaction.merchant_name
    assert_equal "", transaction.description_detail
  end

  test "merchant name preserves asterisks in card statement descriptors" do
    transaction = ExpenseTransaction.new(description: "ABC*5068-ANYTIME FITNE OTTAWA, ON")

    assert_equal "ABC*5068-ANYTIME FITNE OTTAWA, ON", transaction.merchant_name
    assert_equal "", transaction.description_detail
  end
end
