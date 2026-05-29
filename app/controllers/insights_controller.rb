class InsightsController < ApplicationController
  def index
    render inertia: {
      insights: current_user.insights.recent.includes(expense_transactions: [ :category, :subcategories ]).map { |insight| insight_props(insight) },
      actions: {
        regenerate: insights_path
      }
    }
  end

  def create
    start_date = 4.months.ago.to_date.beginning_of_month
    end_date = Date.current
    GenerateInsightsJob.perform_later(start_date, end_date, current_user.id)

    redirect_to root_path, notice: "Queued insight generation for recent month-to-month spending."
  end
end
