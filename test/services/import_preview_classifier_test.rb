require "test_helper"

class ImportPreviewClassifierTest < ActiveSupport::TestCase
  test "matches import rows to manually classified merchants" do
    expense_transactions(:grocery).update!(description: "LOCAL MERCHANT #041", classification_source: "manual")
    row = ImportRow.new(
      user: users(:one),
      description: "LOCAL MERCHANT #095 OTTAWA, ON",
      direction: "debit"
    )

    result = ImportPreviewClassifier.new(user: users(:one)).call(row)

    assert_equal categories(:groceries), result.category
    assert_equal 0.95, result.confidence
    assert_match "manual category", result.reason
  end

  test "falls back to local merchant rules" do
    row = ImportRow.new(
      user: users(:one),
      description: "NEIGHBOURHOOD COFFEE HOUSE",
      direction: "debit"
    )

    result = ImportPreviewClassifier.new(user: users(:one)).call(row)

    assert_equal "Restaurants", result.category.name
    assert_equal 0.65, result.confidence
  end
end
