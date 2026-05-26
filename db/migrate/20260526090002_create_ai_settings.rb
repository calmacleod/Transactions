class CreateAiSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_settings do |t|
      t.string :key, null: false
      t.string :value

      t.timestamps
    end

    add_index :ai_settings, :key, unique: true
  end
end
