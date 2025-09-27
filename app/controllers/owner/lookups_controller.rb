# frozen_string_literal: true

module Owner
  class LookupsController < BaseController
    def suggest
      type = params[:type].to_s
      q = params[:q].to_s.strip
      limit = [ [ params[:limit].to_i, 1 ].max, 50 ].min
      limit = 10 if params[:limit].blank?

      results = case type
      when "Resource"
                  Resource.where("name ILIKE ?", "%#{q}%").order(:name).limit(limit).pluck(:name)
      when "Item"
                  Item.where("name ILIKE ?", "%#{q}%").order(:name).limit(limit).pluck(:name)
      when "Skill"
                  Skill.where("name ILIKE ?", "%#{q}%").order(:name).limit(limit).pluck(:name)
      when "Building"
                  Building.where("name ILIKE ?", "%#{q}%").order(:name).limit(limit).pluck(:name)
      when "Flag"
                  Flag.where("slug ILIKE ?", "%#{q}%").order(:slug).limit(limit).pluck(:slug)
      when "Action"
                  Action.where("name ILIKE ?", "%#{q}%").order(:name).limit(limit).pluck(:name)
      when "Recipe"
                  Item.joins(:recipe).where("items.name ILIKE ?", "%#{q}%").order("items.name").limit(limit).pluck("items.name")
      else
                  []
      end

      render json: { type: type, q: q, results: results }
    end

    def exists
      type = params[:type].to_s
      name = params[:name].to_s.strip
      exists = case type
      when "Resource"
                 Resource.where("LOWER(name) = ?", name.downcase).exists?
      when "Item"
                 Item.where("LOWER(name) = ?", name.downcase).exists?
      when "Skill"
                 Skill.where("LOWER(name) = ?", name.downcase).exists?
      when "Building"
                 Building.where("LOWER(name) = ?", name.downcase).exists?
      when "Flag"
                 Flag.where("LOWER(slug) = ?", name.downcase).exists?
      when "Action"
                 Action.where("LOWER(name) = ?", name.downcase).exists?
      when "Recipe"
                 Item.joins(:recipe).where("LOWER(items.name) = ?", name.downcase).exists?
      else
                 false
      end
      render json: { type: type, name: name, exists: exists }
    end
  end
end
