class AddIndexToActiveEffectsExpiresAt < ActiveRecord::Migration[8.0]
  def change
    add_index :active_effects, :expires_at
  end
end
