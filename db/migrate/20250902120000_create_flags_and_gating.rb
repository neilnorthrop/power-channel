# frozen_string_literal: true

class CreateFlagsAndGating < ActiveRecord::Migration[7.1]
  def change
    create_table :flags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.timestamps
    end
    add_index :flags, :slug, unique: true

    create_table :user_flags do |t|
      t.references :user, null: false, foreign_key: true
      t.references :flag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_flags, [ :user_id, :flag_id ], unique: true

    create_table :flag_requirements do |t|
      t.references :flag, null: false, foreign_key: true
      t.string :requirement_type, null: false
      t.bigint :requirement_id, null: false
      t.integer :quantity, null: false, default: 1
      t.timestamps
    end
    add_index :flag_requirements, [ :requirement_type, :requirement_id ], name: 'index_flag_requirements_on_req'

    create_table :unlockables do |t|
      t.references :flag, null: false, foreign_key: true
      t.string :unlockable_type, null: false
      t.bigint :unlockable_id, null: false
      t.timestamps
    end
    add_index :unlockables, [ :flag_id, :unlockable_type, :unlockable_id ], unique: true, name: 'index_unlockables_unique'
    add_index :unlockables, [ :unlockable_type, :unlockable_id ], name: 'index_unlockables_on_unlockable'
  end
end
