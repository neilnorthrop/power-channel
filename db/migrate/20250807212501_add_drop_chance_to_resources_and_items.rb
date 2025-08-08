class AddDropChanceToResourcesAndItems < ActiveRecord::Migration[8.0]
  def change
    add_column :resources, :drop_chance, :float, default: 1.0
    add_column :items, :drop_chance, :float, default: 1.0

    Resource.find_or_create_by(name: 'Gold Coins').update(drop_chance: 1.0)
    Resource.find_or_create_by(name: 'Wood').update(drop_chance: 1.0)
    Resource.find_or_create_by(name: 'Stone').update(drop_chance: 1.0)
    Resource.find_or_create_by(name: 'Coal').update(drop_chance: 0.33)

    Item.find_or_create_by(name: 'Minor Potion of Luck').update(drop_chance: 0.001)
    Item.find_or_create_by(name: 'Scroll of Haste').update(drop_chance: 0.002)

    # Ensure existing resources and items have a drop chance set
    Resource.where(drop_chance: nil).update_all(drop_chance: 1.0)
    Item.where(drop_chance: nil).update_all(drop_chance: 1.0)
  end
end
