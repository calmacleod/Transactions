  class InsightsController < ApplicationController
    def index
      @insights = Insight.recent
    end

    def create
      start_date = ExpenseTransaction.minimum(:occurred_on) || 30.days.ago.to_date
      end_date = ExpenseTransaction.maximum(:occurred_on) || Date.current
      insights = Ai::InsightGenerator.new.call(start_date:, end_date:)

      redirect_to root_path, notice: "Generated #{insights.size} insights."
    end
  end
