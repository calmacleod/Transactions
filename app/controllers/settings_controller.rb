class SettingsController < ApplicationController
  def show
    render inertia: {
      reminder: reminder_props(Current.user),
      import_retention: {
        retain_uploaded_csv: Current.user.retain_uploaded_csv?
      },
      days: Date::DAYNAMES.each_with_index.map { |name, index| { label: name, value: index } },
      hours: (0..23).map { |hour| { label: Time.zone.local(2000, 1, 1, hour).strftime("%-l:00 %p"), value: hour } },
      actions: {
        update: settings_path
      }
    }
  end

  def update
    Current.user.update!(settings_params)

    redirect_to settings_path, notice: "Reminder settings updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to settings_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def settings_params
    params.require(:user).permit(:csv_reminder_enabled, :csv_reminder_wday, :csv_reminder_hour, :retain_uploaded_csv)
  end

  def reminder_props(user)
    {
      enabled: user.csv_reminder_enabled?,
      wday: user.csv_reminder_wday,
      hour: user.csv_reminder_hour,
      label: user.csv_reminder_label,
      last_sent_at_label: user.csv_reminder_last_sent_at&.strftime("%b %-d, %Y at %-l:%M %p")
    }
  end
end
