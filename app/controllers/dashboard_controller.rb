class DashboardController < ApplicationController
  def index
    transactions = ExpenseTransaction.includes(:category).recent.limit(4)
    insights = Insight.where(starts_on: 4.months.ago.to_date.beginning_of_month..).recent.limit(6)
    categories = Category.by_name
    month_range = Date.current.beginning_of_month..Date.current.end_of_month
    dashboard = DashboardSummary.new(range: month_range)
    category_totals = dashboard.category_totals
    day_totals = dashboard.day_of_week_totals
    month_trend = dashboard.month_trend

    render inertia: {
      month_range: {
        start: month_range.begin.iso8601,
        end: month_range.end.iso8601,
        label: "#{month_range.begin.strftime("%b %-d")} to #{month_range.end.strftime("%b %-d")}"
      },
      metrics: {
        total_spend_label: money_from_cents(dashboard.total_spend_cents),
        expense_count: dashboard.expense_count,
        transaction_count: dashboard.transaction_count,
        average_expense_label: money_from_cents(dashboard.average_expense_cents),
        unclassified_count: ExpenseTransaction.unclassified.count,
        category_count: categories.count
      },
      category_totals: category_totals.map { |item| dashboard_item_props(item) },
      day_totals: day_totals.map { |item| dashboard_item_props(item) },
      month_trend: month_trend.map { |item| dashboard_item_props(item) },
      month_delta: dashboard.month_to_month_delta.merge(label: money_from_cents(dashboard.month_to_month_delta[:cents])),
      top_merchants: dashboard.top_merchants.map { |item| dashboard_item_props(item).merge(merchant_label: item[:merchant].titleize) },
      recommendations: dashboard.recommendations.map { |item| dashboard_item_props(item) },
      transactions: transactions.map { |transaction| transaction_props(transaction) },
      insights: insights.map { |insight| insight_props(insight) },
      classification_run: classification_run_props(visible_classification_run),
      actions: {
        classify: classifications_path,
        generate_insights: insights_path,
        import: imports_path,
        month_transactions: transactions_path(start_date: month_range.begin, end_date: month_range.end, direction: "debit"),
        unclassified_transactions: transactions_path(classified: "unclassified")
      }
    }
  end

  private

  def dashboard_item_props(item)
    item.merge(
      amount_label: money_from_cents(item[:cents].to_i),
      filters_path: transactions_path(item[:filters] || {})
    )
  end

  def visible_classification_run
    latest_run = ClassificationRun.latest.first
    return if latest_run.blank?
    return if session[:dismissed_classification_run_id] == latest_run.id

    latest_run
  end
end
