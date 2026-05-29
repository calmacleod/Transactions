module Admin
  class DashboardController < BaseController
    def index
      users = User.order(:email_address)
      invitations = UserInvitation.recent.limit(25)

      render inertia: {
        metrics: {
          user_count: users.count,
          admin_count: users.select(&:admin?).size,
          pending_invitation_count: UserInvitation.pending.count,
          total_ai_spend_label: money_from_microdollars(ai_request_microdollars(AiRequest.all))
        },
        users: users.map { |user| user_props(user) },
        invitations: invitations.map { |invitation| invitation_props(invitation) },
        actions: {
          invite: admin_invitations_path,
          jobs: "/admin/jobs",
          ai_controls: admin_ai_controls_path,
          models: admin_models_path,
          email_previews: Rails.env.development? ? "/rails/mailers" : nil,
          first_time_flow_preview: Rails.env.development? ? admin_first_time_flow_preview_path : nil
        }
      }
    end

    private

    def user_props(user)
      {
        id: user.id,
        email_address: user.email_address,
        role: user.role,
        role_label: user.role.titleize,
        transaction_count: user.expense_transactions.count,
        ai_spend_label: money_from_microdollars(ai_request_microdollars(user.ai_requests)),
        csv_reminder_enabled: user.csv_reminder_enabled?,
        csv_reminder_label: user.csv_reminder_label,
        created_at_label: user.created_at.strftime("%b %-d, %Y")
      }
    end

    def invitation_props(invitation)
      {
        id: invitation.id,
        email_address: invitation.email_address,
        status: invitation.accepted_at.present? ? "Accepted" : invitation.expires_at.future? ? "Pending" : "Expired",
        invited_by: invitation.invited_by&.email_address,
        accepted_by: invitation.accepted_by&.email_address,
        expires_at_label: invitation.expires_at.strftime("%b %-d, %Y"),
        created_at_label: invitation.created_at.strftime("%b %-d, %Y")
      }
    end
  end
end
