require "stringio"

class ImportsController < ApplicationController
  def index
    batches = current_user.import_batches.with_attached_source_file.order(created_at: :desc).limit(100)

    render inertia: {
      import_batches: batches.map { |batch| import_batch_index_props(batch) },
      actions: {
        dashboard: root_path,
        upload: imports_path
      }
    }
  end

  def create
    uploaded_file = params.require(:csv_file)
    batch = StatementCsvImporter.new(io: uploaded_file.tempfile, filename: uploaded_file.original_filename, user: current_user).preview
    attach_uploaded_file(batch, uploaded_file)
    ClassifyImportRowsJob.perform_later(batch.id, current_user.id)

    redirect_to preview_import_path(batch), notice: "Review #{helpers.pluralize(batch.import_rows.count, "transaction")} from #{batch.filename}."
  rescue ActionController::ParameterMissing
    redirect_to root_path, alert: "Choose a CSV file to import."
  rescue StandardError => error
    redirect_to root_path, alert: "Import failed: #{error.message}"
  end

  def preview
    batch = current_user.import_batches.includes(import_rows: :category).find(params[:id])
    duplicate_context = duplicate_context_for(batch.import_rows.ordered)
    unfinished = batch.unfinished?

    render inertia: {
      import_batch: import_batch_props(batch),
      rows: batch.import_rows.ordered.map { |row| import_row_props(row, duplicate_context:) },
      groups: import_group_props(batch.import_rows.ordered, duplicate_context),
      categories: category_options(current_user.categories.by_name),
      actions: {
        commit: unfinished ? commit_import_path(batch) : nil,
        download: batch.source_file_retained? ? download_import_path(batch) : nil,
        dashboard: root_path,
        classification_stream: unfinished ? {
          channel: "ImportBatchChannel",
          import_batch_id: batch.id
        } : nil
      }
    }
  end

  def commit
    batch = current_user.import_batches.find(params[:id])
    return redirect_to preview_import_path(batch), alert: "#{batch.filename} is already finished." unless batch.unfinished?

    StatementCsvImporter.new(io: StringIO.new, filename: batch.filename, user: current_user).commit(batch:, rows: import_rows_params)

    redirect_to root_path, notice: "Imported #{helpers.pluralize(batch.transactions_count, "new transaction")} from #{batch.filename}."
  rescue ActionController::ParameterMissing
    redirect_to root_path, alert: "Choose a CSV file to import."
  rescue StandardError => error
    redirect_to root_path, alert: "Import failed: #{error.message}"
  end

  def download
    batch = current_user.import_batches.find(params[:id])
    return redirect_to preview_import_path(batch), alert: "The original CSV is not retained for this import." unless batch.source_file_retained?

    send_data batch.source_file.download,
      filename: batch.source_file.filename.to_s,
      type: batch.source_file.content_type || "text/csv",
      disposition: "attachment"
  end

  private

  def import_batch_props(batch)
    {
      id: batch.id,
      filename: batch.filename,
      rows_count: batch.rows_count,
      transactions_count: batch.transactions_count,
      status: batch.status,
      active: batch.unfinished?,
      complete: batch.complete?,
      read_only: !batch.unfinished?,
      imported_at_label: batch.imported_at&.strftime("%b %-d, %Y"),
      retained_file: batch.source_file_retained?,
      source_file_label: batch.source_file_retained? ? batch.source_file.filename.to_s : nil
    }
  end

  def import_batch_index_props(batch)
    {
      id: batch.id,
      filename: batch.filename,
      status: batch.status,
      status_label: batch.status.to_s.titleize,
      rows_count: batch.rows_count,
      transactions_count: batch.transactions_count,
      skipped_count: [ batch.rows_count.to_i - batch.transactions_count.to_i, 0 ].max,
      created_at_label: batch.created_at.strftime("%b %-d, %Y"),
      created_at_time_label: batch.created_at.strftime("%-l:%M %p"),
      imported_at_label: batch.imported_at&.strftime("%b %-d, %Y"),
      imported_at_time_label: batch.imported_at&.strftime("%-l:%M %p"),
      retained_file: batch.source_file_retained?,
      source_file_label: batch.source_file_retained? ? batch.source_file.filename.to_s : nil,
      notes: batch.notes,
      preview_path: preview_import_path(batch),
      download_path: batch.source_file_retained? ? download_import_path(batch) : nil,
      complete: batch.complete?,
      unfinished: batch.unfinished?
    }
  end

  def import_row_props(row, duplicate_context:)
    duplicate = duplicate_context.fetch(row.id, nil)

    {
      id: row.id,
      row_number: row.row_number,
      occurred_on: row.occurred_on&.iso8601,
      description: row.description,
      amount: format("%.2f", row.amount_cents.to_i / 100.0),
      amount_cents: row.amount_cents,
      direction: row.direction,
      card_last4: row.card_last4,
      category_id: row.category_id,
      category: category_props(row.category),
      notes: row.notes,
      raw_data: row.raw_data || {},
      classification_status: row.classification_status,
      classification_confidence: row.classification_confidence&.to_f,
      classification_reason: row.classification_reason,
      included: duplicate.blank?,
      include_duplicate: false,
      duplicate:
    }
  end

  def import_rows_params
    params.require(:import).fetch(:rows, []).map do |row|
      row.permit(:id, :occurred_on, :description, :amount, :amount_cents, :direction, :card_last4, :category_id, :notes, :included, :include_duplicate)
    end
  end

  def attach_uploaded_file(batch, uploaded_file)
    return unless current_user.retain_uploaded_csv?

    uploaded_file.tempfile.rewind
    batch.source_file.attach(
      io: uploaded_file.tempfile,
      filename: uploaded_file.original_filename,
      content_type: uploaded_file.content_type.presence || "text/csv"
    )
  end

  def duplicate_context_for(rows)
    rows = rows.to_a
    existing_by_external_id = {}
    existing_by_full_key = {}
    existing_by_natural_key = {}

    current_user.expense_transactions.includes(:category).find_each do |transaction|
      existing_by_external_id[transaction.external_id] = transaction if transaction.external_id.present?
      existing_by_full_key[transaction_key(transaction, include_source: true)] = transaction
      existing_by_natural_key[transaction_key(transaction, include_source: false)] = transaction
    end

    seen_upload_keys = {}
    rows.each_with_object({}) do |row, duplicates|
      existing_match = existing_by_external_id[row.external_id] ||
        existing_by_full_key[transaction_key(row, include_source: true)] ||
        existing_by_natural_key[transaction_key(row, include_source: false)]
      upload_key = transaction_key(row, include_source: true)
      uploaded_match = seen_upload_keys[upload_key]
      seen_upload_keys[upload_key] ||= row

      if existing_match
        duplicates[row.id] = {
          kind: "existing",
          label: "Already imported",
          detail: "Transaction ##{existing_match.id}, #{existing_match.occurred_on.strftime("%b %-d, %Y")}",
          transaction: matched_transaction_props(existing_match)
        }
      elsif uploaded_match
        duplicates[row.id] = {
          kind: "upload",
          label: "Duplicate in upload",
          detail: "Matches row #{uploaded_match.row_number}"
        }
      end
    end
  end

  def matched_transaction_props(transaction)
    {
      id: transaction.id,
      occurred_on_label: transaction.occurred_on.strftime("%b %-d, %Y"),
      description: transaction.description,
      amount_label: money_from_cents(transaction.amount_cents),
      direction: transaction.direction.titleize,
      card_last4: transaction.card_last4,
      category: category_props(transaction.category),
      notes: transaction.notes
    }
  end

  def import_group_props(rows, duplicate_context)
    rows.group_by { |row| row.occurred_on&.beginning_of_month }.sort_by { |month, _rows| month || Date.new(1, 1, 1) }.reverse.map do |month, group_rows|
      ids = group_rows.map(&:id)
      duplicate_count = ids.count { |id| duplicate_context.key?(id) }

      {
        key: month&.strftime("%Y-%m") || "unknown",
        label: month&.strftime("%B %Y") || "Unknown date",
        row_ids: ids,
        count: group_rows.size,
        duplicate_count:
      }
    end
  end

  def transaction_key(record, include_source:)
    [
      record.occurred_on,
      record.description,
      record.amount_cents,
      record.direction,
      record.card_last4,
      (record.source if include_source)
    ].compact.join("|")
  end
end
