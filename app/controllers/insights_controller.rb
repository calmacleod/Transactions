  class InsightsController < ApplicationController
    def index
      @insights = Insight.recent
    end

    def create
      start_date = 4.months.ago.to_date.beginning_of_month
      end_date = Date.current
      GenerateInsightsJob.perform_later(start_date, end_date)

      redirect_to root_path, notice: "Queued insight generation for recent month-to-month spending."
    end
  end
