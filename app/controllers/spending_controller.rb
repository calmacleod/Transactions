class SpendingController < ApplicationController
  def index
    months = months_on_record
    category_rows = category_month_rows(months)

    render inertia: {
      months: months.map { |month| month_props(month) },
      monthly_totals: monthly_totals(months),
      category_rows:,
      max_month_cents: monthly_totals(months).map { |item| item[:cents] }.max.to_i,
      max_category_cents: category_rows.flat_map { |row| row[:months].map { |month| month[:cents] } }.max.to_i
    }
  end

  private

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
    grouped = current_user.expense_transactions.expenses.includes(:category).to_a.group_by { |transaction| transaction.category || uncategorized_category }

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
end
