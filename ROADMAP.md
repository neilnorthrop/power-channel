# AetherForge Roadmap

This document collects future features and improvements. Grouped by area for easy planning.

## Gameplay & Systems
- Effects expansion: richer item/skill/building effects and effect classes; define stacking and expiration rules.
- Balancing: tune resource costs, multipliers, cooldown modifiers; add difficulty curves and progression pacing.
- Gating semantics: grouped OR requirements, e.g., (A|B) AND (C|D) via a `group_key` on requirements.

## Content & Authoring
- Externalize content (actions, resources, items, recipes, buildings, flags) to YAML/JSON with env overlays and versioning.
- Bulk upserts with validations and diffs; CI guardrails for content changes.
- Admin/editor UI for managing content with previews and publishing workflow.

## Seeding & Content Pipeline
- External files under `db/data/*.yml|json` with environment overlays; validate schema (JSON Schema/dry-schema); allow ERB for small computed/env values.
- Strong uniqueness + bulk upserts: unique indexes + model validations; use `upsert_all`; composite unique indexes for joins (e.g., RecipeResource).
- Safety and idempotency: dry-run mode with diffs; post-run change summary; guarded prune mode; per-model transactions/chunking for large datasets.
- Env-specific behavior: dev/test demo generators behind flags (SEEDS_DEMO, SEEDS_VERBOSE); production stays definition-only.
- Versioning & change detection: content versions/hashes; `seed_runs` table to store last-applied versions, operator, and summaries.
- Declarative relationships: reference by natural keys (names) and/or stable slugs; resolve to IDs with helpful errors.
- Data migrations vs. seeds: keep structural/historical changes in migrations; seeds define current canonical reference data.
- CI integration: run `db:seed` in CI; add `seeds:lint`, `seeds:dry_run`, `seeds:dump`, `seeds:prune` tasks; `bin/seeds` convenience wrapper.
- Performance tips: batch upserts; prefetch reference hashes to avoid N+1; optionally disable heavy callbacks during seeds.
- Multi-tenant: scope seeds per tenant or run within tenant schemas.
- Rollback & audit: optional pre-seed snapshots (SEEDS_BACKUP); maintain `seed_runs` audit log.
- Developer ergonomics: wrapper tasks and flags for common flows.
- Flag requirement logic groups: support `group_key` to model (A|B) AND (C|D) expressions in a declarative way.
- Content packs: support `db/data/packs/<pack>` folders and optional `PACKS=...` env var to merge themed bundles (woodworking, alchemy) over core content; add seeds:lint awareness for packs.

## Crafting & Inventory
- Concurrency safety: row locking on `user_resources`/`user_items` within the craft transaction; optimistic retry on conflicts.
- SQL-only decrements when consuming multiple components (single `UPDATE ... CASE`).
- DB check constraints to prevent negative `amount`/`quantity`.
- Delta broadcasts over ActionCable: send only changed user_items/resources, not full lists.

- Advanced crafting mode:
  - Gate switch: select `AdvancedCraftingService` when `users.experimental_crafting` is true (controller in place).
  - Quality rolls: introduce outcome tables/modifiers to produce varying quality tiers and/or quantities.
  - Failure/partial outcomes: configurable failure chance, component return rates, and byproduct outputs.
  - Skill/tool modifiers: integrate skill levels, tool durability/bonuses, buffs, and building bonuses into outcome math.
  - Data model: extend recipes to support multiple outcomes by quality; consider `recipe_outcomes` with chances and multipliers.
  - Indexing: add composite index on `user_items(user_id,item_id,quality)` and backfill existing rows to `quality = 'normal'`.
  - API/UI: expose item `quality` and experimental-outcome previews; badge experimental mode; add opt-in hints/tooltips.

## Gates & Flags
- Cache `Unlockable` maps per type (in-process or Rails.cache) with simple versioning.
- SQL gate filtering: LEFT JOIN `unlockables` + `user_flags` to filter visible records at the DB layer.
- Set-based flag evaluation: compute satisfaction via SQL aggregates instead of per-requirement Ruby checks.
- Dev assertions: ensure controllers pass `gates` and `requirement_names` to serializers (avoid fallback queries).

## API & Serialization
- Optional includes/fields to trim payloads by default; view-specific opt-ins.
- Conditional GETs (ETag/Last-Modified) on list endpoints to skip unchanged responses.
- Evaluate faster JSON generation (e.g., Oj) or lighter serializers for hot paths.

## Performance & Loading
- Async preloads (`load_async`) for independent reads on heavy endpoints.
- Broader prefetch helpers (e.g., requirement-name prefetch) across endpoints that render requirement lists.
- Gate and requirement name caching (short TTL) once patterns stabilize.

## Frontend & UX
- Accessibility polish: aria states, focus management, keyboard support for dialogs/menus.
- Consistent tooltips/affordances for disabled actions and locked content; optional preview mode for locked items.

## Security & Auth
- JWT lifecycle: short-lived tokens + refresh flow; rotate secrets.
- Content Security Policy: strict CSP with nonces and pinned CDNs; minimize inline scripts/styles.

## Tooling, CI/CD, Observability
- Observability: SQL tracing, slow query surfacing, basic metrics/dashboards.
- Test hardening: factories for content, deterministic RNG in services, system tests for gating/crafting.
- Build pipeline: finalize Tailwind pipeline (or codify CDN strategy); Docker/Kamal CI polish.
- Task organization/naming: move composite seed/backfill orchestration to a broader namespace (e.g., `data:seed_and_backfill`, `app:bootstrap`); keep user-specific tasks under `users:`.

## Database & Schema
- Maintain and review composite indexes: `user_items(user_id,item_id)`, `user_resources(user_id,resource_id)`, `unlockables(unlockable_type,unlockable_id)`, `flag_requirements(flag_id,requirement_type,requirement_id)`.
- Periodic query plan reviews; add covering indexes where beneficial.
