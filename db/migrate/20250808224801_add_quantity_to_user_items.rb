class AddQuantityToUserItems < ActiveRecord::Migration[8.0]
  def change
    add_column :user_items, :quantity, :integer
  end
end
