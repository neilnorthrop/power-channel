# frozen_string_literal: true

class AdvancedCraftingService < CraftingService
  # Experimental crafting logic scaffold: run base craft, then log a quality roll.
  # Current behavior does not change inventory results to avoid instability while iterating.
  def craft_item(recipe_id)
    result = super
    return result unless result[:success]

    # Simple prototype roll (no side effects yet)
    # In the future, outcomes can upgrade quality or add byproducts.
    tiers = {
      "legendary" => 0.01,
      "epic"      => 0.04,
      "rare"      => 0.15
    }
    rolled = "normal"
    r = rand
    acc = 0.0
    tiers.each do |tier, p|
      acc += p
      if r < acc
        rolled = tier
        break
      end
    end
    Event.create!(user: @user, level: "debug", message: "AdvancedCrafting roll=#{rolled}")
    result
  end
end
