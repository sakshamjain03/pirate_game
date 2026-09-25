class_name AIDifficultyData extends Resource

## Purpose: one player-selectable enemy difficulty level — M23 Requirement 6.
## `SettingsManager.get_ai_difficulty_profile()` returns the active one.
## Every multiplier is applied at use time to hostile (non-player-side) ships
## only, and never written into a shared ShipStats resource.

@export var display_name: String = ""
@export_multiline var description: String = ""
## Enemy cannonball damage.
@export_range(0.1, 3.0) var damage_mult: float = 1.0
## Enemy reload TIME (>1 = slower reload).
@export_range(0.1, 3.0) var reload_time_mult: float = 1.0
## Enemy aim error (>1 = more misses).
@export_range(0.1, 3.0) var spread_mult: float = 1.0
@export_range(0.1, 3.0) var detection_range_mult: float = 1.0
@export_range(0.0, 3.0) var ram_tendency_mult: float = 1.0


static func applies_to(ship: Node) -> bool:
	## Player-side hulls (the player and `friendly_ship` escorts) are never
	## scaled — difficulty is about how hard the *enemy* hits.
	if not ship or not is_instance_valid(ship):
		return false
	return not (ship.is_in_group("player_ship") or ship.is_in_group("friendly_ship"))


static func for_ship(ship: Node) -> AIDifficultyData:
	## The active profile if it applies to this ship, else null (= neutral).
	if not applies_to(ship):
		return null
	var tree := ship.get_tree() if ship.is_inside_tree() else null
	var settings: Node = tree.root.get_node_or_null("SettingsManager") if tree else null
	if settings and settings.has_method("get_ai_difficulty_profile"):
		return settings.get_ai_difficulty_profile()
	return null
