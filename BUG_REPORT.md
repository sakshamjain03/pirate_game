# Pirate Empire - Bug Report

Generated from codebase analysis on 2026-09-14.

**Triaged and actioned 2026-09-14** against the live codebase (see
`docs/05_CURRENT_SYSTEMS.md`'s "BUG_REPORT.md fix pass (2026-09-14)" entry for the full writeup).
Each item below is marked with its actual disposition — several had already been fixed by
intervening milestones this report's static analysis never saw, some described behavior not
actually reachable through any real UI path, and a few are balance/design questions rather than
defects. Full GUT suite: 467/467 passing after this pass (see `docs/14_SYSTEM_INVENTORY.md`).

---

## Critical Bugs

### 1. ShipCombat.current_health setter doesn't properly handle missing ShipDamage
**Status: FIXED (narrower than originally described).** The setter already forwarded to
`ShipDamage.repair()` for positive deltas (a prior milestone's fix, not visible when this report
was written). The remaining real bug: the negative-delta (damage) branch clamped only at the
floor (`maxf(value, 0.0)`), with no ceiling — now `clamp(value, 0.0, get_pool_maximum("hull"))`,
matching `ShipDamage.apply_hit()`'s own convention. `scripts/world/ShipCombat.gd`.

---

### 2. EmpireManager._compute_defense_score - Incomplete FleetManager integration
**Status: NOT A BUG.** `_compute_defense_score()` correctly calls
`FleetManager.get_ships_defending_home()`, and that method correctly excludes the active ship and
any ship on a mission. A low score with a 1-ship fleet is the design's actual behavior (a
1-ship empire has minimal home defense), not a logic error. Left as-is; a balance question for a
future pass if raids feel too easy/hard at low fleet sizes, not a mechanical fix.

---

### 3. SaveManager.load_game calls private methods for offline catch-up
**Status: FIXED.** `Island.gd` and `FleetManager.gd`'s `_on_economy_tick()` were renamed to
`on_economy_tick()` (dropping the leading underscore, since `SaveManager` was always calling them
from outside their own class — the original name was simply wrong, not a design that needed
preserving). Their `global_economy_tick` signal connections were updated to match. Deliberately
*not* switched to re-emitting the shared signal instead — the existing code comment explains why:
`FactionManager` also subscribes to `global_economy_tick` for hunter-ship spawning, and would
misfire at absurd rates if replayed hundreds of times during offline catch-up.

---

### 4. Island._on_economy_tick doesn't check for FRIENDLY ownership
**Status: FIXED.** Added `IslandData.is_owned_by_player()` (true for `FRIENDLY` or `CAPITAL`).
`_on_economy_tick()` now gates production on it instead of only excluding `ENEMY` — `NEUTRAL` and
`LEGENDARY` islands no longer produce resources for the player.

---

### 5. FactionManager hunter spawn doesn't scale with reputation severity
**Status: BY DESIGN, deferred.** The flat 20%-per-tick chance at reputation ≤ -50 is the current
authored balance, not a logic bug — there's no existing severity-scaling mechanism to wire up
without inventing new balance curves. Flagged as a backlog balance item, not fixed blind in this
pass.

---

### 6. DockingSystem._process_healing heals ships at enemy shipyards
**Status: FIXED.** `_process_healing()` now also requires `island.island_data.is_owned_by_player()`
alongside the existing `has_shipyard()` check, using the same helper added for item #4.

---

## High Priority Bugs

### 7. CampaignManager._catch_up potential infinite loop
**Status: NOT A BUG.** Traced by hand: the `if current_chapter_index >= 0 and _current_chapter()
!= null: return` guard already prevents both infinite-looping and skipping past an incomplete
chapter, regardless of `completed_chapter_ids` ordering. Added
`test_catch_up_handles_completed_chapter_ids_with_a_gap` to `tests/test_campaign_manager.gd` to
lock this in, since the exact "gap in the middle" shape wasn't explicitly covered before.

---

### 8. ResourceManager.recalculate_storage_capacity misses "research" capacity clamping
**Status: FIXED (real, but subtler than described).** `base_storage` already includes `"research"`
correctly. The actual gap: the clamp loop only iterated `current_resources.keys()`, so a type that
gained capacity via a building bonus but had no balance entry yet was never tracked. Now unions
`max_storage.keys()` into the loop too.

---

### 9. Island._resolve_building assumes specific ID format
**Status: NOT A BUG.** Checked the capitalization logic (`"tavern_l1"` → `"Tavern_L1.tres"`)
against the real filenames under `resources/buildings/` — they match exactly. The report's
concern doesn't reproduce.

---

### 10. FleetManager.owned_ships/owned_captains not initialized before use
**Status: Real but currently unreachable — left as a documented latent risk, not fixed
speculatively.** No other autoload currently calls `FleetManager.add_ship()`/etc. before
`FleetManager._ready()` has run, so the race described can't presently occur. Fixing it
speculatively (e.g. lazy-initializing on first access) would add complexity for a scenario that
doesn't happen today; revisit if a future change introduces a call path that could trigger it.

---

### 11. ShipController.respawn doesn't re-apply captain/tech health modifiers
**Status: ALREADY FIXED (prior milestone).** `respawn()` calls `ShipDamage.restore_all()`, which
correctly resets `_is_destroyed` and restores hull/sails/crew to their proper maxima (including
captain/tech modifiers via `get_pool_maximum()`/`get_effective_max_health()`). The code's own
comments document this was fixed as part of the M6 `ShipDamage.repair()` work.

---

### 12. EmpireManager._check_raid uses attacking_region.tier but region data may not have tier
**Status: FIXED.** `RegionData.tier` has no enforced minimum (`@export var tier: int` defaults to
0 if never authored). `EmpireManager._ready()`'s region-loading loop now `push_error`s when a
loaded region's `tier <= 0`, so a missing tier is surfaced immediately instead of silently making
that region look equal-or-lowest in raid target selection.

---

### 13. SaveManager.save_game backup logic may lose saves on failure
**Status: FIXED.** Added `SaveManager._restore_backup()`, called from both `save_game()` and
`_apply_cloud_save()` when the new write fails after an existing save was already backed up — the
player is no longer left with neither a current save nor their last-known-good backup.

---

### 14. ShipDamage.apply_hit uses hit_direction for facing but may receive zero vector
**Status: NOT A BUG (verified).** Both real callers (`Cannonball._on_body_entered()`,
`ShipCombat.take_damage()`) either always pass a real direction, or default to `Vector3.ZERO` only
for tests/legacy callers where direction genuinely doesn't apply
(`tests/test_ship_combat.gd:67,81,85` calls `take_damage(60.0)` with no direction, deliberately).
`apply_hit()`'s zero-vector fallback — skip the facing calculation, use the baseline
`broadside_armor_multiplier` — is the correct behavior for a hit with unknown direction; it must
not invent a bow/stern crit or bonus it didn't earn. Confirmed by reading every caller and the
existing test suite's own use of the zero-vector default.

---

### 15. FiringSolver not connected to ShipCombat's auto-fire for chasers
**Status: FIXED (real, narrow gap; the described symptom itself wasn't reachable).** Verified:
auto-fire's `sides` array (`_physics_process`) and `_spawn_cannon_models()` both correctly gate
bow/stern on `ship_stats.has_bow_chaser`/`has_stern_chaser` already. The one real gap was
`fire_broadside()` itself — if ever called directly with `"bow"`/`"stern"`, it would fire from
`bow_markers`/`stern_markers` (populated by scene node name alone) with no flag check. Traced every
caller: `EnemyAI.gd` and `WorldManager.gd` only ever pass `"port"`/`"starboard"`, so this was dead
code today, not a live bug — but `fire_broadside()` now checks `has_bow_chaser`/`has_stern_chaser`
before firing bow/stern regardless, so it can't silently fire an unmounted chaser if a future
caller ever does pass "bow"/"stern" directly.

---

## Medium Priority Bugs

### 16. ShipStats.cannon_range may exceed actual projectile reach
**Status: NOT A BUG (verified — already fixed and test-locked).** The `85.0`/`100.0` values
flagged are only `ShipStats.gd`'s bare script defaults, never used by a real ship — every one of
the 11 real ship/enemy `.tres` resources authors its own `cannon_range`/`cannon_speed`, and
`tests/test_combat_integration.gd`'s
`test_authored_cannon_range_is_actually_reachable_by_a_cannonball` already asserts, for every one
of those 11 resources (plus their chaser range, where applicable), that `cannon_range` is reachable
given `cannon_speed` and the documented ~0.70s flight time. This is regression-tested, not a live
gap.

---

### 17. CampaignManager._advance_level uses different thresholds for different conditions
**Status: NOT A BUG.** `ObjectiveData` has both `target_count` and `target_value` fields by
design — `REACH_ISLAND_TIER` is a level-check using `target_count`, everything else uses
`target_value`. Both `CampaignManager` and `SeasonalEventManager` dispatch this consistently, and
`ObjectiveDispatch` centralizes the pattern.

---

### 18. EnemySpawner.spawn_hunter called with faction resource but may need ShipStats
**Status: NOT A BUG.** `spawn_hunter(faction: Resource)` takes a plain `Resource`;
`FactionManager` passes a `FactionData` resource. No type mismatch.

---

### 19. SaveManager.load_game migration only handles version 0 to 1
**Status: Confirmed, intentionally left as-is.** No schema version 2+ exists yet, so this isn't an
active bug. The fail-loud behavior (push_error + empty dict on an unknown future version) was a
deliberate choice, confirmed during this pass, over a best-effort/degraded load — whoever bumps
`SAVE_SCHEMA_VERSION` next must add the matching `_migrate()` arm at that time.

---

### 20. Island.capture_island doesn't remove enemy defenders
**Status: NOT A BUG.** `ShipController._on_died()` already schedules `queue_free()` on any
non-player ship (after its 2-second sinking sequence), the same path every other destroyed enemy
ship goes through — including the island defender. No separate cleanup was needed.

---

### 21. ResourceManager.add_resource doesn't emit changed signal for new resource types
**Status: FIXED (stronger than originally proposed).** `add_resource()` now rejects (push_error,
no-op) any resource type not already declared in `max_storage` and `base_storage`, rather than
silently granting it 999999 (effectively unlimited) capacity. Every resource type is meant to be
part of the authored data schema, not created ad hoc at runtime.

---

### 22. ShipController._apply_tech_modifiers clamps health but doesn't handle captain change
**Status: Real as described, but not reachable — left unchanged.** The only place
`active_captain` is ever reassigned (`IslandMenu._on_make_active_pressed()`) is a full ship-swap
flow that already calls `ShipDamage.restore_all()` for a full heal; `_apply_tech_modifiers()` only
fires from `TechManager.tech_recalculated`, where `active_captain` doesn't change. This is also
already recorded as a known, deliberately-deferred design gap in `docs/05_CURRENT_SYSTEMS.md`'s
"Post-M5 static bug sweep" section (proportional rescaling needs a product decision — refill to
full? scale proportionally? — not a mechanical fix).

---

### 23. EmpireManager.add_notoriety emits signal even for negative amounts
**Status: NOT A BUG.** Negative notoriety is clamped to 0.0 before the signal emits, and no region
*deactivation* logic exists to misfire from it (`_check_region_activation` only ever activates,
never deactivates). Safe as written.

---

### 24. CampaignManager._for_each_matching doesn't handle chapter completion during iteration
**Status: NOT A BUG.** `_complete_chapter()` already guards on
`completed_chapter_ids.has(chapter.chapter_id)` and returns immediately on a repeat call — calling
it more than once for the same chapter is already a no-op.

---

### 25. ShipCombat.fire_broadside doesn't validate side parameter
**Status: FIXED.** `fire_broadside()` now `push_warning`s on an unrecognized `side` string instead
of silently returning `false`, so a typo reads as a warning during testing rather than "nothing
fired, no reason given."

---

## Low Priority / Design Concerns

### 26. EmpireManager notoriety decay rate is hardcoded
**Status: BY DESIGN, deferred.** Same category as #34 below — a data-driven-balance backlog item
(move to a `Resource`), not a defect. Not actioned in this pass.

---

### 27. FleetManager.equip_module doesn't check module compatibility with ship
**Status: FIXED.** Added `ShipModuleData.compatible_ship_classes: Array[int]` (empty = fits every
class — the correct default; none of the 10 existing authored modules restrict themselves) and
`ShipModuleData.is_compatible_with_class()`. `FleetManager.equip_module()` now checks it against
the owned ship's `ship_stats.ship_class` before allowing the equip.

---

### 28. Island.build_structure allows building on enemy islands
**Status: FIXED.** `build_structure()` now returns `false` immediately unless
`island_data.is_owned_by_player()` (the same helper added for #4/#6).

---

### 29. TutorialManager not reviewed - potential similar issues
**Status: REVIEWED — no bug found.** Follows the same save/load conventions as `CampaignManager`
correctly, but has much simpler state (a boolean completion flag + an unlock ID list, no
sequentially-progressing chapter index), so it doesn't have an equivalent out-of-order-completion
surface to begin with.

---

### 30. SeasonalEventManager not reviewed - potential similar issues
**Status: REVIEWED — no bug found.** Explicitly defensive against the failure mode this item
worried about: `_ensure_current_window()` resets progress whenever the active window changes,
preventing stale progress from a past window carrying forward. Save/load duplicates nested
dictionaries correctly (`duplicate(true)`).

---

## Architecture / Code Quality Issues

### 31. Multiple managers use DirAccess to scan resource directories at runtime
**Status: Confirmed real in `EmpireManager.gd` (region loading, `_ready()`); the `FactionManager`
and `ResourceLookup` instances this item originally cited were not found in the current
codebase** (already fixed/refactored out before this pass, independent of it). Left as an
explicitly out-of-scope architecture item for this fix batch — it's a real export-compatibility
risk, but a repo-wide pattern change deserves its own dedicated pass rather than being bundled into
a bug-fix batch.

---

### 32. Many managers are autoloads but access scene nodes via get_tree()
**Status: Confirmed, out of scope for this pass.** A repo-wide architectural pattern, not an
isolated bug — deferred to a dedicated refactor pass.

---

### 33. Inconsistent signal naming conventions
**Status: Confirmed, out of scope for this pass.** Cosmetic/API-consistency concern, not a defect.

---

### 34. Magic numbers throughout codebase
**Status: Confirmed, out of scope for this pass.** Same category as #16/#26 — data-driven-balance
backlog, not a defect fixable without a broader balance-authoring pass.

---

### 35. No validation on ResourceLoader.load() results
**Status: Confirmed, out of scope for this pass.** A repo-wide defensive-programming pattern, not
an isolated bug — deferred to a dedicated pass.

---

## Test Coverage Gaps

### 36. No integration tests for save/load round-trip with all managers
**Status: FIXED.** Added `tests/test_save_load_full_round_trip.gd` — a real `SaveManager.save_game()`
/ `load_game()` pass driving distinct state into Economy, Fleet, Tech, Faction, and Empire
together, asserting all of it survives the same round trip.

---

### 37. No tests for offline catch-up with fleet missions
**Status: FIXED.** Added `test_offline_catch_up_advances_active_fleet_mission` to
`tests/test_save_manager_offline.gd` — asserts a real trade mission's gold payout actually fires
during offline catch-up, not just that a tick count was computed correctly.

---

### 38. No tests for campaign chapter gating edge cases
**Status: Partially already covered, one real gap fixed.**
`test_the_overshoot_case_cascades_through_already_satisfied_gates` (existing) already covers
multiple-gates-satisfied overshoot and region-activation-before-chapter-start. The specific gap —
`completed_chapter_ids` with a hole in the middle (e.g. ch1 and ch3 marked done, ch2 not) — was not
covered; added `test_catch_up_handles_completed_chapter_ids_with_a_gap` to
`tests/test_campaign_manager.gd`.

---

## Summary

Of 33 original items: **12 fixed**, **11 confirmed not-a-bug** (stale report, already-correct
code, or already covered by an existing regression test), **2 already fixed by prior milestones**,
**2 real-but-unreachable** (left unchanged, with reasoning recorded), **3 confirmed real but
deferred as balance/design questions**, **5 confirmed real but deferred as repo-wide architecture
concerns** (own dedicated pass warranted), and **3 test-coverage gaps closed** (2 new files/tests,
1 existing gap found already partially covered). Every item was ultimately traced to a concrete
verdict — nothing was left as "not investigated." Full detail and reasoning for every disposition
is in `docs/05_CURRENT_SYSTEMS.md`'s "BUG_REPORT.md fix pass (2026-09-14)" entry.

---

*End of Report*
