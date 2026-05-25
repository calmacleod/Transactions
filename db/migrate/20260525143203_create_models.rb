class CreateModels < ActiveRecord::Migration[8.1]
  def change
    create_table :models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.json :modalities, default: {}
      t.json :capabilities, default: []
      t.json :pricing, default: {}
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :models, [ :provider, :model_id ], unique: true
    add_index :models, :provider
    add_index :models, :family
  end
end
