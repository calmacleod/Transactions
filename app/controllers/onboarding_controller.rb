class OnboardingController < ApplicationController
  def update
    Current.user.update!(onboarding_dismissed_at: Time.current)
    session.delete(:preview_onboarding)

    redirect_back_or_to root_path, notice: "Walkthrough dismissed."
  end
end
