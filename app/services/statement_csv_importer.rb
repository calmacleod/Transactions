require "csv"
require "digest"

class StatementCsvImporter
  HEADERLESS_COLUMNS = %i[occurred_on description debit credit card_number].freeze
  SOURCE = "statement_csv"

  def initialize(io:, filename:)
    @io = io
    @filename = filename.presence || "transactions.csv"
  end

  def call
    batch = ImportBatch.create!(filename:, imported_at: Time.current, status: "processing")
    rows_count = 0
    transactions_count = 0

    CSV.new(io, headers: false).each do |row|
      rows_count += 1
      attributes = attributes_for(row)
      next if attributes.nil?

      transaction = find_existing_transaction(attributes)

      if transaction
        transaction.update!(external_id: attributes[:external_id]) if transaction.external_id.blank?
      else
        ExpenseTransaction.create!(attributes.merge(import_batch: batch))
        transactions_count += 1
      end
    end

    batch.update!(rows_count:, transactions_count:, status: "complete")
    batch
  rescue StandardError => error
    batch&.update!(rows_count:, transactions_count:, status: "failed", notes: error.message)
    raise
  ensure
    io.rewind if io.respond_to?(:rewind)
  end

  private

  attr_reader :io, :filename

  def attributes_for(row)
    values = HEADERLESS_COLUMNS.zip(row).to_h
    debit = parse_money(values[:debit])
    credit = parse_money(values[:credit])
    amount = debit || credit
    return if amount.nil? || amount.zero?

    normalized = {
      occurred_on: Date.iso8601(values[:occurred_on].to_s),
      description: values[:description].to_s.squish,
      amount_cents: (amount * 100).round,
      direction: debit.present? ? "debit" : "credit",
      card_last4: values[:card_number].to_s.last(4),
      source: SOURCE,
      raw_data: values
    }

    normalized.merge(external_id: Digest::SHA256.hexdigest(normalized.values_at(
      :occurred_on, :description, :amount_cents, :direction, :card_last4
    ).join("|")))
  end

  def find_existing_transaction(attributes)
    ExpenseTransaction.find_by(external_id: attributes[:external_id]) ||
      ExpenseTransaction.find_by(
        occurred_on: attributes[:occurred_on],
        description: attributes[:description],
        amount_cents: attributes[:amount_cents],
        direction: attributes[:direction],
        card_last4: attributes[:card_last4],
        source: attributes[:source]
      ) ||
      ExpenseTransaction.find_by(
        occurred_on: attributes[:occurred_on],
        description: attributes[:description],
        amount_cents: attributes[:amount_cents],
        direction: attributes[:direction],
        card_last4: attributes[:card_last4]
      )
  end

  def parse_money(value)
    return if value.blank?

    BigDecimal(value.to_s.delete("$,"))
  end
end
