class SpendingController < ApplicationController
  def index
    months = months_on_record
    monthly_totals = monthly_totals(months)
    category_rows = category_month_rows(months)
    weekly_summary = WeeklySpendingSummary.new(user: current_user)
    completed_week_delta = weekly_summary.completed_week_delta

    render inertia: {
      week_trend: weekly_summary.trend.map { |week| week_props(week) },
      completed_week_delta: completed_week_delta.merge(label: money_from_cents(completed_week_delta[:cents])),
      months: months.map { |month| month_props(month) },
      monthly_totals:,
      category_rows:,
      max_month_cents: monthly_totals.map { |item| item[:cents] }.max.to_i,
      max_category_cents: category_rows.flat_map { |row| row[:months].map { |month| month[:cents] } }.max.to_i
    }
  end

  private

  def week_props(week)
    week.merge(
      amount_label: money_from_cents(week[:cents]),
      filters_path: transactions_path(week[:filters])
    ).except(:filters)
  end

  def months_on_record
    first_date = current_user.expense_transactions.expenses.minimum(:occurred_on)&.beginning_of_month || Date.current.beginning_of_month
    last_date = current_user.expense_transactions.expenses.maximum(:occurred_on)&.beginning_of_month || Date.current.beginning_of_month

    months = []
    current_month = first_date
    while current_month <= last_date
      months << current_month
      current_month = current_month.next_month
    end
    months
  end

  def monthly_totals(months)
    totals = current_user.expense_transactions.expenses.group_by_month

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
    grouped_totals = current_user.expense_transactions.expenses
      .group(:category_id, "strftime('%Y-%m-01', occurred_on)")
      .sum(:amount_cents)
      .each_with_object(Hash.new { |categories, category_id| categories[category_id] = {} }) do |((category_id, month), cents), categories|
        categories[category_id][Date.iso8601(month)] = cents
      end
    categories_by_id = current_user.categories.where(id: grouped_totals.keys.compact).index_by(&:id)

    grouped_totals.map do |category_id, month_totals|
      category = categories_by_id[category_id]
      total_cents = month_totals.values.sum

      {
        category: category_props(category).merge(name: category&.name || "Uncategorized"),
        total_cents:,
        total_label: money_from_cents(total_cents),
        months: months.map do |month|
          cents = month_totals.fetch(month, 0)
          {
            month: month.iso8601,
            cents:,
            amount_label: money_from_cents(cents),
            filters_path: transactions_path(start_date: month.iso8601, end_date: month.end_of_month.iso8601, direction: "debit", category_id:, classified: category_id.present? ? nil : "unclassified")
          }
        end
      }
    end.sort_by { |row| -row[:total_cents] }
  end
end
