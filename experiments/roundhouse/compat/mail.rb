# Local development delivery adapter: persist messages to disk instead of
# retaining every delivery in the process. These are normal invitation codes
# and signed, expiring password-reset links, issued by the app's mailers.
module NativeMail
  def self.origin
    ENV.fetch('NATIVE_APP_URL', 'http://127.0.0.1:' + ENV.fetch('PORT', '3901'))
  end

  def self.deliver(message)
    directory = 'storage/mail'
    Dir.mkdir(directory) unless Dir.exist?(directory)
    File.write(directory + '/' + SecureRandom.uuid + '.json', JSON.generate({
      to: message.to, from: message.from, subject: message.subject, body: message.body,
      delivered_at: Time.now.utc.iso8601
    }))
    message
  end
end

module ActionMailer
  class Message
    def deliver_now
      NativeMail.deliver(self)
    end
    def deliver_later
      NativeMail.deliver(self)
    end
  end
end

class PasswordsMailer
  def reset(user)
    link = NativeMail.origin + '/passwords/' + user.password_reset_token + '/edit'
    mail(to: user.email_address, from: ENV.fetch('MAILER_FROM', 'Transactions <no-reply@example.test>'),
      subject: 'Reset your password',
      body: "You can reset your password on\n#{link}\n\nThis link will expire in 15 minutes.\n")
  end
end

class UserMailer
  def invitation(invitation, code = invitation.raw_code)
    normalized_code = code.to_s.strip.upcase
    raise ArgumentError, 'Invitation raw code is invalid' unless invitation.valid_code?(normalized_code)
    # Query encoding is provided by the generated helper; prefix its path
    # with the native app's configured origin for an absolute email URL.
    link = NativeMail.origin + RouteHelpers.new_registration_path(email_address: invitation.email_address, code: normalized_code)
    body = "You have been invited to Transactions.\n\nUse this one-time code to create your account:\n\n#{normalized_code}\n\nCreate account:\n#{link}\n\nThis invitation expires on #{invitation.expires_at.strftime('%B %-d, %Y')}.\n"
    mail(to: invitation.email_address, from: ENV.fetch('MAILER_FROM', 'Transactions <no-reply@example.test>'), subject: 'Your Transactions invitation', body: body)
  end

  def csv_upload_reminder(user)
    mail(to: user.email_address, from: ENV.fetch('MAILER_FROM', 'Transactions <no-reply@example.test>'),
      subject: "Upload this week's Transactions CSV",
      body: "Upload your latest CSV.\n\nYour Transactions reminder is due. Import your latest headerless credit card CSV so dashboards, budgets, and insights stay current.\n\nOpen Transactions:\n#{NativeMail.origin}/\n\nYou can change this reminder schedule from Settings.\n")
  end
end
