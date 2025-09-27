# frozen_string_literal: true

class Announcement < ApplicationRecord
  scope :active, -> { where(active: true) }
  scope :published, -> { where("published_at IS NULL OR published_at <= ?", Time.current) }
  validates :title, presence: true
end
