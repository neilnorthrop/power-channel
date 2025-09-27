# frozen_string_literal: true

module Owner
  class ActionItemDropsController < BaseController
    def index
      @actions = Action.order(:name)
      if params[:q].present?
        pick = Action.where("name ILIKE ?", "%#{params[:q]}%").order(:name).first
        params[:action_id] ||= pick&.id
      end
      @action = params[:action_id].present? ? Action.find(params[:action_id]) : @actions.first
      @drops = ActionItemDrop.includes(:item).where(action_id: @action.id).order("items.name")
      @items = Item.order(:name)
    end

    def update
      action = Action.find(params[:id])
      ActionItemDrop.where(action_id: action.id).delete_all
      Array(params[:drops]).each do |_, d|
        next if d[:item_id].blank?
        ActionItemDrop.create!(
          action_id: action.id,
          item_id: d[:item_id],
          min_amount: d[:min_amount].presence,
          max_amount: d[:max_amount].presence,
          drop_chance: d[:drop_chance].presence || 1.0
        )
      end
      OwnerAuditLog.create!(actor: current_actor, action: "action_item_drops.update", metadata: { action_id: action.id })
      redirect_to owner_action_item_drops_path(action_id: action.id), notice: "Item drops updated."
    end

    def validate
      @actions = Action.order(:name)
      @action = Action.find(params[:id])
      @items = Item.order(:name)
      errors = []
      Array(params[:drops]).each do |idx, d|
        label = "row #{idx}"
        if d[:item_id].blank? || Item.where(id: d[:item_id]).empty?
          errors << "#{label}: Unknown item"
        end
        if d[:drop_chance].present?
          begin
            chance = Float(d[:drop_chance])
            errors << "#{label}: drop_chance must be between 0.0 and 1.0" unless chance >= 0.0 && chance <= 1.0
          rescue ArgumentError
            errors << "#{label}: drop_chance must be a number"
          end
        end
        if d[:min_amount].present? && d[:max_amount].present?
          begin
            min = Integer(d[:min_amount])
            max = Integer(d[:max_amount])
            errors << "#{label}: min_amount cannot exceed max_amount" if min > max
          rescue ArgumentError
            errors << "#{label}: min/max must be integers"
          end
        end
      end
      @drops = ActionItemDrop.includes(:item).where(action_id: @action.id).order("items.name")
      @validation_errors = errors
      @validation_success_message = "All drops look good." if errors.empty?
      render :index, status: :ok
    end
  end
end
