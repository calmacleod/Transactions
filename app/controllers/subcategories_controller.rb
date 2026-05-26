class SubcategoriesController < ApplicationController
  def index
    render inertia: {
      subcategories: TransactionSubcategory.by_name.map { |subcategory| subcategory_props(subcategory).merge(destroy_path: subcategory_path(subcategory)) },
      actions: {
        create: subcategories_path
      }
    }
  end

  def create
    TransactionSubcategory.create!(subcategory_params)

    redirect_to subcategories_path, notice: "Subcategory added."
  end

  def destroy
    TransactionSubcategory.find(params[:id]).destroy!

    redirect_to subcategories_path, notice: "Subcategory removed."
  end

  private

  def subcategory_params
    params.require(:transaction_subcategory).permit(:name, :color)
  end
end
