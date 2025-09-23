class UserAction < ApplicationRecord
  belongs_to :user
  belongs_to :action

  def off_cooldown?
    return true if self.last_performed_at.nil?

    Time.current > self.last_performed_at + action.cooldown.seconds
  end

  def upgrade
    self.level += 1
    save
  end
end
