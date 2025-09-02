require "test_helper"

class RecipeResourceTest < ActiveSupport::TestCase
  test "polymorphic component supports Resource and Item" do
    hatchet_recipe = recipes(:hatchet_recipe)
    comps = hatchet_recipe.recipe_resources
    assert_equal 2, comps.size
    types = comps.map(&:component_type).sort
    assert_equal ["Item", "Resource"], types
  end
end
