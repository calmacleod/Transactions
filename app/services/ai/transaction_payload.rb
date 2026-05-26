module Ai
  class TransactionPayload
    def self.record(transaction)
      {
        id: transaction.id,
        date: transaction.occurred_on,
        description: transaction.description,
        merchant: transaction.merchant_name,
        amount_dollars: dollars(transaction.amount_cents),
        signed_amount_dollars: dollars(transaction.signed_amount_cents),
        direction: transaction.direction,
        category: transaction.category&.name,
        subcategories: transaction.subcategories.map(&:name),
        notes: transaction.notes
      }
    end

    def self.dollars(cents)
      (cents.to_d / 100).round(2).to_s("F")
    end
  end
end
