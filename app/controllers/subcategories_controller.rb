class SubcategoriesController < ApplicationController
  def index
    render inertia: {
      subcategories: current_user.transaction_subcategories.by_name.map { |subcategory| subcategory_props(subcategory).merge(destroy_path: subcategory_path(subcategory.id)) },
      actions: {
        create: subcategories_path
      }
    }
  end

  def create
    current_user.transaction_subcategories.create!(subcategory_params.to_h.symbolize_keys)

    redirect_to subcategories_path, notice: "Subcategory added."
  end

  def destroy
    current_user.transaction_subcategories.find(params[:id]).destroy!

    redirect_to subcategories_path, notice: "Subcategory removed."
  end

  private

  def subcategory_params
    params.require(:transaction_subcategory).permit(:name, :color)
  end
end
