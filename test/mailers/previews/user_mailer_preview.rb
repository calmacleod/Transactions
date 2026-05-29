# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def invitation
    invitation = UserInvitation.new(
      email_address: "new-user@example.com",
      expires_at: 14.days.from_now
    )
    UserMailer.invitation(invitation, "ABC123XYZ0")
  end

  def csv_upload_reminder
    UserMailer.csv_upload_reminder(User.first || User.new(email_address: "user@example.com"))
  end
end
