# frozen_string_literal: true

class Api::V1::ItemsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/items
  # Retrieve a list of items for the current user, including information about whether each item is locked based on unlockable requirements and user flags.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "user_id": 1,
  #     "item_id": 1,
  #     "quantity": 10,
  #     "item": {
  #       "id": 1,
  #       "name": "Wooden Sword",
  #       "description": "A basic wooden sword.",
  #       "effect": "sword_effect",
  #       "locked": false
  #     }
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of user items with associated item details, including lock status
  # @example GET /api/v1/items
  #   curl -X GET "https://example.com/api/v1/items"
  def index
    user_items = @current_user.user_items.includes(:item)
    item_ids = user_items.map { |ui| ui.item_id }.uniq
    items_with_effects = Effect.where(effectable_type: "Item", effectable_id: item_ids).distinct.pluck(:effectable_id).to_set
    options = { include: [ :item ], params: { current_user: @current_user, items_with_effects: items_with_effects } }
    render json: UserItemSerializer.new(user_items, options).serializable_hash.to_json
  end

  # POST /api/v1/items
  # Add an item to the current user's inventory based on the provided item ID.
  # Example return value:
  # {
  #   "message": "Item added to inventory."
  # }
  # @return [JSON] a JSON object indicating the success of the addition operation or any error details
  # @example POST /api/v1/items
  #   curl -X POST "https://example.com/api/v1/items" -d '{"item_id": 1}'
  def create
    item = Item.find(params[:item_id])
    @current_user.items << item
    render json: { message: "#{item.name} added to inventory." }
  end

  # PATCH /api/v1/items/:id/use
  # Use an item from the current user's inventory, applying its effects and removing it from the inventory.
  # Example return value:
  # {
  #   "message": "Item used successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the use operation or any error details
  # @example PATCH /api/v1/items/1/use
  #   curl -X PATCH "https://example.com/api/v1/items/1/use" -d '{"item_id": 1}'
  def use
    user_item = @current_user.user_items.find_by(item_id: params[:id])
    if user_item
      item_service = ItemService.new(@current_user, user_item.item)
      item_service.use
      user_item.destroy
      # Broadcast only the changed item as a delta
      UserUpdatesChannel.broadcast_to(@current_user, { type: 'user_item_delta', data: { changes: [ { item_id: user_item.item_id, quality: user_item.quality, quantity: 0 } ] } })
      render json: { message: "#{user_item.item.name} used." }
    else
      render json: { error: "Item not found in inventory." }, status: :not_found
    end
  end
end
