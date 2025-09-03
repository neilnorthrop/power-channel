class RequirementNameLookup
  # Build a nested map of names by requirement type and id
  # { 'Item' => {1=> 'Twine'}, 'Building' => {...}, 'Resource' => {...}, 'Flag' => {...}, 'Skill' => {...} }
  def self.for_flag_ids(flag_ids)
    return {} if flag_ids.blank?
    reqs = FlagRequirement.where(flag_id: flag_ids)
    new(reqs).to_map
  end

  def initialize(requirements)
    @by_type = requirements.group_by(&:requirement_type)
    @names = {}
    preload('Item')     { |ids| Item.where(id: ids).pluck(:id, :name).to_h }
    preload('Building') { |ids| Building.where(id: ids).pluck(:id, :name).to_h }
    preload('Resource') { |ids| Resource.where(id: ids).pluck(:id, :name).to_h }
    preload('Flag')     { |ids| Flag.where(id: ids).pluck(:id, :name).to_h }
    preload('Skill')    { |ids| Skill.where(id: ids).pluck(:id, :name).to_h }
  end

  def preload(type)
    ids = (@by_type[type] || []).map(&:requirement_id).uniq
    return if ids.empty?
    @names[type] = yield(ids)
  end

  def to_map
    @names
  end
end

