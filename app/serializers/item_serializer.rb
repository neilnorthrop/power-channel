# frozen_string_literal: true

class ItemSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :effect

  attribute :locked do |object, params|
    user = params && params[:current_user]
    gates = params && params[:gates] && params[:gates]['Item']
    user_flag_ids = params && params[:user_flag_ids]
    if user
      if gates && user_flag_ids
        flag_id = gates[object.id]
        flag_id.present? && !user_flag_ids.include?(flag_id)
      else
        if (gate = Unlockable.find_by(unlockable_type: 'Item', unlockable_id: object.id))
          !user.user_flags.exists?(flag_id: gate.flag_id)
        else
          false
        end
      end
    else
      false
    end
  end
end
