## AreaDamage — shared static area-of-effect damage utility.
##
## Purpose: apply damage to all hulls within a radius of a position, used by:
## - MaelstromRun powder keg detonation (M26)
## - Fireship tactic contact damage (M30 W1)
##
## All values are data-driven (passed in, not hardcoded). The damage is applied
## through each hull's ShipCombat.take_damage() path, so kills sink, drop loot
## and count exactly like cannon kills.

class_name AreaDamage

extends Node  # Only for the class namespace; never instantiate


## Apply area damage to all hulls within radius.
##
## Args:
##   epicenter: Vector3 — the position from which to measure distance
##   radius: float — maximum distance from epicenter for damage application
##   damage: float — flat damage to apply to each hull
##   target_hulls: Array[Node3D] — candidate hulls to damage (e.g. from spawner._active_enemies or free_enemies in the scene)
##
## Side effects:
##   - Plays explosion sound (via AudioManager)
##   - Calls ShipCombat.take_damage() for each hull in range
static func apply_damage(epicenter: Vector3, radius: float, damage: float, target_hulls: Array[Node3D]) -> void:
	if AudioManager:
		AudioManager.play_sound("explosion")

	for hull in target_hulls:
		if not is_instance_valid(hull):
			continue

		if hull.global_position.distance_to(epicenter) > radius:
			continue

		var combat = hull.get_node_or_null("ShipCombat")
		if combat and combat.has_method("take_damage"):
			combat.take_damage(damage)
