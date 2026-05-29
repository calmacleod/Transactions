class ApplicationMailer < ActionMailer::Base
  APP_ICON_FILENAME = "transactions-icon.png"
  APP_ICON_PATH = Rails.root.join("public/icon-20260526.png")

  before_action :attach_app_icon

  default from: -> { ENV.fetch("MAILER_FROM", "Transactions <no-reply@transaction.callummacleod.ca>") }
  layout "mailer"

  private

  def attach_app_icon
    attachments.inline[APP_ICON_FILENAME] = {
      mime_type: "image/png",
      content: File.binread(APP_ICON_PATH)
    }
    @app_icon = attachments.inline[APP_ICON_FILENAME]
  end
end
