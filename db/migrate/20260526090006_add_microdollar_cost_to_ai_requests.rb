class AddMicrodollarCostToAiRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_requests, :estimated_cost_microdollars, :integer, default: 0, null: false
  end
end
