# frozen_string_literal: true

class SkillSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :cost, :effect

  attribute :locked do |object, params|
    user = params && params[:current_user]
    gates = params && params[:gates] && params[:gates]["Skill"]
    user_flag_ids = params && params[:user_flag_ids]
    if user
      if gates && user_flag_ids
        flag_id = gates[object.id]
        flag_id.present? && !user_flag_ids.include?(flag_id)
      else
        if (gate = Unlockable.find_by(unlockable_type: "Skill", unlockable_id: object.id))
          !user.user_flags.exists?(flag_id: gate.flag_id)
        else
          false
        end
      end
    else
      false
    end
  end

  attribute :requirements do |object, params|
    gates = params && params[:gates] && params[:gates]["Skill"]
    flag = if gates
      flag_id = gates[object.id]
      flag_id ? Flag.find(flag_id) : nil
    else
      (Unlockable.find_by(unlockable_type: "Skill", unlockable_id: object.id)&.flag)
    end
    if flag
      names = params && params[:requirement_names]
      flag.flag_requirements.map do |r|
        name = names ? (names.dig(r.requirement_type, r.requirement_id) || r.requirement_type) :
                case r.requirement_type
                when "Item" then Item.find_by(id: r.requirement_id)&.name
                when "Building" then Building.find_by(id: r.requirement_id)&.name
                when "Resource" then Resource.find_by(id: r.requirement_id)&.name
                when "Flag" then Flag.find_by(id: r.requirement_id)&.name
                when "Skill" then Skill.find_by(id: r.requirement_id)&.name
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
