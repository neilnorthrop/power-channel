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

  private

  def self.col
    Effect.arel_table[:target_attribute]
  end

end
