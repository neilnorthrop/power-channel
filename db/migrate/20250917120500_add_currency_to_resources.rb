class AddCurrencyToResources < ActiveRecord::Migration[8.0]
  def up
    add_column :resources, :currency, :boolean, default: false, null: false

    # Backfill existing currency-like resources (e.g., Gold Coins)
    execute <<~SQL
      UPDATE resources
      SET currency = TRUE
      WHERE LOWER(name) LIKE '%coin%';
    SQL
  end

  def down
    remove_column :resources, :currency
  end
end
