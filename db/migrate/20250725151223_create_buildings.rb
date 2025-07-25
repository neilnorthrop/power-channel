class CreateBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :buildings do |t|
      t.string :name
      t.text :description
      t.integer :level
      t.string :effect

      t.timestamps
    end
  end
end
