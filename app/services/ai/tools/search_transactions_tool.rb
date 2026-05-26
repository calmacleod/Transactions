module Ai
  module Tools
    class SearchTransactionsTool < RubyLLM::Tool
      description "Search existing transactions by text, dates, category, direction, amount, day of week, or subcategory."

      param :query, desc: "Merchant or description text", required: false
      param :start_date, desc: "Start date in YYYY-MM-DD format", required: false
      param :end_date, desc: "End date in YYYY-MM-DD format", required: false
      param :category_id, desc: "Category id", required: false
      param :subcategory_id, desc: "Subcategory id", required: false
      param :direction, desc: "debit or credit", required: false
      param :min_amount, desc: "Minimum amount in dollars", required: false
      param :max_amount, desc: "Maximum amount in dollars", required: false

      def name
        "search_transactions"
      end

      def execute(**filters)
        transactions = TransactionFilter.new(filters.stringify_keys).call.includes(:category, :subcategories).limit(50).to_a

        {
          count: transactions.size,
          transactions: transactions.map { |transaction| Ai::TransactionPayload.record(transaction) }
        }
      end
    end
  end
end
