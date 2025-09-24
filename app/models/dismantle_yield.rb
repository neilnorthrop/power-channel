class DismantleYield < ApplicationRecord
  belongs_to :dismantle_rule
  belongs_to :component, polymorphic: true

  validates :component_type, inclusion: { in: %w[Resource Item] }
  validates :quantity, numericality: { greater_than: 0 }
  validates :salvage_rate, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
end
