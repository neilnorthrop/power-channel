class UserItem < ApplicationRecord
  belongs_to :user
  belongs_to :item

  enum quality: { normal: 'normal', rare: 'rare', epic: 'epic', legendary: 'legendary' }
end
