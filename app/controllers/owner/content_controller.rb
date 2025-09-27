# frozen_string_literal: true

module Owner
  class ContentController < BaseController
    before_action :resolve_resource!

    def index
      @q = params[:q].to_s.strip
      scope = @model.all
      if @q.present?
        like = "%#{@q}%"
        cols = Array(@config[:search] || [ :name ])
        where_sql = cols.map { |c| "CAST(#{c} AS TEXT) ILIKE :q" }.join(" OR ")
        scope = scope.where(where_sql, q: like)
      end
      # Sorting
      @sort = params[:sort].to_s
      @dir  = params[:dir].to_s.downcase == "desc" ? "desc" : "asc"
      scope = apply_sort(scope, @key, @sort, @dir)

      @page = [ params[:page].to_i, 1 ].max
      @per = [ [ params[:per].to_i, 1 ].max, 50 ].min
      @per = 20 if params[:per].blank?
      @total = scope.count
      @records = scope.offset((@page - 1) * @per).limit(@per)
    end

    def new
      @record = @model.new
      # Prefill common attributes from query
      if @record.respond_to?(:name) && params[:name].present?
        @record.name = params[:name]
      end
    end

    def create
      @record = @model.new(permitted_params)
      if @record.save
        OwnerAuditLog.create!(actor: current_actor, action: "content.create", metadata: { model: @model.name, id: @record.id })
        redirect_to owner_content_index_path(resource: @key), notice: "Created #{@model.name}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @record = @model.find(params[:id])
    end

    def update
      @record = @model.find(params[:id])
      if @record.update(permitted_params)
        OwnerAuditLog.create!(actor: current_actor, action: "content.update", metadata: { model: @model.name, id: @record.id })
        redirect_to owner_content_index_path(resource: @key), notice: "Updated #{@model.name}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      rec = @model.find(params[:id])
      rec.destroy!
      OwnerAuditLog.create!(actor: current_actor, action: "content.destroy", metadata: { model: @model.name, id: rec.id })
      redirect_to owner_content_index_path(resource: @key), notice: "Deleted #{@model.name}."
    end

    def export
      YamlExporter.export!(@key)
      OwnerAuditLog.create!(actor: current_actor, action: "content.export_yaml", metadata: { resource: @key })
      redirect_to owner_content_index_path(resource: @key), notice: "Exported #{@key} to YAML."
    end

    def export_validate
      basename, rows = YamlExporter.preview!(@key)
      render json: { file: basename, rows: rows }, status: :ok
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def resolve_resource!
      @key = params[:resource].to_s
      @config = supported_resources[@key]
      raise ActionController::RoutingError, "Unsupported resource" unless @config
      @model = @config[:model]
    end

    def supported_resources
      @supported_resources ||= {
        "actions" => {
          model: Action,
          search: %i[name description],
          order: :order,
          permitted: %i[name description cooldown order]
        },
        "resources" => {
          model: Resource,
          search: %i[name description],
          order: :name,
          permitted: %i[name description base_amount action_id min_amount max_amount drop_chance currency]
        },
        "skills" => {
          model: Skill,
          search: %i[name description effect],
          order: :name,
          permitted: %i[name description cost effect multiplier]
        },
        "items" => {
          model: Item,
          search: %i[name description effect],
          order: :name,
          permitted: %i[name description effect drop_chance]
        },
        "buildings" => {
          model: Building,
          search: %i[name description effect],
          order: :name,
          permitted: %i[name description level effect]
        },
        # View-only placeholders (export only via Export button)
        "recipes" => { model: Recipe, search: [], order: :id, permitted: [] },
        "flags" => { model: Flag, search: %i[name slug], order: :slug, permitted: [] },
        "effects" => { model: Effect, search: %i[name description], order: :name, permitted: [] },
        "dismantle" => { model: DismantleRule, search: %i[notes], order: :id, permitted: [] },
        "action_item_drops" => { model: ActionItemDrop, search: [], order: :id, permitted: [] }
      }
    end

    def permitted_params
      params.require(@model.model_name.param_key).permit(*Array(@config[:permitted]))
    end

    # Applies sorting to an ActiveRecord scope based on the provided key, sort column, and direction.
    #
    # @param scope [ActiveRecord::Relation] The initial scope to apply sorting to.
    # @param key [String] The resource type or context (e.g., "actions", "resources", "items", etc.).
    # @param sort [String] The column or attribute to sort by, specific to the resource type.
    # @param dir [String] The direction of sorting ("asc" or "desc").
    # @return [ActiveRecord::Relation] The scope with the applied sorting.
    #
    # The method determines the appropriate column and sorting logic based on the key and sort parameters.
    # It safely quotes table and column names to prevent SQL injection, and handles special cases where
    # sorting requires joining related tables (e.g., sorting resources by action name).
    #
    # If the key or sort parameter is not recognized, it falls back to a default ordering.
    def apply_sort(scope, key, sort, dir)
      up = dir.upcase
      # Helper: quote table + column for ORDER BY
      qcol = ->(model_class, col) do
        %(#{model_class.quoted_table_name}.#{ActiveRecord::Base.connection.quote_column_name(col)} #{up})
      end
      case key
      when "actions"
        col = %w[name cooldown order id].include?(sort) ? sort : "order"
        if col == "order"
          scope.order(Action.arel_table[:order].public_send(dir))
        else
          scope.order(Arel.sql(qcol.call(Action, col)))
        end
      when "resources"
        if sort == "action_name"
          scope.left_outer_joins(:action).order(Arel.sql("actions.name #{up} NULLS LAST"))
        elsif %w[name min_amount max_amount drop_chance currency id].include?(sort)
          scope.order(Arel.sql(qcol.call(Resource, sort)))
        else
          scope.order(:name)
        end
      when "items"
        col = %w[name effect drop_chance id].include?(sort) ? sort : "name"
        scope.order(Arel.sql(qcol.call(Item, col)))
      when "skills"
        col = %w[name effect cost multiplier id].include?(sort) ? sort : "name"
        scope.order(Arel.sql(qcol.call(Skill, col)))
      when "buildings"
        col = %w[name level effect id].include?(sort) ? sort : "name"
        scope.order(Arel.sql(qcol.call(Building, col)))
      when "recipes"
        if sort == "item_name"
          scope.joins(:item).order(Arel.sql("items.name #{up}"))
        elsif %w[quantity id].include?(sort)
          scope.order(Arel.sql(qcol.call(Recipe, sort)))
        else
          scope.joins(:item).order("items.name ASC")
        end
      when "flags"
        col = %w[slug name id].include?(sort) ? sort : "slug"
        scope.order(Arel.sql(qcol.call(Flag, col)))
      when "effects"
        col = %w[name target_attribute modifier_type modifier_value duration id].include?(sort) ? sort : "name"
        scope.order(Arel.sql(qcol.call(Effect, col)))
      when "dismantle"
        if sort == "subject_name"
          scope.joins("LEFT JOIN items ON items.id = dismantle_rules.subject_id").order(Arel.sql("items.name #{up}"))
        else
          scope.order(Arel.sql(qcol.call(DismantleRule, "id")))
        end
      when "action_item_drops"
        if sort == "action_name"
          scope.joins(:action).order(Arel.sql("actions.name #{up}"))
        elsif sort == "item_name"
          scope.joins(:item).order(Arel.sql("items.name #{up}"))
        elsif %w[min_amount max_amount drop_chance id].include?(sort)
          scope.order(Arel.sql(qcol.call(ActionItemDrop, sort)))
        else
          scope.joins(:action).order("actions.name ASC")
        end
      else
        scope.order(@config[:order] || :id)
      end
    end
  end
end
