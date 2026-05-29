require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  test "dismisses onboarding for the current user" do
    user = users(:two)
    sign_in_as user

    patch onboarding_path

    assert_redirected_to root_path
    assert user.reload.onboarding_dismissed_at
  end
end
