class CreateDismantleRulesAndYields < ActiveRecord::Migration[8.0]
  def change
    create_table :dismantle_rules do |t|
      t.string  :subject_type, null: false # 'Item' for initial scope
      t.bigint  :subject_id,   null: false
      t.text    :notes
      t.timestamps
    end
    add_index :dismantle_rules, [ :subject_type, :subject_id ], unique: true, name: 'index_dismantle_rules_on_subject'

    create_table :dismantle_yields do |t|
      t.references :dismantle_rule, null: false, foreign_key: true
      t.string  :component_type, null: false # 'Resource' or 'Item'
      t.bigint  :component_id,   null: false
      t.integer :quantity,       null: false, default: 1
      t.decimal :salvage_rate,   null: false, default: 1.0, precision: 5, scale: 2
      t.string  :quality # for Item outputs; nil means default
      t.timestamps
    end
    add_index :dismantle_yields, [ :dismantle_rule_id, :component_type, :component_id ], name: 'index_dismantle_yields_on_rule_component'
  end
end
