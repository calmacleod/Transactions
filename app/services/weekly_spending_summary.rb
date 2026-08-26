class WeeklySpendingSummary
  attr_reader :user

  def initialize(user: Current.user)
    @user = user
  end

  def trend(weeks: 8)
    @trends ||= {}
    @trends[weeks] ||= begin
      current_week = Date.current.beginning_of_week
      start_week = current_week.advance(weeks: -(weeks - 1))
      totals = transaction_scope.expenses.where(occurred_on: start_week..Date.current).group_by_week

      weeks.times.map do |offset|
        week = start_week.advance(weeks: offset)
        current = week == current_week
        period_end = current ? Date.current : week.end_of_week

        {
          label: week.strftime("%b %-d"),
          full_label: "#{week.strftime('%b %-d')} to #{period_end.strftime('%b %-d')}",
          cents: totals.fetch(week, 0),
          current_week: current,
          filters: {
            start_date: week.iso8601,
            end_date: period_end.iso8601,
            direction: "debit"
          }
        }
      end
    end
  end

  def completed_week_delta
    @completed_week_delta ||= begin
      previous_week, latest_week = trend.reject { |week| week[:current_week] }.last(2)
      if latest_week.blank? || previous_week.blank?
        { cents: 0, percent: 0 }
      else
        cents = latest_week[:cents] - previous_week[:cents]
        percent = percentage(cents.abs, previous_week[:cents])
        { cents:, percent: }
      end
    end
  end

  private

  def transaction_scope
    user&.expense_transactions || ExpenseTransaction.all
  end

  def percentage(numerator, denominator)
    return 0 if denominator.blank? || denominator.zero?

    ((numerator.to_f / denominator) * 100).round
  end
end
