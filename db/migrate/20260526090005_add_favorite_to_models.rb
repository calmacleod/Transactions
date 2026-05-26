class AddFavoriteToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :models, :favorite, :boolean, default: false, null: false
    add_index :models, :favorite
  end
end
