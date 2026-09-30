require "test_helper"
require "tempfile"

class TransactionClassificationPublicMerchantCatalogTest < ActiveSupport::TestCase
  test "normalizes statement noise without conflating merchant words" do
    normalizer = TransactionClassification::MerchantName

    assert_equal "mcdonalds", normalizer.normalize("SQ *McDonald’s #142 OTTAWA, ON")
    assert_equal "bulk barn 0014 toronto on", normalizer.normalize("BULK BARN 0014 TORONTO, ON")
    assert_equal "t and t", normalizer.normalize("T&T #142")
    assert_equal "cafe unique", normalizer.normalize("CAFÉ UNIQUE  #014")
    assert_equal "7 eleven", normalizer.normalize("7-ELEVEN #142")
    assert_equal "forever 21", normalizer.normalize("FOREVER 21 #142")
    assert_equal "中国商店", normalizer.normalize("中国商店 #142")
  end

  test "respects word boundaries and the most specific merchant name" do
    catalog = TransactionClassification::PublicMerchantCatalog.new

    assert_nil catalog.call("SUBWAYISH #142")
    assert_nil catalog.call("A LOCAL RESTAURANT")
    assert_equal "Best Buy Mobile", catalog.call("BEST BUY MOBILE #142").name
    assert_equal "Bulk Barn", catalog.call("BULK BARN 0014 TORONTO, ON").name
    assert_equal "KFC", catalog.call("KFC #142").name
    assert_equal "IGA", catalog.call("IGA #142").name
    assert_nil catalog.call("KFC UNKNOWN MERCHANT")
  end

  test "rejects equally specific conflicting merchants" do
    with_catalog([
      { id: "Q1", name: "Same Name", category: "Groceries", aliases: [ "Same Name" ] },
      { id: "Q2", name: "Same Name", category: "Restaurants", aliases: [ "Same Name" ] }
    ]) do |catalog|
      assert_nil catalog.call("SAME NAME #142")
    end
  end

  test "a shared name with the same merchant type does not invent a brand identity" do
    with_catalog([
      { id: "Q1", name: "Same Name", category: "Groceries", aliases: [ "Same Name" ] },
      { id: "Q2", name: "Same Name", category: "Groceries", aliases: [ "Same Name" ] }
    ]) do |catalog|
      match = catalog.call("SAME NAME #142")
      assert_equal "Groceries", match.category_name
      assert_nil match.identity
    end
  end

  test "ignores generic aliases" do
    with_catalog([ { id: "Q1", name: "Cafe", category: "Restaurants", aliases: [ "Cafe", "Shop" ] } ]) do |catalog|
      assert_nil catalog.call("CAFE UNIQUE #142")
      assert_nil catalog.call("SHOP UNKNOWN")
    end
  end

  test "invalid JSON structure falls back without failing the import" do
    with_catalog([ { id: "Q1", name: "Invalid merchant", category: "Groceries", aliases: nil } ]) do |catalog|
      assert_nil catalog.call("INVALID MERCHANT")
    end
  end

  test "missing or malformed public data still permits manual history and rules" do
    [ "/nonexistent/merchants.json", nil ].each do |path|
      Tempfile.create("bad-merchant-catalog") do |file|
        file.write("invalid JSON")
        file.flush
        catalog = TransactionClassification::PublicMerchantCatalog.new(path: path || file.path)
        classifier = TransactionClassification::MerchantClassifier.new(user: users(:one), catalog:)

        assert_equal "Pets", classifier.call(description: "PET SUPPLY", direction: "debit").category_name
        users(:one).expense_transactions.create!(description: "UNIQUE MERCHANT #041", occurred_on: Date.new(2026, 5, 22),
          category: categories(:restaurants), classification_source: "manual", amount_cents: 1000, direction: "debit", external_id: SecureRandom.uuid)
        classifier = TransactionClassification::MerchantClassifier.new(user: users(:one), catalog:)
        assert_equal "Restaurants", classifier.call(description: "UNIQUE MERCHANT #095", direction: "debit").category_name
      end
    end
  end

  test "bundled catalog has versioned provenance and broad coverage" do
    data = JSON.parse(File.read(TransactionClassification::PublicMerchantCatalog::PATH))

    assert_equal data.fetch("merchants").size, data.fetch("metadata").fetch("merchant_count")
    assert_operator data.fetch("merchants").size, :>, 10_000
    assert_match(/\A\d+\.\d+\.\d+\z/, data.fetch("metadata").fetch("version"))
    assert_equal "BSD-3-Clause", data.fetch("metadata").fetch("license")
    assert data.fetch("merchants").none? { |merchant| merchant.fetch("aliases").include?(merchant.fetch("id")) }
  end

  private

  def with_catalog(merchants)
    Tempfile.create("merchant-catalog") do |file|
      file.write({ merchants: }.to_json)
      file.flush
      yield TransactionClassification::PublicMerchantCatalog.new(path: file.path)
    end
  end
end
