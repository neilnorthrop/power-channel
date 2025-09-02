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
    to_grant = []
    flags.find_each do |flag|
      next if @user.user_flags.exists?(flag_id: flag.id)
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
    Flag.where(id: req_scope.select(:flag_id))
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
    case req.requirement_type
    when 'Item'
      ui = @user.user_items.find_by(item_id: req.requirement_id)
      ui && ui.quantity.to_i >= req.quantity
    when 'Building'
      ub = @user.user_buildings.find_by(building_id: req.requirement_id)
      ub && (ub.level.to_i >= req.quantity)
    when 'Resource'
      ur = @user.user_resources.find_by(resource_id: req.requirement_id)
      ur && ur.amount.to_i >= req.quantity
    when 'Flag'
      @user.user_flags.exists?(flag_id: req.requirement_id)
    when 'Skill'
      @user.user_skills.exists?(skill_id: req.requirement_id)
    else
      false
    end
  end
end
