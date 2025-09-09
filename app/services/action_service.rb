# frozen_string_literal: true

class ActionService
  def initialize(user)
    @user = user
  end

  # Perform an action for the user, checking for cooldowns and unlockable requirements
  # Returns a hash with success status and message or error details for the action performed
  #
  # Example return values:
  # { success: true, message: "Action performed successfully." }
  # { success: false, error: "Action is on cooldown." }
  # { success: false, error: "Action not found." }
  # { success: false, error: "Locked. Requirements: Item x2, Building x1" }
  # { success: true, message: "10 coins collected from taxes!", hint: { kind: 'action' } }
  # { success: true, message: "5 resources found!", hint: { kind: 'action' } }
  # { success: true, message: "Action performed.", hint: { kind: 'action' } }
  # The hint key can be used to provide additional context for the frontend to display relevant hints or notifications.
  #
  # @param action_id [Integer] the ID of the action to perform
  # @return [Hash] result of the action attempt with success status and message or error details
  def perform_action(action_id)
    action = Action.find_by(id: action_id)
    return { success: false, error: "Action not found." } unless action

    # Gate by flag via polymorphic unlockables
    if (gate = Unlockable.find_by(unlockable_type: "Action", unlockable_id: action.id))
      unless @user.user_flags.exists?(flag_id: gate.flag_id)
        # Build requirements summary for friendly error
        reqs = gate.flag.flag_requirements.includes(:requirement).map do |r|
          name = case r.requirement_type
          when "Item" then Item.find_by(id: r.requirement_id)&.name
          when "Building" then Building.find_by(id: r.requirement_id)&.name
          when "Resource" then Resource.find_by(id: r.requirement_id)&.name
          when "Flag" then Flag.find_by(id: r.requirement_id)&.name
          when "Skill" then Skill.find_by(id: r.requirement_id)&.name
          else r.requirement_type
          end
          qty = r.quantity.to_i > 1 ? " x#{r.quantity}" : ""
          [ name, qty ].compact.join
        end.compact
        msg = "Locked. Requirements: #{reqs.presence || [ 'Unavailable' ] .join(', ')}"
        return { success: false, error: msg }
      end
    end

    user_action = @user.user_actions.find_or_create_by(action: action)

    cooldown = action.cooldown

    if user_action.last_performed_at.nil? || Time.current > user_action.last_performed_at + cooldown.seconds
      total_gained = 0
      coins_gained = 0
      action.resources.each do |resource|
        if rand.round(4) <= resource.drop_chance
          amount = resource.base_amount
          skill_service = SkillService.new(@user)
          cooldown, amount = skill_service.apply_skills_to_action(action, cooldown, amount)
          user_resource = @user.user_resources.find_or_create_by(resource: resource)
          user_resource.increment!(:amount, amount)
          total_gained += amount.to_i
          coins_gained += amount.to_i if resource.name.to_s.downcase.include?("coin")
        end
      end
      user_action.update(last_performed_at: Time.current)
      @user.gain_experience(10)
      @user.save
      UserUpdatesChannel.broadcast_to(@user, { type: "user_action_update", data: UserActionSerializer.new(user_action, include: [ :action ]).serializable_hash })
      UserUpdatesChannel.broadcast_to(@user, { type: "user_resource_update", data: UserResourcesSerializer.new(@user.user_resources).serializable_hash })
      Event.create!(user: @user, level: "info", message: "Performed action: #{action.name}")
      # Friendly toast message hints
      msg = if action.name.to_s.downcase.include?("tax") && coins_gained > 0
              "#{coins_gained} coins collected from taxes!"
      elsif total_gained > 0
              "#{total_gained} #{action.name} resources found!"
      else
              "#{action.name} performed."
      end
      { success: true, message: msg, hint: { kind: "action" } }
    else
      Event.create!(user: @user, level: "warning", message: "Attempted action on cooldown: #{action.name}")
      { success: false, error: "Action is on cooldown." }
    end
  end
end
