# frozen_string_literal: true

module Owner
  class RecipesController < BaseController
    def index
      @q = params[:q].to_s.strip
      scope = Recipe.includes(:item).order("items.name")
      if @q.present?
        scope = scope.where(Item.arel_table[:name].matches("%#{@q}%"))
      end
      @recipes = scope
    end

    def new
      @recipe = Recipe.new(quantity: 1)
      load_selects
    end

    def create
      rp = params.require(:recipe).permit(:item_id, :quantity, recipe_resources_attributes: [ :component_type, :component_id, :quantity, :group_key, :logic ])
      @recipe = Recipe.find_or_initialize_by(item_id: rp[:item_id])
      @recipe.quantity = rp[:quantity]
      if @recipe.save
        if rp[:recipe_resources_attributes]
          @recipe.recipe_resources.destroy_all
          rp[:recipe_resources_attributes].each_value do |rr|
            next if rr[:component_type].blank? || rr[:component_id].blank?
            @recipe.recipe_resources.create!(rr.permit(:component_type, :component_id, :quantity, :group_key, :logic))
          end
        end
        OwnerAuditLog.create!(actor: current_actor, action: "recipes.create", metadata: { id: @recipe.id })
        redirect_to owner_recipes_path, notice: "Recipe created."
      else
        load_selects
        render :new, status: :unprocessable_entity
      end
    end

    def duplicate
      src = Recipe.find(params[:id])
      load_selects
      @recipe = Recipe.new(quantity: src.quantity)
      src.recipe_resources.each do |rr|
        @recipe.recipe_resources.build(
          component_type: rr.component_type,
          component_id: rr.component_id,
          quantity: rr.quantity,
          group_key: rr.group_key,
          logic: rr.logic
        )
      end
      render :new
    end

    def edit
      @recipe = Recipe.find(params[:id])
      load_selects
    end

    def update
      @recipe = Recipe.find(params[:id])
      if @recipe.update(recipe_params)
        OwnerAuditLog.create!(actor: current_actor, action: "recipes.update", metadata: { id: @recipe.id })
        redirect_to owner_recipes_path, notice: "Recipe updated."
      else
        load_selects
        render :edit, status: :unprocessable_entity
      end
    end

    def validate_all
      @recipe = Recipe.find(params[:id])
      load_selects
      errors = []
      Array(params.dig(:recipe, :recipe_resources_attributes)).each do |_, rr|
        next if rr[:component_type].blank? && rr[:component_id].blank?
        begin
          if rr[:component_type] == "Resource"
            Resource.find(rr[:component_id])
          else
            Item.find(rr[:component_id])
          end
        rescue StandardError => e
          errors << "Component #{rr[:component_type]} id=#{rr[:component_id]} invalid (#{e.message})"
        end
      end
      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      render :edit, status: :ok
    end

    # Collection validation for the New form (no id)
    def validate_new
      rp = params.fetch(:recipe, {}).permit(:item_id, :quantity, recipe_resources_attributes: [ :component_type, :component_id, :quantity, :group_key, :logic ])
      @recipe = Recipe.new(item_id: rp[:item_id], quantity: rp[:quantity])
      load_selects
      errors = []
      begin
        Item.find(rp[:item_id])
      rescue StandardError => e
        errors << "Unknown Item id=#{rp[:item_id]} (#{e.message})"
      end
      Array(rp[:recipe_resources_attributes]).each do |rr|
        next if rr.blank?
        type = rr[:component_type]
        id   = rr[:component_id]
        next if type.blank? || id.blank?
        begin
          type == "Resource" ? Resource.find(id) : Item.find(id)
        rescue StandardError => e
          errors << "Component #{type} id=#{id} invalid (#{e.message})"
        end
        @recipe.recipe_resources.build(rr) # keep entered rows
      end
      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      render :new, status: :ok
    end

    private

    def recipe_params
      params.require(:recipe).permit(:quantity, recipe_resources_attributes: [ :id, :component_type, :component_id, :quantity, :group_key, :logic, :_destroy ])
    end

    def load_selects
      @resources = Resource.order(:name)
      @items = Item.order(:name)
      @resource_options_json = @resources.map { |r| [r.id, r.name] }.to_json
      @item_options_json = @items.map { |i| [i.id, i.name] }.to_json
    end
  end
end
