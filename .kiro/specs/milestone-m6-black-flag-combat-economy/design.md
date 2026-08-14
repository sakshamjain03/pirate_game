# Design Document — M6 Black Flag Combat & Island Economy

## Guiding constraints

From `AGENTS.md`, non-negotiable and repeated here because M6 touches the two systems most at
risk of being duplicated:

- **Never duplicate systems.** `Island.upgrade_structure()` and `BuildingData.next_upgrade`
  already exist and are already wired into `IslandMenu`. M6 authors *data* to make them work;
  it does not write a second upgrade path.
- **Data-driven balance.** Every number in this milestone lives in a `.tres`. A `.tres` that
  sets a property the script does not `@export` fails silently — always check the script's real
  exported properties first (this has caused real bugs: `docs/05_CURRENT_SYSTEMS.md` D3/D14).
- **Composition over inheritance.** New behaviour goes into new focused components hung off
  `ShipController`, not into a deeper class hierarchy.
- **Signals over direct references.**

---

## Part A — Combat

### A1. Ammunition (`AmmoData`)

New resource script `scripts/combat/AmmoData.gd`:

```gdscript
@tool
class_name AmmoData extends Resource

@export var ammo_id: String = "round"
@export var display_name: String = "Round Shot"

@export_group("Damage")
@export var hull_damage_mult: float = 1.0
@export var sail_damage_mult: float = 0.0
@export var crew_damage_mult: float = 0.0

@export_group("Effects")
@export var speed_penalty: float = 0.0        # fraction of top speed removed
@export var speed_penalty_duration: float = 0.0

@export_group("Ballistics")
@export var speed_mult: float = 1.0           # multiplies ShipStats.cannon_speed
@export var spread_degrees: float = 0.0       # grape spreads, round does not
@export var projectiles_per_cannon: int = 1   # grape fires a cluster
```

Authored instances under `resources/combat/ammo/`: `RoundShot.tres`, `ChainShot.tres`,
`GrapeShot.tres`.

`ShipCombat.fire_broadside()` gains a `current_ammo: AmmoData` and passes it to
`_spawn_cannonball()`, which applies `speed_mult`, `spread_degrees` and loops
`projectiles_per_cannon`. `Cannonball` carries the `AmmoData` reference and hands it to the
damage call on impact. **This extends the existing firing path — it does not replace it.**

### A2. Damage model (`ShipDamage` component)

Today `ShipCombat.current_health` is the entire model. Rather than bolt pools onto
`ShipCombat` (which already owns firing, markers, cooldowns, and cannon models at 187 lines),
M6 adds a focused sibling component `scripts/world/ShipDamage.gd`:

```gdscript
class_name ShipDamage extends Node

signal pool_changed(pool: String, current: float, maximum: float)
signal destroyed()

@export var ship_stats: ShipStats

var hull: float
var sails: float
var crew: float
```

`ShipStats` gains `@export` fields: `max_sails: float`, `max_crew: float`,
`stern_crit_multiplier: float`, `stern_arc_degrees: float`, `min_speed_fraction: float`.

`apply_hit(amount, ammo, hit_direction)`:
1. Compute the stern arc: angle between `hit_direction` and the ship's `+Z` (aft). Inside
   `stern_arc_degrees` → multiply total damage by `stern_crit_multiplier`.
2. Split damage across pools by the ammo's three multipliers.
3. Emit `pool_changed` per affected pool.
4. `hull <= 0` → emit `destroyed`.

**Migration:** `ShipCombat.take_damage()` is kept as a thin forwarder into `ShipDamage` so
every existing caller (`Cannonball`, tests, `EnemyAI`) keeps working, and `ShipCombat.died`
keeps firing. This is the single most important compatibility decision in the milestone —
`test_ship_combat.gd` must keep passing unchanged.

**Save compatibility (Req 2.7):** `load_save_data()` defaults any missing pool to its maximum.

### A3. Speed coupling

`ShipMovement` reads its cap from `ship_stats.max_speed`. M6 introduces a multiplier queried
from `ShipDamage`:

```
effective_max_speed = max_speed * lerp(min_speed_fraction, 1.0, sails / max_sails) * chain_debuff
```

Applied inside `ShipMovement` at the point the throttle target is computed. **Do not touch the
buoyancy/stability block** — that code was stabilized across four separate root causes and is
documented in `docs/09_VISUAL_BUG_TRACKER.md` V1. Sail damage scales the *speed target only*.

### A4. Boarding (`BoardingSystem`)

New `scripts/combat/BoardingSystem.gd`, a `Node` under `World/Systems` alongside
`DockingSystem` (mirroring the pattern `Island.gd` already uses to find `Systems/DockingSystem`).

Resource `scripts/combat/BoardingData.gd` → `resources/combat/Boarding.tres`:
`hull_threshold` (0.3), `range` (12.0), `loot_multiplier` (2.0), `win_crew_loss_fraction`,
`lose_crew_loss_fraction`, `attacker_advantage`.

Resolution is deterministic, per Req 3.2:

```
attacker_strength = player.crew * captain.boarding_modifier * attacker_advantage
defender_strength = enemy.crew
success = attacker_strength > defender_strength
```

`CaptainData` gains `@export var boarding_modifier: float = 1.0`.

The prompt reuses `WorldHUD`; the result reuses `LootDrop`/`LootTableData` with the multiplier
applied. No new input scheme (Req 3.6).

### A5. AI differentiation

`EnemyAI` already has a working five-state machine and (as of 2026-08-09) three-feeler
obstacle avoidance. M6 does **not** rewrite it. It adds a `AIProfileData` resource
(`aggression`, `preferred_combat_distance`, `flee_health_threshold`, `broadside_angle_tolerance`,
`ammo_preference`) so a Galleon fights like a Galleon and a Sloop harries. Profiles are
assigned per ship class / faction.

---

## Part B — Economy

### B1. Building levels — the central data change

`BuildingData` gains:

```gdscript
@export var level: int = 1
@export var required_island_tier: int = 1
@export var storage_bonus: Dictionary = {}   # replaces the hardcoded warehouse constants
```

**The core of this milestone is authoring 5 linked `.tres` per production building.** Naming
convention, mandatory for the restore path: `<building>_l<level>`, e.g. `lumber_mill_l1` …
`lumber_mill_l5`. Files: `resources/buildings/LumberMill_L1.tres` … `_L5.tres`.

Level *N* sets `next_upgrade` to the level *N+1* resource. Level 5 leaves it unset (Req 5.3).

**Curves** (authored, not computed at runtime):

| Level | Production | Cumulative cost factor |
|-------|-----------|------------------------|
| 1     | ×1.0      | base                   |
| 2     | ×1.8      | ×2.5                   |
| 3     | ×3.2      | ×6                     |
| 4     | ×5.5      | ×14                    |
| 5     | ×9.0      | ×32                    |

Cost grows faster than production — that gap is exactly what forces combat loot into the loop
(Req 7.4).

### B2. `Island.restore_buildings()` must change

This function currently hardcodes a **10-entry `building_id` → path dictionary**. With 5 levels
per building that becomes 50 entries and will rot immediately. Replace the dictionary with a
convention-based load:

```gdscript
const BUILDING_DIR := "res://resources/buildings/"

func _resolve_building(building_id: String) -> BuildingData:
    # "lumber_mill_l3" -> "LumberMill_L3.tres"
    ...
```

Resolution must be by directory scan or deterministic name mapping, and must fail loudly
(`push_error`) on an unresolvable id rather than silently skipping — silent skipping here would
delete a player's building on load.

### B3. Island tier

`Island.gd` gains:

```gdscript
signal tier_changed(new_tier: int)
func get_island_tier() -> int   # derived from built_buildings levels
```

Derivation (authored in `IslandData`, not hardcoded): tier = floor(average building level),
clamped 1–5, requiring at least N buildings for tiers above 1.

`EmpireManager` listens and the HUD announces via the existing `announce_event()`.

### B4. Storage from Warehouse level

Delete the hardcoded block in `ResourceManager.recalculate_storage_capacity()` and sum
`storage_bonus` from every constructed building instead. This is a **replacement**, not an
addition — leaving the old constants alongside the new sum would double-count.

### B5. Cap feedback

`WorldHUD` tints a resource readout when `current >= max_storage` (Req 7.3). Small change,
large retention effect: it is the signal that tells the player to go spend.

---

## Part C — Deferred M2 polish

- **C1 Docking camera (M2 5.3):** `CameraRig` gains `enter_docked_view()` /
  `exit_docked_view()` tweening `target_zoom`/`target_pitch` to authored docked values,
  driven by the existing `DockingSystem` signals.
- **C2 Rebinding (M2 6.3):** `InputManager` gains `rebind_action(action, event)` +
  `reset_to_defaults()` over `InputMap`; `SettingsManager` persists to its existing
  `ConfigFile`; `SettingsMenu` gains a Controls tab. Reject unbinding essentials (Req 9.3).

---

## Testing strategy

New GUT test files, flat under `tests/` (GUT's `-gdir` does not recurse here):

- `test_ammo_properties.gd` — each ammo type routes damage to the intended pool; multipliers
  never produce negative pools.
- `test_damage_model.gd` — hull zero destroys; sails reduce speed but never below
  `min_speed_fraction`; crew zero disables firing; stern arc crits apply only inside the arc;
  save round-trip with missing pools defaults to full.
- `test_boarding.gd` — resolution is deterministic for fixed crew counts; success yields the
  configured multiplier; failure leaves the enemy alive.
- `test_building_levels.gd` — **every** level 1–4 resource has a `next_upgrade` whose `level`
  is exactly one higher; level 5 has none; production and cost are monotonically increasing
  across each chain. This test is the guard against the exact defect M6 exists to fix.
- `test_island_tier.gd` — tier derivation and clamping; `tier_changed` fires once per change.
- `test_storage_scaling.gd` — storage equals the sum of `storage_bonus`, with no double count.

`test_ship_combat.gd` must continue to pass **unmodified** — it is the compatibility guard on
the A2 migration.

Baseline before M6: 103 tests, 102 passing, 1 known failure
(`test_property_21_lod_distance_transitions`, a tracked LOD gap). Any other failure, or a drop
in total count, is a regression.

Manual/visual only (cannot be verified headlessly — state this rather than claiming a pass):
boarding prompt feel, docked camera framing, building model changes, cap-tint legibility.
