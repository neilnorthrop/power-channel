# frozen_string_literal: true

class Flag < ApplicationRecord
  has_many :user_flags, dependent: :destroy
  has_many :flag_requirements, dependent: :destroy
  has_many :unlockables, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
end
