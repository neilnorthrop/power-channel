# Troubleshooting

This document captures common issues observed during development and how to diagnose and fix them. Add new entries as they come up.

## Event Viewer (Footer) Overlaps Page Content / Can’t Scroll to Buttons

- Symptom
  - On smaller windows, the fixed Event Viewer at the bottom covers Action buttons or the end of long pages (e.g., Inventory). Scrolling over the Event Viewer only scrolls the event list, not the page content.

- Root Cause
  - The Event Viewer is a fixed overlay (`position: fixed; bottom: 0`). If the scroll container under it does not have bottom padding equal to the footer height, content sits “under” the overlay and becomes hard to reach. Mouse wheel focus over the footer scrolls the footer instead of the page.

- Fix Implemented
  - Dynamically pad the main scroll container (and related wrappers) to match the footer’s height so content always scrolls above the overlay.
  - Code: `app/javascript/pages/footer.js`
    - Applies `padding-bottom` to `#main-scroll`, `#main` (Turbo frame), `#page-container`, and `#sidebar` based on `#event-log` height (+ small gap).
    - Uses `ResizeObserver` and `window.onresize` to adjust padding when the footer height or window size changes.

- Why This Works
  - Padding the scroll container moves the bottom of the content area above the fixed footer, avoiding overlap while keeping the footer interactive.

- How To Prevent on New Pages
  - Render page content inside the layout’s scroll container `#main-scroll` (inside Turbo frame `#main`).
  - Avoid setting `overflow: hidden` on page wrappers unless you also provide your own internal `overflow-y-auto` container that receives the padding.
  - If adding a new fixed overlay (toolbars, banners), either:
    - Reserve space by padding the scroll container based on the overlay’s height, or
    - Ensure the overlay does not cover actionable UI.

- Verify
  - Resize the window to a short height and scroll to the bottom.
  - Action buttons or last rows remain visible above the footer.
  - Mouse wheel over the page scrolls the page; mouse wheel over the Event Viewer scrolls the log.

## Inventory Craft Button Stays Disabled After Crafting

- Symptom
  - After crafting an item, the Craft button stays disabled even when components are available again.

- Root Cause
  - Button is disabled optimistically on click, but the render did not re-compute server-side `craftable_now` immediately after deltas.

- Fix Implemented
  - After crafting, call a lightweight `refresh()` to re-fetch recipes and re-compute `craftable_now`. Deltas still patch counts in-place.
  - Code: `app/javascript/pages/inventory.js` — Craft click handler `.finally(() => refresh())` and delta handlers schedule a debounced refresh to update button states.

- Preventive Guidance
  - When using server-side computed availability flags (e.g., `craftable_now`), schedule a re-check after actions that can change availability (craft/use/dismantle) or patch them on the client if you maintain a local model.

## Authorization Errors (401) — Expired or Invalid Token

- Symptom
  - API requests intermittently fail with HTTP 401; response body includes `{ "error": "token_expired" }` or a decode error message.

- Root Cause
  - JWTs include an `exp` claim and are verified on decode with algorithm constrained to `HS256`. Expired or tampered tokens are rejected.

- Fix
  - Re-authenticate to obtain a fresh token. Ensure the client refreshes tokens before expiration, or re-issues on 401.

- Notes
  - Local development: set a strong `JWT_SECRET`. Test env provides a deterministic secret via `config.jwt_secret`.
  - Clock skew: if running multiple systems (containers/VMs), keep clocks in sync.

## Actions Feel Slow / Duplicate Refreshes

- Symptom
  - Clicking Actions triggers multiple fetches and delays; the UI looks unresponsive.

- Fix Implemented
  - Rely on ActionCable deltas and remove redundant `fetch*()` calls after POST/PATCH.
  - Broadcast minimal deltas (`user_resource_delta`, `user_item_delta`, `user_update`) from services.
  - Patch UI in-place where possible; otherwise, one debounced refresh.
  - Code: `app/services/*_service.rb`, `app/javascript/pages/home.js`, `app/javascript/pages/inventory.js`.

- Preventive Guidance
  - Prefer event-driven updates over refetching entire lists.
  - Keep broadcast payloads light (only changed rows) and patch the DOM selectively.

## Action Upgrade Level Not Updating in UI

- Symptom
  - After clicking Upgrade on an action, the level badge still shows the previous level (e.g., stays at Lvl 1 after upgrading to Lvl 2).

- Root Cause
  - The upgrade endpoint did not broadcast a UserUpdatesChannel message describing the upgraded `user_action`.
  - The client handler only updated cooldowns on `user_action_update`, not the level badge text.

- Fix Implemented
  - Backend: `Api::V1::ActionsController#update` now broadcasts `{ type: 'user_action_update', data: UserActionSerializer.new(user_action, include: [:action]) }` after a successful upgrade.
  - Frontend: Home page adds an id to the level badge (`#level-badge-<user_action.id>`) and updates its text inside `updateCooldown()` when a payload includes a new `attributes.level`.
  - Files: `app/controllers/api/v1/actions_controller.rb`, `app/javascript/pages/home.js`.

- Why This Works
  - The client receives the exact `user_action` that changed and patches the DOM node with the new level. No heavy refetch is required.

- Preventive Guidance
  - For any endpoint that mutates user-facing state, broadcast a small, specific delta (e.g., `user_action_update`, `user_resource_delta`).
  - Ensure the UI renders dynamic values with stable element ids so they can be patched in place by event handlers.
