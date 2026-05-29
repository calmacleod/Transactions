module Ai
  module Tools
    class BudgetSummaryTool < RubyLLM::Tool
      description "Return category budgets and spending for a month."

      param :month, desc: "Month in YYYY-MM format. Defaults to the current month.", required: false

      def name
        "budget_summary"
      end

      def execute(month: nil)
        start_date = parse_month(month)
        range = start_date..start_date.end_of_month
        transaction_scope = Current.user&.expense_transactions || ExpenseTransaction.all
        category_scope = Current.user&.categories || Category.all
        spent_by_category = transaction_scope.expenses.between(range.begin, range.end).group(:category_id).sum(:amount_cents)

        {
          month: start_date.strftime("%Y-%m"),
          categories: category_scope.by_name.map do |category|
            budget_cents = category.monthly_budget_cents.to_i
            spent_cents = spent_by_category.fetch(category.id, 0)
            {
              id: category.id,
              name: category.name,
              budget_dollars: Ai::TransactionPayload.dollars(budget_cents),
              spent_dollars: Ai::TransactionPayload.dollars(spent_cents),
              remaining_dollars: Ai::TransactionPayload.dollars(budget_cents - spent_cents)
            }
          end
        }
      end

      private

      def parse_month(month)
        Date.strptime("#{month.presence || Date.current.strftime('%Y-%m')}-01", "%Y-%m-%d")
      rescue ArgumentError
        Date.current.beginning_of_month
      end
    end
  end
end
