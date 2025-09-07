# AetherForge Discussion History

This file groups our ongoing discussions by topic (feature, test, tool, process, architecture, etc.) and records a chronological history for each. Newest entries appear last under each topic.

Note: If you want a different structure (strict chronology, or per-sprint sections), say the word and I’ll reorganize.

## Frontend Asset Pipeline & Importmap
- Review: Identified fragility from hashed pins in `config/importmap.rb` and presence of compiled files under `public/assets`. Recommended logical pins and removing tracked assets.
- Change: Switched to logical pins and then mapped bare specifiers to concrete assets (`turbo.min.js`, `stimulus.min.js`, `stimulus-loading.js`, `actioncable.esm.js`). File: `config/importmap.rb`.
- Change: Simplified `dev:rebuild_assets` to stop patching compiled outputs and syncing importmaps. File: `lib/tasks/assets.rake`.
- Note: Recommended keeping compiled assets out of Git and relying on importmap + Propshaft resolution.

## Game UI JavaScript Refactor
- Review: Inline JS in `app/views/game/index.html.erb` mixed with ActionCable CDN and importmap caused ordering issues.
- Change: Moved page logic to `app/javascript/game/index.js` and imported via `app/javascript/application.js` along with Turbo and Stimulus controllers.
- Change: Exposed JWT to JS via `<meta name="jwt-token">` in layout. File: `app/views/layouts/application.html.erb`.
- Change: Removed ActionCable CDN dependency; now using `@rails/actioncable` via importmap.

## Tailwind & CSS
- Review: Tailwind CDN used while `application.css` contained unprocessed `@tailwind` directives.
- Change: Removed Tailwind directives from CSS (CDN only for now). File: `app/assets/stylesheets/application.css`.
- Note: Offered two strategies: CDN-only or proper Tailwind build (CLI or tailwindcss-rails).

## Security & Auth (JWT, CSP)
- Review: JWT embedded in HTML for API and ActionCable; CSP not configured.
- Guidance: Keep short JWT expirations, consider refresh strategy, and add CSP with nonces/whitelisted CDNs if keeping inline content or external scripts.

## BuildingService & Tests
- Issue: Failures due to `nil` level and resource deduction logic not handling duplicates or absences.
- Change: Default building level to 1 on create; safe upgrade when `level` is nil; compute cost from current level; resource sufficiency checks now sum across duplicates and ignore truly missing types for non-destructive flows; consolidate duplicates on deduction. File: `app/services/building_service.rb`.
- Issue: Controller/building service tests failing due to defaults interfering.
- Change: Disabled `UserInitializationService` auto-run in test env to prevent unintended records. File: `app/models/user.rb`.

## Test Environment Warnings
- Issue: RDoc duplicate version warnings during tests.
- Change: Suppressed constant redefinition warnings in test by setting `$VERBOSE = nil` early in `config/boot.rb`. Also recommended cleaning global gems or pinning rdoc in Gemfile for a clean fix.

## Seeds Strategy & Best Practices
- Issue: Original seeds were destructive and mixed data migrations with content seeding.
- Change: Rewrote `db/seeds.rb` to upsert reference data idempotently (actions, resources with action_name, skills, items, buildings, recipes). Helpers update existing records and create missing ones; do not touch user-owned tables.
- Documentation: Added extensive roadmap notes and a "How to change reference models safely" guide at the end of seeds.

## Rake Tasks: User Initialization
- Added tasks to initialize defaults:
  - `users:init_one[ID,FORCE]` — initialize a single user (guarded; `FORCE=1` to override).
  - `users:init_all` — initialize all users (skips users that already have defaults).
- Generator utilities:
  - `users:generate[N,X]` — create N users where X are initialized and the rest uninitialized (disabled in production).
  - `users:status` — neat table showing each user’s initialization status and totals.

## Rake Tasks: Ensure Associations (Backfill for New Content)
- `users:ensure_actions_one[ID]` and `users:ensure_actions` — backfill missing `user_actions` (guards: skip users without defaults).
- `users:ensure_resources_one[ID]` and `users:ensure_resources` — backfill missing `user_resources` with `amount = base_amount` (same guards).
- Optional backfills (opt-in via ENV):
  - `users:ensure_items` — create zero-quantity `user_items` when `ITEMS_CREATE_ZERO=1`.
  - `users:ensure_skills` — unlock all skills for all users when `AUTO_GRANT=1`.
  - `users:ensure_buildings` — grant all buildings at `LEVEL` (default 1) when `AUTO_GRANT=1`.

## Composite Tasks & Organization
- Added composite tasks under `app:` namespace to chain seeding with ensure steps:
  - `app:seed_and_ensure_actions`, `…_resources`, `…_items`, `…_skills`, `…_buildings`, and `app:seed_and_ensure_all`.
- Note: Commented guidance to consider moving composite tasks to a broader file/namespace (e.g., `data:seed_and_backfill`) and keep `users:` file focused on user-specific tasks.

## Seeds Roadmap & Governance Docs
- Added detailed comments in `db/seeds.rb` covering: externalized data (YAML/JSON), uniqueness + bulk upserts, dry-run & summaries, env overlays, versioning, declarative relationships, CI hooks, performance, multi-tenant, rollback/audit, I18n, security, and authoring practices.

## Feature Flags (Gating) Spike
- Brainstorm: Proposed a data-driven flags system to gate actions and other content behind prerequisites (crafted items, built buildings, resources, etc.).
- Scope: New tables (`flags`, `user_flags`, `flag_requirements`) and either per-model `flag_id` or a polymorphic `unlockables` join.
- Flow: Award flags on craft/build/other events; enforce gates before using a gated unlockable; include unlock status + requirements in API.
- Backfill: Add `users:ensure_flags` and composite `app:seed_and_ensure_flags`; run flags ensure before `users:ensure_actions`.
- Reference doc: Added `feature_flag_spike` in the repo root with details, examples, and next steps.
 - Update: Implemented OR semantics via `FlagRequirement.logic` ('AND'/'OR').
 - Note: Future extension could add a `group_key` to support grouped OR logic
   like (A or B) AND (C or D). Semantics: all ANDs must pass; each group_key
   represents an OR-bucket where at least one requirement in that group must pass.

## Experimental Crafting Preview (Attempt 1)
- Decision: Gate an experimental crafting mode behind a per-user flag `users.experimental_crafting`.
- Change: Added `AdvancedCraftingService < CraftingService` as a placeholder to enable a gradual refactor while reusing base behavior. File: `app/services/advanced_crafting_service.rb`.
- Change: Switched controller to pick the service class by flag. File: `app/controllers/api/v1/crafting_controller.rb:37`.
- Change: Introduced item quality to inventory to support future advanced outcomes. Files: `db/migrate/20250906153642_add_quality_to_user_items.rb`, `app/models/user_item.rb`, `app/serializers/user_item_serializer.rb`.
- Change: Updated base `CraftingService` to scope consumption/production to a default quality (`DEFAULT_QUALITY = 'normal'`) so both classic and advanced modes share the same storage. File: `app/services/crafting_service.rb`.
- Migrations: Added `experimental_crafting` to users. File: `db/migrate/20250906153638_add_experimental_crafting_to_users.rb`.
- Behavior notes: Craft performs atomic decrements and increments within a transaction, evaluates unlock flags in-transaction, then broadcasts consolidated updates to `UserUpdatesChannel`. File: `app/services/crafting_service.rb`.
- Environment: Database migrations/tests not executed in this environment (no local Postgres). Validate locally with `bin/rails db:migrate` and `bin/rails test`.

## Seeding Content Packs
- Idea: Introduce themed “starter packs” as drop‑in YAML bundles under `db/data/packs/<pack>` to accelerate world‑building.
- Loader behavior: Keep core YAML in `db/data/*.yml`, optionally merge packs listed in `PACKS` env (e.g., `PACKS=woodworking,alchemy bin/rails db:seed`). Later packs win on key collisions.
- Conventions: Packs avoid renaming core; reference by names (or flag slugs); keep changes additive and idempotent.
- Example pack: “woodworking” with Fell Trees/Saw Planks actions, Timber/Bark resources, Wood Plank/Handle/Bow/Arrows items and recipes, Carpenter’s Workshop building, and flags `woodworking_intro` and `bowyer_path`.

## Dismantling (Items Only, v1)
- Decision: Introduce a simple dismantle system starting with items only.
- Data model: `DismantleRule(subject_type='Item', subject_id)` and `DismantleYield(component_type, component_id, quantity, salvage_rate, quality)`.
- Seeds: YAML file `db/data/dismantle.yml` to define per-item salvage outputs; deterministic yields via `floor(quantity * salvage_rate)`.
- Service: `DismantleService#dismantle_item(item_id, quality)` decrements one item and grants outputs transactionally; broadcasts deltas and logs an event.
- API: `POST /api/v1/dismantle` with `item_id` and optional `quality`.
