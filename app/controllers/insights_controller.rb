class InsightsController < ApplicationController
  def index
    start_date = 4.months.ago.to_date.beginning_of_month
    end_date = Date.current
    transactions = current_user.expense_transactions.includes(:category).between(start_date, end_date)
    analysis = Insights::Analysis.new(transactions:, start_date:, end_date:, user: current_user).call

    render inertia: {
      insights: current_user.insights.recent.includes(expense_transactions: [ :category, :subcategories ]).map { |insight| insight_props(insight) },
      overview: analysis[:overview],
      period: analysis[:period],
      actions: {
        regenerate: insights_path
      }
    }
  end

  def create
    start_date = 4.months.ago.to_date.beginning_of_month
    end_date = Date.current
    GenerateInsightsJob.perform_later(start_date, end_date, current_user.id)

    redirect_to insights_path, notice: "Queued a fresh analysis of recent spending patterns."
  end
end
