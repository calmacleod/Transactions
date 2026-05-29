require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates a user with a valid invitation code" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))
    code = invitation.raw_code

    assert_difference -> { User.count }, 1 do
      post registrations_path, params: {
        user: {
          email_address: "new@example.com",
          invite_code: code,
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(email_address: "new@example.com")
    assert_redirected_to root_path
    assert cookies[:session_id]
    assert invitation.reload.accepted_at
    assert_equal user, invitation.accepted_by
    assert user.categories.exists?(name: "Groceries")
  end

  test "rejects invalid invitation code" do
    UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    assert_no_difference -> { User.count } do
      post registrations_path, params: {
        user: {
          email_address: "new@example.com",
          invite_code: "WRONGCODE",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to new_registration_path(email_address: "new@example.com")
  end
end
