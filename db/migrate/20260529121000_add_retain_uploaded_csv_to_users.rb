class AddRetainUploadedCsvToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :retain_uploaded_csv, :boolean, default: true, null: false
  end
end
