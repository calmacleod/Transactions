require "test_helper"

class ExpenseTransactionTest < ActiveSupport::TestCase
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
