class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :color
      t.integer :monthly_budget_cents

      t.timestamps
    end

    add_index :categories, :name, unique: true
  end
end
