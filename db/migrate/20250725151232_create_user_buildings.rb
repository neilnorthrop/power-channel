class CreateUserBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_buildings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.integer :level

      t.timestamps
    end
  end
end
