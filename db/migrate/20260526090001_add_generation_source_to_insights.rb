class AddGenerationSourceToInsights < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :generation_source, :string, default: "automatic", null: false
    add_index :insights, :generation_source
  end
end
