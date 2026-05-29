module Development
  class PreviewsController < ApplicationController
    before_action :require_admin_user

    def first_time_flow
      session[:preview_onboarding] = true

      redirect_to root_path, notice: "First-time walkthrough preview enabled."
    end
  end
end
