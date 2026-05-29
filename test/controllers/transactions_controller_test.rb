require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "filters transactions by start and end date" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "2026-05-21", end_date: "2026-05-21" }

    assert_response :success
    props = inertia_props
    assert_equal "Showing May 21, 2026 to May 21, 2026", props["date_summary"]
    assert_equal [ "NEIGHBOURHOOD RESTAURANT" ], props["transactions"].map { |transaction| transaction["description"] }
    assert_equal ai_chats_path, props.dig("actions", "chats")
  end

  test "ignores invalid date filters" do
    sign_in_as users(:one)

    get transactions_path, params: { start_date: "not-a-date" }

    assert_response :success
  end

  test "sorts transactions by date and amount" do
    sign_in_as users(:one)

    get transactions_path, params: { sort: "date", sort_direction: "asc" }

    assert_response :success
    assert_equal [ "LOCAL GROCERY MARKET", "NEIGHBOURHOOD RESTAURANT" ], inertia_props["transactions"].map { |transaction| transaction["description"] }
    assert_equal({ "field" => "date", "direction" => "asc" }, inertia_props["sort"])

    get transactions_path, params: { sort: "amount", sort_direction: "desc" }

    assert_response :success
    assert_equal [ "NEIGHBOURHOOD RESTAURANT", "LOCAL GROCERY MARKET" ], inertia_props["transactions"].map { |transaction| transaction["description"] }
    assert_equal({ "field" => "amount", "direction" => "desc" }, inertia_props["sort"])
  end

  test "renders transaction subcategories without per-row queries" do
    sign_in_as users(:one)
    ExpenseTransactionSubcategory.create!(
      user: users(:one),
      expense_transaction: expense_transactions(:grocery),
      transaction_subcategory: transaction_subcategories(:work)
    )

    get transactions_path

    assert_response :success
    subcategory_names = inertia_props["transactions"].index_by { |transaction| transaction["description"] }.transform_values do |transaction|
      transaction["subcategories"].map { |subcategory| subcategory["name"] }
    end
    assert_equal [ "Work" ], subcategory_names.fetch("LOCAL GROCERY MARKET")
    assert_equal [ "Gift" ], subcategory_names.fetch("NEIGHBOURHOOD RESTAURANT")
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

  test "updates manual subcategories and notes" do
    sign_in_as users(:one)
    transaction = expense_transactions(:grocery)

    patch transaction_path(transaction),
      params: { expense_transaction: { subcategory_ids: [ transaction_subcategories(:gift).id, transaction_subcategories(:work).id ], notes: "Birthday present accounting note" } }

    assert_redirected_to transactions_path
    assert_equal [ "Gift", "Work" ], transaction.reload.subcategories.by_name.pluck(:name)
    assert_equal "Birthday present accounting note", transaction.notes
  end

  test "passes filtered transaction context to chat endpoint" do
    sign_in_as users(:one)
    AiSetting.set("monthly_request_limit", "1")
    AiRequest.create!(feature: "chat", model: "test-model")

    post chat_transactions_path,
      params: { question: "What did gifts cost?", filters: { subcategory_id: transaction_subcategories(:gift).id } },
      as: :json

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "automatic", body["source"]
    assert_match "disabled", body["answer"]
    assert_equal "complete", body["messages"].last["status"]
  end

  test "creates chat context from selected transactions" do
    sign_in_as users(:one)
    AiSetting.set("monthly_request_limit", "1")
    AiRequest.create!(feature: "chat", model: "test-model")

    post chat_transactions_path,
      params: {
        question: "What stands out?",
        transaction_ids: [ expense_transactions(:grocery).id ]
      },
      as: :json

    assert_response :accepted
    chat = users(:one).ai_chats.last
    assert_equal [ expense_transactions(:grocery).id ], chat.expense_transaction_ids
  end

  test "queues enabled chat requests for async RubyLLM processing" do
    old_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "present"
    sign_in_as users(:one)
    AiSetting.set("monthly_request_limit", "100")

    assert_enqueued_with(job: ProcessAiChatMessageJob) do
      post chat_transactions_path,
        params: {
          question: "What stands out?",
          transaction_ids: [ expense_transactions(:grocery).id ]
        },
        as: :json
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "queued", body["source"]
    assert_equal %w[user assistant], body["messages"].last(2).map { |message| message["role"] }
    assert_equal "queued", body["messages"].last["status"]
  ensure
    old_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = old_key
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
