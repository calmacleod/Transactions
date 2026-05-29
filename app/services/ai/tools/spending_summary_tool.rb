module Ai
  module Tools
    class SpendingSummaryTool < RubyLLM::Tool
      description "Summarize spending totals for a date range by category and merchant."

      param :start_date, desc: "Start date in YYYY-MM-DD format", required: false
      param :end_date, desc: "End date in YYYY-MM-DD format", required: false

      def name
        "spending_summary"
      end

      def execute(start_date: nil, end_date: nil)
        start_on = parse_date(start_date) || Date.current.beginning_of_month
        end_on = parse_date(end_date) || Date.current
        transaction_scope = Current.user&.expense_transactions || ExpenseTransaction.all
        transactions = transaction_scope.expenses.includes(:category).between(start_on, end_on).to_a

        {
          start_date: start_on,
          end_date: end_on,
          transaction_count: transactions.size,
          total_dollars: Ai::TransactionPayload.dollars(transactions.sum(&:amount_cents)),
          category_totals: totals(transactions.group_by { |transaction| transaction.category&.name || "Uncategorized" }),
          merchant_totals: totals(transactions.group_by { |transaction| transaction.merchant_name.downcase }).sort_by { |_merchant, dollars| -dollars.to_d }.first(25).to_h
        }
      end

      private

      def parse_date(value)
        Date.iso8601(value) if value.present?
      rescue ArgumentError
        nil
      end

      def totals(groups)
        groups.transform_values { |items| Ai::TransactionPayload.dollars(items.sum(&:amount_cents)) }
      end
    end
  end
end
