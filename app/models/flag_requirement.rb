# frozen_string_literal: true

class FlagRequirement < ApplicationRecord
  belongs_to :flag
  belongs_to :requirement, polymorphic: true

  validates :requirement_type, :requirement_id, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end

