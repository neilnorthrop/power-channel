class AddGroupKeyAndLogicToRecipeResources < ActiveRecord::Migration[8.0]
  def change
    add_column :recipe_resources, :group_key, :string
    add_column :recipe_resources, :logic, :string, null: false, default: 'AND'
    add_index :recipe_resources, [:recipe_id, :group_key]
  end
end

