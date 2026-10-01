module Ai
  module Tools
    class SearchTransactionsTool < RubyLLM::Tool
      description "Search existing transactions by text, dates, category, direction, amount, day of week, or subcategory."

      parameter :query, description: "Merchant or description text", required: false
      parameter :start_date, description: "Start date in YYYY-MM-DD format", required: false
      parameter :end_date, description: "End date in YYYY-MM-DD format", required: false
      parameter :category_id, description: "Category id", required: false
      parameter :subcategory_id, description: "Subcategory id", required: false
      parameter :direction, description: "debit or credit", required: false
      parameter :min_amount, description: "Minimum amount in dollars", required: false
      parameter :max_amount, description: "Maximum amount in dollars", required: false

      def name
        "search_transactions"
      end

      def execute(**filters)
        transactions = TransactionFilter.new(filters.transform_keys(&:to_s)).call.includes(:category, :subcategories).limit(50).to_a

        {
          count: transactions.size,
          transactions: transactions.map { |transaction| Ai::TransactionPayload.record(transaction) }
        }
      end
    end
  end
end
