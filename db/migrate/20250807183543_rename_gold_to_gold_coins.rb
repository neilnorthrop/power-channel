class RenameGoldToGoldCoins < ActiveRecord::Migration[8.0]
  def change
    Resource.where(name: 'Gold').update_all(name: 'Gold Coins')
  end
end
