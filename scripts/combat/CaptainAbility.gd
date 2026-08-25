class_name CaptainAbility extends Node

## Purpose: the player's captain ability button (`docs/navalCombat.md` §10).
## Responsibilities: read the active captain's ability, gate it on a cooldown, and
##   route its effects through CombatModifiers. Nothing else.
## Dependencies: ShipController.active_captain, CombatModifiers, ShipDamage.
##
## The ability *follows the captain*, not the ship: swapping captains at the Tavern
## swaps the verb, which is the whole point of a collectible hero roster. It tracks
## `active_captain` rather than caching a resource at _ready() so a mid-session
## captain change is picked up.

signal ability_activated(ability: CaptainAbilityData)
signal ability_ready()

var _cooldown_remaining: float = 0.0
var _last_captain: CaptainData = null


func _ready() -> void:
	_last_captain = _get_captain()


func _process(delta: float) -> void:
	# Swapping captains resets the cooldown so a fresh hire is usable immediately
	# rather than inheriting the previous captain's spent timer.
	var cap := _get_captain()
	if cap != _last_captain:
		_last_captain = cap
		_cooldown_remaining = 0.0
		ability_ready.emit()

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			ability_ready.emit()


func _get_captain() -> CaptainData:
	var parent = get_parent()
	if parent and "active_captain" in parent:
		return parent.active_captain
	return null


func get_ability() -> CaptainAbilityData:
	var cap := _get_captain()
	return cap.active_ability if cap else null


func has_ability() -> bool:
	return get_ability() != null


func is_ready() -> bool:
	return has_ability() and _cooldown_remaining <= 0.0


func get_cooldown_fraction() -> float:
	## 0.0 = just used, 1.0 = ready. For the HUD.
	var ability := get_ability()
	if not ability or ability.cooldown <= 0.0:
		return 1.0
	return clamp((ability.cooldown - _cooldown_remaining) / ability.cooldown, 0.0, 1.0)


func activate() -> bool:
	if not is_ready():
		return false

	var ability := get_ability()
	var parent = get_parent()
	# A docked or sunk ship has no business firing off an ability.
	if parent and "is_docked" in parent and parent.is_docked:
		return false
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
		return false

	var mods := parent.get_node_or_null("CombatModifiers") as CombatModifiers if parent else null
	if not mods:
		# Without the modifier layer there is nowhere for the effect to live, and
		# silently burning the cooldown would be worse than refusing.
		push_warning("CaptainAbility: no CombatModifiers on %s" % parent)
		return false

	var timed := ability.get_timed_effects()
	if not timed.is_empty() and ability.duration > 0.0:
		mods.add_timed_effect(timed, ability.duration)

	if ability.instant_hull_fraction > 0.0:
		mods.repair_pool("hull", ability.instant_hull_fraction)
	if ability.instant_sails_fraction > 0.0:
		mods.repair_pool("sails", ability.instant_sails_fraction)
	if ability.instant_crew_fraction > 0.0:
		mods.repair_pool("crew", ability.instant_crew_fraction)

	_cooldown_remaining = ability.cooldown
	ability_activated.emit(ability)
	return true
