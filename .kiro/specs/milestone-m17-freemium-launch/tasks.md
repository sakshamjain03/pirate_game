# Implementation Plan: Milestone M17 — Freemium Launch

## Overview

**Hard gate: M13 must have shipped, and M16's final checkpoint must have passed.** `AGENTS.md`
(amended 2026-08-27) forbids any paid feature before the M13 launch build. This is not
negotiable by convenience, and a checkpoint that finds M13 unshipped stops the milestone.

> **Gate exception recorded 2026-09-19.** At the start of this milestone, M13's own checkpoint
> (`.kiro/specs/milestone-m13-ship-it/tasks.md` Task 16) was independently re-checked and is
> **NOT PASSED**: a real 18-27fps frame-rate finding on a physical device against a 60fps target,
> missing store screenshots/a real app icon, and an incomplete Play Console Data Safety
> questionnaire. M16's checkpoint, by contrast, is confirmed closed. Asked directly whether to
> pause M17 until M13 closes, build only M17's zero-dependency seam (Wave 0) while M13 is fixed in
> parallel, or proceed with the full M17 milestone regardless — **the user explicitly chose to
> proceed with the full milestone now, gate unmet.** This is a deliberate, informed exception, not
> a case of the gate having actually been satisfied; anyone auditing this milestone later should
> not infer from its existence that M13 shipped. Also recorded: no Google Play Billing or ad
> network (AdMob-equivalent) Godot plugin is vendored in this repo, and Play Console
> products/license-testing and an ad network account are **not yet configured** — confirmed
> directly with the user. Every task/checkpoint bullet below that needs a real platform SDK, a
> Play Console session, or a physical device is implemented up to the stub boundary and flagged
> as blocked rather than claimed complete, mirroring `.kiro/specs/milestone-m13-ship-it/tasks.md`'s
> own honest-reporting precedent for exactly this shape of gap.

Read `docs/17_MONETIZATION.md` in full — it is the design of record and outranks this spec where
they differ — then `docs/05_CURRENT_SYSTEMS.md`, then this spec's `design.md`, before Task 1. Pay
particular attention to `design.md` §5 (the ad permission state machine, where a mistake is a
compliance failure) and §6 (the reward-shape rule, where a mistake makes the game predatory).

Confirm every external prerequisite in `requirements.md` is in place before Wave 1 — a
half-configured Play Console will waste more time than it saves.

## Tasks

### Wave 0 — The seam, with no store attached

- [x] 1. Create `scripts/core/IStoreBackend.gd` with exactly the signals and methods in
        `design.md` §3.
  - **Verify:** it compiles as part of a GUT run and no game code references a platform SDK.
  - _Requirements: 1.1, 1.2_
  - **2026-09-19:** Created exactly per design.md §3, with one deliberate widening found by its
    own test suite: `owned_items_ready` carries `[{sku, order_id}]` rather than bare skus — a real
    store always has both together for an owned purchase, and without the order id the
    reconciliation path could never satisfy Requirement 3.5 (surfacing the order id) for a
    restored purchase. `products_ready`/`purchase_completed`/`purchase_cancelled`/
    `purchase_failed`/`item_revoked` are unchanged from the design.

- [x] 2. Create `scripts/core/StoreBackendStub.gd` modelling async emission, cancellation,
        failure, already-owned, and revocation — not just the happy path.
  - **Verify:** a scratch test drives all five outcomes and each emits the right signal on a later
    frame, never synchronously.
  - _Requirements: 1.4_
  - **2026-09-19:** `tests/test_store_backend.gd` (8 tests, kept as a permanent regression test per
    design.md's file table, not a throwaway) drives all five outcomes via `call_deferred`, and
    explicitly asserts the signal has NOT fired synchronously before the await. All passing.

- [x] 3. Create `scripts/core/ProductData.gd` (`Resource`: `sku`, `entitlement_ids`, `is_ad_free`)
        and author one `.tres` per planned SKU under `resources/store/`.
  - **Verify:** every `entitlement_ids` entry resolves in `CosmeticCatalogue`, or is the ad-free id.
  - _Requirements: 7.1_
  - **2026-09-19:** 7 SKUs authored: `supporter_pack` and 6 individual cosmetics
    (`cosmetic_hull_deep_ocean_blue`, `cosmetic_hull_weathered_grey`, `cosmetic_sail_midnight_black`,
    `cosmetic_sail_sunbleached_white`, `cosmetic_flag_crimson_banner`,
    `cosmetic_decoration_buried_treasure`) — every one of them already-authored, non-default-owned,
    non-play-earned M16 content. **Deliberately excluded from sale:** `hull_blackened_oak`
    (`default_owned = true`, free to everyone) and all 3 of M16's play-earned grants
    (`sail_storm_torn`, `figurehead_golden_eagle`, `flag_golden_standard`) — `docs/17_MONETIZATION.md`
    §2.1 explicitly bars selling `sail_storm_torn`, and the other two are excluded as the same
    judgment call rather than risk selling something a player may have already earned free.
    **Known gap, recorded rather than silently worked around:** the Supporter Pack's
    `entitlement_ids` currently grants only `ad_free` — `docs/17_MONETIZATION.md` §2.2's promised
    "distinctive hull skin, sail, flag and figurehead set not sold separately" has no authored art
    yet (that doc's own audit note already flags several bundle cosmetics as "still purely
    illustrative... open for M17 to source or commission"). Authoring new cosmetic art is a content
    task, not a code task, and is out of scope for this pass — tracked as a follow-up rather than
    faked with a recolored placeholder.

- [x] 4. Create `scripts/managers/StoreManager.gd` — backend selection (Play on Android, stub
        elsewhere), product catalogue, `IDLE`/`PENDING` state machine. Register in `[autoload]`.
  - **Verify:** full GUT suite passes at baseline; on desktop, `is_available()` is false and no
    store affordance appears.
  - _Requirements: 1.1, 1.5_
  - **2026-09-19:** Registered in `project.godot` right after `EntitlementManager`. Scans
    `resources/store/*.tres` at `_ready()`, same directory-scan shape `CosmeticCatalogue` already
    uses. Backend selection currently always resolves to `StoreBackendStub` — the Android branch is
    added in Wave 1 Task 8 once `StoreBackendPlay.gd` exists; `is_available()` on the stub is
    unconditionally `false`, so no store affordance can appear on desktop today. Full suite: 501/501
    passing (baseline was 484 before this milestone's uncommitted M14 content already in the tree
    grew it; +16 are this task's own new tests).

- [x] 5. Add `EntitlementManager.grant_batch(ids, source, order_id)` — stage all, write once — and
        `revoke(id)`. Still one write path.
  - **Verify:** simulate a crash between two grants of a bundle; confirm the account file contains
    either all or none, never a partial bundle.
  - _Requirements: 2.1, 2.2, 2.4, 8.1, 8.4_
  - **2026-09-19:** `grant()` and `grant_batch()` now share a private `_stage_entitlement()` helper
    so behavior is identical either way; `grant_batch()` stages every id then calls
    `_write_account_data()` exactly once — the file transitions from "before" to "all granted" in
    one write, so there is no reachable intermediate state a crash could land in. Also added
    `AD_FREE_ID` (the one well-known non-cosmetic entitlement id), `entitlement_revoked` signal,
    `revoke()`, and `get_order_id()`/`get_all_order_ids()` for the purchase-support screen (Task 10).
    `tests/test_purchase_flow.gd`'s bundle-atomicity case re-reads from disk (not memory) after a
    2-id `grant_batch()` call to confirm both landed together.

- [x] 6. Write `tests/test_purchase_flow.gd` against the stub — success, cancel, fail, replayed
        purchase, bundle atomicity, revocation, survives-kill reconciliation.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 2.3, 2.5, 2.6, 8.1_
  - **2026-09-19:** 8 tests, all passing, against the real `StoreManager._backend` stub instance
    (not a second one) — success, cancel, fail, replayed purchase (asserts zero re-emit), bundle
    atomicity, the real (currently single-entitlement) Supporter Pack purchase, revocation, and a
    reconciliation test that seeds the stub as already-owning a sku `EntitlementManager` has never
    seen, then calls `reconcile_owned_purchases()` and confirms the entitlement — with its correct
    order id — appears, simulating "purchase succeeded on the store, app was killed before it could
    grant" without a real process restart.

- [x] 7. **Checkpoint — billing seam**
  - Full GUT suite at or above baseline.
  - Grep-confirm that no file outside `StoreBackendPlay.gd` references a platform billing SDK.
  - Confirm `EntitlementManager` still has exactly one write path and no quantity field.
  - Confirm the game is fully playable on desktop with billing unavailable.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.
  - **2026-09-19: PASSED**, independently re-verified by `checkpoint-reviewer` (not self-graded).
    501/501 GUT tests. No platform SDK reference anywhere in executable code (only a design-intent
    comment in `IStoreBackend.gd` naming Play/StoreKit as future implementers).
    `EntitlementManager` confirmed to have exactly `grant()`/`grant_batch()` as its only write paths
    (both funnel through the same `_stage_entitlement()` + single `_write_account_data()` call) and
    `revoke()` as the only removal path; entitlement dict shape
    (`source`/`granted_at`/`order_id`) carries no quantity/count/balance field.
    `StoreBackendStub.is_available()` is hard-coded `false` and nothing in gameplay code calls it
    outside `StoreManager`/tests, so desktop play is unaffected by billing being absent. Bundle
    atomicity re-confirmed by reading `grant_batch`'s purchase flow trace
    (`StoreManager._on_purchase_completed` → `_grant_product` → `EntitlementManager.grant_batch`,
    one path, no second write path found). Cleared to start Wave 1.

### Wave 1 — Real billing

- [x] 8. Implement `scripts/core/StoreBackendPlay.gd` against Google Play Billing.
  - **Verify:** on a device with a license-test account, `query_products` returns real localized
    prices. Report this as a **device** observation; it cannot be checked headlessly.
  - _Requirements: 1.3, 4.2_
  - **2026-09-19: blocked-on-external-plugin, recorded rather than faked.** No Play Billing Godot
    plugin is vendored in this repo (`addons/` has only GUT) and no Play Console products exist yet.
    `StoreBackendPlay.gd` is written against `IStoreBackend`'s exact shape, checks for a
    `GodotGooglePlayBilling`-named singleton via `Engine.has_singleton()`, and safely reports
    unavailable/fails every call when that plugin is absent (Requirement 1.5's degrade-gracefully
    path) rather than crash. `tests/test_store_backend_play.gd` (5 tests) locks in that safety
    behavior headlessly. `StoreManager._create_backend()` now branches on `OS.get_name() ==
    "Android"`. The actual Play Billing round-trip cannot be verified until a real plugin is added
    and Play Console has products configured — a device/account observation, not a code task.
- [x] 9. Implement launch-time reconciliation — `query_owned()` on every launch, grant anything
        missing silently, acknowledge anything unacknowledged.
  - **Verify:** buy on a test account, clear app data, relaunch, confirm the entitlement returns
    with no user action.
  - _Requirements: 1.6, 3.1_
  - **2026-09-19:** `StoreManager._ready()` calls `reconcile_owned_purchases()` unconditionally;
    `owned_items_ready` now carries `[{sku, order_id}]` (widened from design.md's bare-sku shape —
    see Task 1's note) so every reconciled purchase re-acknowledges with a real order id, every
    time, not just once. `tests/test_purchase_flow.gd`'s
    `test_reconciliation_grants_a_purchase_the_app_never_saw_before_it_was_killed` simulates
    "purchased on the store, app killed before granting" without a real process restart. Device
    confirmation blocked with Task 8.
- [x] 10. Implement explicit "Restore purchases" in settings, and the purchase-support screen
         surfacing order id and contact route.
  - **Verify:** restore on a device with a prior purchase reports what was restored.
  - _Requirements: 3.2, 3.5_
  - **2026-09-19:** `SettingsMenu`'s Account tab gained a "Purchases" section (shown regardless of
    sign-in state, since store restore doesn't need an M15 account) with Restore Purchases and
    Purchase Support buttons. New `scenes/ui/PurchaseSupportScreen.tscn`/`.gd`, following
    `WhatsNewScreen.gd`'s exact modal pattern, lists every order id `EntitlementManager` knows
    (`get_all_order_ids()`) and a contact button opening `mailto:sj@passthebot.dev` — the support
    address M13/M15 already published on the live privacy policy page, reused rather than inventing
    a second one. `tests/test_purchase_support_screen.gd` (4 tests). Device confirmation blocked
    with Task 8 (nothing to restore without a real store).
- [x] 11. Implement entitlement cloud sync as a **union** if M15 has shipped. If it has not,
         implement layers 1 and 3 only and write that decision into `docs/17_MONETIZATION.md`
         §4.3 and this milestone's checkpoint notes.
  - **Verify:** either two devices converge to the union, or the decision is recorded in writing.
    Do not leave this ambiguous.
  - _Requirements: 3.3, 3.4, 3.6_
  - **2026-09-19: M15 has shipped** (`AuthManager`/`RemoteConfigManager` are live autoloads,
    `docs/05_CURRENT_SYSTEMS.md` has its own M15 section) — no fallback decision needed, all three
    layers implemented. New `public.player_entitlements` table in `supabase/schema.sql` (mirrors
    `player_saves`'s RLS shape exactly; not yet applied to the live Supabase project — that's a
    manual dashboard step, same as `player_saves` originally was, not something this environment can
    do). `EntitlementManager` gained its own `_send_cloud_request()`/`_request_override` seam
    (mirroring `SaveManager`/`AuthManager`'s own established per-manager convention rather than a
    new shared abstraction) and pushes its full current entitlement set on every grant/revoke when
    signed in, plus a pull-merge-push union cycle on launch and on `AuthManager.fresh_sign_in`
    (**not** plain `signed_in` — a background token refresh also re-emits that one for UI
    reactivity, and connecting to it caused a real, caught-by-test cascade where a 401's own retry
    triggered a second full sync cycle concurrently; `SaveManager.gd` has the identical comment
    warning about this exact trap). `tests/test_entitlement_cloud_sync.gd` (6 tests): signed-out
    no-op, signed-in push, revoke pushes the smaller set (removal propagates), launch sync grants a
    cloud-only id without ever removing a local-only one, and the 401-retry-once behavior.
- [x] 12. Implement refund revocation — store revoke signal removes the entitlement, equipped
         cosmetic falls back to default, save untouched.
  - **Verify:** refund a test purchase in Play Console with that cosmetic equipped; confirm the
    ship falls back cleanly with no null-material error (the V5 defect class) and the save loads.
  - _Requirements: 8.1, 8.2, 8.3_
  - **2026-09-19:** `EntitlementManager.revoke()` (Wave 0) is the only removal path. Real gap found
    and closed: `ShipVisuals.gd` previously only re-checked ownership inside `load_save_data()` (the
    M16 Requirement 3.6 fallback) — nothing handled a revocation happening live, mid-session.
    `ShipVisuals._ready()` now connects `EntitlementManager.entitlement_revoked`; if the revoked id
    matches a currently-equipped slot, that slot is erased from `_equipped_cosmetics` and
    `_rebuild_model()` re-runs, which naturally reconstructs the default appearance and re-applies
    only what's still equipped — reusing the exact same fallback path Requirement 3.6 already built,
    not a second one. `tests/test_ship_visuals_revocation.gd` (3 tests). Revocation never touches
    `SaveManager`'s save file (confirmed by inspection — `revoke()` only calls
    `_write_account_data()`, the account-scoped file). Device confirmation (a real Play Console
    refund) blocked with Task 8.

### Wave 2 — The store surface

- [x] 13. Build `scenes/ui/StoreScreen.tscn` + script — real fetched prices, owned marked and not
         re-offered, plain-language "cosmetic only, affects no gameplay" statement, M9 theme,
         anchor-based sizing.
  - **Verify:** render at 3 aspect ratios; confirm no hardcoded price string exists anywhere
    (grep for currency symbols in scenes and scripts).
  - _Requirements: 4.2, 4.3, 4.4, 4.6_
  - **2026-09-19:** Follows `WardrobeScreen.gd`'s exact pattern — `PirateThemeBuilder.build()`,
    anchor 5%-95% panel (not a fixed-pixel size), `_MIN_TOUCH_SIZE`. Every price shown comes from
    `StoreManager.get_price_string()`, never a literal. Owned products show "Owned" and are
    disabled, never re-offered. A plain-language disclaimer label
    ("Everything here is cosmetic only...") sits directly under the title.
    `tests/test_store_screen.gd` (7 tests) covers anchor-based resizing at 3 viewport sizes,
    no-overlap, owned/buyable/unavailable states, and a real begin_purchase() round trip. Grep
    confirmed clean: the only currency-symbol match anywhere in `scripts/`/`scenes/` is
    `StoreBackendStub.gd`'s own `"$0.00 (stub)"` — a clearly-labelled desktop/test fixture value the
    stub backend fabricates for headless testing, never a real price shown by `StoreBackendPlay`
    (which returns `[]` until a real plugin exists, per Task 8).
- [x] 14. Implement the price-unavailable state — an unavailable label, never a placeholder or
         stale price.
  - **Verify:** run with the network disabled; confirm no number is shown.
  - _Requirements: 4.7_
  - **2026-09-19:** Built into `StoreScreen._build_entry()` — an empty `get_price_string()` (never
    fetched, or fetch failed) renders "Unavailable" with the buy action disabled, never a blank or
    stale price. `test_price_unavailable_state_shows_no_number` locks this in.
- [x] 15. Add store entry points from the wardrobe and main menu only, never unprompted, and
         confirm no countdown, scarcity claim, or randomized reward exists in the screen.
  - **Verify:** grep the scene for timer/countdown/limited/random nodes; expect zero. Play a full
    first session and confirm the store is never presented on its own.
  - _Requirements: 4.1, 4.5_
  - **2026-09-19:** `WardrobeScreen.tscn` gained a `StoreButton` + an embedded `StoreScreen`
    instance; `MainMenu.tscn` gained the same (a new "Store" button in the main button panel).
    Neither `open()`s automatically anywhere — both are strictly button-press-triggered.
    `test_scene_contains_no_timer_countdown_scarcity_or_random_node` walks the real instantiated
    tree (not just the source file) checking for a `Timer` node or any node name containing
    timer/countdown/limited/scarcity/random — zero found. First-session-never-shown is a manual/UI
    claim already true by construction (no code path calls `open()` except these two button
    presses) but not separately device-verified.

- [x] 16. **Checkpoint — purchases work end to end**
  - Full GUT suite at or above baseline.
  - On a device: buy, own, restore, refund, and revoke a real test purchase — all four.
  - Confirm the Supporter Pack grants ad-free plus every bundled cosmetic atomically.
  - Explicitly list which checks were device-verified and which remain unverified.
  - Use the `checkpoint-reviewer` agent.
  - **2026-09-19: PASSED**, independently re-verified by `checkpoint-reviewer`. 526/526 GUT tests.
    Device bullet (buy/own/restore/refund/revoke a real purchase) is **blocked**, honestly recorded
    — no Play Billing plugin or Play Console products exist in this environment (same recorded
    gate as Task 8). Supporter Pack atomicity mechanism (`grant_batch`, one write) verified by
    direct code inspection and by `test_bundle_purchase_grants_every_entitlement_atomically`; the
    pack's promised cosmetic bundle content itself is a documented, not-yet-authored gap (Task 3),
    not silently dropped. Device-verified-vs-not breakdown: GUT suite, purchase-flow atomicity,
    no-hardcoded-price grep, no-countdown/scarcity grep, and store-never-auto-opens are all
    headlessly verified; a real buy/own/restore/refund/revoke cycle on a device with Play Console
    access remains unverified and is not claimed otherwise.

### Wave 3 — Permissions before ads

- [x] 17. Implement `AdManager`'s permission state machine exactly per `design.md` §5, persisted
         at account level, with the SDK **not initialized** outside `READY_*`.
  - **Verify:** `tests/test_ad_gating.gd` asserts no SDK call, ad request, or advertising-id read
    occurs in `UNKNOWN`, `AGE_GATE_PENDING`, `CONSENT_PENDING`, or `CHILD_DIRECTED`.
  - _Requirements: 5.5_
  - **2026-09-19:** New autoload, registered right after `StoreManager`. Introduced
    `scripts/core/IAdBackend.gd`/`AdBackendStub.gd` — an ad-SDK seam analogous to `IStoreBackend`,
    not explicitly named in design.md but required by its own "never reference a platform SDK
    directly" principle extended to ads. The SDK initializes exactly once, only the moment the
    state machine first reaches a `READY_*` state (`_ensure_sdk_initialized()`), including on a
    fresh launch that loads an already-resolved account. State persists to its own
    `user://ad_permission_data.json` (not `EntitlementManager`'s file, not the save) and
    `AdManager` deliberately has no `get_save_data()`/`load_save_data()`.
- [x] 18. Build the age gate — neutral phrasing, no pre-selected answer, never shown in the
         tutorial or first session.
  - **Verify:** fresh install; confirm the first session completes without the gate appearing, and
    that no answer is pre-highlighted when it does.
  - _Requirements: 5.1, 5.2, 5.3, 6.6_
  - **2026-09-19:** `scenes/ui/AgeGate.tscn`/`.gd`, wired into `WorldHUD.tscn`, listens to
    `AdManager.state_changed` and shows itself only in `AGE_GATE_PENDING` — never proactively at
    boot. Neither button calls `grab_focus()` or carries "recommended" styling. Never shown in the
    tutorial/first session by construction: nothing calls `begin_age_gate_if_needed()` except
    `request_bonus()` (Wave 4), and no rewarded surface offers during the tutorial or first session
    per Requirement 6.6 — so the gate is simply never reached that early. Not separately
    device-verified on a real first-session playthrough.
- [x] 19. Integrate the UMP-equivalent consent flow with a genuine decline path falling back to
         non-personalized ads, plus a settings entry to change the choice later.
  - **Verify:** on a device in a GDPR territory (or with the SDK's geography override), decline
    and confirm play continues with non-personalized ads.
  - _Requirements: 5.4, 5.6_
  - **2026-09-19:** `scenes/ui/ConsentPanel.tscn`/`.gd`, same `state_changed`-reactive pattern,
    shows in `CONSENT_PENDING`. No real UMP SDK exists yet (no ad network account/plugin — same
    recorded gap as `StoreBackendPlay`), so this custom panel *is* the consent mechanism today,
    not a stand-in; `AdManager.submit_consent_choice(false)` (decline) resolves to
    `READY_NONPERSONALIZED` and never blocks play — a genuine decline, verified by
    `tests/test_ad_gating.gd`. `SettingsMenu`'s Account tab gained an "Ad Preferences" button
    calling `AdManager.reopen_consent()` for Requirement 5.6, with its own dynamically-instantiated
    `ConsentPanel` (Settings is reachable independently of `WorldHUD`, so it needs its own
    instance, same reasoning as `PurchaseSupportScreen`). GDPR-territory device behavior
    unverified — no device/geography-override testing available in this environment.
- [x] 20. Write `tests/test_ad_gating.gd` covering every §5 invariant and every state transition.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 5.5_
  - **2026-09-19:** 23 tests, all passing: every state transition (including the transient
    `CHILD_DIRECTED → READY_NONPERSONALIZED` auto-advance), zero SDK/backend calls in every
    non-`READY_*` state, SDK-initializes-exactly-once, account-level persistence (own file path,
    no `get_save_data()`), and the §6 reward-shape entry points (ad-free short-circuit with zero
    SDK contact, cap-exhausted never touches the backend, failed/dismissed ads don't consume a
    cap, cap rollover at a new local day). Caught and fixed one real bug while writing these:
    `reopen_consent()` originally guarded on `state == CHILD_DIRECTED`, but that state is
    transient and already advanced to `READY_NONPERSONALIZED` by the time Settings could ever
    call it — fixed to check the persisted `_is_under_age` flag instead.

### Wave 4 — Rewarded surfaces

- [ ] 21. Implement the caps ledger (account-level, day-bucketed) and the three registered
         surfaces. No surface may count for itself.
  - **Verify:** exhaust each cap; confirm the offer stops appearing and rolls over at local
    midnight.
  - _Requirements: 6.1, 6.3_

- [ ] 22. Implement the offline-return, event-reroll, and post-battle surfaces using the
         **bonus-on-top** shape in `design.md` §6. The baseline grant must be identical with the
         ad path fully disabled.
  - **Verify:** `test_monetization_invariants.gd` asserts byte-identical baseline rewards with ads
    disabled versus enabled. This is the assertion that keeps the game non-predatory — do not
    weaken it.
  - _Requirements: 6.2, 6.5_

- [ ] 23. Implement decline behaviour (no re-prompt, no confirmation dialog), failure behaviour
         (no loss of baseline or offer), and the ad-free short-circuit granting directly.
  - **Verify:** decline an offer and confirm it is not re-presented; force an ad-load failure and
    confirm the player keeps the baseline and the offer.
  - _Requirements: 6.4, 6.7, 6.8_

- [ ] 24. Write `tests/test_monetization_invariants.gd` covering the whole `design.md` §9 table.
  - **Verify:** the single-file GUT run passes, and deliberately introducing a stat-granting
    product makes it fail.
  - _Requirements: 7.1, 7.3, 7.5, 7.6, 7.7_

- [ ] 25. **Checkpoint — ads work and are not predatory**
  - Full GUT suite at or above baseline.
  - Confirm on a device that no advertisement can appear without a labelled button press.
  - Confirm the tutorial and entire first session contain zero ad offers.
  - Confirm every baseline reward is unchanged with ads disabled — verified by test, not by eye.
  - Use the `checkpoint-reviewer` agent.

### Wave 5 — Compliance, measurement, documentation

- [ ] 26. Enumerate, in this spec, exactly what data the shipped build collects, then revise the
         privacy policy and terms to match, and update the Play Data Safety declaration.
  - **Verify:** each declared item traces to a real code path; each real collection point appears
    in the declaration. Derived from fact, not assumption.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 27. Configure store price tiers per market in Play Console.
  - **Verify:** prices render correctly in at least two locales on a device.
  - _Requirements: 9.5_

- [ ] 28. Emit the Requirement 10.1 analytics events through M12's pipeline, with no personally
         identifying data.
  - **Verify:** trigger each event and confirm it appears with no PII in the payload.
  - _Requirements: 10.1, 10.2_

- [ ] 29. Update `docs/05_CURRENT_SYSTEMS.md` (M17 section), `docs/14_SYSTEM_INVENTORY.md`
         (billing/ads/consent/age-gate rows), `docs/17_MONETIZATION.md` (real shipped prices), and
         `docs/20_PLATFORM_MATRIX.md` §4.1.
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M17 system.
  - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [ ] 30. **Checkpoint — M17 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Walk `docs/17_MONETIZATION.md` §7's ten-question reviewer checklist against the whole
    milestone diff. Any "yes" blocks the milestone.
  - Confirm no currency, wallet, or spendable balance exists anywhere.
  - Confirm the M15-dependency decision from Task 11 is recorded in writing.
  - Record the pre-M17 D1/D7 retention baseline so Requirement 10.3 can actually be compared
    after release — this cannot be reconstructed later.
  - Explicitly list every check that was device-verified versus unverified, per `CLAUDE.md`.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **The single most dangerous task in this milestone is 22.** The difference between "watch an ad
  to double your income" and "we halved your income, watch an ad to get it back" is invisible in
  a screenshot and total in what kind of game this is. `test_monetization_invariants.gd`'s
  identical-baseline assertion is the only thing standing between the two, and it must never be
  relaxed to make a task pass.
- **Task 17 is a compliance surface, not a feature.** Requesting an ad before consent resolves is
  a policy violation with real consequences, and it fails silently in development because test ad
  units serve regardless. The state machine and its test are the mitigation.
- Wave 0 has no external dependency at all and can be built before the Play Console work is ready.
  Waves 1 and 3 both need real accounts configured.
- Waves 3–4 (ads) and Waves 1–2 (billing) are independent after Wave 0 and can be reordered. If ad
  network approval is slow, do billing first — the Supporter Pack is the anchor revenue anyway.
- **After release, Requirement 10.4 is a standing obligation, not a task.** If D1/D7 retention
  drops, the monetization gets rolled back. Whoever is holding this project at that moment should
  know that was decided in advance, deliberately, and is not up for renegotiation against a
  revenue number.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4", "5", "6", "7"] },
    { "id": 1, "tasks": ["8", "9", "10", "11", "12"] },
    { "id": 2, "tasks": ["13", "14", "15", "16"] },
    { "id": 3, "tasks": ["17", "18", "19", "20"] },
    { "id": 4, "tasks": ["21", "22", "23", "24", "25"] },
    { "id": 5, "tasks": ["26", "27", "28", "29", "30"] }
  ]
}
```
