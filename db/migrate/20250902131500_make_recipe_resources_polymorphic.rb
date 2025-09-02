# frozen_string_literal: true

class MakeRecipeResourcesPolymorphic < ActiveRecord::Migration[8.0]
  def up
    add_column :recipe_resources, :component_type, :string
    add_column :recipe_resources, :component_id, :bigint

    # Backfill existing rows: old resource_id -> component(Resource, id)
    execute <<~SQL.squish
      UPDATE recipe_resources
      SET component_type = 'Resource', component_id = resource_id
      WHERE resource_id IS NOT NULL
    SQL

    # Remove old foreign key and index to resources
    if foreign_key_exists?(:recipe_resources, :resources)
      remove_foreign_key :recipe_resources, :resources
    end
    if index_exists?(:recipe_resources, :resource_id)
      remove_index :recipe_resources, :resource_id
    end

    # Enforce not-null on new columns
    change_column_null :recipe_resources, :component_type, false
    change_column_null :recipe_resources, :component_id, false

    # Add composite indexes
    add_index :recipe_resources, [:component_type, :component_id], name: 'index_recipe_resources_on_component'
    add_index :recipe_resources, [:recipe_id, :component_type, :component_id], unique: true, name: 'index_recipe_resources_unique_component'

    # Drop old column
    remove_column :recipe_resources, :resource_id, :bigint
  end

  def down
    add_column :recipe_resources, :resource_id, :bigint

    # Best-effort restore for Resource components
    execute <<~SQL.squish
      UPDATE recipe_resources
      SET resource_id = component_id
      WHERE component_type = 'Resource'
    SQL

    add_foreign_key :recipe_resources, :resources
    add_index :recipe_resources, :resource_id

    remove_index :recipe_resources, name: 'index_recipe_resources_unique_component'
    remove_index :recipe_resources, name: 'index_recipe_resources_on_component'

    change_column_null :recipe_resources, :component_type, true
    change_column_null :recipe_resources, :component_id, true

    remove_column :recipe_resources, :component_type, :string
    remove_column :recipe_resources, :component_id, :bigint
  end
end

