# frozen_string_literal: true

module Owner
  class FlagsController < BaseController
    def index
      @q = params[:q].to_s.strip
      scope = Flag.order(:slug)
      if @q.present?
        scope = scope.where("slug ILIKE :q OR name ILIKE :q", q: "%#{@q}%")
      end
      @flags = scope
    end

    def new
      @flag = Flag.new(slug: params[:slug].to_s.strip, name: params[:name].to_s.strip)
    end

    def create
      @flag = Flag.new(flag_params)
      if @flag.save
        OwnerAuditLog.create!(actor: current_actor, action: "flags.create", metadata: { id: @flag.id, slug: @flag.slug })
        redirect_to owner_flags_path(q: @flag.slug), notice: "Flag created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @flag = Flag.find(params[:id])
      load_selects
      @requirements = FlagRequirement.where(flag_id: @flag.id)
      @unlockables = Unlockable.where(flag_id: @flag.id)
    end

    def update
      @flag = Flag.find(params[:id])

      ActiveRecord::Base.transaction do
        @flag.update!(flag_params)

        FlagRequirement.where(flag_id: @flag.id).delete_all
        Array(params[:requirements]).each do |_, r|
          next if r.blank? || r[:type].blank? || r[:name].blank?
          req_id = lookup_id(r[:type], r[:name])
          FlagRequirement.create!(flag_id: @flag.id, requirement_type: r[:type], requirement_id: req_id, quantity: r[:quantity].to_i.presence || 1, logic: (r[:logic].presence || "AND").upcase)
        end

        Unlockable.where(flag_id: @flag.id).delete_all
        Array(params[:unlockables]).each do |_, u|
          next if u.blank? || u[:type].blank? || u[:name].blank?
          target = lookup_unlockable(u[:type], u[:name])
          Unlockable.create!(flag_id: @flag.id, unlockable: target)
        end
      end

      OwnerAuditLog.create!(actor: current_actor, action: "flags.update", metadata: { id: @flag.id })
      redirect_to owner_flags_path, notice: "Flag updated."
    rescue StandardError => e
      Rails.logger.error("Failed to update flag: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}")
      load_selects
      @requirements = FlagRequirement.where(flag_id: @flag.id)
      @unlockables = Unlockable.where(flag_id: @flag.id)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    def validate_all
      @flag = Flag.find(params[:id])
      load_selects
      @requirements = []
      @unlockables = []
      errors = []

      Array(params[:requirements]).each do |_, r|
        next if r[:type].blank? && r[:name].blank?
        begin
          lookup_id(r[:type], r[:name])
        rescue StandardError => e
          errors << "Requirement #{r[:type]}:'#{r[:name]}' invalid (#{e.message})"
        end
      end

      Array(params[:unlockables]).each do |_, u|
        next if u[:type].blank? && u[:name].blank?
        begin
          lookup_unlockable(u[:type], u[:name])
        rescue StandardError => e
          errors << "Unlockable #{u[:type]}:'#{u[:name]}' invalid (#{e.message})"
        end
      end

      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      render :edit, status: :ok
    end

    def validate_new
      @flag = Flag.new(flag_params)
      load_selects
      errors = []
      Array(params[:requirements]).each do |_, r|
        next if r[:type].blank? && r[:name].blank?
        begin
          lookup_id(r[:type], r[:name])
        rescue StandardError => e
          errors << "Requirement #{r[:type]}:'#{r[:name]}' invalid (#{e.message})"
        end
      end
      Array(params[:unlockables]).each do |_, u|
        next if u[:type].blank? && u[:name].blank?
        begin
          lookup_unlockable(u[:type], u[:name])
        rescue StandardError => e
          errors << "Unlockable #{u[:type]}:'#{u[:name]}' invalid (#{e.message})"
        end
      end
      @validation_errors = errors
      @validation_success_message = "All references look good." if errors.empty?
      render :new, status: :ok
    end

    private

    def flag_params
      params.require(:flag).permit(:name, :slug, :description)
    end

    def load_selects
      @actions = Action.order(:name)
      @items = Item.order(:name)
      @buildings = Building.order(:name)
      @recipes = Recipe.joins(:item).order("items.name")
      @flags_all = Flag.order(:slug)
      @resources = Resource.order(:name)
      @skills = Skill.order(:name)
    end

    def lookup_id(type, name)
      case type
      when "Resource" then Resource.find_by!(name: name).id
      when "Item" then Item.find_by!(name: name).id
      when "Skill" then Skill.find_by!(name: name).id
      when "Building" then Building.find_by!(name: name).id
      when "Flag" then Flag.find_by!(slug: name).id
      else
        raise "Unsupported requirement type: #{type}"
      end
    end

    def lookup_unlockable(type, name)
      case type
      when "Action" then Action.find_by!(name: name)
      when "Recipe" then Recipe.joins(:item).find_by!(items: { name: name })
      when "Item" then Item.find_by!(name: name)
      when "Building" then Building.find_by!(name: name)
      else
        raise "Unsupported unlockable type: #{type}"
      end
    end
  end
end
