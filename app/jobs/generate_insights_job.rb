class GenerateInsightsJob < ApplicationJob
  queue_as :default

  def perform(start_date = 4.months.ago.to_date.beginning_of_month, end_date = Date.current, user_id = nil)
    user = User.find_by(id: user_id)
    Current.session = Session.new(user:) if user.present?
    Ai::InsightGenerator.new(user:).call(start_date:, end_date:)
  end
end
