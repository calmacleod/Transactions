class DashboardController < ApplicationController
  def index
    @transactions = ExpenseTransaction.includes(:category).recent.limit(4)
    @insights = Insight.where(starts_on: 4.months.ago.to_date.beginning_of_month..).recent.limit(6)
    @categories = Category.by_name
    @import_batches = ImportBatch.order(created_at: :desc).limit(5)
    @classification_run = visible_classification_run
    @month_range = Date.current.beginning_of_month..Date.current.end_of_month
    @dashboard = DashboardSummary.new(range: @month_range)
  end

  private

  def visible_classification_run
    latest_run = ClassificationRun.latest.first
    return if latest_run.blank?
    return if session[:dismissed_classification_run_id] == latest_run.id

    latest_run
  end
end
