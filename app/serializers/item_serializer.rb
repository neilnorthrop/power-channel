# frozen_string_literal: true

class ItemSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :effect

  attribute :locked do |object, params|
    user = params && params[:current_user]
    if user
      if (gate = Unlockable.find_by(unlockable_type: 'Item', unlockable_id: object.id))
        !user.user_flags.exists?(flag_id: gate.flag_id)
      else
        false
      end
    else
      false
    end
  end
end
