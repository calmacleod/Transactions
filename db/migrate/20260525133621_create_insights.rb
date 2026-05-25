class CreateInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.string :title
      t.text :body
      t.string :severity, default: "info", null: false
      t.date :starts_on
      t.date :ends_on
      t.json :payload

      t.timestamps
    end

    add_index :insights, [ :starts_on, :ends_on ]
  end
end
