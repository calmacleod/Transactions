require "csv"
require "digest"

class StatementCsvImporter
  HEADERLESS_COLUMNS = %i[occurred_on description debit credit card_number].freeze
  SOURCE = "statement_csv"

  def initialize(io:, filename:, user: Current.user)
    @io = io
    @filename = filename.presence || "transactions.csv"
    @user = user
  end

  def call
    batch = preview
    commit(batch:, rows: batch.import_rows.ordered.map(&:transaction_attributes))
  end

  def preview
    batch = ImportBatch.create!(filename:, status: "preview", user:)
    rows_count = 0

    CSV.new(io, headers: false).each do |row|
      rows_count += 1
      attributes = attributes_for(row)
      next if attributes.nil?

      batch.import_rows.create!(
        attributes.merge(row_number: rows_count, category_id: suggested_category_id(attributes), user:)
      )
    end

    batch.update!(rows_count:, transactions_count: batch.import_rows.count, status: "preview")
    batch
  rescue StandardError => error
    batch&.update!(rows_count:, transactions_count: batch.import_rows.count, status: "failed", notes: error.message)
    raise
  ensure
    io.rewind if io.respond_to?(:rewind)
  end

  def commit(batch:, rows:)
    rows_count = 0
    transactions_count = 0
    raise ArgumentError, "#{batch.filename} is already finished" unless batch.unfinished?

    ImportBatch.transaction do
      batch.update!(status: "processing", notes: nil)
      batch.import_rows.destroy_all

      Array(rows).each do |row|
        attributes = attributes_from_submission(row)
        next if attributes.nil?

        rows_count += 1
        category_id = category_id_from(row)
        include_row = boolean_from(row_value(row, :included), default: true)
        include_duplicate = boolean_from(row_value(row, :include_duplicate))
        notes = row_value(row, :notes).presence
        import_row = batch.import_rows.create!(attributes.merge(row_number: rows_count, category_id:, notes:, user:))
        next unless include_row

        transaction = find_existing_transaction(attributes)

        if transaction
          if include_duplicate
            ExpenseTransaction.create!(import_row.transaction_attributes.merge(external_id: forced_external_id(attributes[:external_id], batch, rows_count), import_batch: batch, user:))
            transactions_count += 1
          else
            transaction.update!(external_id: attributes[:external_id]) if transaction.external_id.blank?
          end
        else
          ExpenseTransaction.create!(import_row.transaction_attributes.merge(import_batch: batch, user:))
          transactions_count += 1
        end
      end

      batch.update!(rows_count:, transactions_count:, imported_at: Time.current, status: "complete")
    end

    batch
  rescue StandardError => error
    batch&.update!(rows_count:, transactions_count:, status: "failed", notes: error.message) if batch&.unfinished?
    raise
  end

  private

  attr_reader :io, :filename, :user

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

    normalized.merge(external_id: digest_for(normalized))
  end

  def find_existing_transaction(attributes)
    transaction_scope.find_by(external_id: attributes[:external_id]) ||
      transaction_scope.find_by(
        occurred_on: attributes[:occurred_on],
        description: attributes[:description],
        amount_cents: attributes[:amount_cents],
        direction: attributes[:direction],
        card_last4: attributes[:card_last4],
        source: attributes[:source]
      ) ||
      transaction_scope.find_by(
        occurred_on: attributes[:occurred_on],
        description: attributes[:description],
        amount_cents: attributes[:amount_cents],
        direction: attributes[:direction],
        card_last4: attributes[:card_last4]
      )
  end

  def transaction_scope
    ExpenseTransaction.where(user:)
  end

  def parse_money(value)
    return if value.blank?

    BigDecimal(value.to_s.delete("$,"))
  end

  def attributes_from_submission(row)
    amount = parse_money(row_value(row, :amount))
    amount ||= BigDecimal(row_value(row, :amount_cents).to_s) / 100 if row_value(row, :amount_cents).present?
    return if amount.nil? || amount.zero?

    normalized = {
      occurred_on: Date.iso8601(row_value(row, :occurred_on).to_s),
      description: row_value(row, :description).to_s.squish,
      amount_cents: (amount * 100).round,
      direction: row_value(row, :direction).presence_in(%w[debit credit]) || "debit",
      card_last4: row_value(row, :card_last4).to_s.last(4),
      source: SOURCE,
      raw_data: {
        occurred_on: row_value(row, :occurred_on),
        description: row_value(row, :description),
        amount: row_value(row, :amount),
        direction: row_value(row, :direction),
        card_last4: row_value(row, :card_last4)
      }
    }

    normalized.merge(external_id: digest_for(normalized))
  end

  def category_id_from(row)
    category_id = row_value(row, :category_id).presence
    user.categories.find(category_id).id if category_id.present?
  end

  def suggested_category_id(attributes)
    find_existing_transaction(attributes)&.category_id
  end

  def row_value(row, key)
    row.respond_to?(:[]) ? row[key] || row[key.to_s] : nil
  end

  def digest_for(attributes)
    Digest::SHA256.hexdigest(attributes.values_at(
      :occurred_on, :description, :amount_cents, :direction, :card_last4
    ).join("|"))
  end

  def forced_external_id(external_id, batch, row_number)
    "#{external_id}-import-#{batch.id}-row-#{row_number}"
  end

  def boolean_from(value, default: false)
    return default if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end
end
