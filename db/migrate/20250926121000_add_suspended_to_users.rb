# frozen_string_literal: true

class AddSuspendedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :suspended, :boolean, null: false, default: false
    add_index :users, :suspended
  end
end

