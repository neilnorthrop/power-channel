class UserAction < ApplicationRecord
  belongs_to :user
  belongs_to :action

  def upgrade
    self.level += 1
    save
  end
end
