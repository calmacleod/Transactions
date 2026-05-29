class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    render inertia: {
      email_address: params[:email_address],
      invite_code: params[:code],
      actions: {
        registration: registrations_path,
        new_session: new_session_path,
        session: session_path,
        root: root_path
      }
    }
  end

  def create
    invitation = matching_invitation
    unless invitation
      redirect_to new_registration_path(email_address: registration_params[:email_address]), alert: "Enter a valid invitation code."
      return
    end

    user = User.create!(
      email_address: invitation.email_address,
      password: registration_params[:password],
      password_confirmation: registration_params[:password_confirmation]
    )
    invitation.accept!(user)
    start_new_session_for(user)

    redirect_to root_path, notice: "Welcome to Transactions."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_registration_path(email_address: registration_params[:email_address]), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :invite_code, :password, :password_confirmation)
  end

  def matching_invitation
    email_address = registration_params[:email_address].to_s.strip.downcase
    UserInvitation.pending.where(email_address:).detect { |invitation| invitation.valid_code?(registration_params[:invite_code]) }
  end
end
