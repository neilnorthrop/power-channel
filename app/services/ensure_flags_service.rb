# frozen_string_literal: true

class EnsureFlagsService
  def self.evaluate_for(user, touch: {})
    new(user).evaluate!(touch: touch)
  end

  def initialize(user)
    @user = user
  end

  # touch: { items: [ids], buildings: [ids], resources: [ids], flags: [ids], skills: [ids] }
  def evaluate!(touch: {})
    flags = candidate_flags(touch)

    # Preload user state for candidate requirements to avoid N+1
    reqs = flags.flat_map(&:flag_requirements)
    item_req_ids     = reqs.select { |r| r.requirement_type == 'Item' }.map(&:requirement_id).uniq
    building_req_ids = reqs.select { |r| r.requirement_type == 'Building' }.map(&:requirement_id).uniq
    resource_req_ids = reqs.select { |r| r.requirement_type == 'Resource' }.map(&:requirement_id).uniq

    @pre_user_items_by_id = if item_req_ids.any?
      rows = @user.user_items.where(item_id: item_req_ids).order(:id).to_a
      rows.group_by(&:item_id).transform_values { |arr| arr.first }
    else
      {}
    end
    @pre_user_buildings_by_id = if building_req_ids.any?
      @user.user_buildings.where(building_id: building_req_ids).index_by(&:building_id)
    else
      {}
    end
    @pre_user_resources_by_id = if resource_req_ids.any?
      @user.user_resources.where(resource_id: resource_req_ids).index_by(&:resource_id)
    else
      {}
    end
    to_grant = []
    @user_flag_ids ||= @user.user_flags.pluck(:flag_id).to_set
    flags.find_each do |flag|
      next if @user_flag_ids.include?(flag.id)
      if requirements_satisfied?(flag)
        to_grant << { user_id: @user.id, flag_id: flag.id, created_at: Time.current, updated_at: Time.current }
      end
    end
    UserFlag.insert_all(to_grant, unique_by: :index_user_flags_on_user_id_and_flag_id) if to_grant.any?
  end

  private

  def candidate_flags(touch)
    scope = Flag.all
    return scope if touch.blank?
    req_scope = FlagRequirement.all
    req_scope = req_scope.where(requirement_type: 'Item', requirement_id: touch[:items]) if touch[:items].present?
    req_scope = req_scope.or(FlagRequirement.where(requirement_type: 'Building', requirement_id: touch[:buildings])) if touch[:buildings].present?
    req_scope = req_scope.or(FlagRequirement.where(requirement_type: 'Resource', requirement_id: touch[:resources])) if touch[:resources].present?
    req_scope = req_scope.or(FlagRequirement.where(requirement_type: 'Flag', requirement_id: touch[:flags])) if touch[:flags].present?
    req_scope = req_scope.or(FlagRequirement.where(requirement_type: 'Skill', requirement_id: touch[:skills])) if touch[:skills].present?
    Flag.where(id: req_scope.select(:flag_id)).includes(:flag_requirements)
  end

  def requirements_satisfied?(flag)
    reqs = flag.flag_requirements

    and_reqs = reqs.select { |r| r.logic == 'AND' }
    or_reqs  = reqs.select { |r| r.logic == 'OR' }

    and_ok = and_reqs.all? { |req| requirement_met?(req) }
    or_ok  = or_reqs.empty? || or_reqs.any? { |req| requirement_met?(req) }

    and_ok && or_ok
  end

  def requirement_met?(req)
    # Lazy-memoized user state per requirement type/id to avoid repeated queries
    @user_flag_ids ||= @user.user_flags.pluck(:flag_id).to_set
    @user_skill_ids ||= @user.user_skills.pluck(:skill_id).to_set

    case req.requirement_type
    when 'Item'
      @user_items_cache ||= {}
      ui = @user_items_cache[req.requirement_id] ||= (@pre_user_items_by_id && @pre_user_items_by_id[req.requirement_id]) || @user.user_items.find_by(item_id: req.requirement_id)
      ui && ui.quantity.to_i >= req.quantity
    when 'Building'
      @user_buildings_cache ||= {}
      ub = @user_buildings_cache[req.requirement_id] ||= (@pre_user_buildings_by_id && @pre_user_buildings_by_id[req.requirement_id]) || @user.user_buildings.find_by(building_id: req.requirement_id)
      ub && (ub.level.to_i >= req.quantity)
    when 'Resource'
      @user_resources_cache ||= {}
      ur = @user_resources_cache[req.requirement_id] ||= (@pre_user_resources_by_id && @pre_user_resources_by_id[req.requirement_id]) || @user.user_resources.find_by(resource_id: req.requirement_id)
      ur && ur.amount.to_i >= req.quantity
    when 'Flag'
      @user_flag_ids.include?(req.requirement_id)
    when 'Skill'
      @user_skill_ids.include?(req.requirement_id)
    else
      false
    end
  end
end
