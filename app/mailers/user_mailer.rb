class UserMailer < ApplicationMailer
  def invitation(invitation, code = invitation.raw_code)
    normalized_code = code.to_s.strip.upcase
    raise ArgumentError, "Invitation raw code is invalid" unless invitation.valid_code?(normalized_code)

    @invitation = invitation
    @code = normalized_code
    @registration_url = new_registration_url(email_address: invitation.email_address, code: @code)

    mail subject: "Your Transactions invitation", to: invitation.email_address
  end

  def csv_upload_reminder(user)
    @user = user
    @upload_url = root_url

    mail subject: "Upload this week's Transactions CSV", to: user.email_address
  end
end
