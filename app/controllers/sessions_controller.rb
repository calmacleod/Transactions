class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    render inertia: {
      email_address: params[:email_address],
      development: Rails.env.development?,
      actions: {
        session: session_path,
        new_password: new_password_path,
        new_registration: new_registration_path
      }
    }
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url, status: :see_other
    else
      redirect_to new_session_path, alert: "Try another email address or password.", status: :see_other
    end
  end

  def destroy
    terminate_session
    redirect_to sign_out_redirect_path, status: :see_other
  end

  private

  def sign_out_redirect_path
    return_to = params[:return_to].to_s
    return return_to if return_to.start_with?("/") && !return_to.start_with?("//")

    new_session_path
  end
end
