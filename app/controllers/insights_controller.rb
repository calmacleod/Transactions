class InsightsController < ApplicationController
  def index
    start_date = 4.months.ago.to_date.beginning_of_month
    end_date = Date.current
    transactions = current_user.expense_transactions.select(:id, :occurred_on, :description, :amount_cents, :direction, :category_id).between(start_date, end_date)
    analysis = Insights::Analysis.new(transactions:, start_date:, end_date:, user: current_user).summary
    insights = current_user.insights.recent.to_a
    evidence = InsightTransaction.recent_for_insights(insights.map(&:id), limit: 25).group_by(&:insight_id)

    render inertia: {
      insights: insights.map { |insight| insight_props(insight, transactions: evidence.fetch(insight.id, []).map(&:expense_transaction).sort_by { |transaction| [ transaction.occurred_on, transaction.id ] }.reverse) },
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

    message = "Insight regeneration queued. New insights will appear when the background job finishes."

    respond_to do |format|
      format.html { redirect_to insights_path, notice: message }
      format.json { render json: { message: }, status: :accepted }
    end
  end
end
