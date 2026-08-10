class RedesignInsights < ActiveRecord::Migration[8.1]
  def up
    add_column :insights, :kind, :string, null: false, default: "observation"
    add_column :insights, :action, :text
    add_column :insights, :metric, :json, null: false, default: {}
    add_index :insights, [ :user_id, :kind ]

    execute "DELETE FROM insight_transactions"
    execute "DELETE FROM insights"
  end

  def down
    remove_index :insights, [ :user_id, :kind ]
    remove_column :insights, :metric
    remove_column :insights, :action
    remove_column :insights, :kind
  end
end
