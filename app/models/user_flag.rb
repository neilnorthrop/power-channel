# frozen_string_literal: true

class UserFlag < ApplicationRecord
  belongs_to :user
  belongs_to :flag

  validates :user_id, uniqueness: { scope: :flag_id }
end

