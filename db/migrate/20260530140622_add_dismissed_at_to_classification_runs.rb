class AddDismissedAtToClassificationRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :classification_runs, :dismissed_at, :datetime
  end
end
