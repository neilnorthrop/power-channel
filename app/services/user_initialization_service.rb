# frozen_string_literal: true

class UserInitializationService
  def initialize(user)
    @user = user
  end

  def initialize_defaults
    @user.skill_points = 0
    @user.level = 1
    @user.experience = 0
    assign_default_resources_and_actions
    @user.save
  end

  private

  def assign_default_resources_and_actions
    Resource.all.each do |resource|
      @user.user_resources.find_or_create_by(resource: resource) do |user_resource|
        user_resource.amount = resource.base_amount
      end
    end

    Action.all.each do |action|
      @user.user_actions.find_or_create_by(action: action)
    end
  end
end
