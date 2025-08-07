class RenameMineGoldToTaxes < ActiveRecord::Migration[8.0]
  def change
    gold_coins = Resource.find_or_create_by(name: 'Gold Coins')
    action = Action.find_by(name: 'Mine Gold')
    action.update(name: 'Taxes', description: 'Gather taxes from your citizens.')
    gold_coins.update(action: action)
  end
end
