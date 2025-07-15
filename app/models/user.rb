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

  def gain_experience(amount)
    self.experience += amount
    level_up if experience >= experience_for_next_level
    save
  end

  private

  def experience_for_next_level
    100 * level
  end

  def level_up
    self.level += 1
    self.experience = 0
    self.skill_points += 1
  end

  def assign_default_resources_and_actions
    Resource.all.each do |resource|
      user_resources.create(resource: resource, amount: resource.base_amount)
    end

    Action.all.each do |action|
      user_actions.create(action: action)
    end
  end
end
