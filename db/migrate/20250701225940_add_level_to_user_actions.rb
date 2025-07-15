class AddLevelToUserActions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_actions, :level, :integer, default: 1
  end
end
