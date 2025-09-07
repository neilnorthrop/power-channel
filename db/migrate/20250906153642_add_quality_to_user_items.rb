class AddQualityToUserItems < ActiveRecord::Migration[8.0]
  def change
    add_column :user_items, :quality, :string, default: 'normal', null: false
  end
end
