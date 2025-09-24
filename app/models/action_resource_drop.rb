# frozen_string_literal: true

class ActionResourceDrop < ApplicationRecord
  belongs_to :action
  belongs_to :resource

  validates :drop_chance, presence: true
  validates :min_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end

