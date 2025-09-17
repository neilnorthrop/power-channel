class Action < ApplicationRecord
  has_many :resources
  has_many :user_actions
  has_many :users, through: :user_actions
  has_many :effects, as: :effectable, dependent: :destroy
  has_many :item_drops, class_name: 'ActionItemDrop', dependent: :destroy
  has_many :drop_items, through: :item_drops, source: :item
end
