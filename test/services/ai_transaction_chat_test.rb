require "test_helper"

class AiTransactionChatTest < ActiveSupport::TestCase
  test "merchant context ranks grouped expenses by cents before formatting and limits to 25" do
    transactions = 26.times.map do |index|
      expense_transactions(:grocery).dup.tap do |transaction|
        transaction.description = "MERCHANT #{index.to_s.rjust(2, '0')}"
        transaction.amount_cents = index + 1
        transaction.external_id = "chat-merchant-#{index}"
        transaction.save!
      end
    end
    transactions << transactions.first.dup.tap do |transaction|
      transaction.amount_cents = 100
      transaction.external_id = "chat-repeat-merchant"
      transaction.save!
    end
    transactions << transactions.last.dup.tap do |transaction|
      transaction.description = "CREDIT ONLY"
      transaction.direction = "credit"
      transaction.amount_cents = 100_000
      transaction.external_id = "chat-credit"
      transaction.save!
    end

    payload = Ai::TransactionChat.new(model: nil).send(
      :summary_payload, ExpenseTransaction.where(id: transactions.map(&:id)).includes(:category, :subcategories)
    )
    merchants = payload.fetch(:merchants)

    assert_equal 25, merchants.size
    assert_equal "merchant 00", merchants.keys.first
    assert_equal({ count: 2, dollars: "1.01" }, merchants.fetch("merchant 00"))
    assert_equal "merchant 25", merchants.keys.second
    assert_not merchants.key?("merchant 01")
    assert_not merchants.key?("credit only")
  end
end
