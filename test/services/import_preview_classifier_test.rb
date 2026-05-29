require "test_helper"

class ImportPreviewClassifierTest < ActiveSupport::TestCase
  test "matches import rows to previously classified merchants" do
    row = ImportRow.new(
      user: users(:one),
      description: "LOCAL GROCERY MARKET OTTAWA, ON",
      direction: "debit"
    )

    result = ImportPreviewClassifier.new(user: users(:one)).call(row)

    assert_equal categories(:groceries), result.category
    assert_equal 0.9, result.confidence
    assert_match "previously classified", result.reason
  end

  test "falls back to local merchant rules" do
    row = ImportRow.new(
      user: users(:one),
      description: "TIM HORTONS #6445 ORLEANS, ON",
      direction: "debit"
    )

    result = ImportPreviewClassifier.new(user: users(:one)).call(row)

    assert_equal "Restaurants", result.category.name
    assert_equal 0.65, result.confidence
  end
end
