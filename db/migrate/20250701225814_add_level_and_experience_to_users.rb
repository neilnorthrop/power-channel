class AddLevelAndExperienceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :level, :integer, default: 1
    add_column :users, :experience, :integer, default: 0
  end
end
