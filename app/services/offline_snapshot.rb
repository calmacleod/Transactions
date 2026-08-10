class OfflineSnapshot
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  def initialize(user:, generated_at: Time.current)
    @user = user
    @generated_at = generated_at
  end

  def to_h
    {
      generated_at: generated_at.iso8601,
      paths: {
        root: root_path,
        transactions: transactions_path,
        spending: spending_path,
        budgets: budgets_path,
        subcategories: subcategories_path,
        insights: insights_path
      },
      pages: {
        dashboard: dashboard_props,
        transactions: transactions_props,
        spending: spending_props,
        budgets: budgets_props,
        insights: insights_props,
        subcategories: subcategories_props
      }
    }
  end

  private

  attr_reader :user, :generated_at

  def dashboard_props
    categories = user.categories.by_name
    month_range = Date.current.beginning_of_month..Date.current.end_of_month
    dashboard = DashboardSummary.new(range: month_range, user:)
    month_delta = dashboard.month_to_month_delta

    {
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
        unclassified_count: user.expense_transactions.unclassified.count,
        category_count: categories.count
      },
      category_totals: dashboard.category_totals.map { |item| dashboard_item_props(item) },
      day_totals: dashboard.day_of_week_totals.map { |item| dashboard_item_props(item) },
      month_trend: dashboard.month_trend.map { |item| dashboard_item_props(item) },
      month_delta: month_delta.merge(label: money_from_cents(month_delta[:cents])),
      top_merchants: dashboard.top_merchants.map { |item| dashboard_item_props(item).merge(merchant_label: item[:merchant].titleize) },
      recommendations: dashboard.recommendations.map { |item| dashboard_item_props(item) },
      transactions: user.expense_transactions.includes(:category, :subcategories).recent.limit(8).map { |transaction| transaction_props(transaction) },
      insights: insight_collection_props(user.insights.where(starts_on: 4.months.ago.to_date.beginning_of_month..).recent.limit(6), transaction_limit: 10)
    }
  end

  def transactions_props
    transactions = user.expense_transactions.includes(:category, :subcategories).recent.to_a

    {
      categories: category_options,
      subcategories: subcategory_options,
      saved_queries: user.saved_transaction_queries.ordered.map { |query| saved_query_props(query) },
      filter_params: {},
      quick_ranges: TransactionFilter::QUICK_RANGES.map { |value, label| { value:, label: } },
      filter_active: false,
      date_summary: "Showing offline snapshot",
      sort: { field: "date", direction: "desc" },
      transactions: transactions.map { |transaction| transaction_props(transaction) },
      pagination: {
        count: transactions.size,
        from: transactions.any? ? 1 : 0,
        to: transactions.size,
        page: 1,
        pages: 1,
        pages_series: [ { label: "1", current: true, gap: false } ]
      },
      per_page: "all",
      per_page_options: [ { label: "All", value: "all" } ]
    }
  end

  def spending_props
    months = months_on_record
    category_rows = category_month_rows(months)
    monthly_totals = monthly_totals(months)

    {
      months: months.map { |month| month_props(month) },
      monthly_totals:,
      category_rows:,
      max_month_cents: monthly_totals.map { |item| item[:cents] }.max.to_i,
      max_category_cents: category_rows.flat_map { |row| row[:months].map { |month| month[:cents] } }.max.to_i
    }
  end

  def budgets_props
    month = Date.current.beginning_of_month
    range = month..month.end_of_month
    totals = user.expense_transactions.expenses.includes(:category).between(range.begin, range.end).group(:category_id).sum(:amount_cents)

    {
      month: {
        value: month.strftime("%Y-%m"),
        label: month.strftime("%B %Y")
      },
      categories: user.categories.by_name.map { |category| budget_category_props(category, totals.fetch(category.id, 0), range) },
      unclassified: {
        name: "Unclassified",
        color: "#71717a",
        spent_cents: totals.fetch(nil, 0),
        spent_label: money_from_cents(totals.fetch(nil, 0)),
        filters_path: transactions_path(start_date: range.begin.iso8601, end_date: range.end.iso8601, direction: "debit", classified: "unclassified")
      }
    }
  end

  def insights_props
    {
      insights: insight_collection_props(user.insights.recent, transaction_limit: 25)
    }
  end

  def subcategories_props
    {
      subcategories: subcategory_options
    }
  end

  def dashboard_item_props(item)
    item.merge(
      amount_label: money_from_cents(item[:cents].to_i),
      filters_path: transactions_path(item[:filters] || {})
    ).except(:filters)
  end

  def transaction_props(transaction)
    {
      id: transaction.id,
      occurred_on: transaction.occurred_on.iso8601,
      occurred_on_label: transaction.occurred_on.strftime("%b %-d, %Y"),
      short_date_label: transaction.occurred_on.strftime("%b %-d"),
      description: transaction.description,
      merchant_name: transaction.merchant_name,
      description_detail: transaction.description_detail,
      amount_cents: transaction.amount_cents,
      signed_amount_cents: transaction.signed_amount_cents,
      amount_label: transaction.expense? ? money_from_cents(transaction.amount_cents) : "-#{money_from_cents(transaction.amount_cents)}",
      amount_class: transaction.expense? ? "text-foreground" : "text-emerald-600 dark:text-emerald-400",
      direction: transaction.direction,
      category_id: transaction.category_id,
      category: category_props(transaction.category),
      subcategories: transaction_subcategories_for_props(transaction).map { |subcategory| subcategory_props(subcategory) },
      notes: transaction.notes,
      classification_reason: transaction.classification_reason,
      confidence_label: transaction.classification_confidence.present? ? "#{(transaction.classification_confidence.to_d * 100).round}%" : "Pending",
      view_path: transactions_path(transaction_id: transaction.id)
    }
  end

  def insight_collection_props(insights, transaction_limit:)
    insight_records = insights.to_a
    transactions_by_insight_id = insight_transactions_by_insight_id(insight_records, transaction_limit:)

    insight_records.map { |insight| insight_props(insight, transactions: transactions_by_insight_id.fetch(insight.id, [])) }
  end

  def insight_props(insight, transactions:)
    {
      id: insight.id,
      title: insight.title,
      body: insight.body,
      action: insight.action,
      kind: insight.kind,
      kind_label: insight.kind.humanize,
      metric: insight.metric,
      severity: insight.severity,
      generation_source: insight.generation_source,
      generation_source_label: insight.generation_source == "ai" ? "AI generated" : "Automatic",
      starts_on: insight.starts_on&.iso8601,
      starts_on_label: insight.starts_on&.strftime("%b %Y"),
      ends_on: insight.ends_on&.iso8601,
      transactions: transactions.map { |transaction| transaction_props(transaction) }
    }
  end

  def category_options
    user.categories.by_name.map { |category| category_props(category) }
  end

  def category_props(category)
    return { id: nil, name: "Unclassified", color: "#71717a" } if category.blank?

    {
      id: category.id,
      name: category.name,
      color: category.color.presence || "#52525b",
      monthly_budget_cents: category.monthly_budget_cents
    }
  end

  def subcategory_options
    user.transaction_subcategories.by_name.map { |subcategory| subcategory_props(subcategory) }
  end

  def subcategory_props(subcategory)
    {
      id: subcategory.id,
      name: subcategory.name,
      color: subcategory.color.presence || "#71717a"
    }
  end

  def transaction_subcategories_for_props(transaction)
    transaction.subcategories.sort_by(&:name)
  end

  def insight_transactions_by_insight_id(insights, transaction_limit:)
    insight_ids = insights.map(&:id)
    return {} if insight_ids.empty?

    transactions_by_insight_id = Hash.new { |hash, key| hash[key] = [] }
    InsightTransaction.where(insight_id: insight_ids)
                      .includes(expense_transaction: [ :category, :subcategories ])
                      .find_each do |insight_transaction|
      transactions_by_insight_id[insight_transaction.insight_id] << insight_transaction.expense_transaction
    end

    transactions_by_insight_id.transform_values do |transactions|
      transactions.compact
                  .sort_by { |transaction| [ transaction.occurred_on || Date.new(1, 1, 1), transaction.id ] }
                  .reverse
                  .first(transaction_limit)
    end
  end

  def saved_query_props(saved_query)
    {
      id: saved_query.id,
      name: saved_query.name,
      path: transactions_path(saved_query_id: saved_query.id)
    }
  end

  def budget_category_props(category, spent_cents, range)
    budget_cents = category.monthly_budget_cents.to_i

    category_props(category).merge(
      spent_cents:,
      spent_label: money_from_cents(spent_cents),
      budget_label: money_from_cents(budget_cents),
      monthly_budget: format("%.2f", budget_cents / 100.0),
      remaining_cents: budget_cents - spent_cents,
      remaining_label: money_from_cents(budget_cents - spent_cents),
      used_percent: percentage(spent_cents, budget_cents),
      filters_path: transactions_path(start_date: range.begin.iso8601, end_date: range.end.iso8601, direction: "debit", category_id: category.id)
    )
  end

  def months_on_record
    first_date = user.expense_transactions.expenses.minimum(:occurred_on)&.beginning_of_month || Date.current.beginning_of_month
    last_date = user.expense_transactions.expenses.maximum(:occurred_on)&.beginning_of_month || Date.current.beginning_of_month

    months = []
    current_month = first_date
    while current_month <= last_date
      months << current_month
      current_month = current_month.next_month
    end
    months
  end

  def monthly_totals(months)
    totals = user.expense_transactions.expenses.group_by_month

    months.map do |month|
      cents = totals.fetch(month, 0)
      {
        month: month.iso8601,
        label: month.strftime("%b %Y"),
        cents:,
        amount_label: money_from_cents(cents),
        filters_path: transactions_path(start_date: month.iso8601, end_date: month.end_of_month.iso8601, direction: "debit")
      }
    end
  end

  def month_props(month)
    {
      value: month.strftime("%Y-%m"),
      label: month.strftime("%b %Y"),
      year: month.strftime("%Y"),
      short_label: month.strftime("%b")
    }
  end

  def category_month_rows(months)
    grouped = user.expense_transactions.expenses.includes(:category).to_a.group_by { |transaction| transaction.category || uncategorized_category }

    grouped.map do |category, transactions|
      month_totals = transactions.group_by { |transaction| transaction.occurred_on.beginning_of_month }
                                  .transform_values { |items| items.sum(&:amount_cents) }

      {
        category: category_props(category.persisted? ? category : nil).merge(name: category.name),
        total_cents: transactions.sum(&:amount_cents),
        total_label: money_from_cents(transactions.sum(&:amount_cents)),
        months: months.map do |month|
          cents = month_totals.fetch(month, 0)
          {
            month: month.iso8601,
            cents:,
            amount_label: money_from_cents(cents),
            filters_path: transactions_path(start_date: month.iso8601, end_date: month.end_of_month.iso8601, direction: "debit", category_id: category.persisted? ? category.id : nil, classified: category.persisted? ? nil : "unclassified")
          }
        end
      }
    end.sort_by { |row| -row[:total_cents] }
  end

  def uncategorized_category
    @uncategorized_category ||= Category.new(name: "Uncategorized", color: "#71717a")
  end

  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0)
  end

  def percentage(numerator, denominator)
    return 0 if denominator.blank? || denominator.zero?

    ((numerator.to_f / denominator) * 100).round.clamp(0, 999)
  end
end
