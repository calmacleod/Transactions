require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "shows and updates CSV reminder settings" do
    sign_in_as users(:one)

    get settings_path

    assert_response :success
    assert_equal "Monday at 9:00 AM", inertia_props.dig("reminder", "label")

    patch settings_path, params: { user: { csv_reminder_enabled: "0", csv_reminder_wday: 5, csv_reminder_hour: 8 } }

    assert_redirected_to settings_path
    assert_not users(:one).reload.csv_reminder_enabled?
    assert_equal 5, users(:one).csv_reminder_wday
    assert_equal 8, users(:one).csv_reminder_hour
  end
end
