class AddDropChanceToResourcesAndItems < ActiveRecord::Migration[8.0]
  def change
    add_column :resources, :drop_chance, :float, default: 1.0
    add_column :items, :drop_chance, :float, default: 1.0
  end
end
