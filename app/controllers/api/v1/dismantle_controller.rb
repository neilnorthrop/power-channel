# frozen_string_literal: true

class Api::V1::DismantleController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def create
    item_id = params.require(:item_id)
    quality = params[:quality] || DismantleService::DEFAULT_QUALITY
    service = DismantleService.new(@current_user)
    result = service.dismantle_item(item_id, quality: quality)

    if result[:success]
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end

