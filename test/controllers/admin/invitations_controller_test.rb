require "test_helper"

class Admin::InvitationsControllerTest < ActionDispatch::IntegrationTest
  test "admin can create an email invitation" do
    sign_in_as users(:one)

    assert_difference -> { UserInvitation.count }, 1 do
      assert_enqueued_jobs 1 do
        post admin_invitations_path, params: { user_invitation: { email_address: "Invitee@Example.com" } }
      end
    end

    invitation = UserInvitation.last
    assert_redirected_to admin_root_path
    assert_equal "invitee@example.com", invitation.email_address
    assert_equal users(:one), invitation.invited_by
  end
end
