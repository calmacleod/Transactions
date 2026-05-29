require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "invitation includes the one-time code and registration link" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    mail = UserMailer.invitation(invitation, invitation.raw_code)

    assert_equal [ "new@example.com" ], mail.to
    assert_equal "Your Transactions invitation", mail.subject
    assert_match invitation.raw_code, mail.text_part.body.to_s
    assert_match "email_address=new%40example.com", mail.html_part.body.to_s
    assert_match "code=#{invitation.raw_code}", mail.html_part.body.to_s
  end

  test "csv upload reminder links to the app" do
    mail = UserMailer.csv_upload_reminder(users(:one))

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal "Upload this week's Transactions CSV", mail.subject
    assert_match "http://example.com", mail.text_part.body.to_s
  end
end
