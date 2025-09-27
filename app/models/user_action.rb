class UserAction < ApplicationRecord
  belongs_to :user
  belongs_to :action

  def off_cooldown?
    return true if self.last_performed_at.nil?

    cooldown_seconds = action&.cooldown.to_i
    return true if cooldown_seconds <= 0

    Time.current > (self.last_performed_at + cooldown_seconds.seconds)
  end

  def upgrade
    self.level += 1
    save
  end
end
