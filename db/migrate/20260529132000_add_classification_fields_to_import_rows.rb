class AddClassificationFieldsToImportRows < ActiveRecord::Migration[8.1]
  def change
    add_column :import_rows, :classification_status, :string, null: false, default: "pending"
    add_column :import_rows, :classification_confidence, :decimal, precision: 4, scale: 2
    add_column :import_rows, :classification_reason, :text
    add_column :import_rows, :classified_at, :datetime
  end
end
