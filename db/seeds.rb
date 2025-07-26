# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Create Resources
gold = Resource.find_or_create_by(name: 'Gold') { |r| r.description = 'The currency of the realm.'; r.base_amount = 10 }
wood = Resource.find_or_create_by(name: 'Wood') { |r| r.description = 'A common building material.'; r.base_amount = 5 }
stone = Resource.find_or_create_by(name: 'Stone') { |r| r.description = 'A sturdy building material.'; r.base_amount = 5 }

# Create Actions
Action.find_or_create_by(name: 'Mine Gold') { |a| a.description = 'Mine for gold.'; a.cooldown = 60; a.resource = gold }
Action.find_or_create_by(name: 'Chop Wood') { |a| a.description = 'Chop down trees for wood.'; a.cooldown = 30; a.resource = wood }
Action.find_or_create_by(name: 'Quarry Stone') { |a| a.description = 'Quarry for stone.'; a.cooldown = 45; a.resource = stone }

# Create Skills
Skill.find_or_create_by(name: 'Golden Touch') { |s| s.description = 'Increase gold gained from all actions by 10%.'; s.cost = 1; s.effect = 'increase_gold_gain' }
Skill.find_or_create_by(name: 'Lumberjack') { |s| s.description = 'Decrease wood action cooldown by 10%.'; s.cost = 1; s.effect = 'decrease_wood_cooldown' }
Skill.find_or_create_by(name: 'Stone Mason') { |s| s.description = 'Increase stone gained from all actions by 10%.'; s.cost = 1; s.effect = 'increase_stone_gain' }

# Create Items
potion_of_luck = Item.find_or_create_by(name: 'Minor Potion of Luck') { |i| i.description = 'Slightly increases the chance of finding rare resources.'; i.effect = 'increase_luck' }
scroll_of_haste = Item.find_or_create_by(name: 'Scroll of Haste') { |i| i.description = 'Instantly completes the cooldown of a single action.'; i.effect = 'reset_cooldown' }

# Create Recipes
recipe1 = Recipe.find_or_create_by(item: potion_of_luck) { |r| r.quantity = 1 }
RecipeResource.find_or_create_by(recipe: recipe1, resource: gold) { |rr| rr.quantity = 10 }
RecipeResource.find_or_create_by(recipe: recipe1, resource: wood) { |rr| rr.quantity = 5 }

recipe2 = Recipe.find_or_create_by(item: scroll_of_haste) { |r| r.quantity = 1 }
RecipeResource.find_or_create_by(recipe: recipe2, resource: stone) { |rr| rr.quantity = 10 }
RecipeResource.find_or_create_by(recipe: recipe2, resource: wood) { |rr| rr.quantity = 10 }

# Create Buildings
Building.find_or_create_by(name: 'Lumber Mill') { |b| b.description = 'Increases wood production by 10% per level.'; b.level = 1; b.effect = 'increase_wood_production' }
Building.find_or_create_by(name: 'Mine') { |b| b.description = 'Increases gold production by 10% per level.'; b.level = 1; b.effect = 'increase_gold_production' }
Building.find_or_create_by(name: 'Quarry') { |b| b.description = 'Increases stone production by 10% per level.'; b.level = 1; b.effect = 'increase_stone_production' }
