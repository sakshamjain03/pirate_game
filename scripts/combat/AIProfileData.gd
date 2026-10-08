@tool
extends Resource
class_name AIProfileData

## Purpose: authored personality for one AI hull — tunables `EnemyAI` reads in
## `_ready()`, plus a `role` tag (`docs/navalCombat.md` "real roles, not just
## bigger numbers": Raider/Artillery/Tank/Support/Boss).
##
## `role` extends this resource rather than replacing it: the roles are not a
## second numeric system layered on top of `aggression`/`flee_health_threshold`/
## etc. — they ARE those fields, authored differently per profile. A Tank is a
## Tank because `AggressiveGalleon.tres` sets `flee_health_threshold = 0.0`, not
## because code multiplies a Tank bonus into it. `role` only drives one thing
## code branches on: `SUPPORT` ships repair a wounded ally instead of attacking.
enum Role { BALANCED, RAIDER, ARTILLERY, TANK, SUPPORT, BOSS }

@export var role: Role = Role.BALANCED
@export var aggression: float = 0.7
@export var preferred_combat_distance: float = 25.0
@export var flee_health_threshold: float = 0.25
@export var broadside_angle_tolerance: float = 30.0
@export var ammo_preference: String = "RoundShot"

@export_group("Support Role")
## Only meaningful when `role == SUPPORT`. How close the ship must close on a
## wounded ally before it starts repairing rather than just steering toward them.
@export var support_heal_range: float = 15.0
## Hull points restored per second while in range.
@export var support_heal_rate: float = 15.0
## An ally at or above this hull fraction doesn't need help — a Support ship at
## full strength itself has nothing to do but hold position and wait.
@export_range(0.0, 1.0) var support_heal_threshold: float = 0.6

@export_group("Ramming")
## M23 Requirement 4 — chance, re-rolled every `EnemyAI.ram_eval_interval`
## seconds in ATTACK, that this hull commits to a ram run when the target shows
## it a broadside. 0 = never rams on purpose (still takes accidental ram damage).
@export_range(0.0, 1.0) var ram_tendency: float = 0.0
## Only consider a ram run inside this distance of the target.
@export var ram_max_distance: float = 60.0

## M30 W1-1.1 — where this hull positions itself in ATTACK. **Append-only**:
## authored `.tres` files store the integer, so a value may never be reordered
## or removed. STANDARD keeps the original perpendicular-to-the-line-of-fire
## approach exactly; every other tactic places `ideal_position` at
## `preferred_bearing_deg` off the TARGET's heading (0 = dead ahead of its bow,
## 180 = dead astern), low-pass filtered so it can't feed back into a
## circling-of-death. TENDER's healing is the existing SUPPORT role
## (`role = SUPPORT`), not a second heal system — the tactic only decides where
## it waits while nobody needs patching.
enum Tactic { STANDARD, STERN_RAKER, LONG_GUNNER, RAM_RUNNER, TENDER, FIRESHIP }

@export_group("Tactic")
@export var tactic: Tactic = Tactic.STANDARD
## Unsigned bearing off the target's bow, degrees. The side (port/starboard of
## the target) is whichever the hull is already on, so it never cuts across.
@export_range(0.0, 180.0) var preferred_bearing_deg: float = 90.0  # placeholder: tune in M31
## Time constant of the bearing low-pass filter:
## `smoothed = lerp_angle(prev, target, 1 - exp(-dt / bearing_filter_seconds))`.
@export var bearing_filter_seconds: float = 0.8  # placeholder: tune in M31
## LONG_GUNNER only: while closer than this, `ideal_position` is pushed outward.
@export var kite_min_distance: float = 0.0  # placeholder: tune in M31
## Range-banded ammo choice: `{ammo id: max distance}`. In ATTACK the hull loads
## the rule with the smallest max distance still >= the current range; out of
## every band it falls back to `ammo_preference`. Empty = always
## `ammo_preference` (the pre-M30 behaviour). Ids resolve to
## `res://resources/combat/ammo/<id>.tres`; an unknown id push_errors.
@export var ammo_rules: Dictionary = {}  # placeholder: tune in M31
## Throttle while manoeuvring in ATTACK (STANDARD always used 0.5).
@export_range(0.0, 1.0) var attack_throttle: float = 0.5  # placeholder: tune in M31
## Extra physics layers OR-ed into EnemyAI.avoid_collision_mask, so this
## profile's existing obstacle probe also steers around them. The Raker sets
## bit 32 (layer 6, powder kegs): it holds the stern quarter, which is exactly
## where the player drops kegs (M30 W1 task 1.10).
@export_flags_3d_physics var extra_avoid_mask: int = 0  # placeholder: tune in M31

@export_group("Ram Telegraph")
## Seconds between committing to a ram (`EnemyAI.ram_telegraphed`) and the run
## actually starting — the player's window to read it and turn away. 0 = no
## telegraph (pre-M30 rammers).
@export var ram_telegraph_seconds: float = 0.0  # placeholder: tune in M31

@export_group("Fireship")
## FIRESHIP only: flat distance to the target at which it detonates even
## without a hull-on-hull `rammed` contact (a slow touch never reports one).
@export var fireship_contact_distance: float = 9.0  # placeholder: tune in M31
## Every hull within this radius of the fireship takes `fireship_damage`.
@export var fireship_radius: float = 18.0  # placeholder: tune in M31
@export var fireship_damage: float = 60.0  # placeholder: tune in M31
