# Idempotent, non-destructive seeding for reference data.
# - Does not destroy or modify user-owned data (User*, except reference joins like RecipeResource)
# - Updates existing definitions and adds new ones without bespoke code each time
#
# Quick Start
# 1) Define content below (Actions, Resources with action_name, Skills, Items, Buildings, Recipes).
# 2) Apply definitions:
#      bin/rails db:seed
# 3) Backfill for existing users (idempotent):
#      bin/rails users:ensure_actions
#      bin/rails users:ensure_resources
#    Optional (env‑gated):
#      ITEMS_CREATE_ZERO=1 bin/rails users:ensure_items
#      AUTO_GRANT=1         bin/rails users:ensure_skills
#      AUTO_GRANT=1 LEVEL=1 bin/rails users:ensure_buildings
# 4) One‑liners that chain seed + ensure:
#      bin/rails app:seed_and_ensure_actions
#      bin/rails app:seed_and_ensure_resources
#      bin/rails app:seed_and_ensure_all  # obeys env flags for items/skills/buildings
# 5) Single user and status:
#      bin/rails users:ensure_actions_one[USER_ID]
#      bin/rails users:ensure_resources_one[USER_ID]
#      bin/rails users:status
# Notes: Safe to re‑run; seeds never alter user‑owned rows. For renames, prefer a
# data migration or introduce a stable `slug` and upsert by that key.
#
# -----------------------------------------------------------------------------
# Reference Data Guide (modify/add/delete, incl. renames)
# -----------------------------------------------------------------------------
# Scope: Actions, Resources, Skills, Items, Buildings, Recipes are reference
# data. Seeds do not touch user-owned rows (User* tables).
#
# Principles
# - Idempotent and non‑destructive: multiple runs converge without harming user data.
# - Enforce uniqueness (usually on `name`) with DB indexes + validations.
#
# Modify attributes
# - Edit the arrays below (e.g., `resources`, `skills`) and run:
#     bin/rails db:migrate db:seed
# - When adding columns, ship a migration (with default/backfill if needed), then
#   include the attribute in seeds so it stays updated.
#
# Rename a record
# - Prefer a data migration to rename in place, then update seeds.
# - If renames are common, add a stable `slug` (unique) and upsert by `slug` so
#   `name` can change freely.
#
# Add a record
# - Append to the relevant array (include required attributes). Ensure related
#   records exist (e.g., Resource `action_name`). Seed to create.
#
# Delete / deprecate
# - Prefer deprecation (e.g., `deprecated` boolean) over delete; users may own it.
# - If removal is required, write a migration/maintenance task that handles
#   dependencies and is reviewed carefully.
#
# Relationships
# - Associations are resolved by names here (e.g., Resource.action via `action_name`).
#   Update the name and rerun seeds to move relationships. For recipes, adjust
#   components/quantities via the helpers below.
#
# Uniqueness & integrity
# - Add unique indexes on natural keys; e.g.:
#     add_index :actions,   :name, unique: true
#     add_index :resources, :name, unique: true
#     add_index :skills,    :name, unique: true
#     add_index :items,     :name, unique: true
#     add_index :buildings, :name, unique: true
#   For joins (RecipeResource), add a composite unique index (recipe_id, resource_id).
#
# Test, rollout, performance
# - Test locally (db:migrate db:seed); consider CI seeding.
# - Feature‑flag UI that uses new definitions; validate in staging before prod.
# - For large datasets, consider bulk `upsert_all` with unique indexes and preloaded
#   lookups to avoid N+1.
# -----------------------------------------------------------------------------
#
# Upsert helper: upserts rows into model based on keys in `by`.
# - `by` can be a single symbol or an array of symbols for composite keys.
# - Updates existing records and creates new ones as needed.
# - Does not delete any records.
# - Raises on validation errors.
#
# Example:
#   upsert(Action, by: :name, rows: [{ name: "Chop Wood", description: "..." }])
#
#   upsert(Resource, by: [:name, :action_name], rows: [...])
#
# Note: for relationships, resolve by name after upsert (see Resources below).
# For large datasets, consider bulk upsert_all with unique indexes.
# For join tables, consider composite unique indexes to prevent dupes.
# Wrap in transactions if needed for atomicity.
# Handle validations and errors as appropriate for your app.
# This is a simple implementation; adapt as needed.
# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------
# Seeding + Backfill Workflow With Rake Tasks
# -----------------------------------------------------------------------------
# The seeds in this file define and upsert reference data (Actions, Resources,
# Skills, Items, Buildings, Recipes) without touching user-owned data. When new
# content is added, you have several rake tasks that can “backfill” missing
# associations for existing users in an idempotent way.
#
# Typical workflow when adding content
# 1) Edit db/seeds.rb (or external data later, if adopted) to add/modify
#    definitions (e.g., new Action/Resource/Skill/Item/Building/Recipe).
# 2) Run db:seed to upsert definitions:
#      bin/rails db:seed
# 3) Backfill associations for existing users, as needed:
#    - Actions (recommended when new global Action is added):
#        bin/rails users:ensure_actions
#    - Resources (recommended if users should always track all resources):
#        bin/rails users:ensure_resources
#    - Items (optional; creates zero-quantity rows to make inventories complete):
#        ITEMS_CREATE_ZERO=1 bin/rails users:ensure_items
#    - Skills (optional; unlock-all, generally not recommended):
#        AUTO_GRANT=1 bin/rails users:ensure_skills
#    - Buildings (optional; grant-all at level N):
#        AUTO_GRANT=1 LEVEL=1 bin/rails users:ensure_buildings
#
# Composite “seed + ensure” shortcuts (namespace: app)
# - Run seeds then ensure specific associations in one go:
#     bin/rails app:seed_and_ensure_actions
#     bin/rails app:seed_and_ensure_resources
#     ITEMS_CREATE_ZERO=1 bin/rails app:seed_and_ensure_items
#     AUTO_GRANT=1 bin/rails app:seed_and_ensure_skills
#     AUTO_GRANT=1 LEVEL=1 bin/rails app:seed_and_ensure_buildings
# - Or run them all in order (items/skills/buildings obey env flags and will
#   no‑op if flags are not set):
#     bin/rails app:seed_and_ensure_all
#
# One-off / targeted backfills
# - Single user variants:
#     bin/rails users:ensure_actions_one[USER_ID]
#     bin/rails users:ensure_resources_one[USER_ID]
# - Inspect current initialization:
#     bin/rails users:status
#
# Behavior notes
# - “Ensure” tasks are idempotent (safe to run repeatedly) and skip users whose
#   defaults are not initialized; they only create missing rows.
# - Items/Skills/Buildings tasks are opt-in (env flags) to avoid unintended
#   global grants; Actions/Resources default to on because they’re commonly
#   universal.
# - For large user bases, the tasks use batched insert_all under the hood for
#   efficiency.

def upsert(model, by:, rows:)
  Array(rows).each do |attrs|
    keys = Array(by)
    find_hash = keys.to_h { |k| [ k, attrs.fetch(k) ] }
    rec = model.find_or_initialize_by(find_hash)
    rec.assign_attributes(attrs.except(*keys))
    rec.save!
  end
end

# Actions
actions = [
  { name: "Taxes", description: "Gather taxes from your citizens.", cooldown: 60 },
  { name: "Gather", description: "Gather basic resources.", cooldown: 60 },
  { name: "Chop Wood", description: "Chop down trees for wood.", cooldown: 60 },
  { name: "Quarry Stone", description: "Quarry for stone.", cooldown: 60 }
]

upsert(Action, by: :name, rows: actions)

# Resources (action by name)
resources = [
  { name: "Gold Coins", description: "The currency of the realm.", base_amount: 10, drop_chance: 1.0, action_name: "Taxes" },
  { name: "Stick", description: "A basic crafting material.", base_amount: 5, drop_chance: 0.85, action_name: "Gather" },
  { name: "Stone", description: "A basic crafting material.", base_amount: 1, drop_chance: 0.75, action_name: "Gather" },
  { name: "Weeds", description: "A basic crafting material.", base_amount: 1, drop_chance: 0.5, action_name: "Gather" },
  { name: "Wood", description: "A common building material.", base_amount: 1, drop_chance: 1.0, action_name: "Chop Wood" },
  { name: "Stone", description: "A sturdy building material.", base_amount: 5, drop_chance: 1.0, action_name: "Quarry Stone" },
  { name: "Coal", description: "A fuel source for smelting and crafting.", base_amount: 2, drop_chance: 0.33, action_name: "Quarry Stone" }
]

resources.each do |attrs|
  action_name = attrs.delete(:action_name)
  rec = Resource.find_or_initialize_by(name: attrs[:name])
  rec.assign_attributes(attrs)
  rec.action = Action.find_by(name: action_name) if action_name
  rec.save!
end

# Skills
skills = [
  { name: "Golden Touch", description: "Increase gold gained from all actions by 10%.", cost: 1, effect: "increase_gold_gain", multiplier: 1.1 },
  { name: "Lumberjack", description: "Decrease wood action cooldown by 10%.", cost: 1, effect: "decrease_wood_cooldown", multiplier: 0.9 },
  { name: "Stone Mason", description: "Increase stone gained from all actions by 10%.", cost: 1, effect: "increase_stone_gain", multiplier: 1.1 }
]

upsert(Skill, by: :name, rows: skills)

# Items
items = [
  { name: "Minor Potion of Luck", description: "Slightly increases the chance of finding rare resources.", effect: "increase_luck", drop_chance: 0.001 },
  { name: "Scroll of Haste", description: "Instantly completes the cooldown of a single action.", effect: "reset_cooldown", drop_chance: 0.002 }
]

upsert(Item, by: :name, rows: items)

# Buildings (definitions)
buildings = [
  { name: "Lumber Mill", description: "Increases wood production by 10% per level.", level: 1, effect: "increase_wood_production" },
  { name: "Mine", description: "Increases gold production by 10% per level.", level: 1, effect: "increase_gold_production" },
  { name: "Quarry", description: "Increases stone production by 10% per level.", level: 1, effect: "increase_stone_production" }
]

upsert(Building, by: :name, rows: buildings)

# Recipes
def ensure_recipe(item_name:, quantity: 1)
  item = Item.find_by!(name: item_name)
  rec = Recipe.find_or_initialize_by(item: item)
  rec.quantity = quantity
  rec.save!
  rec
end

def ensure_recipe_resource(recipe:, resource_name:, quantity:)
  resource = Resource.find_by!(name: resource_name)
  rr = RecipeResource.find_or_initialize_by(recipe: recipe, resource: resource)
  rr.quantity = quantity
  rr.save!
end

rec1 = ensure_recipe(item_name: "Minor Potion of Luck", quantity: 1)
ensure_recipe_resource(recipe: rec1, resource_name: "Gold Coins", quantity: 10)
ensure_recipe_resource(recipe: rec1, resource_name: "Wood", quantity: 5)

rec2 = ensure_recipe(item_name: "Scroll of Haste", quantity: 1)
ensure_recipe_resource(recipe: rec2, resource_name: "Stone", quantity: 10)
ensure_recipe_resource(recipe: rec2, resource_name: "Wood", quantity: 10)

# Gentle, idempotent renames
if (gold = Resource.find_by(name: "Gold"))
  gold.update(name: "Gold Coins")
end
if (mine_gold = Action.find_by(name: "Mine Gold"))
  mine_gold.update(name: "Taxes", description: "Gather taxes from your citizens.")
  Resource.find_by(name: "Gold Coins")&.update(action: mine_gold)
end

puts "Seeded: #{Action.count} actions, #{Resource.count} resources, #{Skill.count} skills, #{Item.count} items, #{Building.count} buildings, #{Recipe.count} recipes."

# -----------------------------------------------------------------------------
# Seeding Roadmap & Options (ideas for later)
# -----------------------------------------------------------------------------
# This section outlines potential enhancements to evolve this file into a
# robust, auditable, and scalable content management pipeline for reference
# data. These are suggestions only — not enabled by default.
#
# 1) Externalize seed data (YAML/JSON/CSV)
#    - Store content under db/data/, e.g.:
#      db/data/actions.yml
#      db/data/resources.yml
#      db/data/skills.yml
#      db/data/items.yml
#      db/data/buildings.yml
#      db/data/recipes.yml
#    - Example (db/data/resources.yml):
#        - name: Gold Coins
#          description: The currency of the realm.
#          base_amount: 10
#          drop_chance: 1.0
#          action: Taxes
#        - name: Wood
#          description: A common building material.
#          base_amount: 5
#          drop_chance: 1.0
#          action: Chop Wood
#    - Loader pattern:
#        YAML.safe_load_file(path, aliases: true)
#        Validate keys; resolve references by name (e.g., action: "Taxes").
#    - Pros: non-code content updates; clearer reviews/diffs; easier content ops.
#    - Consider JSON Schema or dry-schema for validating shape before apply.
#    - Support ERB in YAML for small computed fields or environment-specific values.
#    - Allow per-environment overlays, e.g. db/data/production/*.yml overrides.
#
# 2) Strong uniqueness + bulk upserts
#    - Add unique indexes and model validations on natural keys (typically `name`).
#      Example migration:
#        add_index :resources, :name, unique: true
#        add_index :actions,   :name, unique: true
#    - Use ActiveRecord#upsert_all for bulk efficiency:
#        Model.upsert_all(rows, unique_by: :index_resources_on_name)
#      Note: requires unique index and careful column selection.
#    - For join tables (e.g., RecipeResource), consider composite unique indexes
#      (recipe_id, resource_id) to prevent dupes.
#
# 3) Safety and idempotency features
#    - Dry-run mode via ENV["SEEDS_DRY_RUN"], printing a diff of planned changes
#      without writing. Implement by comparing current attributes vs incoming rows.
#    - Change summary after run: created/updated/skipped counts per model.
#    - Guard against destructive operations by default; require ENV flags to
#      enable deletes of now-absent rows ("prune mode").
#    - Wrap in a transaction per model group for atomicity; optionally chunk for
#      very large datasets.
#
# 4) Environment-specific behavior
#    - Extensions for dev/test: generate demo users, fake inventories, etc.,
#      behind ENV flags. Keep production seeds strictly definition-only.
#    - Example flags: SEEDS_DEMO=1, SEEDS_VERBOSE=1.
#
# 5) Versioning and change detection
#    - Embed a version number or content hash in each data file (e.g. `_version`),
#      save last-applied version in a `seed_runs` table to track deployments.
#    - Compute a digest (e.g., SHA256) of the data payload; skip apply when
#      unchanged; record a SeedRun row: who, when, versions, summary.
#
# 6) Declarative relationships
#    - Keep references in data by natural keys (e.g., names), resolving to IDs
#      during load. Provide helpful errors if dependencies are missing.
#    - Optionally annotate rows with stable external IDs (slugs) for resilience
#      across renames (e.g., `slug: taxes`), and treat `name` as display-only.
#
# 7) Data migrations vs seeds
#    - Use Rails migrations for structural changes (columns/indexes) and one-off
#      data migrations that alter historical records.
#    - Reserve seeds for current, canonical reference definitions and recipes.
#    - For renames (like "Gold" -> "Gold Coins"), prefer explicit data migration
#      files over ad hoc seed code when it affects historical data.
#
# 8) CI integration
#    - Run `db:seed` as part of CI setup to catch validation issues early.
#    - Add a lint task (e.g., `seeds:lint`) to validate external data files and
#      reference integrity without touching the DB.
#
# 9) Performance tips
#    - Batch operations per model with `upsert_all` or import gems when volume
#      grows. Avoid N+1 by prefetching referenced records into hashes keyed by
#      natural keys.
#    - Temporarily disable callbacks on models that do heavy work when seeding.
#
# 10) Multi-tenant considerations
#    - If you add tenants, factor seeds per tenant (e.g., `tenant: default`) or
#      run seeds in the context of each tenant schema.
#
# 11) Rollback and auditability
#    - Snapshot pre-seed state for reference models (e.g., to JSON) when
#      SEEDS_BACKUP=1 is set, so you can inspect prior values.
#    - Maintain a `seed_runs` table logging runs, operator, env, versions, and
#      a JSON summary of changes.
#
# 12) Developer ergonomics
#    - Rake tasks to streamline workflows:
#        rails seeds:apply                    # load reference data
#        rails seeds:dry_run                  # compute and print diffs only
#        rails seeds:lint                     # validate external files
#        rails seeds:dump[model]              # dump current DB rows to YAML
#        rails seeds:prune                    # remove rows not in files (guarded)
#    - Add `bin/seeds` wrapper to pass flags conveniently.
#
# 13) Internationalization (I18n)
#    - Store translations for names/descriptions alongside base records or in
#      dedicated locale files. Optionally seed translation tables (e.g., Model::I18n).
#
# 14) Security & governance
#    - Keep seed files free of secrets. Optional signing of data bundles if you
#      plan to accept external contributions. Validate inputs carefully.
#
# These are ideas to consider incrementally. The current implementation remains
# code-first, idempotent, and user-safe. When ready, we can factor the loader
# and add one feature at a time without disrupting existing behavior.
