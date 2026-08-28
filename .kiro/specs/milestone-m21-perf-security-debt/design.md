# Design Document: Milestone M21 — Performance, Security & Debt Zero

## 1. Why this design shape

**Measure first, on the right hardware.** Requirement 1.6 demands before-and-after numbers on the
reference low-end device. Optimizing against a development desktop optimizes the wrong thing —
a Windows machine running this project has an order of magnitude more GPU headroom than the 2020
midrange phone that actually decides whether the frame target holds.

**Extend the LOD system, don't parallel it.** M10 built ocean LOD and it works (it closed the last
standing test failure, 326/326). A second distance-based system with its own thresholds would
drift out of agreement with the first, and disagreement between two distance systems produces
pop-in that looks like a bug in neither. Requirement 1.5 forbids it.

**Integrity, not security.** Requirement 2 is a modest tamper *detector*, not a protection system.
The threat model is one player editing their own single-player save. There is no economy to
inflate and no other player to harm, because nothing gameplay-affecting is ever sold
(`docs/17_MONETIZATION.md` §4.4). Building more than detection here would be spending real effort
against an imaginary adversary — and Requirement 2.4 forbids even *claiming* more.

**Fix root causes.** V5 was closed once and reopened. Requirement 3.2 forbids suppressing the
warning, because that is how a defect gets closed a second time without being fixed.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/world/SpatialPartition.gd` | **New.** Grid or quadtree index over world entities. |
| `scripts/world/OceanController.gd` / LOD | **Changed.** Share distance thresholds with the partition rather than duplicating them. |
| `scripts/managers/SaveManager.gd` | **Changed.** Integrity stamp on write, verification on read. |
| `scripts/managers/EntitlementManager.gd` | **Changed.** Same treatment (Requirement 2.5). |
| `scripts/world/ShipVisuals.gd` or wherever V5 actually originates | **Changed.** Root-cause fix. |
| AI avoidance (the D39 code path) | **Changed.** Extended for V8. |
| `ShipStats` consumers — upgrades, modules, captain modifiers, tech | **Changed.** Consistent `CurrentHealth` policy. |
| `resources/enemies/composition_*.tres` | **New.** Mixed-role compositions. |
| `tests/test_spatial_partition.gd`, `test_save_integrity.gd`, `test_material_nulls.gd`, `test_ship_grounding.gd`, `test_health_on_upgrade.gd` | **New.** Flat under `tests/`. |

## 3. Spatial partitioning

A uniform grid, not a quadtree, unless profiling says otherwise. The world is a roughly flat ocean
with entities distributed across it — the case a uniform grid handles well and simply. A quadtree
buys adaptivity this distribution does not need, at the cost of code nobody will remember.

```
partition.update(entity, old_cell, new_cell)   # on significant movement only, not per-frame
partition.query_radius(center, r) -> entities
```

**Culling tiers** — each tier must be justified by a measurement, not assumed:

| Distance | Treatment |
|---|---|
| Near | Full simulation, full visuals |
| Mid | Full simulation, reduced visual fidelity |
| Far | Reduced-rate simulation, not rendered |
| Beyond | Suspended — **only where suspension is provably safe** |

**Requirement 1.3 is the hazard.** Suspending an entity that owns gameplay state is how a fleet
quietly stops existing. Before any entity type is suspended, name what state it owns and prove
suspension does not lose it. Economy ticks, fleet travel, and raid timers are all things a player
expects to continue while they are elsewhere on the map. When in doubt, reduce the rate rather
than suspend.

**Sharing thresholds with ocean LOD (Requirement 1.5):** the distance bands live in one place and
both systems read them. Two sets of constants that are meant to agree will not, eventually.

## 4. Save integrity

```
save_data.json  →  { "payload": {...}, "integrity": "<hmac-ish digest of payload>" }
```

A keyed digest over the serialized payload, with the key embedded in the build. **This is
obfuscation, not cryptography** — anyone who wants the key can extract it from the binary. That
is fine and expected: the goal is to make casual editing fail noticeably, not to make it
impossible.

**Behaviour on mismatch (Requirement 2.2) is the important part.** Warn, and let the player
continue:

> This save file appears to have been modified. You can keep playing — some things may not work
> as expected.

Never delete, never refuse to load, never silently reset. A false positive — a corrupted write, a
partial flush, a cloud-sync artifact — must not cost someone their empire. The false-positive cost
massively outweighs the true-positive benefit here, and the design should reflect that asymmetry
rather than treating a mismatch as an accusation.

Requirement 2.6 (no measurable slowdown): digest the serialized string once, at the existing write
point in `SaveManager.save_game()`. Do not walk the object graph a second time.

**Requirement 2.4 is a documentation constraint too.** No comment, no UI string, and no doc line
may describe this as anti-cheat or security. It is a corruption and casual-tamper detector.

## 5. V5 — root cause, not suppression

Known: four `Parameter "material" is null` errors at startup. Closed once as D32, reopened
2026-08-26 as D68. A defect that reopens usually means the first fix addressed a symptom.

Investigation order:

1. Get the actual stack — enable verbose stdout and identify which node and which material slot.
2. Determine whether the material is null because a resource failed to load, because a mesh has an
   empty surface slot, or because code writes a material before `_ready`.
3. Check `KenneyMaterialApplier` and `ShipVisuals._rebuild_model()` specifically — both write
   materials during construction, and `_rebuild_model()` destroys and recreates `_model_instance`,
   which is exactly where a null-slot window can open.

**Requirement 3.2 forbids `push_warning` suppression or a null-guard that hides it.** A null guard
that lets startup proceed without explaining *why* the material was null is the same fix that
failed the first time.

## 6. V8 — beaching

D39 partially addressed this. Extend that path (Requirement 4.2), do not add a second avoidance
system.

- **Avoidance:** island proximity as a steering influence on the existing AI path, weighted so it
  cannot be entirely overridden by pursuit.
- **Recovery (Requirement 4.3):** a ship detected as stationary-while-under-power near land steers
  off. This matters more than perfect avoidance — a rare beaching that self-corrects is a
  non-issue; one that strands a ship forever is a visible bug.

Hazard: over-weighting avoidance produces AI that will not attack a coastal island, which is a
worse bug than beaching. Requirement 4.4's test should cover both directions — a ship steered at
an island does not beach, **and** an AI ordered to attack a coastal island still reaches it.

## 7. `CurrentHealth` on upgrade

Requirement 5.1's deliverable is a **decision**, and the milestone cannot proceed on this item
without one. The three candidates:

| Option | Behaviour | Cost |
|---|---|---|
| **Preserve ratio** | 50/100 → upgrade to 200 max → 100/200 | Predictable; no free heal; recommended |
| **Preserve absolute** | 50/100 → 50/200 | Upgrading feels like a punishment |
| **Full heal** | 50/100 → 200/200 | Exploitable — upgrade mid-battle to heal |

**Preserve ratio is the recommendation**, and Requirement 5.5 (legibility) means whichever is
chosen must be shown: a health bar that changes on upgrade needs feedback, or it reads as a bug.

Requirement 5.3 is the part most likely to be done incompletely — max health is changed by
upgrades, modules, captain modifiers, and tech, and all four must apply the same policy.
D14 was a captain-stat-modifier defect, so that path in particular has history.

## 8. What cannot be verified headlessly

Per `CLAUDE.md`:

**Testable in GUT:** partition query correctness, save-integrity detection and the warn-not-delete
behaviour, absence of the V5 error condition, ship grounding and recovery, the `CurrentHealth`
policy across all four paths, composition data validity.

**Requires the reference device:** every performance number in Requirement 1. Frame rate is the
entire point of Requirement 1 and cannot be measured here — a desktop run proves nothing.
Requirement 1.6's before-and-after numbers must come from real hardware or the requirement is
not met.

**Requires a headful pass:** whether culling produces visible pop-in, and whether the
`CurrentHealth` feedback reads clearly mid-battle.
