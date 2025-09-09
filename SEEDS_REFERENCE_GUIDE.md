# Seeds Reference Guide

This guide consolidates the seeding comments that previously lived in `db/seeds.rb`. It explains how reference data is managed, how to add/modify/delete content safely, the backfill workflow, and examples for gating content with polymorphic feature flags.

## Overview
- Idempotent and non-destructive: seeds converge safely on repeated runs.
- Never modifies user-owned data (tables prefixed with `user_`), aside from reference joins like `RecipeResource`.
- Updates existing definitions and adds new ones without one-off scripts.

## Quick Start
1) Define content under `db/data/*.yml` (Actions, Resources with `action_name`, Skills, Items, Buildings, Recipes, Flags).
2) Plan first (optional): `bin/rails seeds:plan` shows effective packs, sources, and counts.
3) Apply definitions: `bin/rails db:seed`.
4) Backfill existing users (idempotent):
   - `bin/rails users:ensure_actions`
   - `bin/rails users:ensure_resources`
   - Optional (env-gated):
     - `ITEMS_CREATE_ZERO=1 bin/rails users:ensure_items`
     - `AUTO_GRANT=1         bin/rails users:ensure_skills`
     - `AUTO_GRANT=1 LEVEL=1 bin/rails users:ensure_buildings`
5) One-liners (seed + ensure):
   - `bin/rails app:seed_and_ensure_actions`
   - `bin/rails app:seed_and_ensure_resources`
   - `bin/rails app:seed_and_ensure_all` (obeys env flags for items/skills/buildings)
5) Single user and status helpers:
   - `bin/rails users:ensure_actions_one[USER_ID]`
   - `bin/rails users:ensure_resources_one[USER_ID]`
   - `bin/rails users:status`

## Reference Data Guide (Modify / Add / Delete / Rename)
Scope: Actions, Resources, Skills, Items, Buildings, Recipes, and Flags are reference data. Seeds do not touch user-owned rows.

Principles
- Idempotent and non-destructive.
- Enforce uniqueness (usually on `name`) via DB indexes + model validations.

Modify attributes
- Edit YAML under `db/data/` and run `bin/rails db:migrate db:seed`.
- When adding columns, ship a migration (with default/backfill if needed), then include the attribute in YAML so it stays updated.

Rename a record
- Prefer a data migration to rename in place, then update YAML.
- If renames are common, add a stable `slug` (unique) to upsert by that key so `name` can change freely (e.g., `Flag.slug`).

Add a record
- Append to the relevant YAML file (include required attributes). Ensure related records exist (e.g., a Resource’s `action_name`).

Delete / deprecate
- Prefer deprecation (e.g., `deprecated: true`) over deletion; users may own it.
- If removal is required, write a migration/maintenance task to handle dependencies.

Relationships
- Associations are resolved by names in YAML (e.g., `Resource.action` via `action_name`).
- For recipes, define `components` with `type` (`Resource` or `Item`), `name`, and `quantity`.

Uniqueness & integrity
- Add unique indexes on natural keys, e.g.:
  - `add_index :actions,   :name, unique: true`
  - `add_index :resources, :name, unique: true`
  - `add_index :skills,    :name, unique: true`
  - `add_index :items,     :name, unique: true`
  - `add_index :buildings, :name, unique: true`
- For joins (e.g., `RecipeResource`), consider composite unique indexes (e.g., `recipe_id, component_type, component_id`).

Test, rollout, performance
- Test locally (`db:migrate db:seed`); consider CI seeding/linting (`bin/rails seeds:lint`).
- Feature-flag UI that uses new definitions; validate in staging before prod.
- For large datasets, prefer `upsert_all` and preloaded lookups; YAML-based loader already batches per-record safely.

## Upsert Patterns
The loader performs idempotent find-or-initialize + assign + save per record, keyed by a natural unique attribute (usually `name`) or `slug` (for Flags). Relationships are resolved by names after upsert.

For large datasets, switch to bulk `upsert_all` with unique indexes and prebuilt lookup hashes to avoid N+1 patterns.

## Seeding + Backfill Workflow With Rake Tasks
Typical workflow when adding content
1) Edit YAML in `db/data/` to add/modify definitions.
2) Run seeds to upsert definitions: `bin/rails db:seed`.
3) Backfill associations for existing users, as needed:
   - Actions: `bin/rails users:ensure_actions`
   - Resources: `bin/rails users:ensure_resources`
   - Items (optional; zero-quantity rows): `ITEMS_CREATE_ZERO=1 bin/rails users:ensure_items`
   - Skills (optional; unlock all): `AUTO_GRANT=1 bin/rails users:ensure_skills`
   - Buildings (optional; grant-all at level N): `AUTO_GRANT=1 LEVEL=1 bin/rails users:ensure_buildings`

Composite seed + ensure
- `bin/rails app:seed_and_ensure_actions`
- `bin/rails app:seed_and_ensure_resources`
- `ITEMS_CREATE_ZERO=1 bin/rails app:seed_and_ensure_items`
- `AUTO_GRANT=1 bin/rails app:seed_and_ensure_skills`
- `AUTO_GRANT=1 LEVEL=1 bin/rails app:seed_and_ensure_buildings`
- Or run them all: `bin/rails app:seed_and_ensure_all`

Behavior notes
- Ensure tasks are idempotent and skip users without defaults; they only create missing rows.
- Items/Skills/Buildings tasks are opt-in via env flags; Actions/Resources default to on because they’re commonly universal.
- Tasks use batched inserts where appropriate for efficiency.

## Polymorphic Feature Flags — Concepts & Examples
The app supports data-driven feature flags that “gate” content (actions, items, skills, buildings, recipes). The polymorphic schema keeps gating relationships in one place.

Core tables/models
- `Flag(name, slug, description)`
- `UserFlag(user, flag)` — flags earned by a user
- `FlagRequirement(flag_id, requirement_type, requirement_id, quantity, logic)`
- `Unlockable(flag_id, unlockable_type, unlockable_id)`

OR / AND semantics
- `FlagRequirement.logic` ∈ { 'AND', 'OR' } with default 'AND'.
- A flag is satisfied if every AND requirement is satisfied and each OR-bucket has at least one satisfied requirement. Future extension: `group_key` for grouped OR.

Example 1 — Simple OR requirements
Unlock when the user has ItemA OR ItemB OR ItemC.

```ruby
can_gather = Flag.find_or_create_by!(slug: 'can_gather') { |f| f.name = 'Can Gather' }
item_a = Item.find_by!(name: 'ItemA')
item_b = Item.find_by!(name: 'ItemB')
item_c = Item.find_by!(name: 'ItemC')
FlagRequirement.find_or_create_by!(flag: can_gather, requirement_type: 'Item', requirement_id: item_a.id) { |r| r.quantity = 1; r.logic = 'OR' }
FlagRequirement.find_or_create_by!(flag: can_gather, requirement_type: 'Item', requirement_id: item_b.id) { |r| r.quantity = 1; r.logic = 'OR' }
FlagRequirement.find_or_create_by!(flag: can_gather, requirement_type: 'Item', requirement_id: item_c.id) { |r| r.quantity = 1; r.logic = 'OR' }
```

Example 2 — One Flag gates Action + Recipe together
Requirements: Resource 'Wood' (≥ 25). Unlocks Action 'Chop Wood (Advanced)' and Recipe 'Wood Plank'.

```ruby
woodworker = Flag.find_or_create_by!(slug: 'woodworker_intro') { |f| f.name = 'Woodworker Intro' }
wood_res   = Resource.find_by!(name: 'Wood')
chop_adv   = Action.find_by!(name: 'Chop Wood (Advanced)')
plank_item = Item.find_by!(name: 'Wood Plank')
plank      = Recipe.find_by!(item: plank_item)

FlagRequirement.find_or_create_by!(flag: woodworker, requirement_type: 'Resource', requirement_id: wood_res.id) { |r| r.quantity = 25 }
Unlockable.find_or_create_by!(flag: woodworker, unlockable: chop_adv)
Unlockable.find_or_create_by!(flag: woodworker, unlockable: plank)
```

Example 3 — Shared prerequisite unlocking two different Flags
Crafting Item 'Hatchet' should allow both: can_chop → Action 'Chop Wood'; gatherer_path → Recipe 'Bundle of Sticks'.

```ruby
hatchet  = Item.find_by!(name: 'Hatchet')
can_chop = Flag.find_or_create_by!(slug: 'can_chop') { |f| f.name = 'Can Chop' }
gatherer = Flag.find_or_create_by!(slug: 'gatherer_path') { |f| f.name = 'Gatherer Path' }

FlagRequirement.find_or_create_by!(flag: can_chop,  requirement_type: 'Item', requirement_id: hatchet.id) { |r| r.quantity = 1 }
FlagRequirement.find_or_create_by!(flag: gatherer, requirement_type: 'Item', requirement_id: hatchet.id) { |r| r.quantity = 1 }
Unlockable.find_or_create_by!(flag: can_chop,  unlockable: Action.find_by!(name: 'Chop Wood'))
Unlockable.find_or_create_by!(flag: gatherer, unlockable: Recipe.find_by!(item: Item.find_by!(name: 'Bundle of Sticks')))
```

Example 4 — Tiered flags (Action + Item per tier)
Tier 1 and Tier 2 flags craft a key item and unlock higher-tier action. T2 also requires Flag T1 and a higher Building level.

```ruby
t1 = Flag.find_or_create_by!(slug: 'dungeon_tier_1') { |f| f.name = 'Dungeon Tier 1' }
t2 = Flag.find_or_create_by!(slug: 'dungeon_tier_2') { |f| f.name = 'Dungeon Tier 2' }
camp  = Building.find_by!(name: 'Scout Camp')
delve1 = Action.find_by!(name: 'Delve T1')
delve2 = Action.find_by!(name: 'Delve T2')
key1 = Item.find_by!(name: 'Tier 1 Key')
key2 = Item.find_by!(name: 'Tier 2 Key')

FlagRequirement.find_or_create_by!(flag: t1, requirement_type: 'Building', requirement_id: camp.id) { |r| r.quantity = 1 }
Unlockable.find_or_create_by!(flag: t1, unlockable: delve1)
Unlockable.find_or_create_by!(flag: t1, unlockable: key1)

FlagRequirement.find_or_create_by!(flag: t2, requirement_type: 'Flag',     requirement_id: t1.id)   { |r| r.quantity = 1 }
FlagRequirement.find_or_create_by!(flag: t2, requirement_type: 'Building', requirement_id: camp.id) { |r| r.quantity = 2 }
Unlockable.find_or_create_by!(flag: t2, unlockable: delve2)
Unlockable.find_or_create_by!(flag: t2, unlockable: key2)
```

Example 5 — Skill-based gate with resource threshold
Flag requires Skill 'Lumberjack' and Resource 'Wood' ≥ 100; unlocks Action and Recipe.

```ruby
lumberjack = Skill.find_by!(name: 'Lumberjack')
mastery    = Flag.find_or_create_by!(slug: 'wood_mastery') { |f| f.name = 'Wood Mastery' }
wood       = Resource.find_by!(name: 'Wood')
adv_action = Action.find_by!(name: 'Master Chop')
recipe     = Recipe.find_by!(item: Item.find_by!(name: 'Sturdy Shaft'))

FlagRequirement.find_or_create_by!(flag: mastery, requirement_type: 'Skill',    requirement_id: lumberjack.id) { |r| r.quantity = 1 }
FlagRequirement.find_or_create_by!(flag: mastery, requirement_type: 'Resource', requirement_id: wood.id)       { |r| r.quantity = 100 }
Unlockable.find_or_create_by!(flag: mastery, unlockable: adv_action)
Unlockable.find_or_create_by!(flag: mastery, unlockable: recipe)
```

After adding any of the above and seeding
- `bin/rails db:seed`
- `bin/rails users:ensure_flags`
Users who already satisfy requirements will be granted the appropriate flags. New users will acquire flags as they craft/build/collect according to service hooks.

## Troubleshooting & Tips
- Lint YAML: `bin/rails seeds:lint` to catch shape errors early.
- Dry-run: `bin/rails seeds:dry_run` to validate references without writing.
- Pruning: Use `PRUNE=1` with `db:seed` to remove recipe components not in YAML.
- Indexes: Review and add covering indexes to keep seeding and queries fast.

## Content Packs (Starter Packs)

Content packs are themed bundles of Actions, Resources, Items, Recipes, Buildings, Skills, and Flags that ship as drop‑in YAML and form a coherent gameplay loop. They help you add significant content quickly and safely.

- Structure: place packs under `db/data/packs/<pack_name>/`. Each pack can provide any of the standard YAML files:
  - `actions.yml`, `resources.yml`, `items.yml`, `recipes.yml`, `buildings.yml`, `skills.yml`, `flags.yml`
- Merge model: core data in `db/data/*.yml` remains the base; packs are merged on top. Later packs (in order) win when the same natural key is present (e.g., same Item name).
- Optional loader behavior: support `PACKS` env to load specific packs, e.g. `PACKS=woodworking,alchemy bin/rails db:seed`. Not required to use packs; if `PACKS` is unset all packs can be ignored.
- Isolation: packs should avoid renaming core records; if they depend on core, reference by `name` (or `slug` for Flags). Keep pack content idempotent and additive where possible.

Starter pack ideas
- Woodworking: Fell Trees → Timber → Planks/Handles → Tools (Hatchet/Bow/Arrows), Carpenter’s Workshop, flags for advanced felling/bowyer.
- Mining & Smelting: Ore veins → Ore → Bars → Tools (Pickaxe/Anvil), Smelter/Forge buildings, deeper strata flags.
- Alchemy: Herbs → Reagents → Potions (Luck/Haste/Health), Mortar & Pestle building, brewing skill.
- Agriculture: Seeds → Crops → Food/Ingredients, Farm/Granary buildings.
- Masonry: Stone → Bricks → Structures, Quarry upgrades, construction flags.

Example: woodworking pack (YAML)

db/data/packs/woodworking/actions.yml
---
- name: Fell Trees
  description: Chop mature trees for timber.
  cooldown: 60
- name: Saw Planks
  description: Process timber into planks.
  cooldown: 90

db/data/packs/woodworking/resources.yml
---
- name: Timber
  base_amount: 1
  drop_chance: 0.9
  action_name: Fell Trees
- name: Bark
  base_amount: 1
  drop_chance: 0.4
  action_name: Fell Trees

db/data/packs/woodworking/items.yml
---
- name: Wood Plank
  description: A processed timber plank.
- name: Wooden Handle
  description: A carved wooden handle.
- name: Longbow
  description: A bow made of flexible wood.
- name: Arrows
  description: Bundle of arrows.

db/data/packs/woodworking/recipes.yml
---
- item: Wood Plank
  quantity: 1
  components:
    - { type: Resource, name: Timber, quantity: 2 }
- item: Wooden Handle
  quantity: 1
  components:
    - { type: Item, name: Wood Plank, quantity: 1 }
    - { type: Resource, name: Bark, quantity: 2 }
- item: Longbow
  quantity: 1
  components:
    - { type: Item, name: Wood Plank, quantity: 4 }
    - { type: Item, name: Wooden Handle, quantity: 1 }
    - { type: Item, name: Twine, quantity: 3 }
- item: Arrows
  quantity: 10
  components:
    - { type: Item, name: Wood Plank, quantity: 1 }
    - { type: Resource, name: Stone, quantity: 1 }

db/data/packs/woodworking/buildings.yml
---
- name: Carpenter’s Workshop
  description: Improves plank yield and unlocks advanced woodworking.
  level: 1

db/data/packs/woodworking/flags.yml
---
- slug: woodworking_intro
  name: Woodworking Intro
  requirements:
    - { type: Resource, name: Wood, quantity: 25 }
  unlockables:
    - { type: Action, name: Saw Planks }
    - { type: Recipe, name: Wood Plank }
- slug: bowyer_path
  name: Bowyer Path
  requirements:
    - { type: Item, name: Twine, quantity: 2 }
    - { type: Item, name: Wood Plank, quantity: 4 }
  unlockables:
    - { type: Recipe, name: Longbow }
    - { type: Recipe, name: Arrows }

Implementation notes
- Loader supports `PACKS` and `EXCLUDE`.
  - `PACKS=woodworking,alchemy` merges those packs over core. `PACKS=all` merges all packs found.
  - `EXCLUDE=pack1,pack2` removes those from the selected set. `EXCLUDE=all` disables all packs even if `PACKS` is set.

## Dismantle Rules (Items)

Dismantle rules define how 1 item can be broken down into outputs. Rules are item-only for now and live in `db/data/dismantle.yml`.

- Structure per entry:
  - `subject_type`: `Item`
  - `subject_name`: item name
  - `yields`: list of components with `type` (`Resource` or `Item`), `name`, `quantity`, optional `salvage_rate` (0.0–1.0), optional `quality` (for item outputs)
- Deterministic yields: each output amount is `floor(quantity * salvage_rate)`; 0 is skipped.
- Loader: entries are upserted into `DismantleRule` and `DismantleYield`.
- Service: `DismantleService` consumes one inventory unit and grants outputs transactionally.

Example
```
- subject_type: Item
  subject_name: Hatchet
  yields:
    - { type: Item, name: Twine, quantity: 1, salvage_rate: 0.8 }
    - { type: Resource, name: Stone, quantity: 5, salvage_rate: 0.6 }
```
- Ordering for Actions
- `actions.order` controls display order. You can set it explicitly in YAML.
- If omitted, the loader auto-assigns an order:
  - Core actions get the next available value in the `[0, 10_000)` range.
  - Pack actions get the next available value in their pack’s reserved block of 10,000 (ordered by `PACKS` env).
  - Values are spaced by 10 to leave room for manual inserts later.
- UI sorts by `order` then `name`, so clicking buttons won’t make the list jump.
