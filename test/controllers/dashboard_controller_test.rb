require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows upload prompt with days since last completed import" do
    sign_in_as users(:one)

    travel_to Date.new(2026, 5, 29) do
      get root_path
    end

    assert_response :success
    assert_equal 4, inertia_props.dig("upload_prompt", "days_since_last_upload")
    assert_match "4 days", inertia_props.dig("upload_prompt", "title")
    assert_match "new transactions", inertia_props.dig("upload_prompt", "body")
  end

  test "surfaces unfinished import on dashboard" do
    sign_in_as users(:one)
    batch = users(:one).import_batches.create!(filename: "unfinished.csv", status: "preview")
    batch.import_rows.create!(
      user: users(:one),
      row_number: 1,
      occurred_on: Date.new(2026, 5, 28),
      description: "UNFINISHED MERCHANT",
      amount_cents: 1200,
      direction: "debit",
      card_last4: "2222",
      source: StatementCsvImporter::SOURCE,
      external_id: "unfinished-row"
    )

    get root_path

    assert_response :success
    assert_equal "unfinished.csv", inertia_props.dig("unfinished_import", "filename")
    assert_equal preview_import_path(batch), inertia_props.dig("unfinished_import", "preview_path")
    assert_equal 1, inertia_props.dig("unfinished_import", "rows_count")
  end
end
