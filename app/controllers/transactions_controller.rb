class TransactionsController < ApplicationController
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 25

  helper_method :transaction_per_page_options

  def index
    @categories = Category.by_name
    @saved_queries = Current.session.user.saved_transaction_queries.ordered
    @selected_saved_query = @saved_queries.find_by(id: params[:saved_query_id])
    @filter_params = merged_filter_params
    @filter = TransactionFilter.new(@filter_params)
    @transactions_per_page = transactions_per_page
    @pagy, @transactions = pagy(:offset, @filter.call, limit: @transactions_per_page)
    @start_date = @filter.start_date
    @end_date = @filter.end_date
  end

  def update
    @transaction = ExpenseTransaction.find(params[:id])
    @transaction.update!(transaction_params)
    @categories = Category.by_name

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "Transaction updated." }
      format.html { redirect_back fallback_location: transactions_path, notice: "Transaction updated." }
    end
  end

  private

  def transaction_params
    params.require(:expense_transaction).permit(:category_id)
  end

  def transaction_per_page_options
    PER_PAGE_OPTIONS
  end

  def transactions_per_page
    requested_limit = Integer(params[:limit], exception: false) if params[:limit].present?

    if PER_PAGE_OPTIONS.include?(requested_limit)
      session[:transactions_per_page] = requested_limit
      requested_limit
    elsif PER_PAGE_OPTIONS.include?(session[:transactions_per_page])
      session[:transactions_per_page]
    else
      DEFAULT_PER_PAGE
    end
  end

  def merged_filter_params
    saved_filters = @selected_saved_query&.filters || {}
    request_filters = TransactionFilter.clean(params)

    saved_filters.merge(request_filters)
  end
end
