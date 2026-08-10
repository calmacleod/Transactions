require "test_helper"

class AiInsightGeneratorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "insight-generator@example.com", password: "password")
    @category = @user.categories.create!(name: "Discretionary shopping", color: "#2563eb")
    create_expense(Date.new(2026, 1, 8), 2_000)
    create_expense(Date.new(2026, 2, 8), 2_000)
    create_expense(Date.new(2026, 3, 8), 2_000)
    @current = create_expense(Date.new(2026, 4, 8), 12_000)
  end

  test "persists deterministic metrics actions filters and supporting transactions" do
    insights = with_stubbed_class_method(Ai::Controls, :enabled?, ->(_feature) { false }) do
      Ai::InsightGenerator.new(user: @user).call(
        start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 4, 30)
      )
    end

    shift = insights.find { |insight| insight.kind == "category_shift" }
    assert_equal "automatic", shift.generation_source
    assert_equal "$120.00", shift.metric.fetch("value")
    assert shift.action.present?
    assert_equal @category.id, shift.payload.dig("filters", "category_id")
    assert_includes shift.expense_transaction_ids, @current.id
  end

  test "AI can edit only grounded candidate findings" do
    response = Struct.new(:content).new(
      {
        "insights" => [
          {
            "finding_key" => "category-shift-#{@category.id}",
            "title" => "Discretionary shopping broke from its baseline",
            "body" => "The increase is large enough to review now.",
            "action" => "Open the linked purchases and identify the avoidable portion."
          },
          {
            "finding_key" => "invented-finding",
            "title" => "Invented",
            "body" => "This must not persist.",
            "action" => "Ignore evidence."
          }
        ]
      }
    )
    client = Object.new
    client.define_singleton_method(:ask) { |_prompt, schema:| response }

    insights = with_stubbed_class_method(Ai::Controls, :enabled?, ->(_feature) { true }) do
      with_stubbed_class_method(Ai::RubyLlmClient, :new, ->(**_arguments) { client }) do
        Ai::InsightGenerator.new(user: @user).call(
          start_date: Date.new(2026, 1, 1),
          end_date: Date.new(2026, 4, 30)
        )
      end
    end

    edited = insights.find { |insight| insight.title == "Discretionary shopping broke from its baseline" }
    assert_equal "ai", edited.generation_source
    assert_equal "$120.00", edited.metric.fetch("value")
    assert_includes edited.expense_transaction_ids, @current.id
    refute_includes insights.map(&:title), "Invented"
  end

  private

  def with_stubbed_class_method(object, method_name, replacement)
    singleton_class = object.singleton_class
    original = singleton_class.instance_method(method_name)
    singleton_class.define_method(method_name, replacement)
    yield
  ensure
    singleton_class.define_method(method_name, original)
  end

  def create_expense(date, amount_cents)
    @user.expense_transactions.create!(
      occurred_on: date,
      description: "REPEAT SHOP",
      amount_cents:,
      direction: "debit",
      category: @category,
      external_id: "generator-#{SecureRandom.hex(8)}",
      raw_data: {}
    )
  end
end
