extends Node

## Purpose: Global manager for player resources (Economy).
## Responsibilities: Tracks Gold, Wood, Iron, Rum. Handles adding/spending.
## Dependencies: None

signal resources_changed(resources: Dictionary)
signal global_economy_tick

var _economy_timer: float = 0.0
const ECONOMY_TICK_INTERVAL: float = 10.0

var current_resources: Dictionary = {
	"gold": 200,
	"wood": 50,
	"iron": 20,
	"rum": 10,
	"research": 0
}

var max_storage: Dictionary = {
	"gold": 5000,
	"wood": 200,
	"iron": 100,
	"rum": 50,
	"research": 9999
}

func _ready() -> void:
	# Emit initial state
	call_deferred("emit_signal", "resources_changed", current_resources)

func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.name == "World":
		_economy_timer += delta
		if _economy_timer >= ECONOMY_TICK_INTERVAL:
			_economy_timer -= ECONOMY_TICK_INTERVAL
			global_economy_tick.emit()

func add_resource(type: String, amount: int) -> void:
	if amount <= 0:
		return
		
	type = type.to_lower()
	var cap = max_storage.get(type, 999999)
	if current_resources.has(type):
		current_resources[type] += amount
	else:
		current_resources[type] = amount
		
	if current_resources[type] > cap:
		current_resources[type] = cap
		
	resources_changed.emit(current_resources)

func spend_resource(type: String, amount: int) -> bool:
	if amount <= 0:
		return true
		
	type = type.to_lower()
	if current_resources.has(type) and current_resources[type] >= amount:
		current_resources[type] -= amount
		resources_changed.emit(current_resources)
		return true
		
	return false

func get_resource(type: String) -> int:
	type = type.to_lower()
	return current_resources.get(type, 0)

func can_afford(cost: Dictionary) -> bool:
	for type in cost.keys():
		if get_resource(type) < cost[type]:
			return false
	return true
	
func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
		
	for type in cost.keys():
		current_resources[type.to_lower()] -= cost[type]
		
	resources_changed.emit(current_resources)
	return true

func get_save_data() -> Dictionary:
	return current_resources.duplicate()

func load_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	for key in data:
		var cap = max_storage.get(key, 999999)
		current_resources[key] = min(int(data[key]), cap)

	resources_changed.emit(current_resources)

func recalculate_storage_capacity() -> void:
	var base_storage: Dictionary = {
		"gold": 5000,
		"wood": 200,
		"iron": 100,
		"rum": 50
	}
	
	max_storage = base_storage.duplicate()
	
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("has_building") and island.has_building("warehouse"):
			max_storage["gold"] += 500
			max_storage["wood"] += 200
			max_storage["iron"] += 100
			max_storage["rum"] += 50
			
	var changed = false
	for type in current_resources.keys():
		var cap = max_storage.get(type, 999999)
		if current_resources[type] > cap:
			current_resources[type] = cap
			changed = true
			
	if changed:
		resources_changed.emit(current_resources)

