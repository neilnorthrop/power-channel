# frozen_string_literal: true

class Api::V1::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource(sign_up_params)
    resource.save
    if resource.persisted?
      initialization_service = UserInitializationService.new(resource)
      initialization_service.initialize_defaults
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        render json: resource
      else
        expire_data_after_sign_in!
        render json: resource
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
