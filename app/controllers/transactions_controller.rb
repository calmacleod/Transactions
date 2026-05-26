class TransactionsController < ApplicationController
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 25
  ALL_PER_PAGE = "all"

  helper_method :transaction_per_page_options

  def index
    categories = Category.by_name
    saved_queries = Current.session.user.saved_transaction_queries.ordered
    selected_saved_query = saved_queries.find_by(id: params[:saved_query_id])
    filter_params = merged_filter_params(selected_saved_query)
    filter = TransactionFilter.new(filter_params)
    filtered_transactions = filter.call
    transactions_per_page = transactions_per_page()
    pagy, transactions = pagy(:offset, filtered_transactions, limit: transactions_page_limit(filtered_transactions, transactions_per_page))
    start_date = filter.start_date
    end_date = filter.end_date

    render inertia: {
      categories: category_options(categories),
      saved_queries: saved_queries.map { |query| saved_query_props(query) },
      selected_saved_query_id: selected_saved_query&.id,
      filter_params: filter_params,
      quick_ranges: TransactionFilter::QUICK_RANGES.map { |value, label| { value:, label: } },
      filter_active: filter.active?,
      date_summary: date_summary(start_date, end_date),
      transactions: transactions.map { |transaction| transaction_props(transaction) },
      pagination: pagination_props(pagy, filter_params, selected_saved_query),
      per_page: transactions_per_page,
      per_page_options: transaction_per_page_options.map { |label, value| { label:, value: } },
      actions: {
        index: transactions_path,
        bulk_update: bulk_update_transactions_path,
        save_query: saved_transaction_queries_path
      }
    }
  end

  def update
    transaction = ExpenseTransaction.find(params[:id])
    transaction.update!(transaction_params)

    redirect_back fallback_location: transactions_path, notice: "Transaction updated."
  end

  def bulk_update
    category_id = bulk_category_id

    transactions = ExpenseTransaction.where(id: bulk_transaction_ids)
    transactions.find_each do |transaction|
      transaction.update!(category_id:)
    end

    redirect_back fallback_location: transactions_path, notice: "Updated #{helpers.pluralize(transactions.size, "transaction")}."
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

  def transactions_page_limit(filtered_transactions, transactions_per_page)
    return [ filtered_transactions.count, 1 ].max if transactions_per_page == ALL_PER_PAGE

    transactions_per_page
  end

  def merged_filter_params(selected_saved_query)
    saved_filters = selected_saved_query&.filters || {}
    request_filters = TransactionFilter.clean(params)

    saved_filters.merge(request_filters)
  end

  def saved_query_props(saved_query)
    {
      id: saved_query.id,
      name: saved_query.name,
      path: transactions_path(saved_query_id: saved_query.id),
      destroy_path: saved_transaction_query_path(saved_query)
    }
  end

  def date_summary(start_date, end_date)
    if start_date.present? && end_date.present?
      "Showing #{start_date.strftime("%b %-d, %Y")} to #{end_date.strftime("%b %-d, %Y")}"
    elsif start_date.present?
      "Showing records from #{start_date.strftime("%b %-d, %Y")}"
    elsif end_date.present?
      "Showing records through #{end_date.strftime("%b %-d, %Y")}"
    else
      "Showing filtered records"
    end
  end

  def pagination_props(pagy, filter_params, selected_saved_query)
    base_params = filter_params.dup
    base_params[:saved_query_id] = selected_saved_query.id if selected_saved_query.present?
    base_params[:limit] = params[:limit] if params[:limit].present?

    {
      count: pagy.count,
      from: pagy.count.positive? ? pagy.from : 0,
      to: pagy.count.positive? ? pagy.to : 0,
      page: pagy.page,
      pages: pagy.pages,
      prev_path: pagy.page > 1 ? transactions_path(base_params.merge(page: pagy.page - 1)) : nil,
      next_path: pagy.page < pagy.pages ? transactions_path(base_params.merge(page: pagy.page + 1)) : nil,
      pages_series: pagination_series(pagy).map do |page|
        if page == :gap
          { gap: true }
        else
          {
            label: page.to_s,
            current: page == pagy.page,
            gap: false,
            path: transactions_path(base_params.merge(page:))
          }
        end
      end
    }
  end

  def pagination_series(pagy)
    return (1..pagy.pages).to_a if pagy.pages <= 7

    visible_pages = [ 1, pagy.pages, pagy.page - 1, pagy.page, pagy.page + 1 ]
    visible_pages += [ 2, 3, 4 ] if pagy.page <= 4
    visible_pages += [ pagy.pages - 3, pagy.pages - 2, pagy.pages - 1 ] if pagy.page >= pagy.pages - 3
    visible_pages = visible_pages.select { |page| page.between?(1, pagy.pages) }.uniq.sort

    visible_pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last.to_i + 1
      series << page
    end
  end
end
