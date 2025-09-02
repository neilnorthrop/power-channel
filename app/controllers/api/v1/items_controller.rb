# frozen_string_literal: true

class Api::V1::ItemsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    user_items = @current_user.user_items.includes(:item)
    options = { include: [:item], params: { current_user: @current_user } }
    render json: UserItemSerializer.new(user_items, options).serializable_hash.to_json
  end

  def create
    item = Item.find(params[:item_id])
    @current_user.items << item
    render json: { message: "#{item.name} added to inventory." }
  end

  def use
    user_item = @current_user.user_items.find_by(item_id: params[:id])
    if user_item
      item_service = ItemService.new(@current_user, user_item.item)
      item_service.use
      user_item.destroy
      UserUpdatesChannel.broadcast_to(@current_user, { type: "user_item_update", data: UserItemSerializer.new(@current_user.user_items).serializable_hash })
      render json: { message: "#{user_item.item.name} used." }
    else
      render json: { error: "Item not found in inventory." }, status: :not_found
    end
  end
end
