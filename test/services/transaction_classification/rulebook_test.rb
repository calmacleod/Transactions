require "test_helper"

class TransactionClassificationRulebookTest < ActiveSupport::TestCase
  test "classifies debit descriptions using the shared ordered rules" do
    result = TransactionClassification::Rulebook.new.call(description: "SPOTIFY MONTHLY", direction: "debit")

    assert_equal "Subscriptions", result.category_name
    assert_equal 0.65, result.confidence
    assert_equal "Matched local merchant rules.", result.reason
  end

  test "classifies payments and other credits before merchant rules" do
    payment = TransactionClassification::Rulebook.new.call(description: "CARD PAYMENT RECEIVED", direction: "credit")
    refund = TransactionClassification::Rulebook.new.call(description: "AMAZON REFUND", direction: "credit")

    assert_equal "Payments", payment.category_name
    assert_equal "Refunds & Credits", refund.category_name
  end

  test "accepts custom callable rules for other rulebook consumers" do
    rule = TransactionClassification::Rulebook::Rule.new(
      category_name: "Education",
      pattern: ->(description) { description.start_with?("COURSE ") },
      confidence: 0.9
    )

    result = TransactionClassification::Rulebook.new(rules: [ rule ]).call(description: "COURSE RUBY", direction: "debit")

    assert_equal "Education", result.category_name
    assert_equal rule, result.rule
  end

  test "returns a stable uncategorized result when no rule matches" do
    result = TransactionClassification::Rulebook.new(rules: []).call(description: "UNKNOWN MERCHANT", direction: "debit")

    assert_equal "Uncategorized", result.category_name
    assert_equal 0.25, result.confidence
    assert_nil result.rule
  end
end
