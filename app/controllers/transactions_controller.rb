class TransactionsController < ApplicationController
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 25
  ALL_PER_PAGE = "all"
  INDEX_COLUMNS = %i[
    id occurred_on description amount_cents direction category_id notes
    classification_reason classification_confidence
  ].freeze

  helper_method :transaction_per_page_options

  def index
    render inertia: transaction_index_props
  end

  def chat
    filter_params = TransactionFilter.clean(params[:filters] || params)
    filter = TransactionFilter.new(filter_params)
    transactions = filtered_chat_transactions(filter)
    chat = current_chat(filter_params, transactions)
    user_message = chat.messages.create!(role: "user", content: params[:question].to_s, status: "complete")
    assistant_message = chat.messages.create!(role: "assistant", content: "", status: "queued", model: Ai::Controls.model_for(:chat))
    chat.touch

    AiChatChannel.broadcast_message(chat, user_message)
    AiChatChannel.broadcast_message(chat, assistant_message)

    chat_enabled = Ai::Controls.enabled?(:chat)
    if chat_enabled
      ProcessAiChatMessageJob.perform_later(chat.id, assistant_message.id)
    else
      assistant_message.update!(
        status: "complete",
        content: "AI chat is disabled, over the monthly request limit, or no provider key is configured."
      )
      AiChatChannel.broadcast_message_update(chat, assistant_message)
    end

    render json: {
      source: chat_enabled ? "queued" : "automatic",
      answer: chat_enabled ? nil : assistant_message.content,
      chat_id: chat.id,
      assistant_message_id: assistant_message.id,
      messages: chat_messages(chat)
    }, status: :accepted
  end

  def update
    transaction = current_user.expense_transactions.find(params[:id])
    transaction.update!(normalized_transaction_params)

    respond_to do |format|
      format.html { redirect_back fallback_location: transactions_path, notice: "Transaction updated." }
      format.json do
        updated_transaction = current_user.expense_transactions.includes(:category, :subcategories).find(transaction.id)
        render json: { transaction: transaction_props(updated_transaction) }
      end
    end
  end

  def bulk_update
    bulk_attributes = {}
    bulk_attributes[:category_id] = bulk_category_id if bulk_category_update?
    subcategory_ids = bulk_subcategory_ids

    transactions = current_user.expense_transactions.where(id: bulk_transaction_ids)
    transactions = transactions.includes(:subcategories) if subcategory_ids.any?
    transactions.find_each do |transaction|
      attributes = bulk_attributes.dup
      attributes[:subcategory_ids] = (transaction.subcategory_ids + subcategory_ids).uniq if subcategory_ids.any?
      transaction.update!(attributes) if attributes.any?
    end

    redirect_back fallback_location: transactions_path, notice: "Updated #{helpers.pluralize(transactions.size, "transaction")}."
  end

  private

  def transaction_index_props
    {
      categories: InertiaRails.defer(group: "transaction_controls") { category_options(transaction_categories) },
      subcategories: InertiaRails.defer(group: "transaction_controls") { current_user.transaction_subcategories.by_name.map { |subcategory| subcategory_props(subcategory) } },
      saved_queries: InertiaRails.defer(group: "transaction_controls") { saved_queries.map { |query| saved_query_props(query) } },
      selected_saved_query_id: -> { selected_saved_query&.id },
      filter_params: -> { transaction_filter_params },
      quick_ranges: TransactionFilter::QUICK_RANGES.map { |value, label| { value:, label: } },
      filter_active: -> { transaction_filter.active? },
      date_summary: -> { date_summary(transaction_filter.start_date, transaction_filter.end_date) },
      sort: -> { transaction_sort_props },
      transactions: -> { paginated_transactions.map { |transaction| transaction_props(transaction) } },
      pagination: -> { pagination_props(transaction_pagy, transaction_filter_params, selected_saved_query) },
      per_page: -> { transactions_per_page },
      per_page_options: transaction_per_page_options.map { |label, value| { label:, value: } },
      actions: {
        index: transactions_path,
        chat: chat_transactions_path,
        bulk_update: bulk_update_transactions_path,
        save_query: saved_transaction_queries_path,
        chat_template: ai_chat_path(":id"),
        chats: ai_chats_path
      }
    }
  end

  def transaction_categories
    @transaction_categories ||= current_user.categories.by_name
  end

  def saved_queries
    @saved_queries ||= Current.session.user.saved_transaction_queries.ordered
  end

  def selected_saved_query
    return @selected_saved_query if defined?(@selected_saved_query)
    return @selected_saved_query = nil if params[:saved_query_id].blank?

    @selected_saved_query = saved_queries.find_by(id: params[:saved_query_id])
  end

  def transaction_filter_params
    @transaction_filter_params ||= merged_filter_params(selected_saved_query)
  end

  def transaction_filter
    @transaction_filter ||= TransactionFilter.new(transaction_filter_params)
  end

  def transaction_sort_props
    {
      field: transaction_filter_params["sort"].presence || "date",
      direction: transaction_filter_params["sort_direction"].presence || "desc"
    }
  end

  def paginated_transaction_result
    @paginated_transaction_result ||= begin
      filtered_transactions = transaction_filter
        .call(current_user.expense_transactions)
        .select(*INDEX_COLUMNS)
        .includes(:category, :subcategories)
      limit = transactions_page_limit(filtered_transactions, transactions_per_page)

      pagy(:offset, filtered_transactions, limit:)
    end
  end

  def transaction_pagy
    paginated_transaction_result.first
  end

  def paginated_transactions
    paginated_transaction_result.last
  end

  def transaction_params
    params.require(:expense_transaction).permit(:category_id, :notes, subcategory_ids: [])
  end

  def bulk_transaction_params
    params.fetch(:bulk_transaction, {}).permit(:category_id, subcategory_ids: [], transaction_ids: [])
  end

  def bulk_transaction_ids
    bulk_transaction_params.fetch(:transaction_ids, []).compact_blank
  end

  def bulk_category_update?
    bulk_transaction_params.key?(:category_id)
  end

  def bulk_category_id
    category_id = bulk_transaction_params[:category_id].presence
    current_user.categories.find(category_id).id if category_id.present?
  end

  def bulk_subcategory_ids
    current_user.transaction_subcategories.where(id: bulk_transaction_params.fetch(:subcategory_ids, []).compact_blank).ids
  end

  def transaction_per_page_options
    PER_PAGE_OPTIONS.map { |option| [ option, option ] } + [ [ "All", ALL_PER_PAGE ] ]
  end

  def transactions_per_page
    return @transactions_per_page if defined?(@transactions_per_page)

    requested_limit = params[:limit]
    requested_limit_value = Integer(requested_limit, exception: false) if requested_limit.present?

    if requested_limit == ALL_PER_PAGE
      @transactions_per_page = session[:transactions_per_page] = ALL_PER_PAGE
    elsif PER_PAGE_OPTIONS.include?(requested_limit_value)
      @transactions_per_page = session[:transactions_per_page] = requested_limit_value
    elsif PER_PAGE_OPTIONS.include?(session[:transactions_per_page])
      @transactions_per_page = session[:transactions_per_page]
    elsif session[:transactions_per_page] == ALL_PER_PAGE
      @transactions_per_page = ALL_PER_PAGE
    else
      @transactions_per_page = DEFAULT_PER_PAGE
    end
  end

  def transactions_page_limit(filtered_transactions, transactions_per_page)
    return [ filtered_transactions.unscope(:select).count, 1 ].max if transactions_per_page == ALL_PER_PAGE

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

  def filtered_chat_transactions(filter)
    scope = filter.call(current_user.expense_transactions).includes(:category, :subcategories)
    transaction_ids = Array(params[:transaction_ids]).compact_blank

    transaction_ids.present? ? scope.where(id: transaction_ids) : scope
  end

  def current_chat(filter_params, transactions)
    if params[:chat_id].present?
      return Current.session.user.ai_chats.find(params[:chat_id])
    end

    records = transactions.limit(500).to_a
    chat = Current.session.user.ai_chats.create!(
      title: chat_title(records, filter_params),
      model: Ai::Controls.model_for(:chat),
      context_filters: filter_params
    )
    chat.expense_transactions = records
    chat
  end

  def chat_title(records, filter_params)
    if records.any?
      "#{helpers.pluralize(records.size, "transaction")} from #{records.map(&:occurred_on).compact.min&.strftime("%b %-d")} to #{records.map(&:occurred_on).compact.max&.strftime("%b %-d")}"
    elsif filter_params.present?
      "Filtered transaction chat"
    else
      "Transaction chat"
    end
  end

  def chat_messages(chat)
    chat.messages.ordered.map { |message| AiChatChannel.message_payload(message) }
  end

  def normalized_transaction_params
    attributes = transaction_params.to_h
    if attributes.key?("category_id") && attributes["category_id"].present?
      attributes["category_id"] = current_user.categories.find(attributes["category_id"]).id
    end
    if attributes.key?("subcategory_ids")
      attributes["subcategory_ids"] = current_user.transaction_subcategories.where(id: attributes["subcategory_ids"]).ids
    end
    attributes
  end
end
