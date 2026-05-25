class TransactionsController < ApplicationController
  def index
    @categories = Category.by_name
    @saved_queries = Current.session.user.saved_transaction_queries.ordered
    @selected_saved_query = @saved_queries.find_by(id: params[:saved_query_id])
    @filter_params = merged_filter_params
    @filter = TransactionFilter.new(@filter_params)
    @transactions = @filter.call
    @start_date = @filter.start_date
    @end_date = @filter.end_date
  end

  def update
    transaction = ExpenseTransaction.find(params[:id])
    transaction.update!(transaction_params)

    redirect_back fallback_location: transactions_path, notice: "Transaction updated."
  end

  private

  def transaction_params
    params.require(:expense_transaction).permit(:category_id)
  end

  def merged_filter_params
    saved_filters = @selected_saved_query&.filters || {}
    request_filters = TransactionFilter.clean(params)

    saved_filters.merge(request_filters)
  end
end
