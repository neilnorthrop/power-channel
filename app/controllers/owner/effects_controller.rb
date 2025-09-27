# frozen_string_literal: true

module Owner
  class EffectsController < BaseController
    def index
      @q = params[:q].to_s.strip
      scope = Effect.order(:name)
      if @q.present?
        scope = scope.where("name ILIKE :q OR target_attribute ILIKE :q", q: "%#{@q}%")
      end
      @effects = scope
    end

    def duplicate
      src = Effect.find(params[:id])
      @effect = Effect.new(
        name: src.name,
        description: src.description,
        target_attribute: src.target_attribute,
        modifier_type: src.modifier_type,
        modifier_value: src.modifier_value,
        duration: src.duration,
        effectable_type: src.effectable_type
      )
      # Pre-fill effectable name for the form
      @prefill_effectable_name = src.effectable_type == "Item" ? Item.find_by(id: src.effectable_id)&.name : Action.find_by(id: src.effectable_id)&.name
      render :new
    end

    def new
      @effect = Effect.new
    end

    def create
      @effect = Effect.new(effect_params)
      if @effect.save
        OwnerAuditLog.create!(actor: current_actor, action: "effects.create", metadata: { id: @effect.id })
        redirect_to owner_effects_path, notice: "Effect created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @effect = Effect.find(params[:id])
    end

    def update
      @effect = Effect.find(params[:id])
      if @effect.update(effect_params)
        OwnerAuditLog.create!(actor: current_actor, action: "effects.update", metadata: { id: @effect.id })
        redirect_to owner_effects_path, notice: "Effect updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      eff = Effect.find(params[:id])
      eff.destroy!
      OwnerAuditLog.create!(actor: current_actor, action: "effects.destroy", metadata: { id: eff.id })
      redirect_to owner_effects_path, notice: "Effect deleted."
    end

    def validate_all
      name = params.dig(:effect, :effectable_name).to_s
      type = params.dig(:effect, :effectable_type).to_s
      @effect = params[:id] ? Effect.find(params[:id]) : Effect.new
      errors = []
      begin
        model = type == "Item" ? Item : Action
        model.find_by!(name: name)
      rescue StandardError => e
        errors << "Unknown #{type} '#{name}' (#{e.message})"
      end
      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      if params[:id]
        render :edit, status: :ok
      else
        render :new, status: :ok
      end
    end

    private

    def effect_params
      attrs = params.require(:effect).permit(:name, :description, :target_attribute, :modifier_type, :modifier_value, :duration, :effectable_type, :effectable_name)
      if attrs[:effectable_name].present?
        model = attrs[:effectable_type] == "Item" ? Item : Action
        target = model.find_by!(name: attrs.delete(:effectable_name))
        attrs[:effectable_id] = target.id
      end
      attrs
    end
  end
end
