# Design Document: Milestone M4 — Empire Escalation

## 1. Why this design shape

Every new system here extends an existing manager rather than replacing one:
`FactionManager` already tracks reputation and dispatches "hunter" ships — `EmpireManager` is a
sibling autoload that adds notoriety/region/raid logic on top of it, not a replacement.
`Island.gd` already spawns defenders and handles capture — region activation just gates whether
that existing logic runs, via one new check. `EnemySpawner` already weights spawn selection by
reputation — tier/notoriety scaling is one more multiplier applied at the same call site.

This keeps every task small: most tasks add a field, add a check, or add one new small script,
rather than rearchitecting a working system.

---

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/world/FactionData.gd` | Add `is_empire: bool = false` field |
| `resources/factions/RoyalNavy.tres` | Set `is_empire = true` |
| `resources/factions/SpanishEmpire.tres` | New file |
| `scripts/world/RegionData.gd` | New Resource class |
| `resources/world/regions/BeginnerWaters.tres`, `ContestedWaters.tres`, `ImperialWaters.tres` | New files |
| `resources/islands/VolcanoOutpost.tres` (or similar) | New ENEMY island owned by SpanishEmpire, for Region 3's second island |
| `scripts/managers/EmpireManager.gd` | New autoload — notoriety, region activation, raid simulation |
| `scripts/world/EnemySpawner.gd` | Add tier/notoriety scaling call at spawn time |
| `scripts/world/Island.gd` | Add region-active gate check before defender spawn / capture |
| `scripts/ui/RaidReportScreen.gd` + `scenes/ui/RaidReportScreen.tscn` | New |
| `scripts/ui/WorldHUD.gd` | Add notoriety display + region-activation notification |
| `scripts/managers/SaveManager.gd` | Persist `notoriety`, region active/dormant states, `home_island_id`, last-raid-check timestamp, pending `RaidReport` |
| `scripts/managers/FleetManager.gd` | Add a "Defend Home" assignment flag per owned ship |

---

## 3. EmpireManager responsibilities

```gdscript
# Autoload: EmpireManager
signal notoriety_changed(new_value: float)
signal region_activated(region_id: String)
signal raid_resolved(report: Dictionary)  # RaidReport shape, see §5

var notoriety: float = 0.0
var home_island_id: String = ""
var _regions: Array[RegionData] = []       # loaded at _ready() from resources/world/regions/
var _region_active: Dictionary = {}        # region_id -> bool
var _last_raid_check_unix: int = 0

func add_notoriety(amount: float) -> void
func _check_region_activation() -> void    # called on notoriety_changed
func is_region_active(region_id: String) -> bool
func get_region_for_island(island_id: String) -> RegionData
func compute_spawn_multiplier(region_tier: int) -> float   # Requirement 5
func _check_raid() -> void                  # periodic, Requirement 6
func _resolve_raid(attacking_faction: FactionData, region: RegionData) -> Dictionary
```

`EmpireManager` does not know about UI. It emits signals; `WorldHUD` and `RaidReportScreen`
subscribe. It does not directly manipulate `Island.gd` defender spawning — `Island.gd` asks
`EmpireManager.is_region_active(...)` itself (pull, not push), keeping the dependency direction
consistent with the existing codebase (Island already pulls from `FactionManager` and
`ResourceManager`).

---

## 4. Region activation gate — exact integration point

`Island.gd` already has logic that spawns defenders for ENEMY-type islands and exposes
`capture_island()`. Both entry points get one new guard clause:

```gdscript
func _should_be_active() -> bool:
    var region := EmpireManager.get_region_for_island(island_data.id)
    return region == null or EmpireManager.is_region_active(region.id)
```

- Defender spawn logic: `if not _should_be_active(): return` (no defenders spawn on a dormant
  island).
- `capture_island()`: `if not _should_be_active(): push_warning(...); return` — and
  `IslandMenu.gd`'s Colonize button checks the same condition to disable itself with a tooltip
  rather than letting the player click into a silent no-op.

`region == null` (an island with no region assignment) is treated as always-active — this is a
safety fallback, not an expected state once Requirement 2.3 is satisfied.

---

## 5. Raid resolution formula

```
defense_score = fortress_tier * 20 + watchtower_tier * 15 + (10 * num_ships_defending_home)
attack_score  = region_tier * 25 + notoriety * 0.3

repelled = defense_score >= attack_score

if not repelled:
    steal_fraction = clamp((attack_score - defense_score) / attack_score, 0.05, 0.25)
    stolen = { resource_name: floor(current_amount * steal_fraction) for each resource }
```

These constants are starting values, not sacred — they exist so the system is fully specified
and testable, not left to Gemini's on-the-spot judgment. Tune later via playtesting; tuning is a
data change to these constants, not a redesign.

`RaidReport` shape (Dictionary, matching the project's existing preference for plain data over
custom Resource classes for one-shot event payloads — see `LootTableData.roll()`'s Dictionary
return for precedent):

```gdscript
{
  "faction_id": String,
  "repelled": bool,
  "stolen": Dictionary,   # resource_name -> int, empty if repelled
  "timestamp_unix": int,
}
```

---

## 6. Correctness Properties

### Property M4-1: Notoriety never goes negative
*For any* sequence of notoriety-increasing and notoriety-decreasing events, `EmpireManager.notoriety`
is always ≥ `0.0`.
**Validates: Requirement 3.4**

### Property M4-2: Notoriety changes always emit the signal with the new value
*For any* call to `add_notoriety(amount)` or the idle-decay tick, `notoriety_changed` fires
exactly once per change with an argument equal to the resulting `notoriety` value.
**Validates: Requirement 3.5**

### Property M4-3: Region activation is monotonic and one-shot
*For any* region, once `region_activated(region_id)` has fired for it, it never fires again for
that region, and `is_region_active(region_id)` never returns to `false` afterward within the same
save.
**Validates: Requirement 4.1**

### Property M4-4: Dormant regions never spawn defenders or allow capture
*For any* island belonging to a dormant region, `Island.gd`'s defender-spawn path and
`capture_island()` both no-op (verified via a test double / signal spy showing zero defenders
spawned and zero faction-ownership change attempted).
**Validates: Requirement 4.2**

### Property M4-5: Spawn multiplier is pure and monotonic in tier
*For any* fixed `notoriety`, `compute_spawn_multiplier(tier)` is non-decreasing as `tier`
increases from 1 to 3, and calling it twice with identical inputs returns identical output.
**Validates: Requirement 5.2, 5.3**

### Property M4-6: Non-empire factions are never scaled
*For any* spawn of a faction with `is_empire == false`, the effective stat multiplier applied is
always `1.0` regardless of region tier or notoriety.
**Validates: Requirement 5.4**

### Property M4-7: Raid resolution is deterministic given its inputs
*For any* fixed `(defense_score, attack_score)` pair, `_resolve_raid`'s `repelled` outcome and
`steal_fraction` (if not repelled) are the same every time — the raid **attempt** may be
probabilistic (Requirement 6.3), but its **resolution** given a decided attempt is not.
**Validates: Requirement 6.4**

### Property M4-8: Stolen resources never exceed what's stored
*For any* raid resolution, for every resource in `stolen`, `stolen[resource] <= current_amount`
for that resource at the time of the raid.
**Validates: Requirement 6.5**

### Property M4-9: Only one unshown RaidReport exists at a time
*For any* sequence of raid resolutions, if a `RaidReport` has not yet been shown to the player,
a new raid resolution replaces it rather than queuing a second one (prevents a backlog of stale
reports after long absences) — the player always sees the most recent raid.
**Validates: Requirement 6.6, 7.2**

### Property M4-10: Save/load round-trips all new persisted state
*For any* valid combination of `notoriety`, per-region active/dormant flags, `home_island_id`,
and a pending `RaidReport`, saving then loading restores all of them exactly.
**Validates: Requirement 3.6, 4.6, 6.6**

---

## 7. Manual/visual verification checklist (cannot be property-tested)

- Region 1 is active and playable from a fresh save with `notoriety = 0`.
- Destroying Royal Navy ships and colonizing islands visibly increases the HUD notoriety number.
- Crossing Region 2's threshold visibly flips SkullCove/FrozenIsland from "dormant" (no
  defenders, disabled Colonize button) to active.
- A raid, once triggered (may need to temporarily lower the check interval for testing), shows
  the `RaidReportScreen` on next World load with correct stolen amounts deducted from
  `ResourceManager`.
- Empire ships in Region 2/3 are visibly tougher (more hits to kill) than the same faction's
  ships would be in Region 1, if compared side by side.
