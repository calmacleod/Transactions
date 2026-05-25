class DashboardController < ApplicationController
  def index
    @transactions = ExpenseTransaction.includes(:category).recent.limit(5)
    @insights = Insight.recent.limit(4)
    @categories = Category.by_name
    @import_batches = ImportBatch.order(created_at: :desc).limit(5)
    @month_range = Date.current.beginning_of_month..Date.current.end_of_month
    @dashboard = DashboardSummary.new(range: @month_range)
  end
end
