# Design Document: Milestone M26 — The Maelstrom

## 1. Why this design shape

**Assemble, don't rebuild.** Every mechanic the mode needs already exists for the campaign's
bounded encounters: temporary upgrades (`BattleUpgradeData` + `CombatModifiers`), the choice
screen (`UpgradeChoiceScreen`), population control (`EnemySpawner`), floating pickups
(`LootDrop`). The Maelstrom is a new *scene* and a new *run node* that wire those together under
a different pacing source. No second upgrade system, spawner or pickup type is added.

**Isolation is one flag, checked where the side effects already live.** A run could be made safe
by snapshotting and restoring campaign state, but that is fragile (every new manager is a new
restore bug). Instead the three places a kill leaks into the campaign each check one flag:

| Leak | Where it lives today | Guard |
|---|---|---|
| Notoriety on kill | `ShipController._on_died()` L378-383 | skip when `game_mode != CAMPAIGN` |
| Resources from a crate | `LootDrop._collect()` → `ResourceManager.add_resource()` | Maelstrom pickups carry no campaign keys; `_collect()` skips the grant loop when not in campaign |
| Campaign-drop crate on kill | `ShipController._spawn_loot()` | skip when not in campaign; `MaelstromRun` spawns its own drops from `EnemySpawner.enemy_destroyed` |
| Chapter objective / seasonal kill counters | `CampaignManager`/`SeasonalEventManager` connect to `current_scene/Systems/EnemySpawner` | Maelstrom scene uses `Run/EnemySpawner`, not `Systems/` |
| Autosave | `SaveManager._process()` requires scene name `World` | root named `Maelstrom` |

The mode flag lives on `SceneManager` because it already owns "what is loaded" and every scene
change goes through it.

## 2. New/changed files

| File | Change |
|---|---|
| `scripts/managers/SceneManager.gd` | `enum GameMode { CAMPAIGN, MAELSTROM }`, `var game_mode`, `func is_campaign() -> bool` |
| `scripts/world/ShipController.gd` | `_on_died()`: notoriety + `_spawn_loot()` only when `SceneManager.is_campaign()` |
| `scripts/combat/LootDrop.gd` | `_collect()`: resource-grant loop only when `SceneManager.is_campaign()`; `collected` still emits |
| `scripts/combat/EnemySpawner.gd` | `var spawn_profile_override: Callable` (returns `{cap, interval, strength, pool}`); `get_active_max_enemies()`/`get_active_spawn_interval()`/strength read it first |
| `scripts/combat/CombatModifiers.gd` | new effect keys: `pickup_radius_mult`, `regen_per_second`, `extra_projectiles`, `ram_damage_mult` (only the ones new upgrades need) |
| `scripts/combat/BattleUpgradeData.gd` | append new `Effect` values **at the end** of the enum (int-serialized in `.tres`) |
| **new** `scripts/modes/MaelstromBandData.gd` | one band |
| **new** `scripts/modes/MaelstromCurveData.gd` | bands, XP thresholds, drop table, Eights milestones, cap |
| **new** `scripts/modes/MaelstromRun.gd` | run state machine; implements the `UpgradeChoiceScreen` binding contract |
| **new** `scripts/modes/MaelstromResults.gd` | results panel (Retry / Main Menu) |
| **new** `scripts/modes/MaelstromRecord.gd` | best-run persistence helper (`get_save_data`/`load_save_data`) |
| **new** `scenes/modes/Maelstrom.tscn` | Ocean, PlayerShip, CameraRig, WorldUI, `Run` (MaelstromRun + EnemySpawner + WorldManager), storm wall, UpgradeChoiceScreen, results |
| **new** `resources/balance/MaelstromCurve.tres` | authored curve |
| **new** `resources/combat/upgrades/*.tres` | ≥ 12 new upgrades |
| `scripts/managers/SaveManager.gd` | additive: write/read the `maelstrom` section (omit when empty) |
| `scripts/ui/MainMenu.gd` + `scenes/ui/MainMenu.tscn` | additive: "The Maelstrom" button |
| **new** `tests/test_maelstrom_curve.gd`, `test_maelstrom_isolation.gd`, `test_maelstrom_run.gd` | |

## 3. Data

```gdscript
# MaelstromBandData.gd
@export var start_seconds: float = 0.0
@export var max_enemies: int = 3
@export var spawn_interval: float = 6.0
@export var strength_multiplier: float = 1.0
@export var ship_pool: Array[PackedScene] = []   # empty = EnemySpawner.enemy_scene
@export var boss_scene: PackedScene              # optional, spawned once at band start

# MaelstromCurveData.gd
@export var bands: Array[MaelstromBandData] = []           # sorted by start_seconds
@export var xp_per_level: Array[int] = []                  # plunder needed for level n+1; last value repeats
@export var drops: Array[Dictionary] = []                  # {kind, weight, amount, effect, duration}
@export var drops_per_kill: Vector2i = Vector2i(1, 2)
@export var eights_milestones: Array[Vector2i] = []        # (survived_seconds, eights)
@export var eights_cap_per_run: int = 25
@export var pickup_lifetime: float = 25.0
@export var base_pickup_radius: float = 6.0
func band_at(seconds: float) -> MaelstromBandData          # last band whose start <= seconds
func xp_for_level(level: int) -> int
func eights_for(seconds: float) -> int                     # sum of reached milestones, min(cap)
```

Starting curve (tune in play, not in review): bands at 0/60/150/270/420/600 s, cap 3→10, interval
6→1.5 s, strength 1.0→2.6, a boss at 420 s and 600 s. Eights milestones 120 s→2, 300 s→4,
480 s→6, 720 s→8, 900 s→10, cap 25. **Tier-5 heat's cap of 8 is already unverified on a phone;
a cap of 10 is more so — flag in the checkpoint.**

## 4. `EnemySpawner` override

The spawner already resolves the heat tier and falls back to exports when it is null
(`_heat_tier()`, `get_active_max_enemies()`, `get_active_spawn_interval()`). The override slots in
*above* the heat tier:

```gdscript
## M26 — when valid, replaces the heat-tier lookup. Returns
## {"cap": int, "interval": float, "strength": float, "pool": Array[PackedScene]}.
var spawn_profile_override: Callable = Callable()

func get_active_max_enemies() -> int:
	if spawn_profile_override.is_valid():
		return int(spawn_profile_override.call().cap)
	# ... existing heat-tier / export fallback unchanged
```

Strength goes through the same duplicate-`ShipStats` path `compute_spawn_multiplier()` uses.
Spawned enemies get `EnemyAI.provoke()` so they engage regardless of heat tier. Island-distance
checks are harmless (no islands in the group).

## 5. `MaelstromRun`

```
READY → RUNNING → (OFFERING ↔ RUNNING)* → ENDED
```

- `_ready`: `SceneManager.game_mode = MAELSTROM` (defensive; the menu already set it), load the
  curve, set `spawner.spawn_profile_override = _profile`, connect `spawner.enemy_destroyed` →
  `_on_kill`, player `ShipController.ship_destroyed` → `_end_run`,
  `UpgradeChoiceScreen.bind_encounter_manager(self)`.
- `_process`: `elapsed += delta` while RUNNING; on band change spawn the band's boss once.
- `_on_kill(enemy)`: `kills += 1`; roll `drops_per_kill` drops at the wreck position; each is a
  `LootDrop` whose `loot_data = {"kind": ..., ...}` and whose `collected` routes to `_on_pickup`.
- `_on_pickup(data)`: `plunder` → `xp += amount`, then while `xp >= xp_for_level(level)`:
  `level += 1; _pending_offers += 1`; `repair` → `modifiers.repair_pool("hull", amount)`;
  `powerup` → `modifiers.add_timed_effect(effect, duration)`; `keg` → damage every enemy within
  radius through its `ShipDamage` (the normal damage path, so kills still count).
- Offers: when `_pending_offers > 0` and no offer is open, pick 3 from `upgrade_pool` filtered by
  `modifiers.can_apply()`, weighted by `weight`, emit
  `upgrade_offer_requested(choices, level, 0)`. `apply_upgrade_choice(upgrade)` →
  `modifiers.apply_upgrade(upgrade)`; decrement; next offer on the following frame.
- `_end_run`: stop spawning (`spawning_enabled = false`), compute
  `eights = curve.eights_for(elapsed)`, `ResourceManager.add_resource(PREMIUM_CURRENCY, eights)`
  if > 0, update `MaelstromRecord`, `SaveManager.save_game()` (**the one explicit save of a run**,
  so the Eights and record persist), show results.

  **Hazard:** `SaveManager.save_game()` writes a `player` section from `player_ship` group — the
  Maelstrom ship is in that group. The results path must call a narrower save or remove the
  Maelstrom ship from `player_ship` before saving; otherwise the run's ship position/damage would
  overwrite the campaign ship's. Resolve in Task 8, guarded by the isolation test.
- Quit/Retry: `game_mode = CAMPAIGN` before `SceneManager.change_scene("MainMenu")`; Retry
  reloads `Maelstrom.tscn` with the mode still `MAELSTROM`.

`CombatModifiers` is a child of the player ship and is freed with the scene, so no `reset()` is
needed on exit — but call it at run start anyway in case the ship scene is ever reused.

## 6. Pickup magnet

`LootDrop.pickup_range` becomes `base_pickup_radius * modifiers.pickup_radius_mult`, read at
spawn by `MaelstromRun`. Drops within `2×` range drift toward the player (lerp on position,
Maelstrom only), which is the genre's core "sweep through the loot" feel.

## 7. New upgrades (≥ 12, all `.tres`)

Reusing existing effects at new magnitudes where possible, new effect keys only where needed:
Chain Hooks (special cooldown), Twin Decks (extra projectile), Oiled Blocks (reload), Salvager's
Eye (pickup radius), Ship's Carpenter (regen), Iron Prow (ram damage), Long Glass (range), Wide
Gunports (arc), Stormsails (speed), Grog Ration (rally crew), Tar Patch (repair sails),
Powder Monkey (damage, 3 stacks at low magnitude).

## 8. Persistence

`MaelstromRecord` holds `{best_seconds, best_level, runs}`. `SaveManager.save_game()` writes
`save_dict["maelstrom"]` only when `runs > 0`; `load_game()` reads it when present. This follows
the fragile-area rule: an optional section is omitted, never written empty.
