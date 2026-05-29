class CreateImportRows < ActiveRecord::Migration[8.1]
  def change
    create_table :import_rows do |t|
      t.references :import_batch, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: false, index: true
      t.references :category, null: true, foreign_key: true
      t.integer :row_number, null: false
      t.date :occurred_on
      t.string :description
      t.integer :amount_cents
      t.string :direction
      t.string :card_last4
      t.string :source
      t.string :external_id
      t.text :notes
      t.json :raw_data
      t.timestamps
    end

    add_index :import_rows, [ :import_batch_id, :row_number ], unique: true
    add_index :import_rows, [ :user_id, :external_id ]
  end
end
