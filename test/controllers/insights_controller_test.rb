require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  test "queues recent insight generation" do
    sign_in_as users(:one)

    assert_enqueued_with(job: GenerateInsightsJob) do
      post insights_path
    end

    assert_redirected_to insights_path
  end

  test "renders decision metrics and evidence drill downs" do
    sign_in_as users(:one)
    insight = insights(:category)

    get insights_path

    assert_response :success
    props = inertia_props
    assert props.dig("overview", "spend", "value").present?
    rendered = props.fetch("insights").find { |item| item.fetch("id") == insight.id }
    assert_equal "Review the linked grocery transactions.", rendered.fetch("action")
    assert_equal "Category shift", rendered.fetch("kind_label")
    assert_equal "$58.79", rendered.dig("metric", "value")
    assert_equal transactions_path(
      category_id: categories(:groceries).id,
      start_date: "2026-05-01",
      end_date: "2026-05-31",
      direction: "debit"
    ), rendered.fetch("evidence_path")
    assert_equal transactions_path(transaction_id: expense_transactions(:grocery).id), rendered.dig("transactions", 0, "view_path")
  end
end
