# Implementation Plan: Milestone M21 — Performance, Security & Debt Zero

## Overview

Depends on **M13** (device profiling and the reference-device baseline) and **M10** (ocean LOD,
which the partition work integrates with rather than replaces). **M17 is a soft dependency** —
save integrity is worth more once entitlements have money value, but nothing here requires it.

Read `docs/05_CURRENT_SYSTEMS.md` and `docs/09_VISUAL_BUG_TRACKER.md` before Task 1 to confirm
which defects are **still** open — this spec was written 2026-08-27 and some may have been closed
since. Then read this spec's `design.md`, particularly §3's suspension hazard and §4's
warn-don't-delete rule.

**Scope discipline is a requirement here, not advice.** Requirement 7.3 forbids refactoring
anything not implicated in a listed defect. A debt milestone is where "while we're in here"
becomes a rewrite.

Scaffolded 2026-08-27 as a forward-planning artifact alongside M16–M21; Rule 8 still governs.

## Tasks

### Wave 0 — Standing defects

- [ ] 1. Diagnose V5's actual root cause — capture the real stack, identify the node and material
        slot, and check `KenneyMaterialApplier` and `ShipVisuals._rebuild_model()` first
        (`design.md` §5).
  - **Verify:** the root cause is named specifically — which node, which slot, why null. "Added a
    null guard" is not a diagnosis and does not satisfy this.
  - _Requirements: 3.1_

- [ ] 2. Fix V5 at the root cause. Suppressing the warning or hiding it behind a guard is
        explicitly forbidden (Requirement 3.2) — that is what failed the first time.
  - **Verify:** startup log is free of material-null errors, confirmed by reading an actual
    startup log, not inferred.
  - _Requirements: 3.2, 3.3_

- [ ] 3. Write `tests/test_material_nulls.gd` asserting the error condition is absent.
  - **Verify:** the single-file GUT run passes; reverting the fix makes it fail.
  - _Requirements: 3.4_

- [ ] 4. Extend the existing D39 avoidance path so AI ships do not beach — weighted so pursuit
        cannot fully override it, but not so heavily that AI refuses to attack coastal islands.
  - **Verify:** steer a ship at an island repeatedly; it does not beach. Order an AI to attack a
    coastal island; it still reaches it. **Both directions** — over-correction here is a worse bug.
  - _Requirements: 4.1, 4.2_

- [ ] 5. Implement beaching recovery — a ship stationary under power near land steers off.
  - **Verify:** force a beaching; confirm the ship recovers within a bounded time rather than
    remaining stuck.
  - _Requirements: 4.3_

- [ ] 6. Write `tests/test_ship_grounding.gd` covering both directions from Task 4 plus recovery.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 4.4_

- [ ] 7. **Decide** the `CurrentHealth`-on-upgrade policy (`design.md` §7 recommends preserve-ratio)
        and record the decision and reasoning in `docs/05_CURRENT_SYSTEMS.md`.
  - **Verify:** the decision is written down. This item cannot proceed on an unrecorded decision.
  - _Requirements: 5.1, 5.2_

- [ ] 8. Implement the decision consistently across **all four** paths that change max health:
        upgrades, modules, captain modifiers, and tech. The captain-modifier path has prior defect
        history (D14) — check it specifically.
  - **Verify:** `tests/test_health_on_upgrade.gd` asserts identical behaviour through all four.
  - _Requirements: 5.3, 5.4_

- [ ] 9. Add player-facing feedback when health changes on upgrade, so it does not read as a bug.
  - **Verify:** headful observation of a mid-battle upgrade — report it as a visual check.
  - _Requirements: 5.5_

- [ ] 10. **Checkpoint — standing defects closed**
  - Full GUT suite at or above baseline.
  - Confirm V5's fix addresses a named root cause, not a suppressed warning. Re-verify this
    independently — V5 has already been closed once and reopened.
  - Confirm the `CurrentHealth` decision is recorded and applied to all four paths.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

### Wave 1 — Performance

- [ ] 11. Measure the current frame rate on the **reference device** with the M10 expanded map
         fully populated, and record the number.
  - **Verify:** a real number from real hardware. A desktop measurement does not satisfy this and
    must not be recorded as if it did.
  - _Requirements: 1.6_

- [ ] 12. Implement `scripts/world/SpatialPartition.gd` — uniform grid, updated on significant
         movement rather than per-frame.
  - **Verify:** `test_spatial_partition.gd` asserts `query_radius` returns exactly the entities a
    brute-force scan would.
  - _Requirements: 1.1_

- [ ] 13. Implement frustum and distance culling, sharing distance bands with the M10 ocean LOD
         from a single source rather than duplicating thresholds.
  - **Verify:** grep confirms one set of distance constants, read by both systems.
  - _Requirements: 1.2, 1.5_

- [ ] 14. For each entity type considered for suspension, name the gameplay state it owns and
         prove suspension does not lose it. Where unproven, reduce simulation rate instead of
         suspending (`design.md` §3).
  - **Verify:** travel far from a fleet mid-voyage, return, and confirm it arrived on schedule.
    Same for economy ticks and raid timers.
  - _Requirements: 1.3_

- [ ] 15. Re-measure on the reference device and confirm the frame target holds.
  - **Verify:** before-and-after numbers both recorded, both from real hardware.
  - _Requirements: 1.4, 1.6_

- [ ] 16. Check for visible pop-in at every culling boundary.
  - **Verify:** headful pass sailing across each threshold — report as a visual observation.
  - _Requirements: 1.2_

### Wave 2 — Save integrity

- [ ] 17. Add the integrity stamp to `SaveManager` — digest the already-serialized payload once at
         the existing write point, not by re-walking the object graph.
  - **Verify:** save and load timing on the reference device is unchanged within noise.
  - _Requirements: 2.1, 2.3, 2.6_

- [ ] 18. Implement mismatch behaviour — **warn and continue.** Never delete, never refuse, never
         silently reset.
  - **Verify:** hand-edit a save; confirm the warning appears and the save still loads and plays.
    A false positive must never cost someone their empire.
  - _Requirements: 2.2_

- [ ] 19. Apply the same treatment to `EntitlementManager`'s account data.
  - **Verify:** hand-edit the account file; confirm the same warn-and-continue behaviour.
  - _Requirements: 2.5_

- [ ] 20. Audit every comment, UI string, and doc line touching this work for any claim or
         implication of anti-cheat or security, and remove it.
  - **Verify:** grep for "cheat", "secure", "protect", "tamper-proof" across the diff; each
    remaining hit is justified.
  - _Requirements: 2.4_

- [ ] 21. Write `tests/test_save_integrity.gd` — detection, and the warn-not-delete behaviour.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 2.1, 2.2_

### Wave 3 — Compositions, documentation, final checkpoint

- [ ] 22. Implement region mixed-role enemy compositions as `Resource` data, extending M10's
         per-region enemy work rather than replacing it.
  - **Verify:** add a composition `.tres` and confirm it takes effect with no script change.
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 23. Update `docs/05_CURRENT_SYSTEMS.md` (M21 section plus the Requirement 5 decision),
         `docs/09_VISUAL_BUG_TRACKER.md` (close V5 and V8, or state precisely what remains),
         `docs/14_SYSTEM_INVENTORY.md` (partitioning and integrity rows), and
         `docs/17_MONETIZATION.md` §4.4 (reconcile, preserving the not-anti-cheat statement).
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M21 system.
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 24. **Checkpoint — M21 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Confirm V5 and V8 are genuinely closed, verified independently against the code — not
    accepted from a self-report. V5 in particular has a history of premature closure.
  - Confirm before-and-after performance numbers exist, from the reference device.
  - Confirm nothing in the diff claims anti-cheat.
  - Confirm Requirement 7.2 and 7.3 held: no gameplay features added, no unrelated refactors.
  - State explicitly which checks needed real hardware and whether they got it.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **Task 14 is where this milestone could quietly break the game.** Suspending an entity that owns
  gameplay state loses that state, and the loss is invisible until a player returns to a fleet
  that never arrived. Reduce simulation rate rather than suspending, unless suspension is proven
  safe for that specific entity type. The bug this creates would be intermittent, unreproducible,
  and blamed on save/load.
- **Task 2 is the second attempt at V5.** The first fix closed it and it reopened. Anything that
  makes the warning stop appearing without explaining why the material was null is the same
  mistake again.
- **Task 18's asymmetry is deliberate.** A false positive on save integrity — a partial write, a
  sync artifact — costs a real player their empire. A true positive costs a self-tamperer nothing
  the game cares about. Warn and continue; never do anything irreversible on a mismatch.
- Task 4's over-correction risk is real: an AI that never beaches because it refuses to approach
  land cannot attack coastal islands. Test both directions.
- Waves are largely independent. Wave 0 (defects) and Wave 2 (integrity) have no dependency on
  Wave 1 (performance), and Wave 1 is the only one that needs the reference device — if hardware
  access is a bottleneck, run the others first.
- Requirement 7.3 is load-bearing. Every task here touches code that could plausibly be improved
  in adjacent ways. Do not.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] },
    { "id": 1, "tasks": ["11", "12", "13", "14", "15", "16"] },
    { "id": 2, "tasks": ["17", "18", "19", "20", "21"] },
    { "id": 3, "tasks": ["22", "23", "24"] }
  ]
}
```
