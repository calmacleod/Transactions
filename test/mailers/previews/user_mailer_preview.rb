# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def invitation
    code = "ABC123XYZ0"
    invitation = UserInvitation.new(
      email_address: "new-user@example.com",
      code_digest: BCrypt::Password.create(code),
      expires_at: 14.days.from_now
    )
    UserMailer.invitation(invitation, code)
  end

  def csv_upload_reminder
    UserMailer.csv_upload_reminder(User.first || User.new(email_address: "user@example.com"))
  end
end
