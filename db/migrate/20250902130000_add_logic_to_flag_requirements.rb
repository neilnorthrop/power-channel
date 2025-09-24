# frozen_string_literal: true

class AddLogicToFlagRequirements < ActiveRecord::Migration[8.0]
  def change
    add_column :flag_requirements, :logic, :string, null: false, default: 'AND'
    add_index :flag_requirements, :logic
  end
end
