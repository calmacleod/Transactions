require "test_helper"

class SavedTransactionQueriesControllerTest < ActionDispatch::IntegrationTest
  test "creates a saved transaction query" do
    sign_in_as users(:one)

    assert_difference -> { users(:one).saved_transaction_queries.count }, 1 do
      post saved_transaction_queries_path, params: {
        name: "Recent restaurants",
        filters: {
          quick_range: "last_30_days",
          category_id: categories(:restaurants).id,
          direction: "debit"
        }
      }
    end

    assert_redirected_to transactions_path(saved_query_id: SavedTransactionQuery.last.id)
    assert_equal "last_30_days", SavedTransactionQuery.last.filters["quick_range"]
  end

  test "destroys a saved transaction query" do
    sign_in_as users(:one)
    saved_query = users(:one).saved_transaction_queries.create!(name: "Groceries", filters: { "category_id" => categories(:groceries).id })

    assert_difference -> { users(:one).saved_transaction_queries.count }, -1 do
      delete saved_transaction_query_path(saved_query)
    end

    assert_redirected_to transactions_path
  end
end
