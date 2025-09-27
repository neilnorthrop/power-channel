# frozen_string_literal: true

class CreateDbValidationReports < ActiveRecord::Migration[8.0]
  def change
    create_table :db_validation_reports do |t|
      t.string :status, null: false, default: 'ok'
      t.integer :issues_count, null: false, default: 0
      t.jsonb :report, null: false, default: {}
      t.timestamps
    end
    add_index :db_validation_reports, :created_at
    add_index :db_validation_reports, :status
  end
end
