# frozen_string_literal: true

require "set"

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

    return result if (result = flag_is_locked?)

    user_action = @user.user_actions.find_or_create_by(action: action)

    # Check cooldown
    if user_action.off_cooldown?
      # Roll outcomes first (pure, uses RNG but no persistence)
      resource_rolls, total_gained, coins_gained = roll_resource_drops(action.resource_drops, user_action)
      item_rolls = roll_item_drops(action.item_drops, user_action)

      # Preload current user state for relevant resource/item IDs to avoid N+1 queries
      resource_ids = action.resource_drops.map(&:resource_id)
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
        resource_delta_broadcast(resource_changes)
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

  def flag_is_locked?
    # Gate by flag via polymorphic unlockables
    if (gate = Unlockable.find_by(unlockable_type: "Action", unlockable_id: action.id))
      unless @user.user_flags_exists?(gate.flag_id)
        # Build requirements summary using preloaded names to avoid N+1 queries
        # names_map = RequirementNameLookup.for_flag_ids([ gate.flag_id ])
        reqs = gate.flag_requirements.map do |r|
          [ requirement_name_lookup(gate.flag_id, r.requirement_type, r.requirement_id), req_qty(r) ].join
        end.compact
        msg = "Locked. Requirements: #{reqs.presence&.join(', ') || 'Unavailable' }"
        { success: false, error: msg }
      end
    end
  end

  def requirement_name_lookup(flag_id, req_type, req_id)
    # Lookup name from preloaded map; fallback to type if not found
    # This avoids N+1 queries by using a preloaded hash of names
    # The names_map is structured as { requirement_type => { requirement_id => name } }
    # We use dig to safely navigate the nested hash
    # If the name is not found, we fallback to using the requirement_type as a generic name
    # This ensures we always have something to display in the requirements list
    # Example: If requirement is an Item with id=5 and name="Wood", we show "Wood"
    # If the name is not found, we show "Item" instead
    # This way, we avoid leaking exact requirement details while still providing useful information
    # to the user about what they need to unlock the action.
    # The goal is to inform the user without overwhelming them with specifics.
    # This is especially important for requirements that may not have a user-friendly name
    # or for requirements that are not directly visible to the user.
    # By using the requirement_type as a fallback, we ensure clarity and simplicity in the message.
    # This approach balances informativeness with usability in the user interface.
    # It also helps prevent confusion or frustration if the user cannot find the exact item/building
    # they need to unlock the action.
    (req_name_lookup_for_flag(flag_id).dig(req_type, req_id)) || req_type
  end

  def req_name_lookup_for_flag(flag_id)
    @req_name_lookup_for_flag ||= RequirementNameLookup.for_flag_ids([ flag_id ])
  end

  def req_qty(r)
    # Append quantity if more than 1
    #
    # Note: quantity is informational only; actual requirement logic is enforced in Flag model
    # (e.g., user must have at least that many items/buildings)
    # If quantity is 1 or nil, we omit it for brevity.
    # If quantity is more than 1, we append " xN" to indicate the requirement.
    # This is purely for user information and does not affect the requirement check itself.
    # Example: "Item x2", "Building x3", "Quest"
    # If quantity is 1, we just show "Item", "Building", etc.
    # If quantity is nil, we also just show the type/name.
    # If the name is unavailable, we fallback to the requirement type.
    # This ensures we always have something to display.
    # Examples:
    # - Requirement: Item id=5, quantity=3, name="Wood" => "Wood x3"
    # - Requirement: Building id=2, quantity=1, name="House" => "House"
    # - Requirement: Quest id=10, quantity=nil, name=nil => "Quest"
    # - Requirement: Item id=7, quantity=4, name=nil => "Item x4"
    # - Requirement: Building id=3, quantity=1, name=nil => "Building"
    # - Requirement: Quest id=11, quantity=nil, name="Dragon Slayer" => "Dragon Slayer"
    # This logic ensures clarity while avoiding unnecessary detail that could confuse users.
    # The goal is to inform the user what they need without overwhelming them with specifics.
    # The actual requirement enforcement is handled elsewhere, so this is just for display.
    # This approach balances informativeness with simplicity in the user message.
    # It also avoids revealing exact requirement details that could be exploited.
    # The focus is on what the user needs to unlock the action, not the exact mechanics.
    r.quantity.to_i > 1 ? " x#{r.quantity}" : ""
  end

  def user_action_update_broadcast
    user_broadcast("user_action_update", UserActionSerializer.new(user_action, include: [ :action ]).serializable_hash)
  end

  def user_update_broadcast
    # Broadcast user stats for header without requiring refetch
    user_broadcast("user_update", { level: @user.level, experience: @user.experience, skill_points: @user.skill_points })
  end

  def item_delta_broadcast(changed)
    user_broadcast("user_item_delta", { changes: changed })
  end

  def resource_delta_broadcast(changed)
    user_broadcast("user_resource_delta", { changes: changed })
  end

  def user_broadcast(type, data)
    UserUpdatesChannel.broadcast_to(@user, { type: type, data: data })
  end

  def action
    @action ||= Action.includes(resource_drops: :resource, item_drops: :item).find_by(id: @action_id)
  end

  # Aggregate luck from active effects with optional action scoping
  # Scope key format: "action:<underscored_action_name>" (e.g., action:hunt)
  # Chance multiplier uses global/null and action-targeted luck.
  # Quantity multiplier uses global/null, action-targeted, and quantity-targeted luck.
  def chance_mult
    total = ActiveEffect.luck_sum_for(@user, scope_key)
    1.0 + (total * LUCK_CHANCE_WEIGHT)
  end

  def quantity_mult
    # Sum action-scoped + quantity-scoped (both include global/null)
    total = ActiveEffect.luck_sum_for(@user, scope_key) + ActiveEffect.luck_sum_for(@user, "quantity")
    1.0 + (total * LUCK_QTY_WEIGHT)
  end

  def user_action
    @user_action ||= @user.user_actions.find_by(action_id: @action_id)
  end

  def roll_resource_drops(resource_drops, user_action)
    rolls = []
    # Build a unified view of resource drops.
    drop_struct = Struct.new(:resource, :min_amount, :max_amount, :drop_chance)
    drops = Array(resource_drops).map { |d| drop_struct.new(d.resource, d.min_amount, d.max_amount, d.drop_chance) }
    # Always include legacy Action.resources as well to preserve behavior in tests/older data
    if action && action.respond_to?(:resources)
      existing_ids = drops.map { |d| d.resource&.id }.compact.to_set
      action.resources.each do |r|
        next if existing_ids.include?(r.id)
        drops << drop_struct.new(r, (r.respond_to?(:min_amount) ? r.min_amount : nil), (r.respond_to?(:max_amount) ? r.max_amount : nil), (r.respond_to?(:drop_chance) ? r.drop_chance : 1.0))
      end
    end
    total_gained = 0
    coins_gained = 0
    drops.each do |drop|
      resource = drop.resource
      next unless resource
      chance = DropCalculator.effective_chance(drop.drop_chance, chance_mult)
      next unless DropCalculator.roll?(chance)

      skill_service = SkillService.new(@user)
      base = DropCalculator.base_quantity(drop.min_amount, drop.max_amount, user_action.level, resource.base_amount)
      _cooldown, amount = skill_service.apply_skills_to_action(action, action.cooldown, base)
      exact = amount.to_f * quantity_mult
      amount = DropCalculator.quantize_with_prob(exact, min_on_success: 1)
      total_gained += amount
      coins_gained += amount if resource.name.to_s.downcase.include?("coin")
      rolls << [ resource, amount ]
    end
    [ rolls, total_gained, coins_gained ]
  end

  def roll_item_drops(item_drops, user_action)
    rolls = []
    item_drops.each do |drop|
      chance = DropCalculator.effective_chance(drop.drop_chance, chance_mult)
      next unless DropCalculator.roll?(chance)
      base = DropCalculator.base_quantity(drop.min_amount, drop.max_amount, user_action.level, drop.base_amount)
      exact = base.to_f * quantity_mult
      amount = DropCalculator.quantize_with_prob(exact, min_on_success: 1)
      rolls << [ drop, amount ]
    end
    rolls
  end

  def persist_resource_gains(rolls)
    rolls.each do |resource, amount|
      # Use preloaded map; create only when needed
      ur = @user_resources_by_id[resource.id]
      # Fallback to fetch existing row if not preloaded (e.g., when using resource fallback)
      ur ||= @user.user_resources.find_by(resource_id: resource.id)
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
    action.resource_drops.map do |d|
      r = d.resource
      next unless r
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
end
