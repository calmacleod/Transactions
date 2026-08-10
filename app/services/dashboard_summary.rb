class DashboardSummary
  DISCRETIONARY_CATEGORIES = %w[Restaurants Shopping Subscriptions Entertainment Travel].freeze

  attr_reader :range, :user

  def initialize(range: Date.current.beginning_of_month..Date.current.end_of_month, user: Current.user)
    @range = range
    @user = user
  end

  def total_spend_cents
    @total_spend_cents ||= expenses.sum(:amount_cents)
  end

  def transaction_count
    @transaction_count ||= transactions.count
  end

  def expense_count
    @expense_count ||= expenses.count
  end

  def average_expense_cents
    return 0 if expense_count.zero?

    total_spend_cents / expense_count
  end

  def category_totals
    @category_totals ||= expense_records.group_by { |transaction| transaction.category || uncategorized_category }
                                        .map { |category, records| category_total(category, records) }
                                        .sort_by { |item| -item[:cents] }
  end

  def day_of_week_totals
    @day_of_week_totals ||= begin
      totals = expense_records.group_by { |transaction| transaction.occurred_on.wday }

      Date::DAYNAMES.each_with_index.map do |name, wday|
        records = totals.fetch(wday, [])

        {
          name: name.first(3),
          full_name: name,
          wday:,
          count: records.size,
          cents: records.sum(&:amount_cents),
          filters: range_filters.merge(day_of_week: wday)
        }
      end
    end
  end

  def month_trend(months: 4)
    @month_trends ||= {}
    @month_trends[months] ||= begin
      end_month = Date.current.beginning_of_month
      start_month = (months - 1).months.ago.to_date.beginning_of_month
      totals = transaction_scope.expenses.where(occurred_on: start_month..end_month.end_of_month).group_by_month

      months.times.map do |offset|
        month = start_month.advance(months: offset)

        {
          label: month.strftime("%b"),
          full_label: month.strftime("%B %Y"),
          cents: totals.fetch(month, 0),
          filters: {
            start_date: month.iso8601,
            end_date: month.end_of_month.iso8601,
            direction: "debit"
          }
        }
      end
    end
  end

  def month_to_month_delta
    @month_to_month_delta ||= begin
      current_month, previous_month = month_trend.last(2).reverse
      if current_month.blank? || previous_month.blank?
        { cents: 0, percent: 0 }
      else
        cents = current_month[:cents] - previous_month[:cents]
        percent = percentage(cents.abs, previous_month[:cents])
        { cents:, percent: }
      end
    end
  end

  def top_merchants(limit: 5)
    @top_merchants ||= {}
    @top_merchants[limit] ||= expense_records.group_by { |transaction| normalized_merchant(transaction.description) }
                                            .map { |merchant, records| { merchant:, count: records.size, cents: records.sum(&:amount_cents), filters: range_filters.merge(query: merchant) } }
                                            .sort_by { |item| -item[:cents] }
                                            .first(limit)
  end

  def recommendations
    @recommendations ||= [
      budget_recommendation,
      discretionary_recommendation,
      frequency_recommendation,
      merchant_recommendation
    ].compact.first(4)
  end

  private

  def transactions
    @transactions ||= transaction_scope.includes(:category).between(range.begin, range.end)
  end

  def expenses
    @expenses ||= transactions.expenses
  end

  def expense_records
    @expense_records ||= expenses.to_a
  end

  def category_total(category, records)
    cents = records.sum(&:amount_cents)

    {
      category_id: category.persisted? ? category.id : nil,
      name: category.name,
      color: category.color.presence || "#64748b",
      cents:,
      count: records.size,
      budget_cents: category.monthly_budget_cents,
      percent: percentage(cents, total_spend_cents),
      budget_percent: percentage(cents, category.monthly_budget_cents),
      filters: category.persisted? ? range_filters.merge(category_id: category.id) : range_filters.merge(classified: "unclassified")
    }
  end

  def budget_recommendation
    over_budget = category_totals.select { |category| category[:budget_cents].present? && category[:cents] > category[:budget_cents] }
                                 .max_by { |category| category[:cents] - category[:budget_cents] }
    return if over_budget.blank?

    overage = over_budget[:cents] - over_budget[:budget_cents]

    {
      title: "Bring #{over_budget[:name]} back under budget",
      body: "#{over_budget[:name]} is over its monthly target by #{money(overage)}. A 15% reduction next month would save about #{money((over_budget[:cents] * 0.15).round)}.",
      severity: "warning",
      amount_cents: overage,
      filters: over_budget[:filters]
    }
  end

  def discretionary_recommendation
    category = category_totals.select { |item| DISCRETIONARY_CATEGORIES.include?(item[:name]) }
                              .max_by { |item| item[:cents] }
    return if category.blank? || category[:cents].zero?

    {
      title: "Trim #{category[:name].downcase} first",
      body: "#{category[:name]} is the largest flexible category this period at #{money(category[:cents])}. Cutting it by 20% would free up #{money((category[:cents] * 0.20).round)}.",
      severity: "info",
      amount_cents: (category[:cents] * 0.20).round,
      filters: category[:filters]
    }
  end

  def frequency_recommendation
    busiest_day = day_of_week_totals.max_by { |day| day[:count] }
    return if busiest_day.blank? || busiest_day[:count] < 3

    {
      title: "#{busiest_day[:full_name]} is your busiest spend day",
      body: "#{busiest_day[:count]} purchases landed on #{busiest_day[:full_name]} for #{money(busiest_day[:cents])}. Check recurring habits or errands clustered on that day.",
      severity: "info",
      amount_cents: busiest_day[:cents],
      filters: busiest_day[:filters]
    }
  end

  def merchant_recommendation
    merchant = top_merchants.first
    return if merchant.blank? || merchant[:count] < 2

    {
      title: "Watch repeat spending at #{merchant[:merchant].titleize}",
      body: "#{merchant[:count]} purchases at #{merchant[:merchant].titleize} total #{money(merchant[:cents])}. This is a good candidate for a monthly cap.",
      severity: "warning",
      amount_cents: merchant[:cents],
      filters: merchant[:filters]
    }
  end

  def range_filters
    {
      start_date: range.begin.iso8601,
      end_date: range.end.iso8601,
      direction: "debit"
    }
  end

  def percentage(numerator, denominator)
    return 0 if denominator.blank? || denominator.zero?

    ((numerator.to_f / denominator) * 100).round
  end

  def normalized_merchant(description)
    description.split(/\s{2,}| #|\*/).first.to_s.downcase.squish
  end

  def uncategorized_category
    @uncategorized_category ||= Category.new(name: "Uncategorized", color: "#64748b")
  end

  def transaction_scope
    user&.expense_transactions || ExpenseTransaction.all
  end

  def money(cents)
    "$#{format('%.2f', cents.to_d / 100)}"
  end
end
