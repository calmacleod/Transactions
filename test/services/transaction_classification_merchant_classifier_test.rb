require "test_helper"

class TransactionClassificationMerchantClassifierTest < ActiveSupport::TestCase
  test "manual choices override public data and local rules across store numbers" do
    remember("BULK BARN #041 OTTAWA, ON", categories(:restaurants))

    result = classify("SQ *BULK BARN #095 TORONTO, ON")

    assert_equal "Restaurants", result.category_name
    assert_equal "history", result.source
    assert_equal 0.95, result.confidence
    assert_match "manual category", result.reason
  end

  test "public brand aliases reuse manual categories" do
    remember("McDonald's #041", categories(:groceries))

    result = classify("MCDONALDS #095")

    assert_equal "Groceries", result.category_name
    assert_equal "history", result.source
  end

  test "uses free merchant data without any provider requests" do
    { "BULK BARN #14" => "Groceries", "SUBWAY #991" => "Restaurants", "REXALL #124" => "Health", "BEST BUY #41" => "Shopping" }.each do |description, category|
      result = classify(description)
      assert_equal category, result.category_name
      assert_equal "public", result.source
      assert_match "Name Suggestion Index", result.reason
    end
  end

  test "never learns from automatic guesses or another user's choices" do
    remember("BULK BARN #041", categories(:restaurants), source: "public")
    other_category = users(:two).categories.create!(name: "Other user's choice")
    remember("BULK BARN #095", other_category, user: users(:two))

    result = classify("BULK BARN #204")

    assert_equal "Groceries", result.category_name
    assert_equal "public", result.source
  end

  test "refuses conflicting manual history" do
    remember("BULK BARN #041", categories(:restaurants))
    remember("BULK BARN #095", categories(:groceries))
    remember("BULK BARN #204", categories(:restaurants), source: "legacy")

    result = classify("BULK BARN #311")

    assert_equal "Groceries", result.category_name
    assert_equal "public", result.source
  end

  test "confirmed manual choices take precedence over legacy data" do
    remember("UNIQUE MERCHANT #041", categories(:restaurants), source: "legacy")
    remember("UNIQUE MERCHANT #095", categories(:groceries))

    assert_equal "Groceries", classify("UNIQUE MERCHANT #204").category_name
  end

  test "legacy history is reported with its uncertainty" do
    remember("UNIQUE MERCHANT #041", categories(:restaurants), source: "legacy")

    result = classify("UNIQUE MERCHANT #095")

    assert_equal "Restaurants", result.category_name
    assert_equal 0.8, result.confidence
    assert_match "source is unknown", result.reason
  end

  test "does not transfer a debit category to refunds or payments" do
    remember("BULK BARN #041", categories(:groceries))

    result = classify("BULK BARN #095", direction: "credit")
    assert_equal "Refunds & Credits", result.category_name
    assert_equal "Payments", classify("CARD PAYMENT RECEIVED", direction: "credit").category_name
  end

  test "does not use loose prefixes to match different merchants" do
    remember("UNIQUE MERCHANT", categories(:restaurants))

    result = classify("UNIQUE MERCHANT SERVICES")

    assert_equal "Uncategorized", result.category_name
    assert_equal "rules", result.source
  end

  test "loads history once for an import and includes older manual choices" do
    remember("UNIQUE MERCHANT #041", categories(:restaurants), occurred_on: Date.new(2000, 1, 1))
    classifier = TransactionClassification::MerchantClassifier.new(user: users(:one))
    history_selects = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      history_selects += 1 if payload[:sql].match?(/SELECT.*FROM "expense_transactions"/) && !payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      3.times { assert_equal "Restaurants", classifier.call(description: "UNIQUE MERCHANT #095", direction: "debit").category_name }
    end

    assert_equal 1, history_selects
  end

  test "nil user cannot learn another user's history" do
    remember("UNIQUE MERCHANT #041", categories(:restaurants))

    result = TransactionClassification::MerchantClassifier.new(user: nil).call(description: "UNIQUE MERCHANT #095", direction: "debit")

    assert_equal "Uncategorized", result.category_name
  end

  private

  def classify(description, direction: "debit")
    TransactionClassification::MerchantClassifier.new(user: users(:one)).call(description:, direction:)
  end

  def remember(description, category, source: "manual", user: users(:one), occurred_on: Date.new(2026, 5, 22))
    user.expense_transactions.create!(description:, occurred_on:, category:, classification_source: source,
      amount_cents: 1000, direction: "debit", external_id: SecureRandom.uuid)
  end
end
