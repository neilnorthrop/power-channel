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
      @user.user_resources.build(resource: resource, amount: resource.base_amount)
    end

    Action.all.each do |action|
      @user.user_actions.build(action: action)
    end
  end
end
