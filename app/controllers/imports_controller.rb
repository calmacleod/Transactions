require "stringio"

class ImportsController < ApplicationController
  def index
    batches = current_user.import_batches.with_attached_source_file.order(created_at: :desc).limit(100)

    render inertia: {
      import_batches: batches.map { |import_batch| import_batch_index_props(import_batch) },
      actions: {
        dashboard: root_path,
        upload: imports_path
      }
    }
  end

  def create
    uploaded_file = params.require(:csv_file)
    import_batch = StatementCsvImporter.new(io: uploaded_file.tempfile, filename: uploaded_file.original_filename, user: current_user).preview
    attach_uploaded_file(import_batch, uploaded_file)
    ClassifyImportRowsJob.perform_later(import_batch.id, current_user.id)

    redirect_to preview_import_path(import_batch.id), notice: "Review #{helpers.pluralize(import_batch.import_rows.count, "transaction")} from #{import_batch.filename}."
  rescue ActionController::ParameterMissing
    redirect_to root_path, alert: "Choose a CSV file to import."
  rescue StandardError => error
    redirect_to root_path, alert: "Import failed: #{error.message}"
  end

  def preview
    import_batch = current_user.import_batches.includes(import_rows: :category).find(params[:id])
    duplicate_context = duplicate_context_for(import_batch.import_rows.ordered)
    unfinished = import_batch.unfinished?

    render inertia: {
      import_batch: import_batch_props(import_batch),
      rows: import_batch.import_rows.ordered.map { |row| import_row_props(row, duplicate_context:) },
      groups: import_group_props(import_batch.import_rows.ordered, duplicate_context),
      categories: category_options(current_user.categories.by_name),
      actions: {
        commit: unfinished ? commit_import_path(import_batch.id) : nil,
        download: import_batch.source_file_retained? ? download_import_path(import_batch.id) : nil,
        dashboard: root_path,
        classification_stream: unfinished ? {
          channel: "ImportBatchChannel",
          import_batch_id: import_batch.id
        } : nil
      }
    }
  end

  def commit
    import_batch = current_user.import_batches.find(params[:id])
    return redirect_to preview_import_path(import_batch.id), alert: "#{import_batch.filename} is already finished." unless import_batch.unfinished?

    StatementCsvImporter.new(io: StringIO.new, filename: import_batch.filename, user: current_user).commit(batch: import_batch, rows: permitted_import_rows)

    redirect_to root_path, notice: "Imported #{helpers.pluralize(import_batch.transactions_count, "new transaction")} from #{import_batch.filename}."
  rescue ActionController::ParameterMissing
    redirect_to root_path, alert: "Choose a CSV file to import."
  rescue StandardError => error
    redirect_to root_path, alert: "Import failed: #{error.message}"
  end

  def download
    import_batch = current_user.import_batches.find(params[:id])
    return redirect_to preview_import_path(import_batch.id), alert: "The original CSV is not retained for this import." unless import_batch.source_file_retained?

    send_data import_batch.source_file.download,
      filename: import_batch.source_file.filename.to_s,
      type: import_batch.source_file.content_type || "text/csv",
      disposition: "attachment"
  end

  private

  def import_batch_props(import_batch)
    {
      id: import_batch.id,
      filename: import_batch.filename,
      rows_count: import_batch.rows_count,
      transactions_count: import_batch.transactions_count,
      status: import_batch.status,
      active: import_batch.unfinished?,
      complete: import_batch.complete?,
      read_only: !import_batch.unfinished?,
      imported_at_label: import_batch.imported_at&.strftime("%b %-d, %Y"),
      retained_file: import_batch.source_file_retained?,
      source_file_label: import_batch.source_file_retained? ? import_batch.source_file.filename.to_s : nil
    }
  end

  def import_batch_index_props(import_batch)
    {
      id: import_batch.id,
      filename: import_batch.filename,
      status: import_batch.status,
      status_label: import_batch.status.to_s.titleize,
      rows_count: import_batch.rows_count,
      transactions_count: import_batch.transactions_count,
      skipped_count: [ import_batch.rows_count.to_i - import_batch.transactions_count.to_i, 0 ].max,
      created_at_label: import_batch.created_at.strftime("%b %-d, %Y"),
      created_at_time_label: import_batch.created_at.strftime("%-l:%M %p"),
      imported_at_label: import_batch.imported_at&.strftime("%b %-d, %Y"),
      imported_at_time_label: import_batch.imported_at&.strftime("%-l:%M %p"),
      retained_file: import_batch.source_file_retained?,
      source_file_label: import_batch.source_file_retained? ? import_batch.source_file.filename.to_s : nil,
      notes: import_batch.notes,
      preview_path: preview_import_path(import_batch.id),
      download_path: import_batch.source_file_retained? ? download_import_path(import_batch.id) : nil,
      complete: import_batch.complete?,
      unfinished: import_batch.unfinished?
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

  def permitted_import_rows
    params.require(:import).fetch("rows", []).map do |row|
      row.permit(:id, :occurred_on, :description, :amount, :amount_cents, :direction, :card_last4, :category_id, :manually_classified, :notes, :included, :include_duplicate)
    end
  end

  def attach_uploaded_file(import_batch, uploaded_file)
    return unless current_user.retain_uploaded_csv?

    uploaded_file.tempfile.rewind
    import_batch.source_file.attach(
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
    duplicates = {}
    rows.each do |row|
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
    duplicates
  end

  def matched_transaction_props(transaction)
    {
      id: transaction.id,
      occurred_on_label: transaction.occurred_on.strftime("%b %-d, %Y"),
      description: transaction.description,
      amount_label: money_from_cents(transaction.amount_cents),
      direction: transaction.direction.to_s.titleize,
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
