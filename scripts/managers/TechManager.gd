extends Node

## Purpose: Tracks unlocked technologies and provides their global modifiers.

signal tech_unlocked(tech: Resource)
signal tech_recalculated()

var unlocked_techs: Array[Resource] = []

# Cached global modifiers
var global_health_mod: float = 1.0
var global_damage_mod: float = 1.0
var global_speed_mod: float = 1.0
var global_storage_mod: float = 1.0

func is_unlocked(tech_id: String) -> bool:
	for t in unlocked_techs:
		if t.tech_id == tech_id:
			return true
	return false

## M11 — whether `tech` can be researched given the player's current home island
## tier. Mirrors BuildingData's tier-gate pattern plus a prerequisite chain.
## Does not check affordability — that's ResourceManager's concern, checked
## separately by the caller.
func can_research(tech: TechData, island_tier: int) -> bool:
	if is_unlocked(tech.tech_id):
		return false
	if tech.required_island_tier > island_tier:
		return false
	if not tech.required_prerequisite_tech_id.is_empty() and not is_unlocked(tech.required_prerequisite_tech_id):
		return false
	return true

func unlock_tech(tech: Resource) -> void:
	if not is_unlocked(tech.tech_id):
		unlocked_techs.append(tech)
		_recalculate_modifiers()
		tech_unlocked.emit(tech)

func _recalculate_modifiers() -> void:
	global_health_mod = 1.0
	global_damage_mod = 1.0
	global_speed_mod = 1.0
	global_storage_mod = 1.0
	
	for t in unlocked_techs:
		global_health_mod *= t.health_modifier
		global_damage_mod *= t.damage_modifier
		global_speed_mod *= t.speed_modifier
		global_storage_mod *= t.storage_modifier
		
	tech_recalculated.emit()

func get_save_data() -> Dictionary:
	var paths = []
	for t in unlocked_techs:
		paths.append(t.resource_path)
	return {"unlocked": paths}

func load_save_data(data: Dictionary) -> void:
	unlocked_techs.clear()
	if data.has("unlocked"):
		for p in data["unlocked"]:
			if ResourceLoader.exists(p):
				unlocked_techs.append(load(p))
	_recalculate_modifiers()
