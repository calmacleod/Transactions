require "test_helper"

class SavedTransactionQueryTest < ActiveSupport::TestCase
  test "requires a unique name per user" do
    user = users(:one)
    user.saved_transaction_queries.create!(name: "MTD dining", filters: { "quick_range" => "month_to_date" })

    duplicate = user.saved_transaction_queries.new(name: "MTD dining", filters: { "direction" => "debit" })

    assert_not duplicate.valid?
  end
end
