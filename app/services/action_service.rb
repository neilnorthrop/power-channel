# frozen_string_literal: true

class ActionService
  # Luck split weights (chance vs quantity). Adjust as needed.
  LUCK_CHANCE_WEIGHT = 0.5
  LUCK_QTY_WEIGHT    = 0.5
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

      # Aggregate a simple luck bonus from active effects (modifier_type == 'luck')
      luck_bonus = ActiveEffect
                      .where(user: @user)
                      .where("expires_at > ?", Time.current)
                      .joins(:effect)
                      .where(effects: { modifier_type: "luck" })
                      .sum("COALESCE(effects.modifier_value, 0)").to_f

      # Split luck between chance and quantity; adjust weights above as desired
      chance_mult  = 1.0 + (luck_bonus * LUCK_CHANCE_WEIGHT)
      quantity_mult = 1.0 + (luck_bonus * LUCK_QTY_WEIGHT)

      action.resources.each do |resource|
        # Success roll based on (drop_chance * chance_mult)
        effective_chance = [ resource.drop_chance.to_f * chance_mult, 1.0 ].min
        if rand < effective_chance
          # Determine base quantity (min..max or base_amount)
          base_qty = if resource.min_amount.present? && resource.max_amount.present?
                       min = resource.min_amount.to_i
                       max = resource.max_amount.to_i
                       rand(min..max)
          else
                       resource.base_amount.to_i
          end

          # Apply skills, then quantity multiplier from luck
          skill_service = SkillService.new(@user)
          cooldown, amount = skill_service.apply_skills_to_action(action, cooldown, base_qty)

          # Probabilistic fractional rounding:
          # exact = base * multiplier; give +1 with probability equal to the fractional part.
          exact = amount.to_f * quantity_mult
          int   = exact.floor
          frac  = exact - int
          amount = int + (rand < frac ? 1 : 0)
          amount = 1 if amount <= 0 # ensure a successful drop yields at least 1

          user_resource = @user.user_resources.find_or_create_by(resource: resource)
          user_resource.increment!(:amount, amount)
          total_gained += amount
          coins_gained += amount if resource.name.to_s.downcase.include?("coin")
        end
      end
      user_action.update(last_performed_at: Time.current)
      @user.gain_experience(10)
      @user.save
      # Broadcast minimal deltas
      UserUpdatesChannel.broadcast_to(@user, { type: "user_action_update", data: UserActionSerializer.new(user_action, include: [ :action ]).serializable_hash })
      if total_gained > 0
        changed = action.resources.map do |r|
          ur = @user.user_resources.find_by(resource_id: r.id)
          { resource_id: r.id, amount: ur&.amount.to_i }
        end
        UserUpdatesChannel.broadcast_to(@user, { type: "user_resource_delta", data: { changes: changed } })
      end
      # Broadcast user stats for header without requiring refetch
      UserUpdatesChannel.broadcast_to(@user, { type: 'user_update', data: { level: @user.level, experience: @user.experience, skill_points: @user.skill_points } })
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
