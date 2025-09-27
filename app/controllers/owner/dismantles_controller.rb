# frozen_string_literal: true

module Owner
  class DismantlesController < BaseController
    def index
      @q = params[:q].to_s.strip
      scope = DismantleRule.where(subject_type: "Item").includes(:dismantle_yields)
      if @q.present?
        item_ids = Item.where("name ILIKE ?", "%#{@q}%").pluck(:id)
        scope = scope.where(subject_id: item_ids)
      end
      @rules = scope
    end

    def new
      @items = Item.order(:name)
      @selected_name = params[:item].to_s
    end

    def create
      item_name = params[:item].to_s
      item = Item.find_by(name: item_name)
      unless item
        redirect_to new_owner_dismantle_path(item: item_name), alert: "Item not found: #{item_name}" and return
      end
      rule = DismantleRule.find_or_create_by!(subject_type: "Item", subject_id: item.id)
      redirect_to edit_owner_dismantle_path(rule), notice: "Dismantle rule created."
    end

    def edit
      @rule = DismantleRule.find(params[:id])
      @items = Item.order(:name)
      @resources = Resource.order(:name)
    end

    def update
      @rule = DismantleRule.find(params[:id])
      @rule.update!(notes: params[:dismantle_rule][:notes]) if params[:dismantle_rule]

      DismantleYield.where(dismantle_rule_id: @rule.id).delete_all
      Array(params[:yields]).each do |_, y|
        next if y[:type].blank? || y[:name].blank?
        comp = y[:type]
        comp_id = comp == "Resource" ? Resource.find_by!(name: y[:name]).id : Item.find_by!(name: y[:name]).id
        DismantleYield.create!(
          dismantle_rule_id: @rule.id,
          component_type: comp,
          component_id: comp_id,
          quantity: y[:quantity].to_i.presence || 1,
          salvage_rate: y[:salvage_rate].presence&.to_f || 1.0,
          quality: y[:quality].presence
        )
      end
      OwnerAuditLog.create!(actor: current_actor, action: "dismantle.update", metadata: { id: @rule.id })
      redirect_to owner_dismantles_path, notice: "Dismantle rule updated."
    rescue StandardError => e
      @items = Item.order(:name)
      @resources = Resource.order(:name)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    def validate_all
      @rule = DismantleRule.find(params[:id])
      @items = Item.order(:name)
      @resources = Resource.order(:name)
      errors = []
      Array(params[:yields]).each do |_, y|
        next if y[:type].blank? && y[:name].blank?
        begin
          comp = y[:type]
          if comp == "Resource"
            Resource.find_by!(name: y[:name])
          else
            Item.find_by!(name: y[:name])
          end
        rescue StandardError => e
          errors << "Yield #{y[:type]}:'#{y[:name]}' invalid (#{e.message})"
        end
      end
      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      render :edit, status: :ok
    end
  end
end
