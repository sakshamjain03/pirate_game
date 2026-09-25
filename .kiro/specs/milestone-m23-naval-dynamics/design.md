# Design Document: Milestone M23 — Naval Dynamics

## 1. Why this design shape

Extend, never duplicate (`AGENTS.md`). Every mechanism here hangs off an existing seam:

- Stat changes go through `OwnedShipData.get_effective_stats()` — the one duplicate-never-mutate
  pipeline levels and modules already use. Components are a third term in it, not a new pipeline.
- Damage goes through `ShipDamage` (new `apply_impact()` beside the guarded `apply_hit()`).
- Hostility is `FiringSolver.are_hostile()`, the same rule cannonballs and auto-fire use.
- Firing stays in `ShipCombat.fire_broadside()`; aim error/misfire/ripple are added inside it.
- Collision behavior is one new composed component, `ShipCollisionHandler`, auto-added by
  `ShipController._ready()` so all 8 ship scenes get it without 8 scene edits.
- Balance lives in `.tres`: `RamConfig`, `CannonConfig`, `ShipProgressionConfig` +
  `ShipComponentData` ×5, `AIDifficultyData` ×4, two `PhysicsMaterial`s.

`BuoyancySimulator.gd` is not touched. `ShipMovement`'s yaw servo gets one scalar on its lerp
factor; the roll/pitch-preserving reconstruction is unchanged.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/world/ShipCollisionHandler.gd` | **New.** Hull prism, physics material, contact read, zone classification, ram damage, knockback, anti-stuck watchdog, `rammed` signal |
| `scripts/combat/RamConfigData.gd` + `resources/combat/RamConfig.tres` | **New.** Ram balance + zone matrix |
| `scripts/combat/CannonConfigData.gd` + `resources/combat/CannonConfig.tres` | **New.** Ripple, misfire, spread, glancing-hit balance |
| `scripts/combat/AIDifficultyData.gd` + `resources/combat/ai_difficulty/{Relaxed,Normal,Hard,Brutal}.tres` | **New.** Per-level enemy multipliers |
| `scripts/world/ShipComponentData.gd`, `scripts/world/ShipProgressionConfig.gd`, `resources/ship_components/*.tres`, `resources/ship_components/ShipProgressionConfig.tres` | **New.** Component catalog |
| `resources/materials/ShipHullPhysics.tres`, `TerrainPhysics.tres` | **New.** Low-friction PhysicsMaterials |
| `scripts/world/ShipMovement.gd` | `notify_contact()` + yaw-grace scalar |
| `scripts/world/ShipController.gd` | auto-add handler; soft world-edge spring before the hard clamp |
| `scripts/world/ShipDamage.gd` | `apply_impact()` |
| `scripts/world/ShipStats.gd` | `ram_damage_mult`, `impact_resistance`, `cannons_per_side` |
| `scripts/world/ShipCombat.gd` | gun count/generated markers, ripple, misfire, aim spread, AI difficulty terms |
| `scripts/combat/Cannonball.gd` | glancing-hit multiplier before `apply_hit()` |
| `scripts/combat/EnemyAI.gd` | ship whiskers, RAM run, difficulty multipliers |
| `scripts/combat/AIProfileData.gd` | `ram_tendency`, `ram_max_distance` |
| `scripts/managers/OwnedShipData.gd`, `FleetManager.gd` | component levels, gating, upgrade, save/migration |
| `scripts/managers/SettingsManager.gd`, `scripts/ui/SettingsMenu.gd` | `ai_difficulty` |
| `scripts/ui/IslandMenu.gd` | component rows |
| 7 enemy/boss `.tscn` | `collision_mask` 5 → 7 |
| `scenes/world/Island.tscn` | `physics_material_override` |
| ship `.tres` (player + enemy) | rebalanced `fire_rate`/`cannon_damage`, `cannons_per_side` |

## 3. Anti-stick physics

**Hull prism.** `ShipCollisionHandler._ready()` replaces each `BoxShape3D` on the parent's
`CollisionShape3D` children with a `ConvexPolygonShape3D` built from the same half-extents
(hx, hy, hz), forward = −Z:

```
bow tip        (0,    ±hy, -hz)
bow shoulders  (±hx,  ±hy, -0.45hz)
stern quarter  (±hx,  ±hy,  0.70hz)
transom        (±0.7hx, ±hy, hz)
```

Vertical walls → horizontal contact normals only (no pitching a hull up onto another), and the
AABB is the old box, so GodotPhysics' `ConvexPolygonShape3D::get_moment_of_inertia` (AABB-based)
returns identical inertia — the buoyancy tuning sees the same body. Centre of mass is custom
(mode 1) and unaffected.

**Material.** `physics_material_override = ShipHullPhysics.tres` (friction 0.12, bounce 0.15)
on every ship if none is set; `Island.tscn` gets `TerrainPhysics.tres` (friction 0.08, bounce 0).

**Yaw grace.** `ShipMovement.notify_contact(seconds)` sets `_contact_grace = max(...)`. In
`apply_movement()`: `if _contact_grace > 0: yaw_t *= CONTACT_YAW_AUTHORITY (0.15)` and decrement.
The handler calls it every tick it has any relevant contact and on every ram, so contact spin
survives long enough to rotate hulls off each other.

**Watchdog.** In contact, `controller.current_forward_input > 0.3`, forward speed < 0.6 m/s, for
`unstick_after` (1.2 s) → `apply_central_impulse(n_away * mass * unstick_speed)` plus
`angular_velocity += UP * ±unstick_yaw_rate` (yaw component only — the same split the servo uses),
then `unstick_cooldown`.

**World edge.** Inside `half − edge_margin` the ship gets
`apply_central_force(inward * mass * edge_spring * penetration)`; the existing hard clamp at
`half` is left in place (tests depend on it) but is now rarely reached.

**Enemy masks** 5 → 7 so enemy hulls collide with each other instead of interpenetrating.

**Ship whiskers.** `EnemyAI._get_ship_avoidance_turn()` — same 3-feeler shape as
`_get_avoidance_turn()`, mask `ship_avoid_mask` (1|2), `ship_avoid_distance` 20 m, excludes self
and the current ram target. Consulted only when terrain avoidance returns 0, so terrain always wins.

## 4. Ramming

**Contact read** (`_physics_process`): `PhysicsServer3D.body_get_direct_state(rid)`; for each
contact, collider must be a `ShipController` or `StaticBody3D` (cannonballs/areas ignored). The
contact position is global in Godot 4.3 despite the method name. Normal is re-oriented so it
points from the other body into this one.

**Pre-impact velocity.** Contacts are reported after the solver resolved them, so post-step
velocities are already bounced. Each handler snapshots `linear_velocity` at the end of its
`_physics_process` (`_pre_step_velocity`, stamped with `Engine.get_physics_frames()`, keeping the
previous one too); `get_pre_step_velocity()` returns the snapshot taken *before* the latest step
regardless of callback order.

**One resolver per pair.** For ship–ship contacts the handler with the lower `get_instance_id()`
resolves both sides; the other skips. Per-pair cooldown dictionary keyed by the other's id.

**Zone.** `classify_zone(local_z, half_len, cfg)`: `t = (local_z + half_len) / (2·half_len)`,
0 = bow tip. `t < bow_fraction (0.25)` → BOW; `t > 1 − stern_fraction (0.2)` → STERN; else
MIDSHIP. Static and pure for tests.

**Damage** to ship *me* from *other*:

```
closing  = (v_me − v_other) · n_to_other            # pre-step velocities; skip if < min_closing_speed
mu       = m_me·m_other / (m_me + m_other)          # terrain: mu = m_me
share    = 2·mu / m_me                              # 1.0 for equal masses; small for the heavier ship
scale    = pow(2·mu / reference_mass, mass_scale_exponent)
dmg_me   = damage_per_speed_sq · closing² · share · scale · matrix[my_zone][their_zone]
dmg_me  *= other.ram_damage_mult if their_zone == BOW
dmg_me  *= me.bow_armor_multiplier if my_zone == BOW
dmg_me  /= max(me.impact_resistance, 0.1)
terrain: dmg_me = damage_per_speed_sq · closing² · grounding_damage_mult (· bow armor if BOW)
```

Matrix (damage taken by *me*):

| me \ them | BOW | MIDSHIP | STERN |
|---|---|---|---|
| BOW | 0.6 | 0.2 | 0.25 |
| MIDSHIP | 1.0 | 0.3 | 0.5 |
| STERN | 0.9 | 0.4 | 0.4 |

With `damage_per_speed_sq = 0.35`: two Sloops, bow→midship at 12 m/s closing → victim ≈ 50
(half a Sloop hull), rammer ≈ 7.5.

`ShipDamage.apply_impact(amount, zone, crew_fraction, stern_penalty, stern_duration)` — hull −
amount, crew − amount·crew_fraction, STERN → `apply_speed_penalty()`; same `pool_changed` /
`destroyed` semantics as `apply_hit`. Non-hostile pairs: no damage, knockback still applies.

**Knockback.** Victim of a ram (the ship whose zone is MIDSHIP/STERN, or both for BOW–BOW):
`apply_impulse(n_to_victim · closing · knockback_fraction · m_other·m_victim/(m_sum), r_flat)`
where `r_flat` = contact − centre with y = 0, so the impulse yaws the hull but never rolls it.
Both ships `notify_contact(ram_yaw_grace)`. `rammed(other, my_zone, their_zone, damage)` is
emitted on both handlers. SFX `ram_impact`, splinter `CPUParticles3D` at the contact (Cannonball
splash pattern), player-involved → `hud.announce_event`.

## 5. Cannon fire

**Gun count.** `ShipCombat._rebuild_batteries()` (in `_ready`, and on the parent's
`ship_stats_changed`): if `get_guns_per_side() > markers.size()` for port/starboard, generate
`Marker3D` children named `PortMarkerGen<i>` spaced evenly between the first and last authored
marker's local Z (same X/Y/basis as the first). Generated markers get a cannon model like authored
ones. `get_guns_per_side() = (cannons_per_side if > 0 else authored marker count) +
cannon_component_bonus_guns` (the component adds to `cannons_per_side` on the effective stats, so
ShipCombat only reads one field).

**Ripple + misfire.** In `fire_broadside()` gun 0 spawns immediately (so `fire_broadside()` still
returns true and a cannonball exists synchronously — the invariant `test_battle_upgrades` and
`test_damage_model` rely on). Guns 1..n are scheduled `ripple_interval·i` later via
`get_tree().create_timer`, each rolling misfire first. Cooldown starts at the first gun.

**Aim spread.** `_aim_error_degrees(side)`: off-beam fraction = solver's
`get_broadside_angle(dir to target) / arc`, range fraction = dist / range;
`sigma = base_spread + off_beam_spread·off_beam_frac + range_spread·range_frac`, × AI-difficulty
`spread_mult` for enemies. Yaw error `randfn(0, sigma)`, pitch error `randfn(0, sigma·vertical_ratio)`.
Applied after the ammo spread rotation, before the spawn clearance push.

**Glancing hits.** `Cannonball._on_body_entered`: target's local hit Z → `classify_zone`; if
MIDSHIP, `incidence = |dir_flat · target_right|`, `damage *= lerp(glancing_damage_min, 1, incidence)`.

**Rebalance.** Reload per class (s): 1 → 5.0, 2 → 5.5, 3 → 6.5, 4 → 8.0, 5 → 10.0
(`fire_rate = 1/reload`); `cannon_damage ×1.5`. Enemy/boss stats scale the same way by their
`ship_class`. `cannons_per_side` authored by class: 3, 4, 5, 6, 8.

## 6. Components

`ShipComponentData`: `component_id`, `display_name`, `description`, per-level bonuses
(`max_health_bonus`, `impact_resistance_bonus`, `ram_damage_bonus`, `bow_armor_bonus`,
`turn_rate_bonus`, `stern_crit_reduction`, `max_speed_bonus`, `max_sails_bonus`,
`acceleration_bonus`, `cannon_damage_bonus`, `fire_rate_bonus`), `guns_at_levels: Array[int]`,
cost (`cost_gold_base`, `cost_wood_base`, `cost_iron_base`, `cost_growth`).
`apply_to(stats, level)`: every `*_bonus` is `stat *= 1 + bonus·(level−1)`; `bow_armor` and stern
crit move toward safer values and are clamped to their `@export_range`; `cannons_per_side += count
of guns_at_levels ≤ level` (resolved against the authored marker count when 0 → uses
`base_cannons_per_side` fallback 3).
`get_upgrade_cost(to_level, ship_class)`: `base · ship_class · cost_growth^(to_level − 2)`.

`OwnedShipData`: `MAX_LEVEL = 10`; `component_levels: Dictionary`;
`get_component_level(id)`, `can_upgrade_component(id)` (`< level`), `can_level_up_ship()`
(`level < MAX_LEVEL` and all ≥ `level`), `get_component_upgrade_cost(id)`,
`get_component_catalog()` (static, cached load of `ShipProgressionConfig.tres`).
Save: `"components": {id: level}`. Load: missing key → every component = saved level; unknown id →
`push_error`; unresolvable module path → `push_error` (was a silent skip).

`FleetManager.upgrade_component(index, id)`, `level_up_ship()` gains `can_level_up_ship()`.

## 7. AI difficulty

`AIDifficultyData`: `display_name`, `damage_mult`, `reload_time_mult`, `spread_mult`,
`detection_range_mult`, `ram_tendency_mult`.
`SettingsManager.ai_difficulty: int` (persisted under `[gameplay]`), `get_ai_difficulty_profile()`.
Applied at use time to ships where `not (is_in_group("player_ship") or is_in_group("friendly_ship"))`:
`ShipCombat` (ball damage, cooldown, spread), `EnemyAI` (detection, ram tendency).

| Level | damage | reload time | spread | detection | ram |
|---|---|---|---|---|---|
| Relaxed | 0.55 | 1.4 | 1.6 | 0.8 | 0.3 |
| Normal | 0.8 | 1.15 | 1.25 | 0.9 | 0.7 |
| Hard | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Brutal | 1.25 | 0.85 | 0.8 | 1.15 | 1.3 |

(`EnemyAI.aggression` is read from the profile but consumed by nothing, so no aggression
multiplier is added — it would be a dead knob.)

Hard = the authored (post-rebalance) values; Normal is softer, per Requirement 6.5.

## Hazards

- `tests/test_ship_combat.gd` must pass unmodified — `apply_hit` is untouched; first gun fires
  synchronously; `cannons_per_side = 0` keeps "one gun per marker" for its bare `ShipStats.new()`.
- Tests that fire with `fire_rate` set on a fresh `ShipStats.new()` are unaffected by `.tres`
  rebalancing; tests that read authored `.tres` values may need their expectations updated — any
  such change is listed in the checkpoint summary.
- `ShipController._ready()` model auto-detect picks the first `Node3D` child; the handler is a
  plain `Node`, added after that loop.
- `SettingsMenu.gd` has another session's uncommitted edits — commit only this milestone's hunk.
