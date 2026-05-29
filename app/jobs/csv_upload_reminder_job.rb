class CsvUploadReminderJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    if user_id.present?
      send_reminder(User.find(user_id))
    else
      User.csv_reminders_due_at(Time.current).find_each do |user|
        self.class.perform_later(user.id)
      end
    end
  end

  private

  def send_reminder(user)
    return unless user.csv_reminder_due_at?(Time.current)

    UserMailer.csv_upload_reminder(user).deliver_later
    user.update!(csv_reminder_last_sent_at: Time.current)
  end
end
