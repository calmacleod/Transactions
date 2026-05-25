class CreateClassificationRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :classification_runs do |t|
      t.string :status, null: false, default: "queued"
      t.integer :total_count, null: false, default: 0
      t.integer :processed_count, null: false, default: 0
      t.integer :classified_count, null: false, default: 0
      t.integer :rule_based_count, null: false, default: 0
      t.integer :ai_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.string :active_job_id
      t.text :notes
      t.datetime :cancel_requested_at
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :classification_runs, :status
    add_index :classification_runs, :created_at
  end
end
