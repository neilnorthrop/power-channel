class CreateRecipeResources < ActiveRecord::Migration[8.0]
  def change
    create_table :recipe_resources do |t|
      t.references :recipe, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.integer :quantity

      t.timestamps
    end
  end
end
