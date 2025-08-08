class CreateEffects < ActiveRecord::Migration[8.0]
  def change
    create_table :effects do |t|
      t.string :name
      t.text :description
      t.string :target_attribute
      t.string :modifier_type
      t.float :modifier_value
      t.integer :duration
      t.references :effectable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
