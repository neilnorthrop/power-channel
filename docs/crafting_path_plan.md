# Tier 0 Crafting Path — Analysis and Implementation Plan

This document compares the proposed Tier 0 “survival tools” crafting tree to the current game, and outlines a phased plan to deliver it with minimal risk.

## Summary Comparison

What’s already aligned
- Twine as early bottleneck: Twine exists and is used as a component for tools.
- Tool unlocks: Hatchet unlocks Chop Wood; Pickaxe is present (recipe planned) for mining unlocks.
- Salvage loop: Dismantle returns components (e.g., Hatchet → Twine + Stone).
- Packs: Content organized by theme (woodworking, mining, gather, tax, alchemy).

What differs / missing
- Crafting grammar not explicit: No “Handle + Working End + Binding = Tool” structure; no intermediate heads.
- Substitutions: No support for OR inputs (e.g., Branch OR Bone); requires duplicate recipes or a new grouping model.
- Missing resources: Branch, Loose Stone, Flint, distinct Fibers/Reeds, Bone, Bone Tip, Resin.
- Missing tools: Knife, Spear, Club, Torch; “Shaped Stone Head” as an intermediate.
- Shaping step: No “Loose Stone + Flint → Shaped Stone Head”.
- Tool effects: No passive bonuses (e.g., Knife boosts fiber yield) or equipping.

## Proposed Content Additions (by pack)
- gather: Action ‘Gather’; resources Stick, Fibers/Reeds, Branch; Twine recipe (3 Fibers → 1 Twine).
- woodworking: Axe/Hatchet; Knife and Torch can live here or in a ‘survival’ pack.
- mining: Loose Stone, Flint; recipe ‘Shaped Stone Head’ (Loose Stone + Flint); Pick Axe recipe filled.
- hunting (new): Bone (source to be defined), Bone Tip (crafted), Spear; Club (Branch/Bone only) could live here.
- woodworking/survival: Torch (Stick + Fiber; Resin later), Knife (Stick + Shaped Stone Head + Twine).

Tool recipes (Tier 0)
- Knife: Stick + Shaped Stone Head + Twine
- Axe (Hatchet): Branch + Shaped Stone Head + 2×Twine
- Pickaxe: Branch + 2×Shaped Stone Head + 2×Twine
- Spear: Branch/Bone + Flint/Bone Tip + Twine (alternates)
- Club: Branch or Bone (no binding)
- Torch: Stick + Fiber; optional Resin later for duration

Intermediate components
- Twine: 3×Fibers/Grass/Reeds → 1 Twine
- Shaped Stone Head: Loose Stone + Flint
- Bone Tip: Bone → Bone Tip

Gating
- can_harvest_fibers: craft Knife → unlock ‘Harvest Fibers’ (higher fiber yield) OR grant a passive Gather bonus.
- can_quarry: craft Pickaxe → unlock ‘Quarry Stone’ (already present).

## Substitution Strategies
- Short term: Duplicate recipes for alternates (e.g., Spear with Flint vs Bone Tip). Group by result in UI.
- Mid term: Add grouping to `recipe_resources` (`group_key`, `logic` = AND/OR). Crafting requires all AND groups and ≥1 in each OR group (mirrors FlagRequirement).

## Tool Effects Options
- V1 passive: ActionService checks ownership (e.g., Knife) and increases fiber gain on Gather/Harvest Fibers.
- V2 equip: Add equipped tool per user; effects apply only when equipped.

## Luck and Variable Drops (implemented)
- Each resource can define a quantity range via `min_amount`/`max_amount`. If absent, `base_amount` is used.
- Luck is split between success chance and quantity (currently 50/50; adjustable weights in `ActionService`).
- Quantity uses probabilistic fractional rounding: after computing an exact value, we award +1 extra with probability equal to the fractional part, preserving expected values without bias.

## Phased Implementation Plan

Phase 1 — Content (low risk, high value)
- Add new resources/items/recipes in packs as above.
- Fill Pick Axe recipe; add flags `can_quarry` and `can_harvest_fibers` with unlockables.
- Add dismantle rules for Knife/Spear/Club/Torch.
- Inventory UI: group recipes by item to avoid duplicates (simple client grouping by `item_id`).

Phase 2 — UX polish
- In Inventory, show alternates inline for grouped recipes (labels: “Handle: Branch OR Bone”).
- Add tooltips showing component sufficiency per alternate.

Phase 3 — Substitution model
- Schema: add `group_key` and `logic` to `recipe_resources`.
- CraftingService: evaluate OR/AND groups atomically.
- Serializers: emit grouped components with names.

Phase 4 — Tool bonuses / equip
- V1: Passive Knife bonus to fibers (or unlock a stronger action).
- V2: Add equip slots; item effects apply only when equipped.

## Pros and Cons
Pros
- Physical logic: clear, teachable recipes; strong motivation to progress.
- Flexible: substitutions reduce frustration; supports biome diversity.
- Reusable components: heads and twine reused across tools; clean dismantle.

Cons
- More content: introduces several new resources and recipes.
- Substitutions: requires duplicate recipes or schema/UI work to model OR.
- Effects: adding equips/bonuses is additional system work (phased).

## Suggested Next Steps (Phase 1)
1) Add resources: Branch, Fibers/Reeds, Loose Stone, Flint, Bone (stub source), Resin (optional).
2) Add intermediates: Shaped Stone Head, Bone Tip; Twine recipe: 3 Fibers → 1 Twine.
3) Add tools: Knife, Spear, Club, Torch; fill Pickaxe recipe; ensure Hatchet exists.
4) Add flags: `can_harvest_fibers` (Knife → unlock action/bonus), `can_quarry` (Pickaxe → unlock Quarry Stone).
5) Add dismantle rules for the new tools.
6) Inventory UI: group duplicate recipes by item to prevent clutter.
