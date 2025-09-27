# frozen_string_literal: true

class CreateAnnouncements < ActiveRecord::Migration[8.0]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body
      t.boolean :active, null: false, default: true
      t.datetime :published_at
      t.timestamps
    end
    add_index :announcements, :active
    add_index :announcements, :published_at
  end
end
