require "digest"

module Insights
  class Analysis
    MIN_MEANINGFUL_CENTS = 2_500
    LARGE_NEW_SPEND_CENTS = 10_000
    DISCRETIONARY_CATEGORIES = %w[Restaurants Shopping Subscriptions Entertainment Travel].freeze

    def initialize(transactions:, start_date:, end_date:, user:)
      @records = transactions.to_a
      @start_date = start_date
      @end_date = end_date
      @user = user
    end

    def call
      {
        period: period,
        overview: overview,
        transaction_ids: records.map(&:id),
        findings: findings
      }
    end

    private

    attr_reader :records, :start_date, :end_date, :user

    def expenses
      @expenses ||= records.select(&:expense?)
    end

    def analysis_month
      @analysis_month ||= (expenses.map(&:occurred_on).compact.max || end_date).beginning_of_month
    end

    def period
      {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601,
        analysis_month: analysis_month.iso8601,
        analysis_month_label: analysis_month.strftime("%B %Y")
      }
    end

    def month_sequence
      @month_sequence ||= begin
        first_month = [ start_date.beginning_of_month, analysis_month ].min
        months = []
        month = first_month
        while month <= analysis_month
          months << month
          month = month.next_month
        end
        months
      end
    end

    def current_expenses
      @current_expenses ||= expenses_by_month.fetch(analysis_month, [])
    end

    def previous_month
      analysis_month.prev_month
    end

    def previous_expenses
      @previous_expenses ||= expenses_by_month.fetch(previous_month, [])
    end

    def historical_months
      @historical_months ||= month_sequence.select { |month| month < analysis_month }
    end

    def overview
      current_total = current_expenses.sum(&:amount_cents)
      previous_total = previous_expenses.sum(&:amount_cents)
      delta = current_total - previous_total

      {
        month_label: analysis_month.strftime("%B %Y"),
        spend: metric_value("Spend", current_total),
        change: comparison_value(delta, previous_total),
        recurring: metric_value("Recurring baseline", recurring_merchants.sum { |merchant| merchant[:monthly_cents] }),
        unusual_count: unusual_transactions.size,
        unclassified: metric_value("Unclassified", current_expenses.select { |transaction| transaction.category_id.nil? }.sum(&:amount_cents))
      }
    end

    def findings
      @findings ||= begin
        candidates = budget_findings + category_shift_findings + merchant_frequency_findings + unusual_findings
        candidates << recurring_finding if recurring_finding
        candidates << unclassified_finding if unclassified_finding
        candidates.compact.sort_by { |finding| -finding[:score] }.first(8)
      end
    end

    def budget_findings
      return [] unless user

      category_transactions = current_expenses.group_by(&:category_id)
      user.categories.where.not(monthly_budget_cents: nil).filter_map do |category|
        budget = category.monthly_budget_cents.to_i
        spent = category_transactions.fetch(category.id, []).sum(&:amount_cents)
        next if budget.zero? || spent.zero?

        projected = projected_month_total(spent)
        overage = projected - budget
        next unless overage >= MIN_MEANINGFUL_CENTS && projected >= (budget * 1.05)

        transactions = category_transactions.fetch(category.id, [])
        build_finding(
          key: "budget-pace-#{category.id}",
          kind: "budget_pace",
          title: "#{category.name} is pacing #{money(overage)} over budget",
          body: "At the current pace, #{category.name.downcase} spending is projected to reach #{money(projected)} against a #{money(budget)} monthly target.",
          action: "Review the linked purchases before the month closes and decide where to preserve at least #{money(overage)}.",
          severity: "warning",
          score: 95 + percentage(overage, budget),
          metric: metric("Projected", projected, "Budget", budget, overage, "up"),
          transactions:,
          filters: category_filters(category.id)
        )
      end
    end

    def category_shift_findings
      current_by_category = current_expenses.group_by(&:category_id)
      current_by_category.filter_map do |category_id, transactions|
        current_total = transactions.sum(&:amount_cents)
        historical_totals = historical_months.map do |month|
          expenses_by_category_month.fetch([ category_id, month ], []).sum(&:amount_cents)
        end
        baseline = average(historical_totals)
        category_name = transactions.first.category&.name || "Unclassified"

        if baseline.positive?
          delta = current_total - baseline
          change_percent = percentage(delta.abs, baseline)
          next unless delta.abs >= MIN_MEANINGFUL_CENTS && change_percent >= 25

          direction = delta.positive? ? "above" : "below"
          build_finding(
            key: "category-shift-#{category_id || 'none'}",
            kind: "category_shift",
            title: "#{category_name} is #{change_percent}% #{direction} its recent baseline",
            body: "#{analysis_month.strftime('%B')} totals #{money(current_total)}, compared with an average of #{money(baseline)} across the prior #{historical_months.size} month#{'s' unless historical_months.one?}.",
            action: category_shift_action(category_name, delta),
            severity: delta.positive? ? "warning" : "success",
            score: 70 + [ change_percent, 100 ].min,
            metric: metric("This month", current_total, "Prior average", baseline, delta, delta.positive? ? "up" : "down"),
            transactions:,
            filters: category_filters(category_id)
          )
        elsif current_total >= LARGE_NEW_SPEND_CENTS && historical_months.any?
          build_finding(
            key: "new-category-#{category_id || 'none'}",
            kind: "new_spend",
            title: "#{category_name} added #{money(current_total)} without a recent baseline",
            body: "No #{category_name.downcase} spending appeared in the prior #{historical_months.size} month#{'s' unless historical_months.one?}, making this a new pressure point rather than normal variation.",
            action: "Check whether the linked purchases are one-time or the start of a new monthly commitment.",
            severity: "warning",
            score: 75,
            metric: metric("New spend", current_total, "Prior average", 0, current_total, "up"),
            transactions:,
            filters: category_filters(category_id)
          )
        end
      end
    end

    def merchant_frequency_findings
      current_by_merchant = current_expenses.group_by { |transaction| merchant_key(transaction) }
      current_by_merchant.filter_map do |merchant, transactions|
        current_count = transactions.size
        next if current_count < 2 || historical_months.empty?

        historical_counts = historical_months.map do |month|
          expenses_by_merchant_month.fetch([ merchant, month ], []).size
        end
        baseline = average(historical_counts)
        increase = current_count - baseline
        current_total = transactions.sum(&:amount_cents)
        next unless increase >= 2 && current_total >= 3_000

        build_finding(
          key: "merchant-frequency-#{Digest::SHA256.hexdigest(merchant).first(10)}",
          kind: "merchant_frequency",
          title: "#{merchant.titleize} visits rose to #{current_count} this month",
          body: "The recent baseline is #{format_number(baseline)} visit#{'s' unless baseline == 1}; the extra frequency added #{money(current_total)} this month.",
          action: "Review the linked visits together and decide whether fewer trips or a per-visit cap would help.",
          severity: "warning",
          score: 65 + (increase * 10),
          metric: count_metric("Visits", current_count, "Prior average", baseline, increase),
          transactions:,
          filters: merchant_filters(merchant)
        )
      end
    end

    def unusual_findings
      unusual_transactions.first(3).map do |candidate|
        transaction = candidate[:transaction]
        build_finding(
          key: "unusual-transaction-#{transaction.id}",
          kind: "unusual_transaction",
          title: "#{transaction.merchant_name} is #{candidate[:multiple]}x its usual amount",
          body: "This #{money(transaction.amount_cents)} purchase is #{money(candidate[:difference])} above the merchant's typical #{money(candidate[:baseline])} transaction.",
          action: "Open the exact transaction to confirm the amount, category, and whether it was exceptional or duplicated.",
          severity: "warning",
          score: 90 + [ candidate[:multiple] * 5, 30 ].min,
          metric: metric("This purchase", transaction.amount_cents, "Usual", candidate[:baseline], candidate[:difference], "up"),
          transactions: [ transaction ],
          filters: { transaction_id: transaction.id }
        )
      end
    end

    def unusual_transactions
      @unusual_transactions ||= current_expenses.filter_map do |transaction|
        history = expenses_by_merchant.fetch(merchant_key(transaction), []).select { |candidate| candidate.occurred_on < analysis_month }
        next if history.size < 2

        baseline = median(history.map(&:amount_cents))
        difference = transaction.amount_cents - baseline
        multiple = baseline.positive? ? (transaction.amount_cents.to_f / baseline).round(1) : 0
        next unless difference >= MIN_MEANINGFUL_CENTS && multiple >= 1.75

        { transaction:, baseline:, difference:, multiple: }
      end.sort_by { |candidate| -candidate[:difference] }
    end

    def recurring_finding
      return if recurring_merchants.empty?

      monthly_cents = recurring_merchants.sum { |merchant| merchant[:monthly_cents] }
      names = recurring_merchants.first(4).map { |merchant| merchant[:name].titleize }
      transactions = recurring_merchants.flat_map { |merchant| merchant[:current_transactions] }
      return if transactions.empty?

      build_finding(
        key: "recurring-baseline",
        kind: "recurring_commitment",
        title: "Repeat merchants create a #{money(monthly_cents)} monthly baseline",
        body: "#{names.to_sentence} recur at relatively stable amounts across multiple months, before variable spending begins.",
        action: "Review the linked charges as a group and cancel, renegotiate, or reclassify anything that is no longer intentional.",
        severity: "info",
        score: 85,
        metric: metric("Monthly baseline", monthly_cents, "Repeat merchants", recurring_merchants.size, nil, "steady", comparison_money: false),
        transactions:,
        filters: month_filters
      )
    end

    def recurring_merchants
      @recurring_merchants ||= begin
        required_months = [ month_sequence.size, 3 ].min
        expenses_by_merchant.filter_map do |merchant, transactions|
          by_month = transactions.group_by { |transaction| transaction.occurred_on.beginning_of_month }
          next if by_month.size < required_months || required_months < 2

          monthly_totals = by_month.values.map { |items| items.sum(&:amount_cents) }
          baseline = average(monthly_totals)
          next if baseline < 500

          maximum_deviation = monthly_totals.map { |total| (total - baseline).abs }.max
          next if percentage(maximum_deviation, baseline) > 15

          {
            name: merchant,
            monthly_cents: baseline,
            current_transactions: by_month.fetch(analysis_month, [])
          }
        end.sort_by { |merchant| -merchant[:monthly_cents] }
      end
    end

    def unclassified_finding
      transactions = current_expenses.select { |transaction| transaction.category_id.nil? }
      total = transactions.sum(&:amount_cents)
      current_total = current_expenses.sum(&:amount_cents)
      share = percentage(total, current_total)
      return if total < 3_000 && share < 10

      build_finding(
        key: "unclassified-spend",
        kind: "data_quality",
        title: "#{money(total)} is missing category context",
        body: "Unclassified purchases represent #{share}% of #{analysis_month.strftime('%B')} spending, which can hide budget pressure and distort category comparisons.",
        action: "Classify the linked transactions before relying on category or budget trends.",
        severity: "warning",
        score: 80 + share,
        metric: metric("Unclassified", total, "Share of spend", share, nil, "attention", comparison_money: false, comparison_suffix: "%"),
        transactions:,
        filters: month_filters.merge(classified: "unclassified")
      )
    end

    def build_finding(key:, kind:, title:, body:, action:, severity:, score:, metric:, transactions:, filters:)
      {
        key:,
        kind:,
        title:,
        body:,
        action:,
        severity:,
        score: score.round,
        metric:,
        transaction_ids: transactions.sort_by { |transaction| -transaction.amount_cents }.first(25).map(&:id),
        filters:
      }
    end

    def projected_month_total(spent)
      return spent unless analysis_month == Date.current.beginning_of_month

      elapsed_days = [ Date.current.day, 1 ].max
      (spent.to_d / elapsed_days * analysis_month.end_of_month.day).round
    end

    def category_filters(category_id)
      filters = month_filters
      category_id ? filters.merge(category_id:) : filters.merge(classified: "unclassified")
    end

    def merchant_filters(merchant)
      month_filters.merge(query: merchant)
    end

    def month_filters
      {
        start_date: analysis_month.iso8601,
        end_date: analysis_month.end_of_month.iso8601,
        direction: "debit"
      }
    end

    def category_shift_action(category_name, delta)
      if delta.positive?
        verb = DISCRETIONARY_CATEGORIES.include?(category_name) ? "Set a cap" : "Review the drivers"
        "#{verb} for the remaining month and target at least #{money(delta)} back toward the recent baseline."
      else
        "Check whether the #{money(delta.abs)} reduction is repeatable and protect it in next month's plan."
      end
    end

    def metric(label, cents, comparison_label, comparison, delta, trend, comparison_money: true, comparison_suffix: nil)
      {
        label:,
        value: money(cents),
        comparison_label:,
        comparison_value: comparison_money ? money(comparison) : "#{format_number(comparison)}#{comparison_suffix}",
        delta: delta.nil? ? nil : money(delta.abs),
        trend:
      }
    end

    def count_metric(label, value, comparison_label, comparison, delta)
      {
        label:,
        value: format_number(value),
        comparison_label:,
        comparison_value: format_number(comparison),
        delta: "+#{format_number(delta)}",
        trend: "up"
      }
    end

    def metric_value(label, cents)
      { label:, value: money(cents), cents: }
    end

    def comparison_value(delta, baseline)
      {
        value: money(delta.abs),
        direction: delta.negative? ? "down" : "up",
        percent: baseline.positive? ? percentage(delta.abs, baseline) : nil
      }
    end

    def merchant_key(transaction)
      transaction.merchant_name.downcase.squish
    end

    def expenses_by_month
      @expenses_by_month ||= expenses.group_by { |transaction| transaction.occurred_on.beginning_of_month }
    end

    def expenses_by_category_month
      @expenses_by_category_month ||= expenses.group_by do |transaction|
        [ transaction.category_id, transaction.occurred_on.beginning_of_month ]
      end
    end

    def expenses_by_merchant
      @expenses_by_merchant ||= expenses.group_by { |transaction| merchant_key(transaction) }
    end

    def expenses_by_merchant_month
      @expenses_by_merchant_month ||= expenses.group_by do |transaction|
        [ merchant_key(transaction), transaction.occurred_on.beginning_of_month ]
      end
    end

    def average(values)
      return 0 if values.empty?

      (values.sum.to_d / values.size).round
    end

    def median(values)
      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]).to_d / 2).round
    end

    def percentage(numerator, denominator)
      return 0 if denominator.to_i.zero?

      ((numerator.to_f / denominator) * 100).round
    end

    def money(cents)
      value = cents.to_i
      sign = value.negative? ? "-" : ""
      "#{sign}$#{format('%.2f', value.abs.to_d / 100)}"
    end

    def format_number(value)
      number = value.to_f
      number == number.round ? number.round.to_s : format("%.1f", number)
    end
  end
end
