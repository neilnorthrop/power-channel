class DismantleRule < ApplicationRecord
  has_many :dismantle_yields, dependent: :destroy

  belongs_to :subject, polymorphic: true

  validates :subject_type, inclusion: { in: %w[Item] }
  validates :subject_id, presence: true
end
