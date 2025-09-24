class UserItem < ApplicationRecord
  belongs_to :user
  belongs_to :item

  # Rails 8 enum API prefers positional attribute name
  enum :quality, { normal: "normal", rare: "rare", epic: "epic", legendary: "legendary" }
end
