# frozen_string_literal: true

class DbValidator
  def self.run
    report = {}
    report[:actions] = validate_actions
    report[:resources] = validate_resources
    report[:skills] = validate_skills
    report[:items] = validate_items
    report[:buildings] = validate_buildings
    report[:effects] = validate_effects
    report[:recipes] = validate_recipes
    report[:flags] = validate_flags
    report[:dismantle] = validate_dismantle
    report[:action_item_drops] = validate_action_item_drops
    report
  end

  def self.validate_actions
    issues = []
    seen = {}
    Action.find_each do |a|
      issues << "Action id=#{a.id} missing name" if a.name.blank?
      if a.name.present?
        key = a.name.downcase
        seen[key] ||= 0
        seen[key] += 1
        issues << "Duplicate action name '#{a.name}'" if seen[key] > 1
      end
    end
    issues
  end

  def self.validate_resources
    issues = []
    Resource.find_each do |r|
      issues << "Resource id=#{r.id} missing name" if r.name.blank?
      if r.action_id.present? && !Action.where(id: r.action_id).exists?
        issues << "Resource '#{r.name}' references missing action_id=#{r.action_id}"
      end
      if r.respond_to?(:drop_chance) && !r.drop_chance.nil?
        issues << "Resource '#{r.name}' drop_chance must be 0..1" unless r.drop_chance >= 0.0 && r.drop_chance <= 1.0
      end
      if r.respond_to?(:min_amount) && r.respond_to?(:max_amount) && r.min_amount && r.max_amount
        issues << "Resource '#{r.name}' min_amount>max_amount" if r.min_amount > r.max_amount
      end
    end
    issues
  end

  def self.validate_skills
    issues = []
    Skill.find_each do |s|
      issues << "Skill id=#{s.id} missing name" if s.name.blank?
      if s.respond_to?(:effect) && s.effect.present?
        unless s.class.const_defined?(:EFFECT_FORMAT) && s.effect =~ s.class::EFFECT_FORMAT
          issues << "Skill '#{s.name}' effect has invalid format"
        end
      end
    end
    issues
  end

  def self.validate_items
    issues = []
    Item.find_each do |i|
      issues << "Item id=#{i.id} missing name" if i.name.blank?
    end
    issues
  end

  def self.validate_buildings
    []
  end

  def self.validate_effects
    issues = []
    Effect.find_each do |e|
      if e.effectable_type == "Item"
        issues << "Effect '#{e.name}' missing Item id=#{e.effectable_id}" unless Item.where(id: e.effectable_id).exists?
      elsif e.effectable_type == "Action"
        issues << "Effect '#{e.name}' missing Action id=#{e.effectable_id}" unless Action.where(id: e.effectable_id).exists?
      else
        issues << "Effect '#{e.name}' invalid effectable_type '#{e.effectable_type}'"
      end
    end
    issues
  end

  def self.validate_recipes
    issues = []
    Recipe.includes(:item, :recipe_resources).find_each do |r|
      issues << "Recipe id=#{r.id} missing item" if r.item.nil?
      r.recipe_resources.each do |rr|
        case rr.component_type
        when "Resource"
          issues << "Recipe for '#{r.item&.name}': missing Resource id=#{rr.component_id}" unless Resource.where(id: rr.component_id).exists?
        when "Item"
          issues << "Recipe for '#{r.item&.name}': missing Item id=#{rr.component_id}" unless Item.where(id: rr.component_id).exists?
        else
          issues << "Recipe for '#{r.item&.name}': invalid component_type '#{rr.component_type}'"
        end
      end
    end
    issues
  end

  def self.validate_flags
    issues = []
    Flag.includes(:user_flags).find_each do |f|
      issues << "Flag '#{f.slug}' missing name" if f.name.blank?
      FlagRequirement.where(flag_id: f.id).find_each do |fr|
        case fr.requirement_type
        when "Flag"
          issues << "Flag '#{f.slug}': missing requirement Flag id=#{fr.requirement_id}" unless Flag.where(id: fr.requirement_id).exists?
        when "Resource"
          issues << "Flag '#{f.slug}': missing requirement Resource id=#{fr.requirement_id}" unless Resource.where(id: fr.requirement_id).exists?
        when "Item"
          issues << "Flag '#{f.slug}': missing requirement Item id=#{fr.requirement_id}" unless Item.where(id: fr.requirement_id).exists?
        when "Skill"
          issues << "Flag '#{f.slug}': missing requirement Skill id=#{fr.requirement_id}" unless Skill.where(id: fr.requirement_id).exists?
        when "Building"
          issues << "Flag '#{f.slug}': missing requirement Building id=#{fr.requirement_id}" unless Building.where(id: fr.requirement_id).exists?
        else
          issues << "Flag '#{f.slug}': invalid requirement type '#{fr.requirement_type}'"
        end
      end
      Unlockable.where(flag_id: f.id).find_each do |u|
        case u.unlockable_type
        when "Action"
          issues << "Flag '#{f.slug}': missing unlockable Action id=#{u.unlockable_id}" unless Action.where(id: u.unlockable_id).exists?
        when "Recipe"
          issues << "Flag '#{f.slug}': missing unlockable Recipe id=#{u.unlockable_id}" unless Recipe.where(id: u.unlockable_id).exists?
        when "Item"
          issues << "Flag '#{f.slug}': missing unlockable Item id=#{u.unlockable_id}" unless Item.where(id: u.unlockable_id).exists?
        when "Building"
          issues << "Flag '#{f.slug}': missing unlockable Building id=#{u.unlockable_id}" unless Building.where(id: u.unlockable_id).exists?
        else
          issues << "Flag '#{f.slug}': invalid unlockable type '#{u.unlockable_type}'"
        end
      end
    end
    issues
  end

  def self.validate_dismantle
    issues = []
    DismantleRule.where(subject_type: "Item").includes(:dismantle_yields).find_each do |dr|
      item = Item.find_by(id: dr.subject_id)
      issues << "DismantleRule id=#{dr.id} missing Item subject id=#{dr.subject_id}" if item.nil?
      dr.dismantle_yields.each do |dy|
        if dy.component_type == "Resource"
          issues << "Dismantle '#{item&.name}': missing Resource id=#{dy.component_id}" unless Resource.where(id: dy.component_id).exists?
        elsif dy.component_type == "Item"
          issues << "Dismantle '#{item&.name}': missing Item id=#{dy.component_id}" unless Item.where(id: dy.component_id).exists?
        else
          issues << "Dismantle '#{item&.name}': invalid component_type '#{dy.component_type}'"
        end
      end
    end
    issues
  end

  def self.validate_action_item_drops
    issues = []
    ActionItemDrop.includes(:action, :item).find_each do |d|
      issues << "Drop: missing Action id=#{d.action_id}" unless d.action
      issues << "Drop: missing Item id=#{d.item_id}" unless d.item
      if d.drop_chance && (d.drop_chance < 0.0 || d.drop_chance > 1.0)
        issues << "Drop for action '#{d.action&.name}': drop_chance out of range"
      end
      if d.min_amount && d.max_amount && d.min_amount > d.max_amount
        issues << "Drop for action '#{d.action&.name}': min_amount>max_amount"
      end
    end
    issues
  end
end
