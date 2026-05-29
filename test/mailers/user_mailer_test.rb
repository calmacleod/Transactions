require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "invitation includes the one-time code and registration link" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    mail = UserMailer.invitation(invitation, invitation.raw_code)

    assert_equal [ "new@example.com" ], mail.to
    assert_equal [ "no-reply@transaction.callummacleod.ca" ], mail.from
    assert_equal "Your Transactions invitation", mail.subject
    assert_equal [ "transactions-icon.png" ], mail.attachments.map(&:filename)
    assert mail.attachments.first.inline?
    assert_match invitation.raw_code, mail.text_part.body.to_s
    assert_match "cid:", mail.html_part.body.to_s
    assert_match "email_address=new%40example.com", mail.html_part.body.to_s
    assert_match "code=#{invitation.raw_code}", mail.html_part.body.to_s
  end

  test "invitation raises when the raw code is blank" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    error = assert_raises(ArgumentError) do
      UserMailer.invitation(invitation, "").message
    end

    assert_equal "Invitation raw code is invalid", error.message
  end

  test "invitation raises when the raw code does not match the invitation" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    error = assert_raises(ArgumentError) do
      UserMailer.invitation(invitation, "WRONG-CODE").message
    end

    assert_equal "Invitation raw code is invalid", error.message
  end

  test "invitation normalizes a valid raw code before rendering" do
    invitation = UserInvitation.create_for!(email_address: "new@example.com", invited_by: users(:one))

    mail = UserMailer.invitation(invitation, " #{invitation.raw_code.downcase} ")

    assert_match invitation.raw_code, mail.text_part.body.to_s
    assert_match "code=#{invitation.raw_code}", mail.html_part.body.to_s
  end

  test "csv upload reminder links to the app" do
    mail = UserMailer.csv_upload_reminder(users(:one))

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal "Upload this week's Transactions CSV", mail.subject
    assert_match "http://example.com", mail.text_part.body.to_s
  end
end
