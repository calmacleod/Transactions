class TransactionFilter
  FILTER_KEYS = %w[
    start_date end_date quick_range category_id direction classified query
    min_amount max_amount day_of_week subcategory_id sort sort_direction
  ].freeze
  SORT_COLUMNS = {
    "date" => "occurred_on",
    "amount" => "amount_cents"
  }.freeze

  QUICK_RANGES = {
    "month_to_date" => "Month to date",
    "past_week" => "Past week",
    "last_30_days" => "Last 30 days",
    "previous_month" => "Previous month",
    "last_3_months" => "Last 3 months"
  }.freeze

  attr_reader :params

  def initialize(params = {})
    @params = self.class.clean(params)
  end

  def self.clean(params)
    hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h

    hash.slice(*FILTER_KEYS).compact_blank
  end

  def call(scope = Current.user&.expense_transactions || ExpenseTransaction.all)
    relation = scope.includes(:category)
    relation = apply_dates(relation)
    relation = relation.where(category_id: params["category_id"]) if params["category_id"].present?
    relation = relation.joins(:subcategories).where(transaction_subcategories: { id: params["subcategory_id"] }).distinct if params["subcategory_id"].present?
    relation = relation.where(direction: params["direction"]) if params["direction"].present?
    relation = apply_classified(relation)
    relation = apply_text(relation)
    relation = apply_amounts(relation)
    relation = apply_day(relation)
    apply_sort(relation)
  end

  def start_date
    quick_range&.begin || parse_date(params["start_date"])
  end

  def end_date
    quick_range&.end || parse_date(params["end_date"])
  end

  def active?
    params.present?
  end

  private

  def apply_sort(relation)
    relation.order(sort_column => sort_direction, id: sort_direction)
  end

  def sort_column
    SORT_COLUMNS.fetch(params["sort"], "occurred_on")
  end

  def sort_direction
    params["sort_direction"] == "asc" ? :asc : :desc
  end

  def apply_dates(relation)
    relation = relation.where(occurred_on: start_date..) if start_date.present?
    relation = relation.where(occurred_on: ..end_date) if end_date.present?
    relation
  end

  def apply_classified(relation)
    case params["classified"]
    when "classified"
      relation.where.not(category_id: nil)
    when "unclassified"
      relation.where(category_id: nil)
    else
      relation
    end
  end

  def apply_text(relation)
    return relation if params["query"].blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params["query"])}%"
    relation.where("expense_transactions.description LIKE ?", pattern)
  end

  def apply_amounts(relation)
    relation = relation.where(amount_cents: amount_cents(params["min_amount"])..) if params["min_amount"].present?
    relation = relation.where(amount_cents: ..amount_cents(params["max_amount"])) if params["max_amount"].present?
    relation
  end

  def apply_day(relation)
    return relation if params["day_of_week"].blank?

    relation.where("CAST(strftime('%w', occurred_on) AS INTEGER) = ?", params["day_of_week"].to_i)
  end

  def quick_range
    case params["quick_range"]
    when "month_to_date"
      Date.current.beginning_of_month..Date.current
    when "past_week"
      1.week.ago.to_date..Date.current
    when "last_30_days"
      30.days.ago.to_date..Date.current
    when "previous_month"
      1.month.ago.to_date.beginning_of_month..1.month.ago.to_date.end_of_month
    when "last_3_months"
      3.months.ago.to_date.beginning_of_month..Date.current
    end
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end

  def amount_cents(value)
    (BigDecimal(value.to_s) * 100).round
  rescue ArgumentError
    0
  end
end
