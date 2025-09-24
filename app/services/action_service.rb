# frozen_string_literal: true
require 'set'

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
    @action_id = action_id
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

    # Check cooldown
    if user_action.off_cooldown?
      # Roll outcomes first (pure, uses RNG but no persistence)
      resource_rolls, total_gained, coins_gained = roll_resource_drops(action.resources, user_action)
      item_rolls = roll_item_drops(action.item_drops, user_action)

      # Preload current user state for relevant resource/item IDs to avoid N+1 queries
      resource_ids = action.resources.map(&:id)
      item_ids     = action.item_drops.map(&:item_id)
      @user_resources_by_id = resource_ids.any? ? @user.user_resources.where(resource_id: resource_ids).index_by(&:resource_id) : {}
      @user_items_by_id     = item_ids.any?     ? @user.user_items.where(item_id: item_ids, quality: CraftingService::DEFAULT_QUALITY).index_by(&:item_id) : {}

      # Track changed IDs for efficient delta broadcasts
      @changed_resource_ids = Set.new
      @changed_item_ids     = Set.new

      # Persist atomically
      ApplicationRecord.transaction do
        persist_resource_gains(resource_rolls)
        persist_item_gains(item_rolls)
        user_action.update!(last_performed_at: Time.current)
        @user.gain_experience(10)
        @user.save!
      end

      # After-commit: collect and broadcast
      user_action_update_broadcast

      # Build and broadcast minimal deltas from tracked changed IDs
      if @changed_resource_ids.any?
        resource_changes = @changed_resource_ids.map do |rid|
          ur = @user_resources_by_id[rid] || @user.user_resources.find_by(resource_id: rid)
          { resource_id: rid, amount: ur&.amount.to_i }
        end
        resource_delta_broadcase(resource_changes)
      end

      if @changed_item_ids.any?
        item_changes = @changed_item_ids.map do |iid|
          ui = @user_items_by_id[iid] || @user.user_items.find_by(item_id: iid, quality: CraftingService::DEFAULT_QUALITY)
          { item_id: iid, quality: CraftingService::DEFAULT_QUALITY, quantity: ui&.quantity.to_i }
        end
        item_delta_broadcast(item_changes)
      end

      user_update_broadcast
      Event.create!(user: @user, level: "info", message: "Performed action: #{action.name}")

      { success: true, message: build_message(action, total_gained, coins_gained), hint: { kind: "action" } }
    else
      Event.create!(user: @user, level: "warning", message: "Attempted action on cooldown: #{action.name}")
      { success: false, error: "Action is on cooldown." }
    end
  end

  private

  def user_action_update_broadcast
    user_broadcast("user_action_update", UserActionSerializer.new(user_action, include: [ :action ]).serializable_hash )
  end

  def user_update_broadcast
    # Broadcast user stats for header without requiring refetch
    user_broadcast("user_update", { level: @user.level, experience: @user.experience, skill_points: @user.skill_points })
  end

  def item_delta_broadcast(changed)
    user_broadcast("user_item_delta", { changes: changed })
  end

  def resource_delta_broadcase(changed)
    user_broadcast("user_resource_delta", { changes: changed })
  end

  def user_broadcast(type, data)
    UserUpdatesChannel.broadcast_to(@user, { type: type, data: data })
  end

  def action
    @action ||= Action.includes(:resources, :item_drops).find_by(id: @action_id)
  end

  # Aggregate luck from active effects with optional action scoping
  # Scope key format: "action:<underscored_action_name>" (e.g., action:hunt)
  # Chance multiplier uses global/null and action-targeted luck.
  # Quantity multiplier uses global/null, action-targeted, and quantity-targeted luck.
  def chance_mult
    total = ActiveEffect.luck_total_for_chance(@user, [ scope_key ])
    1.0 + (total * LUCK_CHANCE_WEIGHT)
  end

  def quantity_mult
    total = ActiveEffect.luck_total_for_quantity(@user, [ scope_key ])
    1.0 + (total * LUCK_QTY_WEIGHT)
  end

  def user_action
    @user_action ||= @user.user_actions.find_by(action_id: @action_id)
  end

  def roll_resource_drops(resources, user_action)
    rolls = []
    total_gained = 0
    coins_gained = 0
    resources.each do |resource|
      next unless Kernel.rand < effective_chance(resource.drop_chance, chance_mult)

      skill_service = SkillService.new(@user)
      _cooldown, amount = skill_service.apply_skills_to_action(action, action.cooldown, base_qty(resource, user_action))
      amount = fractional_rounding(amount, quantity_mult)
      total_gained += amount
      coins_gained += amount if resource.name.to_s.downcase.include?("coin")
      rolls << [ resource, amount ]
    end
    [ rolls, total_gained, coins_gained ]
  end

  def roll_item_drops(item_drops, user_action)
    rolls = []
    item_drops.each do |drop|
      next unless Kernel.rand < effective_chance(drop.drop_chance, chance_mult)
      amount = fractional_rounding(base_qty(drop, user_action), quantity_mult)
      rolls << [ drop, amount ]
    end
    rolls
  end

  def persist_resource_gains(rolls)
    rolls.each do |resource, amount|
      # Use preloaded map; create only when needed
      ur = @user_resources_by_id[resource.id]
      unless ur
        ur = @user.user_resources.build(resource_id: resource.id, amount: 0)
        ur.save!
        @user_resources_by_id[resource.id] = ur
      end
      ur.update!(amount: ur.amount.to_i + amount)
      @changed_resource_ids << resource.id if defined?(@changed_resource_ids)
    end
  end

  def persist_item_gains(rolls)
    rolls.each do |drop, amount|
      # Use preloaded map; create only when needed
      ui = @user_items_by_id[drop.item_id]
      unless ui
        ui = @user.user_items.build(item_id: drop.item_id, quality: CraftingService::DEFAULT_QUALITY, quantity: 0)
        ui.save!
        @user_items_by_id[drop.item_id] = ui
      end
      ui.update!(quantity: ui.quantity.to_i + amount)
      @changed_item_ids << drop.item_id if defined?(@changed_item_ids)
    end
  end

  def collect_resource_changes(action)
    # Deprecated in favor of tracked deltas; kept for compatibility if needed
    action.resources.map do |r|
      ur = @user.user_resources.find_by(resource_id: r.id)
      { resource_id: r.id, amount: ur&.amount.to_i }
    end
  end

  def collect_item_changes(item_rolls)
    # Deprecated in favor of tracked deltas; kept for compatibility if needed
    item_ids = item_rolls.map { |drop, _| drop.item_id }.uniq
    item_ids.map do |iid|
      ui = @user.user_items.find_by(item_id: iid, quality: CraftingService::DEFAULT_QUALITY)
      { item_id: iid, quality: CraftingService::DEFAULT_QUALITY, quantity: ui&.quantity.to_i }
    end
  end

  def build_message(action, total_gained, coins_gained)
    if action.name.to_s.downcase.include?("tax") && coins_gained > 0
      "#{coins_gained} coins collected from taxes!"
    elsif total_gained > 0
      "#{total_gained} #{action.name} resources found!"
    else
      "#{action.name} performed."
    end
  end

  def scope_key
    "action:#{action.name.to_s.downcase.gsub(/\s+/, '_')}"
  end
  
  # Success roll based on (drop_chance * chance_mult)
  # Clamp at 100% chance to avoid weirdness
  # (eg. 150% chance doesn't mean guaranteed +50% quantity)
  # Also handles nil drop_chance as 0.0
  # (e.g. resources with 0% drop chance will never drop, even with luck)
  # Note: Skills may further modify cooldown and quantity below
  def effective_chance(drop_chance, chance_mult)
    [ drop_chance.to_f * chance_mult, 1.0 ].min
  end
  
  # Base quantity calculation
  # If min/max defined, use random in that range scaled by user_action level
  # Else use base_amount directly
  # Determine base quantity ((min..max * user action level) or base_amount) first
  def base_qty(drop, user_action)
    Rails.logger.debug("Calculating base quantity for resource || item #{drop.name} for user action level #{user_action.level}")
    Rails.logger.debug("Resource || item details: base_amount='#{drop.base_amount}', min_amount='#{drop.min_amount}', max_amount='#{drop.max_amount}'")
    if drop.min_amount.present? && drop.max_amount.present?
      min = drop.min_amount.to_i
      max = drop.max_amount.to_i
      base = (min == max) ? min : Kernel.rand(min..max)
      (base * user_action.level)
    else
      drop&.base_amount&.to_i || 1
    end
  end
  
  # Probabilistic fractional rounding:
  # exact = base * multiplier; give +1 with probability equal to the fractional part.
  # E.g. 2.3 -> 2 + 30% chance of +1; 2.7 -> 2 + 70% chance of +1
  # Ensures average gain is correct over time while keeping integers
  # Also ensure at least 1 is given on a successful drop
  def fractional_rounding(amount, quantity_mult)
    exact = amount.to_f * quantity_mult
    int   = exact.floor
    frac  = exact - int
    amount = int + (Kernel.rand < frac ? 1 : 0)
    amount = 1 if amount <= 0 # ensure a successful drop yields at least 1
    amount
  end
end
