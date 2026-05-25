class CreateSavedTransactionQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_transaction_queries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.json :filters, default: {}, null: false

      t.timestamps
    end

    add_index :saved_transaction_queries, [ :user_id, :name ], unique: true
  end
end
