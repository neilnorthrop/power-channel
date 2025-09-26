# frozen_string_literal: true

class AddSuspensionFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :suspended_until, :datetime
    add_column :users, :suspension_reason, :text
    add_index :users, :suspended_until
  end
end

