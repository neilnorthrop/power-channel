# frozen_string_literal: true

class Api::V1::DismantleController < Api::ApiController
  include Authenticable

  # POST /api/v1/dismantle
  # Dismantle an item for the current user, returning the resources obtained from the dismantling process.
  # Example return value:
  # {
  #   "message": "Item dismantled successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the dismantling operation or any error details
  # @example POST /api/v1/dismantle
  #   curl -X POST "https://example.com/api/v1/dismantle" -d '{"item_id": 1, "quality": "high"}'
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
