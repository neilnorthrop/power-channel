# frozen_string_literal: true

class Unlockable < ApplicationRecord
  belongs_to :flag
  belongs_to :unlockable, polymorphic: true

  validates :flag_id, :unlockable_type, :unlockable_id, presence: true
  validates :unlockable_id, uniqueness: { scope: [:flag_id, :unlockable_type] }
end

