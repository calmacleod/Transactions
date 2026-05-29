require "test_helper"

class CsvUploadReminderJobTest < ActiveJob::TestCase
  test "sends due reminders and records the send time" do
    user = users(:one)
    user.update!(
      csv_reminder_enabled: true,
      csv_reminder_wday: Time.current.wday,
      csv_reminder_hour: Time.current.hour,
      csv_reminder_last_sent_at: nil
    )

    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs do
      CsvUploadReminderJob.perform_now(user.id)
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert user.reload.csv_reminder_last_sent_at
  end
end
