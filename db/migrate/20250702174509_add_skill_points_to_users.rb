class AddSkillPointsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :skill_points, :integer, default: 0
  end
end
