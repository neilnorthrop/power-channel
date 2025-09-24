class CreateActionItemDrops < ActiveRecord::Migration[8.0]
  def change
    create_table :action_item_drops do |t|
      t.references :action, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :min_amount
      t.integer :max_amount
      t.float :drop_chance, null: false, default: 1.0
      t.timestamps
    end

    add_index :action_item_drops, [ :action_id, :item_id ], unique: true
  end
end
