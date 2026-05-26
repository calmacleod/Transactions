class CreateAiRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_requests do |t|
      t.string :feature, null: false
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :estimated_cost_cents, default: 0, null: false
      t.boolean :successful, default: true, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :ai_requests, :feature
    add_index :ai_requests, :created_at
  end
end
