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
