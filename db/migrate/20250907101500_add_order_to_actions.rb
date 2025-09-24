class AddOrderToActions < ActiveRecord::Migration[8.0]
  def change
    add_column :actions, :order, :integer, null: false, default: 1000
    add_index :actions, :order
  end
end
