require "test_helper"

class UserInvitationTest < ActiveSupport::TestCase
  test "validates pending one-time code" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    assert invitation.valid_code?(invitation.raw_code.downcase)
    assert_not invitation.valid_code?("wrong")
  end
end
