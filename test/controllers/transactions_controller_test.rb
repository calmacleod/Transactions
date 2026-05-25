require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "filters transactions by start and end date" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "2026-05-21", end_date: "2026-05-21" }

    assert_response :success
    assert_includes response.body, "Showing"
    assert_includes response.body, "May 21, 2026"
    assert_includes response.body, "NEIGHBOURHOOD RESTAURANT"
    assert_no_match "LOCAL GROCERY MARKET", response.body
  end

  test "ignores invalid date filters" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "not-a-date" }

    assert_response :success
  end

  test "paginates transaction list" do
    sign_in_as users(:one)
    import_batch = import_batches(:statement)

    30.times do |index|
      ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 1) + index.days,
        description: "Pagination transaction #{index}",
        amount_cents: 1000 + index,
        direction: "debit",
        external_id: "pagination-row-#{index}",
        raw_data: {},
        import_batch: import_batch
      )
    end

    get transactions_path

    assert_response :success
    assert_includes response.body, "Showing <span>1-25</span> of <span>32</span>"
    assert_includes response.body, 'data-turbo-frame="transactions_list"'

    get transactions_path, params: { page: 2 }

    assert_response :success
    assert_includes response.body, "Showing <span>26-32</span> of <span>32</span>"
  end

  test "persists selected transaction page size for the session" do
    sign_in_as users(:one)
    import_batch = import_batches(:statement)

    58.times do |index|
      ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 1) + index.days,
        description: "Page size transaction #{index}",
        amount_cents: 1000 + index,
        direction: "debit",
        external_id: "page-size-row-#{index}",
        raw_data: {},
        import_batch: import_batch
      )
    end

    get transactions_path, params: { limit: 50 }

    assert_response :success
    assert_includes response.body, "Showing <span>1-50</span> of <span>60</span>"
    assert_includes response.body, '<option selected="selected" value="50">50</option>'

    get transactions_path

    assert_response :success
    assert_includes response.body, "Showing <span>1-50</span> of <span>60</span>"

    get transactions_path, params: { limit: 500 }

    assert_response :success
    assert_includes response.body, "Showing <span>1-50</span> of <span>60</span>"
  end

  test "updates transaction category with turbo stream" do
    sign_in_as users(:one)
    transaction = expense_transactions(:grocery)

    patch transaction_path(transaction),
      params: { expense_transaction: { category_id: categories(:restaurants).id } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :no_content
    assert_equal categories(:restaurants), transaction.reload.category
    assert_empty response.body
  end
end
