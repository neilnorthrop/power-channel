# frozen_string_literal: true

class UserActionSerializer
  include JSONAPI::Serializer
  attributes :id, :last_performed_at, :user_id, :action_id, :level

  attribute :cooldown do |object|
    object.action.cooldown
  end

  attribute :locked do |object, params|
    user = params && params[:current_user]
    if user
      if (gate = Unlockable.find_by(unlockable_type: 'Action', unlockable_id: object.action_id))
        !user.user_flags.exists?(flag_id: gate.flag_id)
      else
        false
      end
    else
      false
    end
  end

  attribute :requirements do |object|
    if (gate = Unlockable.find_by(unlockable_type: 'Action', unlockable_id: object.action_id))
      gate.flag.flag_requirements.map do |r|
        name = case r.requirement_type
               when 'Item' then Item.find_by(id: r.requirement_id)&.name
               when 'Building' then Building.find_by(id: r.requirement_id)&.name
               when 'Resource' then Resource.find_by(id: r.requirement_id)&.name
               when 'Flag' then Flag.find_by(id: r.requirement_id)&.name
               when 'Skill' then Skill.find_by(id: r.requirement_id)&.name
               else r.requirement_type
               end
        {
          type: r.requirement_type.downcase,
          id: r.requirement_id,
          name: name,
          quantity: r.quantity,
          logic: r.logic
        }
      end
    else
      []
    end
  end

  belongs_to :action, serializer: ActionSerializer
end
