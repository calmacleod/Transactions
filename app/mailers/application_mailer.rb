class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Transactions <no-reply@transactions.local>") }
  layout "mailer"
end
