class GenerateInsightsJob < ApplicationJob
  queue_as :default

  def perform(start_date = 4.months.ago.to_date.beginning_of_month, end_date = Date.current)
    Ai::InsightGenerator.new.call(start_date:, end_date:)
  end
end
