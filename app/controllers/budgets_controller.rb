class BudgetsController < ApplicationController
  def index
    month = budget_month
    range = month..month.end_of_month
    totals = current_user.expense_transactions.expenses.includes(:category).between(range.begin, range.end).group(:category_id).sum(:amount_cents)

    render inertia: {
      month: {
        value: month.strftime("%Y-%m"),
        label: month.strftime("%B %Y")
      },
      categories: current_user.categories.by_name.map { |category| budget_category_props(category, totals.fetch(category.id, 0), range) },
      unclassified: unclassified_props(totals.fetch(nil, 0), range),
      actions: {
        index: budgets_path,
        update_template: budget_path(":id")
      }
    }
  end

  def update
    category = current_user.categories.find(params[:id])
    category.update!(monthly_budget_cents: dollars_to_cents(params.dig(:category, :monthly_budget)))

    redirect_back fallback_location: budgets_path, notice: "#{category.name} budget updated."
  end

  private

  def budget_month
    Date.strptime(params[:month].to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError
    Date.current.beginning_of_month
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
      filters_path: transactions_path(start_date: range.begin.iso8601, end_date: range.end.iso8601, direction: "debit", category_id: category.id),
      update_path: budget_path(category)
    )
  end

  def unclassified_props(spent_cents, range)
    {
      name: "Unclassified",
      color: "#71717a",
      spent_cents:,
      spent_label: money_from_cents(spent_cents),
      filters_path: transactions_path(start_date: range.begin.iso8601, end_date: range.end.iso8601, direction: "debit", classified: "unclassified")
    }
  end

  def dollars_to_cents(value)
    (BigDecimal(value.to_s.presence || "0") * 100).round
  rescue ArgumentError
    0
  end

  def percentage(numerator, denominator)
    return 0 if denominator.blank? || denominator.zero?

    ((numerator.to_f / denominator) * 100).round.clamp(0, 999)
  end
end
