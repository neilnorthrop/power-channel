# frozen_string_literal: true

class CreateOwnerAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :owner_audit_logs do |t|
      t.bigint :actor_id, null: false
      t.bigint :target_user_id
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :owner_audit_logs, :actor_id
    add_index :owner_audit_logs, :target_user_id
    add_index :owner_audit_logs, :action
    add_foreign_key :owner_audit_logs, :users, column: :actor_id
    add_foreign_key :owner_audit_logs, :users, column: :target_user_id
  end
end

