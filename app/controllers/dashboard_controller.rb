class DashboardController < ApplicationController
  def index
    transactions = current_user.expense_transactions.includes(:category, :subcategories).recent.limit(4)
    insights = current_user.insights.where(starts_on: 4.months.ago.to_date.beginning_of_month..).recent.limit(6)
    categories = current_user.categories.by_name
    month_range = Date.current.beginning_of_month..Date.current.end_of_month
    dashboard = DashboardSummary.new(range: month_range, user: current_user)
    category_totals = dashboard.category_totals
    day_totals = dashboard.day_of_week_totals
    month_trend = dashboard.month_trend
    latest_completed_import = current_user.import_batches.complete.where.not(imported_at: nil).order(imported_at: :desc).first
    unfinished_import = current_user.import_batches.unfinished.first

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
        unclassified_count: current_user.expense_transactions.unclassified.count,
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
      upload_prompt: upload_prompt_props(latest_completed_import),
      unfinished_import: unfinished_import_props(unfinished_import),
      actions: {
        import: imports_path,
        imports: imports_path,
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

  def upload_prompt_props(import_batch)
    days_since = import_batch&.imported_at ? (Date.current - import_batch.imported_at.to_date).to_i : nil

    {
      days_since_last_upload: days_since,
      title: upload_prompt_title(days_since),
      body: upload_prompt_body(days_since)
    }
  end

  def upload_prompt_title(days_since)
    return "Upload transactions" if days_since.nil?
    return "Fresh upload today" if days_since.zero?

    "#{days_since} #{'day'.pluralize(days_since)} since your last upload"
  end

  def upload_prompt_body(days_since)
    return "Import your latest card CSV and review every row before it is added." if days_since.nil?
    return "Your transaction data was refreshed today. Add another CSV only if you have new activity." if days_since.zero?
    return "Do you have new transactions to upload?" if days_since >= 3

    "Upload another CSV when your card has new activity."
  end

  def unfinished_import_props(import_batch)
    return nil if import_batch.blank?

    {
      id: import_batch.id,
      filename: import_batch.filename,
      status: import_batch.status,
      rows_count: import_batch.import_rows.count,
      created_at_label: import_batch.created_at.strftime("%b %-d, %Y"),
      preview_path: preview_import_path(import_batch)
    }
  end
end
