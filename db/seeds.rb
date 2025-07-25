# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Create Resources
gold = Resource.create(name: 'Gold', description: 'The currency of the realm.', base_amount: 10)
wood = Resource.create(name: 'Wood', description: 'A common building material.', base_amount: 5)
stone = Resource.create(name: 'Stone', description: 'A sturdy building material.', base_amount: 5)

# Create Actions
Action.create(name: 'Mine Gold', description: 'Mine for gold.', cooldown: 60, resource: gold)
Action.create(name: 'Chop Wood', description: 'Chop down trees for wood.', cooldown: 30, resource: wood)
Action.create(name: 'Quarry Stone', description: 'Quarry for stone.', cooldown: 45, resource: stone)

# Create Skills
Skill.create(name: 'Golden Touch', description: 'Increase gold gained from all actions by 10%.', cost: 1, effect: 'increase_gold_gain')
Skill.create(name: 'Lumberjack', description: 'Decrease wood action cooldown by 10%.', cost: 1, effect: 'decrease_wood_cooldown')
Skill.create(name: 'Stone Mason', description: 'Increase stone gained from all actions by 10%.', cost: 1, effect: 'increase_stone_gain')

# Create Items
potion_of_luck = Item.create(name: 'Minor Potion of Luck', description: 'Slightly increases the chance of finding rare resources.', effect: 'increase_luck')
scroll_of_haste = Item.create(name: 'Scroll of Haste', description: 'Instantly completes the cooldown of a single action.', effect: 'reset_cooldown')

# Create Recipes
recipe1 = Recipe.create(item: potion_of_luck, quantity: 1)
RecipeResource.create(recipe: recipe1, resource: gold, quantity: 10)
RecipeResource.create(recipe: recipe1, resource: wood, quantity: 5)

recipe2 = Recipe.create(item: scroll_of_haste, quantity: 1)
RecipeResource.create(recipe: recipe2, resource: stone, quantity: 10)
RecipeResource.create(recipe: recipe2, resource: wood, quantity: 10)

# Create Buildings
Building.create(name: 'Lumber Mill', description: 'Increases wood production by 10% per level.', level: 1, effect: 'increase_wood_production')
Building.create(name: 'Mine', description: 'Increases gold production by 10% per level.', level: 1, effect: 'increase_gold_production')
Building.create(name: 'Quarry', description: 'Increases stone production by 10% per level.', level: 1, effect: 'increase_stone_production')
