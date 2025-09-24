# frozen_string_literal: true

class UserActionSerializer
  include JSONAPI::Serializer
  attributes :id, :last_performed_at, :user_id, :action_id, :level

  attribute :cooldown do |object|
    object.action.cooldown
  end

  attribute :locked do |object, params|
    user = params && params[:current_user]
    gates = params && params[:gates] && params[:gates]["Action"]
    user_flag_ids = params && params[:user_flag_ids]
    if user
      if gates && user_flag_ids
        flag_id = gates[object.action_id]
        flag_id.present? && !user_flag_ids.include?(flag_id)
      else
        if (gate = Unlockable.find_by(unlockable_type: "Action", unlockable_id: object.action_id))
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
    gates = params && params[:gates] && params[:gates]["Action"]
    flag = if gates
      flag_id = gates[object.action_id]
      flag_id ? Flag.find(flag_id) : nil
    else
      (Unlockable.find_by(unlockable_type: "Action", unlockable_id: object.action_id)&.flag)
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

  belongs_to :action, serializer: ActionSerializer
end
