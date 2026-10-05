class_name CombatModifiers extends Node

## Purpose: per-ship, runtime-only combat multipliers.
## Responsibilities: hold the stacked effect of temporary battle upgrades and
##   captain abilities, and expose them to the systems that already apply captain
##   and tech modifiers. Nothing here reads input or drives behaviour.
##
## THE RULE THIS COMPONENT EXISTS TO ENFORCE: never mutate a `ShipStats` resource.
## A `.tres` is shared by every ship of that class, so "Rapid Reload: −30% reload"
## applied to `ShipStats.fire_rate` would permanently buff every Sloop in the game,
## including enemy ones, and would persist across sessions once saved. This is the
## same duplicate-never-mutate discipline `EnemySpawner.compute_spawn_multiplier()`
## already follows for empire-scaled enemy stats.
##
## Modifiers are temporary by construction: `EncounterManager` calls `reset()` when
## an encounter ends, which is what makes `docs/navalCombat.md` §11's upgrades last
## "only during the current battle".

signal modifiers_changed()
signal upgrade_applied(upgrade: BattleUpgradeData)

## Public totals — read by ShipCombat, FiringSolver and ShipMovement. Recomputed
## from the battle-long base plus any currently-active timed effect; never assigned
## from outside.
var damage_mult: float = 1.0
## Multiplies ShipStats.fire_rate, so > 1.0 means *faster* reloading.
var fire_rate_mult: float = 1.0
var speed_mult: float = 1.0
var range_mult: float = 1.0
## Added to the firing cone half-width, in degrees. Additive because a percentage
## of an arc is much harder for a player to reason about than "+8 degrees".
var arc_bonus_degrees: float = 0.0
## Multiplies the special broadside's cooldown, so < 1.0 means it returns sooner.
var special_cooldown_mult: float = 1.0
## M26 — multiplies the pickup (and magnet) radius of Maelstrom drops.
var pickup_radius_mult: float = 1.0
## M26 — fraction of max hull restored per second, while the hull is afloat.
var regen_per_second: float = 0.0
## M26 — extra cannonballs every gun fires per shot. Additive, whole balls.
var extra_projectiles: int = 0
## M26 — multiplies the hull damage this ship's bow deals when it rams.
var ram_damage_mult: float = 1.0
## M30 W1 (1.6) — multiplies incoming damage (Brace, status effects). 1.0 = no reduction.
## Brace sets this to (1 - reduction).
var damage_taken_mult: float = 1.0

# Battle-long layer: temporary upgrades, cleared when the encounter ends.
var _base := _neutral()
# Timed layer: captain active abilities ("5-second speed burst"). Held separately
# and recomputed rather than multiplied in and divided back out, so a burst that
# expires restores the exact value it started from with no floating-point drift.
var _timed: Array[Dictionary] = []

var _applied: Array[BattleUpgradeData] = []
# M30 0.16 (B7) — persistent layer: effects owned by something that outlives a
# battle (crew stations, statuses, Fury, Brace), keyed by source id and set /
# cleared only by that owner. reset() used to wipe every layer at encounter end.
var _persistent: Dictionary = {}

## M30 0.16 — how long a layer lives. ENCOUNTER = battle upgrades (_base);
## TIMED = add_timed_effect() (captain abilities, pickups), which expires on
## its own clock and is also cut short when the battle ends; PERSISTENT =
## set_persistent_layer(), which only its owner clears.
enum Lifetime { ENCOUNTER, TIMED, PERSISTENT }


static func _neutral() -> Dictionary:
	return {
		"damage": 1.0, "fire_rate": 1.0, "speed": 1.0,
		"range": 1.0, "arc": 0.0, "special_cooldown": 1.0,
		"pickup_radius": 1.0, "regen": 0.0, "extra_projectiles": 0.0, "ram_damage": 1.0,
		"damage_taken": 1.0,
	}


## End-of-battle clear (M30 0.16): battle upgrades and any still-running timed
## effect end with the battle; persistent layers belong to their owners and
## survive (before M30 this wiped every layer).
func reset() -> void:
	_base = _neutral()
	_timed.clear()
	_applied.clear()
	_recompute()


func set_persistent_layer(id: StringName, effects: Dictionary) -> void:
	_persistent[id] = effects.duplicate()
	_recompute()


func clear_persistent_layer(id: StringName) -> void:
	if _persistent.erase(id):
		_recompute()


func has_persistent_layer(id: StringName) -> bool:
	return _persistent.has(id)


func _process(delta: float) -> void:
	if regen_per_second > 0.0:
		_regen(delta)
	if _timed.is_empty():
		return
	var expired := false
	for i in range(_timed.size() - 1, -1, -1):
		_timed[i]["remaining"] -= delta
		if _timed[i]["remaining"] <= 0.0:
			_timed.remove_at(i)
			expired = true
	if expired:
		_recompute()


func _recompute() -> void:
	var damage: float = _base["damage"]
	var fire_rate: float = _base["fire_rate"]
	var speed: float = _base["speed"]
	var rng: float = _base["range"]
	var arc: float = _base["arc"]
	var special: float = _base["special_cooldown"]
	var pickup: float = _base["pickup_radius"]
	var regen: float = _base["regen"]
	var extra: float = _base["extra_projectiles"]
	var ram: float = _base["ram_damage"]
	var damage_taken: float = _base["damage_taken"]

	var layers: Array = []
	layers.append_array(_timed)
	layers.append_array(_persistent.values())
	for t in layers:
		pickup *= float(t.get("pickup_radius", 1.0))
		regen += float(t.get("regen", 0.0))
		extra += float(t.get("extra_projectiles", 0.0))
		ram *= float(t.get("ram_damage", 1.0))
		damage *= float(t.get("damage", 1.0))
		fire_rate *= float(t.get("fire_rate", 1.0))
		speed *= float(t.get("speed", 1.0))
		rng *= float(t.get("range", 1.0))
		arc += float(t.get("arc", 0.0))
		special *= float(t.get("special_cooldown", 1.0))
		damage_taken *= float(t.get("damage_taken", 1.0))

	damage_mult = damage
	fire_rate_mult = fire_rate
	speed_mult = speed
	range_mult = rng
	arc_bonus_degrees = arc
	special_cooldown_mult = special
	pickup_radius_mult = pickup
	regen_per_second = regen
	extra_projectiles = int(round(extra))
	ram_damage_mult = ram
	damage_taken_mult = damage_taken
	modifiers_changed.emit()


func add_timed_effect(effects: Dictionary, duration: float) -> void:
	## Applies a bundle of multipliers for `duration` seconds — the mechanism behind
	## a captain's active ability (`docs/navalCombat.md` §10, e.g. The Navigator's
	## "5-second speed burst"). Keys match `_neutral()`; anything omitted is neutral.
	if duration <= 0.0:
		return
	var entry := effects.duplicate()
	entry["remaining"] = duration
	_timed.append(entry)
	_recompute()


func has_timed_effect() -> bool:
	return not _timed.is_empty()


func get_applied_upgrades() -> Array[BattleUpgradeData]:
	return _applied.duplicate()


func stacks_of(upgrade_id: String) -> int:
	var n := 0
	for u in _applied:
		if u and u.upgrade_id == upgrade_id:
			n += 1
	return n


func can_apply(upgrade: BattleUpgradeData) -> bool:
	if not upgrade:
		return false
	return stacks_of(upgrade.upgrade_id) < upgrade.max_stacks


func apply_upgrade(upgrade: BattleUpgradeData) -> bool:
	if not can_apply(upgrade):
		return false

	match upgrade.effect:
		BattleUpgradeData.Effect.DAMAGE:
			_base["damage"] *= upgrade.magnitude
		BattleUpgradeData.Effect.RELOAD_SPEED:
			_base["fire_rate"] *= upgrade.magnitude
		BattleUpgradeData.Effect.SHIP_SPEED:
			_base["speed"] *= upgrade.magnitude
		BattleUpgradeData.Effect.CANNON_RANGE:
			_base["range"] *= upgrade.magnitude
		BattleUpgradeData.Effect.FIRING_ARC:
			_base["arc"] += upgrade.magnitude
		BattleUpgradeData.Effect.SPECIAL_COOLDOWN:
			_base["special_cooldown"] *= upgrade.magnitude
		BattleUpgradeData.Effect.REPAIR_HULL:
			_repair("hull", upgrade.magnitude)
		BattleUpgradeData.Effect.REPAIR_SAILS:
			_repair("sails", upgrade.magnitude)
		BattleUpgradeData.Effect.RALLY_CREW:
			_repair("crew", upgrade.magnitude)
		BattleUpgradeData.Effect.PICKUP_RADIUS:
			_base["pickup_radius"] *= upgrade.magnitude
		BattleUpgradeData.Effect.HULL_REGEN:
			# Authored as PERCENT of max hull per second (see BattleUpgradeData).
			_base["regen"] += upgrade.magnitude / 100.0
		BattleUpgradeData.Effect.EXTRA_PROJECTILE:
			_base["extra_projectiles"] += upgrade.magnitude
		BattleUpgradeData.Effect.RAM_DAMAGE:
			_base["ram_damage"] *= upgrade.magnitude
		_:
			push_error("CombatModifiers: unhandled effect on '%s'" % upgrade.upgrade_id)
			return false

	_applied.append(upgrade)
	_recompute()
	upgrade_applied.emit(upgrade)
	return true


func repair_pool(pool: String, fraction: float) -> void:
	## Public so a captain ability can heal too, without duplicating the lookup.
	_repair(pool, fraction)


func _regen(delta: float) -> void:
	## M26 "Ship's Carpenter": a slow hull trickle. Never raises a sunk hull —
	## ShipDamage.repair() itself does not check for destruction.
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if not dmg or dmg.hull <= 0.0:
		return
	_repair("hull", regen_per_second * delta)


func _repair(pool: String, fraction: float) -> void:
	## Instant effects ("Emergency Repairs: restore 20% hull") go straight through
	## ShipDamage.repair() — the write path Slice 0 built. Expressed as a fraction
	## of the pool's maximum so one upgrade reads the same on a Dinghy and a
	## Man O'War.
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if not dmg or not dmg.has_method("repair"):
		return
	var maximum: float = dmg.get_pool_maximum(pool)
	if maximum <= 0.0:
		return
	dmg.repair(pool, maximum * fraction)
