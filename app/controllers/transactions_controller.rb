class TransactionsController < ApplicationController
  def index
    @categories = Category.by_name
    @transactions = ExpenseTransaction.includes(:category).recent
    @transactions = @transactions.where(category_id: params[:category_id]) if params[:category_id].present?
    @transactions = @transactions.where(direction: params[:direction]) if params[:direction].present?
    @start_date = parsed_date(params[:start_date])
    @end_date = parsed_date(params[:end_date])
    @transactions = @transactions.where(occurred_on: @start_date..) if @start_date.present?
    @transactions = @transactions.where(occurred_on: ..@end_date) if @end_date.present?
  end

  def update
    transaction = ExpenseTransaction.find(params[:id])
    transaction.update!(transaction_params)

    redirect_back fallback_location: transactions_path, notice: "Transaction updated."
  end

  private

  def transaction_params
    params.require(:expense_transaction).permit(:category_id)
  end

  def parsed_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end
end
