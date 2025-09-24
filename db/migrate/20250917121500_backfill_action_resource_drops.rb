class BackfillActionResourceDrops < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    say_with_time "Backfilling action_resource_drops from resources.action_id + drop fields" do
      exec_backfill
    end
  end

  def down
    # no-op: data-only migration
  end

  private

  def exec_backfill
    # Bulk insert with upsert behavior to avoid Ruby-side loops/binds
    sql = <<~SQL
      INSERT INTO action_resource_drops (action_id, resource_id, min_amount, max_amount, drop_chance, created_at, updated_at)
      SELECT
        r.action_id,
        r.id AS resource_id,
        r.min_amount,
        r.max_amount,
        COALESCE(r.drop_chance, 1.0) AS drop_chance,
        NOW(),
        NOW()
      FROM resources r
      WHERE r.action_id IS NOT NULL
      ON CONFLICT (action_id, resource_id) DO NOTHING
    SQL

    ActiveRecord::Base.connection.exec_insert(sql)
  end
end
