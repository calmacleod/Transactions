require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows users, AI spend, and admin links to admins" do
    sign_in_as users(:one)
    AiRequest.create!(feature: "chat", model: "test-model", estimated_cost_microdollars: 1_250_000, user: users(:two))
    AiRequest.create!(feature: "insights", model: "test-model", estimated_cost_cents: 37, user: users(:one))

    get admin_root_path

    assert_response :success
    props = inertia_props
    assert_equal 2, props.dig("metrics", "user_count")
    assert_equal "$1.62", props.dig("metrics", "total_ai_spend_label")
    assert_equal "/admin/jobs", props.dig("actions", "jobs")
    assert_equal admin_ai_controls_path, props.dig("actions", "ai_controls")
    assert_equal admin_models_path, props.dig("actions", "models")
    assert_includes props["users"].map { |user| user["email_address"] }, users(:two).email_address
    assert_equal "$1.25", props["users"].find { |user| user["email_address"] == users(:two).email_address }["ai_spend_label"]
    assert_equal "$0.37", props["users"].find { |user| user["email_address"] == users(:one).email_address }["ai_spend_label"]
  end

  test "redirects regular users" do
    sign_in_as users(:two)

    get admin_root_path

    assert_redirected_to root_path
  end
end
