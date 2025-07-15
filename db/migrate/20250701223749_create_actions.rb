class CreateActions < ActiveRecord::Migration[8.0]
  def change
    create_table :actions do |t|
      t.string :name
      t.text :description
      t.integer :cooldown
      t.references :resource, null: false, foreign_key: true

      t.timestamps
    end
  end
end
