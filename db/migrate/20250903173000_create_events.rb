class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :level, null: false, default: 'info'
      t.text :message, null: false
      t.timestamps
    end
    add_index :events, [:user_id, :created_at]
    add_index :events, :level
  end
end

