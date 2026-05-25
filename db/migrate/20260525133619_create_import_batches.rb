class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      t.string :filename
      t.datetime :imported_at
      t.integer :rows_count, default: 0, null: false
      t.integer :transactions_count, default: 0, null: false
      t.string :status, default: "pending", null: false
      t.text :notes

      t.timestamps
    end
  end
end
