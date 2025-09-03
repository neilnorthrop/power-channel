class Event < ApplicationRecord
  belongs_to :user

  LEVELS = %w[debug info warning error critical].freeze

  validates :message, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }

  after_create_commit :broadcast_event

  private

  def broadcast_event
    payload = {
      type: 'event',
      data: EventSerializer.new(self).serializable_hash
    }
    UserUpdatesChannel.broadcast_to(user, payload)
  end
end
