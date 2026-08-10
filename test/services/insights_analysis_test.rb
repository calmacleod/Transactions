require "test_helper"

class InsightsAnalysisTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "insight-analysis@example.com", password: "password")
    @category = @user.categories.create!(name: "Dining out", color: "#dc2626", monthly_budget_cents: 10_000)
  end

  test "produces comparative findings with exact evidence and drill-down filters" do
    create_expense(Date.new(2026, 1, 5), "NEIGHBOURHOOD RESTAURANT", 1_000)
    create_expense(Date.new(2026, 2, 5), "NEIGHBOURHOOD RESTAURANT", 1_000)
    create_expense(Date.new(2026, 3, 5), "NEIGHBOURHOOD RESTAURANT", 1_000)
    current = create_expense(Date.new(2026, 4, 5), "NEIGHBOURHOOD RESTAURANT", 10_000)

    analysis = analyze(Date.new(2026, 1, 1), Date.new(2026, 4, 30))
    shift = analysis[:findings].find { |finding| finding[:kind] == "category_shift" }

    assert_equal "Dining out is 900% above its recent baseline", shift[:title]
    assert_equal "$100.00", shift.dig(:metric, :value)
    assert_equal "$10.00", shift.dig(:metric, :comparison_value)
    assert_includes shift[:transaction_ids], current.id
    assert_equal @category.id, shift.dig(:filters, :category_id)
    assert_equal "2026-04-01", shift.dig(:filters, :start_date)
  end

  test "detects stable recurring commitments and unusual merchant amounts" do
    %w[2026-01-03 2026-02-03 2026-03-03 2026-04-03].each do |date|
      create_expense(Date.iso8601(date), "STREAMING SERVICE", 1_500)
    end
    create_expense(Date.new(2026, 1, 12), "LOCAL MARKET", 1_000)
    create_expense(Date.new(2026, 2, 12), "LOCAL MARKET", 1_200)
    unusual = create_expense(Date.new(2026, 4, 12), "LOCAL MARKET", 5_000)

    analysis = analyze(Date.new(2026, 1, 1), Date.new(2026, 4, 30))
    recurring = analysis[:findings].find { |finding| finding[:kind] == "recurring_commitment" }
    outlier = analysis[:findings].find { |finding| finding[:kind] == "unusual_transaction" }

    assert_equal "$15.00", recurring.dig(:metric, :value)
    assert_match "Streaming Service", recurring[:body]
    assert_equal [ unusual.id ], outlier[:transaction_ids]
    assert_equal unusual.id, outlier.dig(:filters, :transaction_id)
    assert_equal "$50.00", outlier.dig(:metric, :value)
  end

  test "projects current month budget risk instead of waiting for an overage" do
    travel_to Date.new(2026, 8, 10) do
      transaction = create_expense(Date.new(2026, 8, 4), "EARLY MONTH DINING", 5_000)
      analysis = analyze(Date.new(2026, 5, 1), Date.new(2026, 8, 10))
      budget = analysis[:findings].find { |finding| finding[:kind] == "budget_pace" }

      assert_equal "$155.00", budget.dig(:metric, :value)
      assert_equal "$100.00", budget.dig(:metric, :comparison_value)
      assert_equal [ transaction.id ], budget[:transaction_ids]
    end
  end

  private

  def analyze(start_date, end_date)
    transactions = @user.expense_transactions.includes(:category).between(start_date, end_date)
    Insights::Analysis.new(transactions:, start_date:, end_date:, user: @user).call
  end

  def create_expense(date, description, amount_cents, category: @category)
    @user.expense_transactions.create!(
      occurred_on: date,
      description:,
      amount_cents:,
      direction: "debit",
      category:,
      external_id: "insight-#{SecureRandom.hex(8)}",
      raw_data: {}
    )
  end
end
