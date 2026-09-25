class_name RamConfigData extends Resource

## Purpose: all ramming / hull-contact balance — M23 Requirement 2. Read by
## `ShipCollisionHandler`; nothing about ram damage is hardcoded in script.
## Responsibilities: pure data + the zone-matrix lookup.

enum Zone { BOW, MIDSHIP, STERN }

@export_group("Threshold")
## Closing speed (m/s, along the contact normal) below which a contact is a
## nudge, not a ram — no damage, no knockback beyond what the solver does.
@export_range(0.0, 20.0) var min_closing_speed: float = 3.0
## Same pair of bodies cannot be damaged again inside this window, so a
## sustained scrape doesn't tick damage every physics frame.
@export_range(0.0, 5.0) var pair_cooldown: float = 1.0

@export_group("Damage")
## Hull damage per (m/s)^2 of closing speed for an equal-mass pair at matrix 1.0.
@export_range(0.0, 5.0) var damage_per_speed_sq: float = 0.35
## Absolute size scaling: damage *= (2*reduced_mass / reference_mass)^exponent,
## so two Man O'Wars colliding hurts more than two Dinghies.
@export_range(100.0, 50000.0) var reference_mass: float = 5000.0
@export_range(0.0, 1.0) var mass_scale_exponent: float = 0.5
## Fraction of hull damage also dealt to the crew pool.
@export_range(0.0, 1.0) var crew_damage_fraction: float = 0.15
## Terrain impacts (running aground) — damages only the ship.
@export_range(0.0, 5.0) var grounding_damage_mult: float = 0.5

@export_group("Stern hits")
## A hit to the stern damages the rudder: a timed speed penalty via
## ShipDamage.apply_speed_penalty().
@export_range(0.0, 1.0) var stern_speed_penalty: float = 0.3
@export_range(0.0, 20.0) var stern_penalty_duration: float = 4.0

@export_group("Zones")
## Fraction of hull length, from the bow tip, that counts as BOW.
@export_range(0.05, 0.5) var bow_fraction: float = 0.25
## Fraction of hull length, from the transom, that counts as STERN.
@export_range(0.05, 0.5) var stern_fraction: float = 0.2
## Damage taken by ME when MY zone meets THEIR zone. Row = my zone,
## column = their zone, both in Zone order (BOW, MIDSHIP, STERN).
@export var zone_matrix: PackedFloat32Array = PackedFloat32Array([
	0.6, 0.2, 0.25,
	1.0, 0.3, 0.5,
	0.9, 0.4, 0.4,
])

@export_group("Knockback")
## Extra separating impulse as a fraction of closing speed, on top of the
## solver's own bounce — the arcade "shove" of a ram.
@export_range(0.0, 2.0) var knockback_fraction: float = 0.35
## Yaw-servo grace window after a ram so the knockback spin survives.
@export_range(0.0, 3.0) var ram_yaw_grace: float = 0.8
## Grace applied every tick a hull is merely touching something.
@export_range(0.0, 1.0) var contact_yaw_grace: float = 0.25

@export_group("Anti-stuck watchdog")
@export_range(0.0, 5.0) var unstick_after: float = 1.2
@export_range(0.0, 1.0) var unstick_min_throttle: float = 0.3
@export_range(0.0, 5.0) var unstick_max_speed: float = 0.6
@export_range(0.0, 10.0) var unstick_speed: float = 3.0
@export_range(0.0, 3.0) var unstick_yaw_rate: float = 0.6
@export_range(0.0, 10.0) var unstick_cooldown: float = 1.5


func get_zone_multiplier(my_zone: int, their_zone: int) -> float:
	var idx := my_zone * 3 + their_zone
	if my_zone < 0 or my_zone > 2 or their_zone < 0 or their_zone > 2 or idx >= zone_matrix.size():
		push_error("RamConfigData: zone pair (%d, %d) outside the authored matrix" % [my_zone, their_zone])
		return 0.0
	return zone_matrix[idx]


static func zone_name(zone: int) -> String:
	return Zone.keys()[zone] if zone >= 0 and zone < Zone.size() else "?"
