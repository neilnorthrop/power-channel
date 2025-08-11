class AddMultiplierToSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :skills, :multiplier, :float
  end
end
