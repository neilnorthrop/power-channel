# frozen_string_literal: true

class SkillSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :cost, :effect

  attribute :locked do |object, params|
    user = params && params[:current_user]
    if user
      if (gate = Unlockable.find_by(unlockable_type: 'Skill', unlockable_id: object.id))
        !user.user_flags.exists?(flag_id: gate.flag_id)
      else
        false
      end
    else
      false
    end
  end

  attribute :requirements do |object|
    if (gate = Unlockable.find_by(unlockable_type: 'Skill', unlockable_id: object.id))
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
end
