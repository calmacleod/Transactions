require "test_helper"

class AuthenticationAccessTest < ActionDispatch::IntegrationTest
  test "redirects anonymous visitors to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "returns authenticated visitors to the requested page" do
    get transactions_path

    assert_redirected_to new_session_path

    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to transactions_path
  end

  test "does not replace the sign in return path with background json requests" do
    get transactions_path
    get offline_snapshot_path(format: :json)

    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to transactions_path
  end

  test "allows authenticated visitors through" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    page = inertia_page
    assert_equal "dashboard/index", page["component"]
    assert page["props"]["metrics"]
    assert page["props"]["recommendations"]
  end

  test "redirects anonymous visitors away from job management" do
    get "/admin/jobs"

    assert_redirected_to Rails.application.routes.url_helpers.new_session_path
  end

  test "allows authenticated visitors into job management" do
    sign_in_as users(:one)

    get "/admin/jobs"

    assert_response :success
    assert_includes response.body, "Pending jobs"
    assert_includes response.body, "Failed jobs"
  end

  test "sign in page does not expose the admin email as sample text" do
    get new_session_path

    assert_response :success
    assert_equal "sessions/new", inertia_page["component"]
    assert_empty inertia_props["email_address"].to_s
  end
end
