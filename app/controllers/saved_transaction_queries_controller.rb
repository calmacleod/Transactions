class SavedTransactionQueriesController < ApplicationController
  def create
    filters = TransactionFilter.clean(params.fetch(:filters, {}))
    saved_query = Current.session.user.saved_transaction_queries.create!(name: params.require(:name), filters:)

    redirect_to transactions_path(saved_query_id: saved_query.id), notice: "Saved transaction filter."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to transactions_path(filters), alert: error.record.errors.full_messages.to_sentence
  end

  def destroy
    saved_query = Current.session.user.saved_transaction_queries.find(params[:id])
    saved_query.destroy!

    redirect_to transactions_path, notice: "Saved filter deleted."
  end
end
