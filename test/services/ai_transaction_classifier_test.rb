require "test_helper"

class AiTransactionClassifierTest < ActiveSupport::TestCase
  test "falls back to local merchant rules without provider keys" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 22),
        description: "PET SUPPLY",
        amount_cents: 7446,
        direction: "debit",
        card_last4: "2222",
        source: "test",
        external_id: "pet-valu-row",
        user: users(:one)
      )

      Ai::TransactionClassifier.new(user: users(:one)).classify(transaction)

      assert_equal "Pets", transaction.reload.category.name
      assert_equal 0.65.to_d, transaction.classification_confidence
      assert_match "local merchant rules", transaction.classification_reason
    end
  end

  test "classifies credit card payments separately from expenses" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 19),
        description: "CARD PAYMENT RECEIVED",
        amount_cents: 97069,
        direction: "credit",
        card_last4: "2222",
        source: "test",
        external_id: "payment-row",
        user: users(:one)
      )

      Ai::TransactionClassifier.new(user: users(:one)).classify(transaction)

      assert_equal "Payments", transaction.reload.category.name
      assert_equal 1.0.to_d, transaction.classification_confidence
      assert_match "excluded from expense totals", transaction.classification_reason
    end
  end

  test "classifies recurring digital services as subscriptions" do
    without_ai_keys do
      transaction = ExpenseTransaction.create!(
        occurred_on: Date.new(2026, 5, 7),
        description: "AI SERVICE MONTHLY PLAN",
        amount_cents: 15368,
        direction: "debit",
        card_last4: "2222",
        source: "test",
        external_id: "openai-subscription-row",
        user: users(:one)
      )

      Ai::TransactionClassifier.new(user: users(:one)).classify(transaction)

      assert_equal "Subscriptions", transaction.reload.category.name
      assert_equal 0.65.to_d, transaction.classification_confidence
    end
  end

  test "uses local rules before AI when provider keys are present" do
    old_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "present"
    transaction = ExpenseTransaction.create!(
      occurred_on: Date.new(2026, 5, 22),
      description: "PET SUPPLY",
      amount_cents: 7446,
      direction: "debit",
      card_last4: "2222",
      source: "test",
      external_id: "pet-valu-local-first-row",
      user: users(:one)
    )

    RubyLLM.singleton_class.alias_method :chat_without_local_first_test, :chat
    RubyLLM.define_singleton_method(:chat) { |*| raise "AI should not be called for local rule matches" }

    begin
      Ai::TransactionClassifier.new(user: users(:one)).classify(transaction)
    ensure
      RubyLLM.singleton_class.alias_method :chat, :chat_without_local_first_test
      RubyLLM.singleton_class.remove_method :chat_without_local_first_test
    end

    assert_equal "Pets", transaction.reload.category.name
  ensure
    old_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = old_key
  end

  test "classifies structured RubyLLM 2 responses using parsed JSON" do
    old_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    Model.create!(provider: "openai", model_id: "parsed-model", name: "Parsed model", capabilities: [ "structured_output" ], modalities: { input: [ "text" ], output: [ "text" ] })
    AiSetting.set("classification_model", "parsed-model")
    transaction = users(:one).expense_transactions.create!(occurred_on: Date.new(2026, 5, 22), description: "UNKNOWN MERCHANT", amount_cents: 1000, direction: "debit", external_id: "parsed-classification")
    response = RubyLLM::Message.new(role: :assistant, content: { category: "Special expenses", confidence: 0.9, reason: "Structured response" }.to_json)
    client = Object.new
    client.define_singleton_method(:ask) do |_prompt, schema:|
      raise "Expected classification schema" unless schema == TransactionClassificationSchema

      response
    end
    original = Ai::RubyLlmClient.method(:new)
    Ai::RubyLlmClient.define_singleton_method(:new) { |**| client }

    Ai::TransactionClassifier.new(user: users(:one), rulebook: TransactionClassification::Rulebook.new(rules: [])).classify(transaction)

    assert_equal "Special expenses", transaction.reload.category.name
    assert_equal 0.9.to_d, transaction.classification_confidence
    assert_equal "Structured response", transaction.classification_reason
  ensure
    Ai::RubyLlmClient.define_singleton_method(:new, original) if original
    old_key.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = old_key
  end

  private

  def without_ai_keys
    old_values = ENV.values_at("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("ANTHROPIC_API_KEY")
    ENV.delete("GEMINI_API_KEY")
    yield
  ensure
    %w[OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY].zip(old_values).each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
