class AddCompositeIndexes < ActiveRecord::Migration[8.0]
  def change
    # Speeds up user-scoped item lookups by item & quality
    add_index :user_items, [:user_id, :item_id, :quality], name: :index_user_items_on_user_item_quality

    # Speeds up user-scoped resource lookups
    add_index :user_resources, [:user_id, :resource_id], name: :index_user_resources_on_user_and_resource

    # Common user-scoped lookups for joins
    add_index :user_actions, [:user_id, :action_id], name: :index_user_actions_on_user_and_action
    add_index :user_buildings, [:user_id, :building_id], name: :index_user_buildings_on_user_and_building
    add_index :user_skills, [:user_id, :skill_id], name: :index_user_skills_on_user_and_skill
  end
end

