require "test_helper"

class AuthenticationAccessTest < ActionDispatch::IntegrationTest
  test "redirects anonymous visitors to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "allows authenticated visitors through" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_includes response.body, "Spending dashboard"
    assert_includes response.body, "Day-of-week frequency"
    assert_includes response.body, "Cutback targets"
  end

  test "sign in page does not expose the admin email as sample text" do
    get new_session_path

    assert_response :success
    assert_select "input[type=email][placeholder]", false
  end
end
