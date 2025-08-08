class AddDefaultToQuantityInUserItems < ActiveRecord::Migration[8.0]
  def change
    change_column_default :user_items, :quantity, 0
  end
end
