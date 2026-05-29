class AddUserAiModelPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_ai_model, :string
    add_column :models, :user_selectable, :boolean, default: false, null: false

    add_index :models, :user_selectable

    reversible do |direction|
      direction.up do
        execute "UPDATE models SET user_selectable = 1 WHERE favorite = 1"
      end
    end
  end
end
