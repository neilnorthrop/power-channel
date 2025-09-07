class AddExperimentalCraftingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :experimental_crafting, :boolean, default: false, null: false
  end
end
