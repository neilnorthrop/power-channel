# Changelog (by date)

All notable changes are organized by date (YYYY-MM-DD). Newest first.

## 2025-09-06

- Users
  - Added `experimental_crafting` flag to gate advanced crafting mode.
- Inventory
  - Added `quality` column on `user_items` with enum tiers.
- Crafting
  - Introduced `AdvancedCraftingService` and controller switch based on user flag.

## 2025-08-31

- Frontend and JS boot
  - Added `app/javascript/game/index.js` (ActionCable consumer and game UI logic).
  - Centralized importmap boot in `app/javascript/application.js` (Turbo, Stimulus controllers, game module).
  - Moved JWT exposure to a meta tag in layout; removed ActionCable CDN usage.

- Importmap and assets
  - Switched to date-stable logical pins and explicit asset targets for bare specifiers: `turbo.min.js`, `stimulus.min.js`, `stimulus-loading.js`, `actioncable.esm.js`.
  - Simplified `lib/tasks/assets.rake` (no patching compiled outputs).

- Seeds
  - Rewrote `db/seeds.rb` to be idempotent and non-destructive: upserts Actions, Resources (with action_name), Skills, Items, Buildings, and Recipes.
  - Added extensive guidance/comments: safe changes, externalization roadmap, validations, and migration notes.

- Rake tasks — user defaults and inspection
  - `users:init_one[ID,FORCE]`, `users:init_all` for initializing defaults.
  - `users:generate[N,X]` (disabled in production) to create test users with X initialized.
  - `users:status` table shows each user’s initialization status and totals.

- Rake tasks — backfilling associations for new content
  - Actions: `users:ensure_actions_one[ID]`, `users:ensure_actions` (skip users without defaults).
  - Resources: `users:ensure_resources_one[ID]`, `users:ensure_resources` (create missing user_resources with amount = base_amount).
  - Items (opt‑in): `users:ensure_items` when `ITEMS_CREATE_ZERO=1`.
  - Skills (opt‑in): `users:ensure_skills` when `AUTO_GRANT=1`.
  - Buildings (opt‑in): `users:ensure_buildings` when `AUTO_GRANT=1`, with optional `LEVEL`.

- Composite tasks
  - `app:seed_and_ensure_actions`, `app:seed_and_ensure_resources`, `app:seed_and_ensure_items`, `app:seed_and_ensure_skills`, `app:seed_and_ensure_buildings`, `app:seed_and_ensure_all`.

- Services and fixes
  - BuildingService: default level on create; safe upgrade from nil; cost computed from current level + 1; sufficiency/deduction sum across duplicates; consolidate duplicates.
  - User (test env): disabled automatic defaults initialization in tests to avoid unintended data.

- Test environment and tooling
  - Suppressed duplicate RDoc warnings during tests by setting `$VERBOSE = nil` in test within `config/boot.rb`.

- Styles/CSS
  - Removed unprocessed Tailwind directives from `app/assets/stylesheets/application.css` (using CDN approach for now).

- Documentation
  - Added `DISCUSSION_HISTORY.md` (grouped discussion log) to track decisions and changes.

## Future Roadmap

See ROADMAP.md for the full, up-to-date roadmap of features and performance improvements.
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Tests for JWT encode/decode, expired/tampered token handling.
- Integration tests for authenticated requests and 401 on expired/missing tokens.

### Changed
- Hardened JWT handling: constrain algorithm to HS256, verify expiration; return 401 `token_expired` for expired tokens.
- Documentation updates in README (Authentication & JWT, Frontend Assets), TROUBLESHOOTING (Authorization Errors), and ROADMAP (Recently Shipped).

---
