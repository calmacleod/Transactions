module Admin
  class InvitationsController < BaseController
    def create
      invitation = UserInvitation.create_for!(
        email_address: invitation_params.fetch(:email_address),
        invited_by: Current.user
      )
      UserMailer.invitation(invitation, invitation.raw_code).deliver_later

      redirect_to admin_root_path, notice: "Invitation sent to #{invitation.email_address}."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_root_path, alert: error.record.errors.full_messages.to_sentence
    end

    private

    def invitation_params
      params.require(:user_invitation).permit(:email_address)
    end
  end
end
