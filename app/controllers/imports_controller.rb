class ImportsController < ApplicationController
  def create
    uploaded_file = params.require(:csv_file)
    batch = StatementCsvImporter.new(io: uploaded_file.tempfile, filename: uploaded_file.original_filename).call

    redirect_to root_path, notice: "Imported #{batch.transactions_count} new transactions from #{batch.filename}."
  rescue ActionController::ParameterMissing
    redirect_to root_path, alert: "Choose a CSV file to import."
  rescue StandardError => error
    redirect_to root_path, alert: "Import failed: #{error.message}"
  end
end
