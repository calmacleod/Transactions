require "test_helper"
require "stringio"
require "tempfile"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  test "index lists past imports with resume and retained file actions" do
    user = users(:one)
    sign_in_as user
    completed = import_batches(:statement)
    completed.source_file.attach(io: StringIO.new("csv,data\n"), filename: "sample.csv", content_type: "text/csv")
    preview = user.import_batches.create!(filename: "unfinished.csv", rows_count: 3, transactions_count: 0, status: "preview")
    ImportBatch.create!(filename: "other-user.csv", status: "complete", user: users(:two))

    get imports_path

    assert_response :success
    filenames = inertia_props["import_batches"].map { |batch| batch["filename"] }
    assert_includes filenames, "sample.csv"
    assert_includes filenames, "unfinished.csv"
    assert_not_includes filenames, "other-user.csv"

    completed_props = inertia_props["import_batches"].find { |batch| batch["filename"] == "sample.csv" }
    assert_equal "Complete", completed_props["status_label"]
    assert_equal true, completed_props["retained_file"]
    assert_equal download_import_path(completed), completed_props["download_path"]
    assert_equal preview_import_path(completed), completed_props["preview_path"]

    preview_props = inertia_props["import_batches"].find { |batch| batch["filename"] == "unfinished.csv" }
    assert_equal true, preview_props["unfinished"]
    assert_equal 3, preview_props["skipped_count"]
    assert_equal preview_import_path(preview), preview_props["preview_path"]
  end

  test "upload creates a preview batch instead of transactions" do
    sign_in_as users(:one)

    csv = Tempfile.new([ "transactions", ".csv" ])
    csv.write("2026-05-22,\"PREVIEW MERCHANT\",17.24,,1111********2222\n")
    csv.rewind

    assert_enqueued_jobs 1, only: ClassifyImportRowsJob do
      assert_no_difference -> { ExpenseTransaction.count } do
        post imports_path, params: {
          csv_file: Rack::Test::UploadedFile.new(csv.path, "text/csv", original_filename: "preview.csv")
        }
      end
    end

    batch = users(:one).import_batches.order(:created_at).last
    assert_redirected_to preview_import_path(batch)
    assert_equal "preview", batch.status
    assert batch.source_file.attached?
    assert_equal "preview.csv", batch.source_file.filename.to_s
    assert_equal [ "PREVIEW MERCHANT" ], batch.import_rows.pluck(:description)
  ensure
    csv&.close!
  end

  test "upload does not retain source file when user opts out" do
    user = users(:one)
    user.update!(retain_uploaded_csv: false)
    sign_in_as user

    csv = Tempfile.new([ "transactions", ".csv" ])
    csv.write("2026-05-22,\"NO RETAIN MERCHANT\",17.24,,1111********2222\n")
    csv.rewind

    post imports_path, params: {
      csv_file: Rack::Test::UploadedFile.new(csv.path, "text/csv", original_filename: "no-retain.csv")
    }

    batch = user.import_batches.order(:created_at).last
    assert_redirected_to preview_import_path(batch)
    assert_not batch.source_file.attached?
  ensure
    csv&.close!
  end

  test "preview exposes rows and manual category options" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "preview.csv", imported_at: Time.current, status: "preview")
    batch.import_rows.create!(
      user: users(:one),
      row_number: 1,
      occurred_on: Date.new(2026, 5, 22),
      description: "PREVIEW MERCHANT",
      amount_cents: 1724,
      direction: "debit",
      card_last4: "2222",
      source: StatementCsvImporter::SOURCE,
      external_id: "preview-row",
      raw_data: {
        description: "PREVIEW MERCHANT"
      }
    )

    get preview_import_path(batch)

    assert_response :success
    assert_equal "preview.csv", inertia_props.dig("import_batch", "filename")
    assert_equal [ "PREVIEW MERCHANT" ], inertia_props["rows"].map { |row| row["description"] }
    assert_equal "PREVIEW MERCHANT", inertia_props["rows"].first.dig("raw_data", "description")
    assert_includes inertia_props["categories"].map { |category| category["name"] }, "Restaurants"
    assert_equal commit_import_path(batch), inertia_props.dig("actions", "commit")
    assert_equal "ImportBatchChannel", inertia_props.dig("actions", "classification_stream", "channel")
    assert_equal true, inertia_props.dig("import_batch", "active")
    assert_equal false, inertia_props.dig("import_batch", "read_only")
  end

  test "preview marks completed imports as read only" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(
      filename: "finished.csv",
      imported_at: Time.current,
      rows_count: 2,
      transactions_count: 0,
      status: "complete"
    )

    get preview_import_path(batch)

    assert_response :success
    assert_nil inertia_props.dig("actions", "commit")
    assert_nil inertia_props.dig("actions", "classification_stream")
    assert_equal false, inertia_props.dig("import_batch", "active")
    assert_equal true, inertia_props.dig("import_batch", "complete")
    assert_equal true, inertia_props.dig("import_batch", "read_only")
  end

  test "preview marks duplicate rows as skipped by default" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "preview.csv", imported_at: Time.current, status: "preview")
    batch.import_rows.create!(
      user: users(:one),
      row_number: 1,
      occurred_on: expense_transactions(:grocery).occurred_on,
      description: expense_transactions(:grocery).description,
      amount_cents: expense_transactions(:grocery).amount_cents,
      direction: expense_transactions(:grocery).direction,
      card_last4: expense_transactions(:grocery).card_last4,
      source: StatementCsvImporter::SOURCE,
      external_id: expense_transactions(:grocery).external_id
    )

    get preview_import_path(batch)

    row = inertia_props["rows"].first
    assert_equal false, row["included"]
    assert_equal "existing", row.dig("duplicate", "kind")
    assert_match "Already imported", row.dig("duplicate", "label")
  end

  test "downloads retained source csv" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "retained.csv", imported_at: Time.current, status: "preview")
    batch.source_file.attach(io: StringIO.new("csv,data\n"), filename: "retained.csv", content_type: "text/csv")

    get download_import_path(batch)

    assert_response :success
    assert_equal "csv,data\n", response.body
    assert_match "retained.csv", response.headers["Content-Disposition"]
  end

  test "commit imports edited preview rows" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "preview.csv", imported_at: Time.current, status: "preview")

    assert_difference -> { ExpenseTransaction.count }, 1 do
      post commit_import_path(batch), params: {
        import: {
          rows: [
            {
              occurred_on: "2026-05-22",
              description: "EDITED PREVIEW MERCHANT",
              amount: "31.45",
              direction: "debit",
              card_last4: "2222",
              category_id: categories(:groceries).id
            }
          ]
        }
      }
    end

    assert_redirected_to root_path
    transaction = ExpenseTransaction.find_by!(description: "EDITED PREVIEW MERCHANT")
    assert_equal 3145, transaction.amount_cents
    assert_equal categories(:groceries), transaction.category
    assert_equal "complete", batch.reload.status
  end

  test "commit does not rerun completed imports" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(
      filename: "finished.csv",
      imported_at: Time.current,
      rows_count: 1,
      transactions_count: 0,
      status: "complete"
    )

    assert_no_difference -> { ExpenseTransaction.count } do
      post commit_import_path(batch), params: {
        import: {
          rows: [
            {
              occurred_on: "2026-05-22",
              description: "SHOULD NOT IMPORT",
              amount: "31.45",
              direction: "debit",
              card_last4: "2222",
              category_id: categories(:groceries).id
            }
          ]
        }
      }
    end

    assert_redirected_to preview_import_path(batch)
    assert_equal "complete", batch.reload.status
    assert_equal 0, batch.transactions_count
  end

  test "commit skips duplicate preview rows unless forced" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "duplicates.csv", imported_at: Time.current, status: "preview")

    assert_no_difference -> { ExpenseTransaction.count } do
      post commit_import_path(batch), params: {
        import: {
          rows: [
            {
              occurred_on: expense_transactions(:grocery).occurred_on.iso8601,
              description: expense_transactions(:grocery).description,
              amount: "58.79",
              direction: expense_transactions(:grocery).direction,
              card_last4: expense_transactions(:grocery).card_last4,
              category_id: categories(:groceries).id,
              included: "false",
              include_duplicate: "false"
            }
          ]
        }
      }
    end

    assert_redirected_to root_path
    assert_equal 0, batch.reload.transactions_count

    force_batch = users(:one).import_batches.create!(filename: "forced.csv", imported_at: Time.current, status: "preview")

    assert_difference -> { ExpenseTransaction.count }, 1 do
      post commit_import_path(force_batch), params: {
        import: {
          rows: [
            {
              occurred_on: expense_transactions(:grocery).occurred_on.iso8601,
              description: expense_transactions(:grocery).description,
              amount: "58.79",
              direction: expense_transactions(:grocery).direction,
              card_last4: expense_transactions(:grocery).card_last4,
              category_id: categories(:groceries).id,
              included: "true",
              include_duplicate: "true"
            }
          ]
        }
      }
    end

    assert_equal 1, force_batch.reload.transactions_count
  end
end
