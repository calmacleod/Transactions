require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "filters transactions by start and end date" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "2026-05-21", end_date: "2026-05-21" }

    assert_response :success
    props = inertia_props
    assert_equal "Showing May 21, 2026 to May 21, 2026", props["date_summary"]
    assert_equal [ "NEIGHBOURHOOD RESTAURANT" ], props["transactions"].map { |transaction| transaction["description"] }
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
    assert_equal({ "count" => 32, "from" => 1, "to" => 25 }, inertia_props["pagination"].slice("count", "from", "to"))

    get transactions_path, params: { page: 2 }

    assert_response :success
    assert_equal({ "count" => 32, "from" => 26, "to" => 32 }, inertia_props["pagination"].slice("count", "from", "to"))
  end

  test "collapses long pagination series with gaps" do
    sign_in_as users(:one)
    import_batch = import_batches(:statement)

    300.times do |index|
      ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 1) + index.days,
        description: "Long pagination transaction #{index}",
        amount_cents: 1000 + index,
        direction: "debit",
        external_id: "long-pagination-row-#{index}",
        raw_data: {},
        import_batch: import_batch
      )
    end

    get transactions_path, params: { page: 6 }

    assert_response :success
    series = inertia_props["pagination"]["pages_series"]
    assert series.any? { |page| page["gap"] }
    assert_operator series.size, :<, inertia_props["pagination"]["pages"]
    assert_equal %w[1 5 6 7 13], series.reject { |page| page["gap"] }.map { |page| page["label"] }
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
    assert_equal({ "count" => 60, "from" => 1, "to" => 50 }, inertia_props["pagination"].slice("count", "from", "to"))
    assert_equal 50, inertia_props["per_page"]

    get transactions_path

    assert_response :success
    assert_equal({ "count" => 60, "from" => 1, "to" => 50 }, inertia_props["pagination"].slice("count", "from", "to"))

    get transactions_path, params: { limit: 500 }

    assert_response :success
    assert_equal({ "count" => 60, "from" => 1, "to" => 50 }, inertia_props["pagination"].slice("count", "from", "to"))
  end

  test "can show all filtered transactions and persist that page size" do
    sign_in_as users(:one)
    import_batch = import_batches(:statement)

    58.times do |index|
      ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 1) + index.days,
        description: "All page size transaction #{index}",
        amount_cents: 1000 + index,
        direction: "debit",
        external_id: "all-page-size-row-#{index}",
        raw_data: {},
        import_batch: import_batch
      )
    end

    get transactions_path, params: { limit: "all" }

    assert_response :success
    assert_equal({ "count" => 60, "from" => 1, "to" => 60 }, inertia_props["pagination"].slice("count", "from", "to"))
    assert_equal "all", inertia_props["per_page"]

    get transactions_path

    assert_response :success
    assert_equal({ "count" => 60, "from" => 1, "to" => 60 }, inertia_props["pagination"].slice("count", "from", "to"))
  end

  test "updates transaction category" do
    sign_in_as users(:one)
    transaction = expense_transactions(:grocery)

    patch transaction_path(transaction),
      params: { expense_transaction: { category_id: categories(:restaurants).id } }

    assert_redirected_to transactions_path
    assert_equal categories(:restaurants), transaction.reload.category
  end

  test "bulk updates selected transaction categories" do
    sign_in_as users(:one)
    grocery = expense_transactions(:grocery)
    restaurant = expense_transactions(:restaurant)

    patch bulk_update_transactions_path,
      params: {
        bulk_transaction: {
          category_id: categories(:groceries).id,
          transaction_ids: [ grocery.id, restaurant.id ]
        }
      }

    assert_redirected_to transactions_path
    assert_equal categories(:groceries), grocery.reload.category
    assert_equal categories(:groceries), restaurant.reload.category
  end

  test "bulk update can clear selected transaction categories" do
    sign_in_as users(:one)
    grocery = expense_transactions(:grocery)
    restaurant = expense_transactions(:restaurant)

    patch bulk_update_transactions_path,
      params: {
        bulk_transaction: {
          category_id: "",
          transaction_ids: [ grocery.id, restaurant.id ]
        }
      }

    assert_redirected_to transactions_path
    assert_nil grocery.reload.category
    assert_nil restaurant.reload.category
  end
end
