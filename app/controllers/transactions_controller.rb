class TransactionsController < ApplicationController
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 25
  ALL_PER_PAGE = "all"

  helper_method :transaction_per_page_options

  def index
    @categories = Category.by_name
    @saved_queries = Current.session.user.saved_transaction_queries.ordered
    @selected_saved_query = @saved_queries.find_by(id: params[:saved_query_id])
    @filter_params = merged_filter_params
    @filter = TransactionFilter.new(@filter_params)
    filtered_transactions = @filter.call
    @transactions_per_page = transactions_per_page
    @pagy, @transactions = pagy(:offset, filtered_transactions, limit: transactions_page_limit(filtered_transactions))
    @start_date = @filter.start_date
    @end_date = @filter.end_date
  end

  def update
    @transaction = ExpenseTransaction.find(params[:id])
    @transaction.update!(transaction_params)
    @categories = Category.by_name

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back fallback_location: transactions_path, notice: "Transaction updated." }
    end
  end

  def bulk_update
    @categories = Category.by_name
    @transactions = ExpenseTransaction.where(id: bulk_transaction_ids)
    category_id = bulk_category_id

    @transactions.find_each do |transaction|
      transaction.update!(category_id:)
    end

    @transactions = ExpenseTransaction.includes(:category).where(id: bulk_transaction_ids)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: transactions_path, notice: "Updated #{helpers.pluralize(@transactions.size, "transaction")}." }
    end
  end

  private

  def transaction_params
    params.require(:expense_transaction).permit(:category_id)
  end

  def bulk_transaction_params
    params.fetch(:bulk_transaction, {}).permit(:category_id, transaction_ids: [])
  end

  def bulk_transaction_ids
    bulk_transaction_params.fetch(:transaction_ids, []).compact_blank
  end

  def bulk_category_id
    category_id = bulk_transaction_params[:category_id].presence
    Category.find(category_id).id if category_id.present?
  end

  def transaction_per_page_options
    PER_PAGE_OPTIONS.map { |option| [ option, option ] } + [ [ "All", ALL_PER_PAGE ] ]
  end

  def transactions_per_page
    requested_limit = params[:limit]
    requested_limit_value = Integer(requested_limit, exception: false) if requested_limit.present?

    if requested_limit == ALL_PER_PAGE
      session[:transactions_per_page] = ALL_PER_PAGE
      ALL_PER_PAGE
    elsif PER_PAGE_OPTIONS.include?(requested_limit_value)
      session[:transactions_per_page] = requested_limit_value
      requested_limit_value
    elsif PER_PAGE_OPTIONS.include?(session[:transactions_per_page])
      session[:transactions_per_page]
    elsif session[:transactions_per_page] == ALL_PER_PAGE
      ALL_PER_PAGE
    else
      DEFAULT_PER_PAGE
    end
  end

  def transactions_page_limit(filtered_transactions)
    return [ filtered_transactions.count, 1 ].max if @transactions_per_page == ALL_PER_PAGE

    @transactions_per_page
  end

  def merged_filter_params
    saved_filters = @selected_saved_query&.filters || {}
    request_filters = TransactionFilter.clean(params)

    saved_filters.merge(request_filters)
  end
end
