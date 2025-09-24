class ActiveEffect < ApplicationRecord
  belongs_to :user
  belongs_to :effect

  scope :active, -> { where("expires_at > ?", Time.current) }

  scope :for_user, ->(user) { where(user: user) }

  scope :luck, -> { joins(:effect).where(effects: { modifier_type: "luck" }) }

  scope :sum_modifier_value, -> { sum("COALESCE(effects.modifier_value, 0)").to_f }

  scope :effects_target_attribute_is, ->(targets, include_quantity: false) {
    attr = Effect.arel_table[:target_attribute]
    list = Array(targets).dup
    list << "quantity" if include_quantity
    ors = [ attr.eq(nil) ]
    ors << attr.in(list) if list.present?
    where(ors.reduce { |a, b| a.or(b) })
  }

  def self.active_for_user_luck_and_target(user, targets = [], include_quantity: false)
    targets = Array(targets)
    active
      .for_user(user)
      .luck
      .effects_target_attribute_is(targets, include_quantity: include_quantity)
      .sum_modifier_value
  end

  def self.luck_total_for_chance(user, targets = [])
    active_for_user_luck_and_target(user, targets)
  end

  def self.luck_total_for_quantity(user, targets = [])
    active_for_user_luck_and_target(user, targets, include_quantity: true)
  end

  # Sum luck modifiers for a user scoped to a single target key.
  # Keeps the predicate identical to existing logic:
  # - active (expires_at > now)
  # - joins(:effect)
  # - effects.modifier_type = 'luck'
  # - effects.target_attribute IS NULL OR = scope_key
  # Returns a Float.
  def self.luck_sum_for(user, scope_key)
    active
      .for_user(user)
      .luck
      .effects_target_attribute_is([ scope_key ])
      .sum_modifier_value
  end

  private

  def self.col
    Effect.arel_table[:target_attribute]
  end

end
