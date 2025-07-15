class CreateResources < ActiveRecord::Migration[8.0]
  def change
    create_table :resources do |t|
      t.string :name
      t.text :description
      t.integer :base_amount

      t.timestamps
    end
  end
end
