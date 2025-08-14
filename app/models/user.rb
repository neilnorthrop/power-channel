class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :user_resources
  has_many :resources, through: :user_resources
  has_many :user_actions
  has_many :actions, through: :user_actions
  has_many :user_skills
  has_many :skills, through: :user_skills
  has_many :user_items
  has_many :items, through: :user_items
  has_many :user_buildings
  has_many :buildings, through: :user_buildings
  has_many :active_effects, dependent: :destroy
  has_many :effects, through: :active_effects

  after_create :initialize_defaults

  # Gain experience and level up if the threshold is reached.
  # This method increases the user's experience by the specified amount,
  # checks if the user has enough experience to level up, and updates the user's level and skill points accordingly.
  # @param amount [Integer] The amount of experience to gain.
  # @return [void]
  # This method is typically called when the user performs actions that grant experience,
  # such as completing quests or defeating enemies.
  # It is defined in the model to encapsulate the logic for gaining experience and leveling up.
  # @example
  #   user = User.find(1)
  #   user.gain_experience(150)
  #   # This will increase the user's experience by 150 and check if they level up
  #   # If the user has enough experience to level up, it will increase their level and skill points.
  #
  # @note This method is called automatically when the user performs actions that grant experience,
  #       as defined in the `after_create` callback.
  #
  def gain_experience(amount)
    self.experience += amount
    while experience >= experience_for_next_level
      level_up
    end
  end

  private

  # Calculates the experience required for the next level based on the current level.
  # The formula is: 100 * level, where level starts at 1.
  #
  # @return [Integer] The experience required for the next level.
  # For level 1, it returns 100; for level 2, it returns 200, and so on.
  #
  # This method is used to determine when the user should level up based on their experience.
  # It is called in the `gain_experience` method to check if the user has enough experience to level up.
  #
  # Example:
  #   user.experience_for_next_level # => 100 for level 1, 200 for level 2, etc.
  #
  # @example
  #   user = User.new(level: 1)
  #   user.experience_for_next_level # => 100
  #
  # @example
  #   user = User.new(level: 2)
  #   user.experience_for_next_level # => 200
  #
  def experience_for_next_level
    100 * level
  end

  # Levels up the user by increasing their level, resetting experience to 0,
  # and increasing skill points by 1.
  # This method is called when the user has enough experience to level up.
  # It updates the user's attributes and saves the record.
  # @return [void]
  # This method is typically called after the user gains enough experience
  # to reach the next level.
  # # Example:
  #   user = User.find(1)
  #   user.gain_experience(150) # If this brings the user to level 2,
  #   # it will call level_up internally.
  # @example
  #   user = User.find(1)
  #   user.level_up
  #   # This will increase the user's level by 1, reset experience to 0
  #   # and increase skill points by 1.
  #
  # @note This method is called automatically when the user gains enough experience
  #       to reach the next level, as defined in the `gain_experience` method.
  #
  # @see User#gain_experience
  def level_up
    self.experience -= (100 * level)
    self.level += 1
    self.skill_points += 1
  end

  def initialize_defaults
    UserInitializationService.new(self).initialize_defaults
  end
end
