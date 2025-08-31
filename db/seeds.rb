# Idempotent, non-destructive seeding for reference data.
# - Does not destroy or modify user-owned data (User*, except reference joins like RecipeResource)
# - Updates existing definitions and adds new ones without bespoke code each time


# -----------------------------------------------------------------------------
# How To Change Reference Models Safely (Modify/Add/Delete, incl. renames)
# -----------------------------------------------------------------------------
# This app treats Actions, Resources, Skills, Items, Buildings, and Recipes as
# reference data. User-owned rows (UserResource, UserBuilding, etc.) are NOT
# mutated by seeds. Follow this checklist when changing reference data.
#
# 0) Principles
#    - Idempotent seeds: running db:seed many times should converge to the same
#      database state for reference rows.
#    - Non-destructive: do not alter or delete user-owned rows in seeds.
#    - Validations + unique indexes: enforce uniqueness (typically on `name`) at
#      the DB level to avoid duplicates (see “Uniqueness” below).
#
# 1) Modifying attributes (without renaming)
#    - Update the corresponding entry in the arrays above (e.g., `resources`,
#      `skills`, etc.). The upsert helper will update changed attributes.
#    - If you add new attributes/columns:
#      a) Create a Rails migration adding the column with a sensible default.
#      b) If existing rows need backfill, write a data migration (or include a
#         one-off backfill step) to set correct values for current production.
#      c) Add the attribute to the data arrays here so seeds maintain it going
#         forward.
#    - Run: bin/rails db:migrate && bin/rails db:seed
#
# 2) Renaming a record (changing `name`)
#    - If `name` is a natural key with a unique index, a rename should be
#      considered a “data migration” rather than a seed update, because other
#      rows may reference it by id and business logic/clients may refer to it by
#      name.
#    - Recommended process:
#      a) Add an explicit data migration to rename the row in place, e.g.:
#           old = Resource.find_by(name: "Gold")
#           old&.update!(name: "Gold Coins")
#      b) Update the seed arrays to use the new name so future seeds don’t
#         regress it.
#    - If frequent renames are expected, introduce a stable `slug` column with a
#      unique index. Use `slug` as the upsert key and treat `name` as
#      user-facing display. Seeds upsert by `slug`, and you may change `name`
#      freely.
#
# 3) Adding a new record
#    - Append a new hash to the relevant array; include all required attributes.
#    - Ensure any relationships exist (e.g., when a Resource has `action_name`,
#      that action is also present in `actions`).
#    - Run seeds; the row is created.
#
# 4) Deleting a definition (removing a record)
#    - Soft deprecation is safer than deletion because users might already own
#      the record (e.g., a building users constructed, or an item in recipes).
#    - Strategy options:
#      a) Deprecated flag: add a boolean `deprecated` column; hide it from UI and
#         exclude it from new content while keeping data intact.
#      b) Prune mode (advanced): implement an optional ENV-guarded “prune” path
#         that deletes rows no longer present in seed files. Only enable when
#         you are certain it’s safe and you’ve handled orphaning/cascades.
#    - If you must delete, write a migration or maintenance task that:
#      - Validates there are no dependent records (or handles them),
#      - Removes the reference row,
#      - Is reviewed carefully in code review.
#
# 5) Changing relationships
#    - This file resolves associations by names (e.g., Resource.action by
#      `action_name`). If you move a resource to a different action:
#      - Update the `action_name` in the resources array.
#      - Ensure the target action exists in the actions array.
#      - Run seeds to update the association.
#    - For recipes, use the ensure helpers to adjust quantities or switch
#      components.
#
# 6) Uniqueness and data integrity
#    - Add unique indexes on natural keys, e.g.:
#        add_index :actions,   :name, unique: true
#        add_index :resources, :name, unique: true
#        add_index :skills,    :name, unique: true
#        add_index :items,     :name, unique: true
#        add_index :buildings, :name, unique: true
#      For joins like RecipeResource, add composite unique indexes (recipe_id,
#      resource_id) to prevent duplicates.
#
# 7) Testing your changes
#    - Locally: bin/rails db:migrate db:seed
#    - In CI: consider seeding as part of test setup to catch validation errors.
#    - Consider a dry-run mode that prints a diff (see roadmap above) before
#      applying changes.
#
# 8) Rollouts and safety
#    - Wrap changes behind feature flags if the UI depends on new definitions.
#    - Consider progressive rollout: seed in staging, verify, then seed in prod.
#    - Keep seeds idempotent; avoid any writes to user tables here.
#
# 9) Performance
#    - When data grows large, use bulk upserts with unique_by indices.
#    - Preload name→id maps for referenced models to avoid N+1 lookups.
#
# 10) Documentation and ownership
#    - Document intent and business impact in PRs that modify these arrays.
#    - If content has a product owner, route reviews to them.
#
# With these practices, you can safely evolve reference data over time without
# disrupting user data, while maintaining a simple, auditable seeding story.
# -----------------------------------------------------------------------------

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
