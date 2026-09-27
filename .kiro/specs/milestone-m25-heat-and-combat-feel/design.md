# Design Document: Milestone M25 — Heat & Combat Feel

## 1. Why this design shape

**Heat is a lens on notoriety, not a new number.** `EmpireManager.notoriety` already rises on
kills, already decays, already gates region activation, and already persists. Adding a parallel
"heat" stat would give the game two escalation numbers that drift apart — exactly what
`AGENTS.md` means by "never duplicate systems". So heat is a *band* over notoriety plus a set of
authored behaviours per band. Tier boundaries are pinned to the existing region thresholds (60,
150) so "the sea got harder" and "a new region opened" happen together instead of at random
offsets.

**Passivity is the interesting half.** The swarm at high heat is easy; the valuable half is that at
low heat ships *ignore you*. That converts the open sea from a uniform threat into a place with
weather, and it makes the first unprovoked attack a real narrative beat. It also means a new player
cannot be farmed to death before learning to steer.

**The paid relief must not become an energy meter.** Nothing about heat blocks sailing, fighting or
boarding. Heat only changes *how many* ambient ships exist and *whether they engage first*. Three
ways down — wait, lie low in port, or pay — with the free paths always sufficient. This is the line
in `docs/00_VISION.md` §19.2 and the design must stay visibly on the right side of it.

**Combat feel is mostly a default-flip.** `fire_broadside(side)` is public, the `fire_port`/
`fire_starboard` actions exist and route through `WorldManager._unhandled_input`, and
`MobileControls` already has both fire buttons plus captain ability and special broadside. The work
is flipping `auto_fire_enabled`, adding the one missing control (ammo), and making the three damage
pools visible so ammo choice means something.

## 2. New/changed files

| File | Change |
|---|---|
| **new** `scripts/world/HeatTierData.gd` | one authored tier |
| **new** `scripts/world/HeatConfigData.gd` | the tier catalog + lookup |
| **new** `resources/balance/HeatCurve.tres` | 6 tiers (absorbs M24's deferred `DifficultyCurve`) |
| `scripts/managers/EmpireManager.gd` | tier derivation, `heat_tier_changed`, authored decay, lying-low, `spend_to_reduce_heat()` |
| `scripts/combat/EnemySpawner.gd` | cap/cadence/strength from the tier; **no hardcoded tuning left** |
| `scripts/combat/EnemyAI.gd` | passive patrol until provoked; `provoke()` |
| `scripts/world/ShipCombat.gd` | `auto_fire_enabled` default false; provoke on hit |
| `scripts/managers/SettingsManager.gd` | `auto_fire` persisted setting |
| `scripts/ui/SettingsMenu.gd` | auto-fire accessibility toggle |
| `scripts/ui/MobileControls.gd` | ammo-swap button |
| `scripts/ui/EnemyHealthBarWidget.gd` (+ `.tscn`) | three pool segments + crippled markers |
| `scripts/ui/WorldHUD.gd` | heat indicator, ammo indicator |
| `scripts/managers/ResourceManager.gd` | `eights` currency + production guard |
| `scripts/world/ChapterData.gd` | `reward_eights` |
| `scripts/managers/CampaignManager.gd` | grant `reward_eights` |
| **new** `tests/test_heat_system.gd`, `test_enemy_provocation.gd`, `test_manual_fire.gd`, `test_eights_currency.gd` | |

## 3. Heat tiers

`HeatTierData` (authored, never hardcoded):

```gdscript
@export var tier: int                          # 0..5
@export var display_name: String               # "Unknown" ... "Nemesis"
@export var min_notoriety: float               # inclusive lower bound
@export var max_ambient_enemies: int
@export var spawn_interval_seconds: float
@export var enemy_strength_multiplier: float
@export var engages_unprovoked: bool           # the GTA line
@export var decay_per_minute: float
@export var clear_cost_eights: int             # paid drop to the tier below
```

Authored curve, pinned to the region thresholds:

| Tier | Name | Notoriety | Cap | Unprovoked? | Note |
|---|---|---|---|---|---|
| 0 | Unknown | 0 | 2 | no | new player cannot be farmed |
| 1 | Noticed | 20 | 3 | no | |
| 2 | Wanted | **60** | 4 | **yes** | Contested Waters opens here |
| 3 | Hunted | 110 | 5 | yes | today's flat cap |
| 4 | Scourge | **150** | 6 | yes | Imperial Waters opens here |
| 5 | Nemesis | 220 | 8 | yes | swarm |

`HeatConfigData.tier_for(notoriety)` is the single resolver; everything else asks it.

**Decay.** Today: `1.0/60` per second, only after **600 s** with no gain. That is far too inert to
read as "cooling off". Replaced with an authored per-tier `decay_per_minute` after a short grace
(~120 s), doubled while docked at a player-owned island. Free decay must always be able to reach
tier 0 unaided — the paid clear is a shortcut, never the only way down.

**Paid clear.** `EmpireManager.spend_to_reduce_heat()` charges the current tier's
`clear_cost_eights` via `ResourceManager.spend_resources()` and drops notoriety to just below the
current tier's `min_notoriety` — **one tier per purchase**, so clearing from Nemesis is a deliberate
repeated choice, not a single button that erases consequences.

## 4. Passive until provoked

`EnemyAI` currently goes IDLE/PATROL to CHASE the moment the player is within `detection_range`.
Passivity adds one gate in front of that transition:

```
may_engage = tier.engages_unprovoked
             or _provoked
             or FactionManager.is_hostile(faction_id)
```

`_provoked` is **per-ship** and set by `provoke()`, called when the player damages it
(`ShipCombat.take_damage` / `ShipDamage.apply_impact` on a player-sourced hit) or boards it. Once
provoked a ship stays provoked for the rest of its life — a ship you shot does not forgive you.

Two things this must not break:

- **Obstacle avoidance.** `_get_avoidance_turn` / `_probe` / `_push_to_open_water` are what stop
  enemies beaching (`CLAUDE.md` fragile list). A passive ship still patrols, so it still runs the
  full avoidance path. The gate sits on the *engage* decision only; no avoidance code is touched.
- **Already-hostile factions.** A faction the player has wrecked reputation with attacks at any
  heat. Heat governs the *ambient* world, not diplomacy.

## 5. Firing

`auto_fire_enabled` flips to false. The auto-fire block in `_physics_process` already early-returns
on that flag, so no restructuring — which matters, because `tests/test_ship_combat.gd` guards this
file and must pass unmodified.

Arc-lock still gates: pressing fire with no lock does nothing but a rejection cue. That keeps
positioning as the skill and keeps `FiringSolver` the single shared arc authority for player and AI.

Ammo swap cycles `ShipCombat.current_ammo` through the three authored `AmmoData` resources.
`set_ammo()` must not touch `can_fire_*` or the cooldown timers, so swapping mid-reload is free and
the player is never punished for it.

## 6. Eights

A `ResourceManager` currency like any other, with one rule enforced in code rather than by
convention: **production can never mint it.** `Island._produce_resource()` pushes an error if a
`BuildingData.produces_resource` names it. Sources in M25 are chapter completion
(`ChapterData.reward_eights`) and first-time boss kills; the store lands in M31.

This is deliberately early. The heat clear needs a sink the player already holds, and shipping the
currency before the shop means players learn what Eights are worth by *earning and spending* them
first — which is also the honest order.

## Hazards

- **Do not let heat become an energy meter.** If a future change makes heat block sailing, spawning
  into the world, or entering combat, it has crossed §19.2. Pressure, never a gate.
- **Do not add a second escalation number.** Heat is derived. If something starts writing a `heat`
  variable, the design has been lost.
- **`tests/test_ship_combat.gd` must pass unmodified** — it guards the `ShipDamage` migration. If it
  fails, the change is wrong, not the test.
- **Do not touch** `_get_avoidance_turn` / `_probe` / `_push_to_open_water`, buoyancy, stability,
  the yaw servo, collision hull AABB, or hull-basis cannon direction.
- Flipping auto-fire off changes every existing combat test's assumptions about damage over time.
  Expect some to need an explicit `fire_broadside()` call; that is a legitimate update, but any test
  that starts *asserting less* is a red flag.
- Ambient enemy caps above today's 5 are a **performance** question on a phone as much as a balance
  one. Tier 5's cap of 8 needs a device check before it is treated as final.
