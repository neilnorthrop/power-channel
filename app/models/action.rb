class Action < ApplicationRecord
  has_many :resources
  # Clean up join records; keep resources intact
  has_many :user_actions, dependent: :destroy
  has_many :users, through: :user_actions
  has_many :effects, as: :effectable, dependent: :destroy
  has_many :item_drops, class_name: "ActionItemDrop", dependent: :destroy
  has_many :drop_items, through: :item_drops, source: :item
  has_many :resource_drops, class_name: "ActionResourceDrop", dependent: :destroy
  has_many :drop_resources, through: :resource_drops, source: :resource

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :order, numericality: { only_integer: true }, allow_nil: true

  # Scopes
  scope :by_order, -> { order(:order) }
  scope :by_name,  -> { order(:name) }
end
