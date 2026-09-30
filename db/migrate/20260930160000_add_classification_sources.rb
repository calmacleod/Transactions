class AddClassificationSources < ActiveRecord::Migration[8.1]
  def up
    add_column :expense_transactions, :classification_source, :string
    add_column :import_rows, :classification_source, :string
    add_index :expense_transactions, [ :user_id, :classification_source ]

    # Old imports discarded provenance. Keep these separate from confirmed manual choices.
    execute <<~SQL
      UPDATE expense_transactions
      SET classification_source = CASE
        WHEN classified_at IS NULL AND classification_reason IS NULL AND classification_confidence IS NULL THEN 'legacy'
        ELSE 'automatic'
      END
      WHERE category_id IS NOT NULL
    SQL
  end

  def down
    remove_index :expense_transactions, [ :user_id, :classification_source ]
    remove_column :expense_transactions, :classification_source
    remove_column :import_rows, :classification_source
  end
end
