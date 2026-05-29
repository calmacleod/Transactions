require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
    assert_equal Rails.env.development?, inertia_props["development"]
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "destroy can return to a local invitation path" do
    sign_in_as(User.take)

    delete session_path, params: { return_to: "/registrations/new?email_address=new%40example.com&code=ABC123XYZ0" }

    assert_redirected_to "/registrations/new?email_address=new%40example.com&code=ABC123XYZ0"
    assert_empty cookies[:session_id]
  end

  test "destroy ignores external return paths" do
    sign_in_as(User.take)

    delete session_path, params: { return_to: "//example.com/registrations/new" }

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
