# frozen_string_literal: true

class CreateSuspensionTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :suspension_templates do |t|
      t.string :name, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :suspension_templates, :name, unique: true
  end
end

