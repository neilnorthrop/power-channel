# frozen_string_literal: true

class ActionItemDrop < ApplicationRecord
  belongs_to :action
  belongs_to :item

  validates :drop_chance, presence: true,
                          numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :min_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :min_not_greater_than_max

  private

  def min_not_greater_than_max
    return if min_amount.nil? || max_amount.nil?
    return if min_amount.to_i <= max_amount.to_i

    errors.add(:min_amount, "cannot be greater than max_amount")
  end
end
