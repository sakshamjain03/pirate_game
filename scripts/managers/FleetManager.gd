extends Node

## Purpose: Global manager for the player's fleet (M6).
## Responsibilities: Tracks owned ships, owned captains, and current active ship.
## Dependencies: ShipStats, CaptainData

signal fleet_changed()
signal active_ship_changed(ship_stats: ShipStats, captain: CaptainData)

var owned_ships: Array[ShipStats] = []
var owned_captains: Array[CaptainData] = []
var active_ship_index: int = 0
var active_captain_index: int = 0

# Dictionary mapping ship_index (int) -> { "captain_index": int, "mission_type": String, "timer": float }
var active_missions: Dictionary = {}

func _ready() -> void:
	# Give the player a starter ship if empty
	if owned_ships.size() == 0:
		var starter = load("res://resources/ships/Dinghy.tres")
		if starter:
			owned_ships.append(starter)
			
	if owned_captains.size() == 0:
		var starter_cap = load("res://resources/captains/Jack.tres")
		if starter_cap:
			owned_captains.append(starter_cap)
			
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(_on_economy_tick)

func _on_economy_tick() -> void:
	for ship_idx in active_missions.keys():
		var mission = active_missions[ship_idx]
		var cap_idx = mission["captain_index"]
		var cap = owned_captains[cap_idx]
		
		# Give XP to captain
		cap.add_xp(10)
		
		# Generate resources
		if mission["mission_type"] == "trade":
			var amount = 10 * cap.level
			ResourceManager.add_resource("gold", amount)
			print("Trade Fleet earned ", amount, " Gold!")
		elif mission["mission_type"] == "patrol":
			if FactionManager.has_method("add_reputation"):
				FactionManager.add_reputation("merchant_guild", 1)
				print("Patrol Fleet earned 1 Reputation with Merchants!")

func assign_mission(ship_index: int, captain_index: int, mission_type: String) -> void:
	if ship_index == active_ship_index: return # Active ship cannot run background missions
	active_missions[ship_index] = {
		"captain_index": captain_index,
		"mission_type": mission_type,
		"timer": 0.0
	}
	fleet_changed.emit()

func unassign_mission(ship_index: int) -> void:
	if active_missions.has(ship_index):
		active_missions.erase(ship_index)
		fleet_changed.emit()

func is_on_mission(ship_index: int) -> bool:
	return active_missions.has(ship_index)

func add_ship(ship: ShipStats) -> void:
	if not ship in owned_ships:
		owned_ships.append(ship)
		fleet_changed.emit()

func add_captain(captain: CaptainData) -> void:
	if not captain in owned_captains:
		owned_captains.append(captain)
		fleet_changed.emit()

func get_active_ship() -> ShipStats:
	if active_ship_index >= 0 and active_ship_index < owned_ships.size():
		return owned_ships[active_ship_index]
	return null

func get_active_captain() -> CaptainData:
	if active_captain_index >= 0 and active_captain_index < owned_captains.size():
		return owned_captains[active_captain_index]
	return null

func get_save_data() -> Dictionary:
	var ship_paths = []
	for s in owned_ships:
		ship_paths.append(s.resource_path)
		
	var cap_paths = []
	for c in owned_captains:
		cap_paths.append(c.resource_path)
		
	return {
		"owned_ships": ship_paths,
		"owned_captains": cap_paths,
		"active_ship_index": active_ship_index,
		"active_captain_index": active_captain_index,
		"active_missions": active_missions
	}

func load_save_data(data: Dictionary) -> void:
	owned_ships.clear()
	owned_captains.clear()
	active_missions.clear()
	
	if data.has("owned_ships"):
		for p in data["owned_ships"]:
			if ResourceLoader.exists(p):
				owned_ships.append(load(p))
				
	if data.has("owned_captains"):
		for p in data["owned_captains"]:
			if ResourceLoader.exists(p):
				owned_captains.append(load(p))
				
	active_ship_index = int(data.get("active_ship_index", 0))
	active_captain_index = int(data.get("active_captain_index", 0))
	if data.has("active_missions"):
		# Ensure dict keys are converted to int for ship indices
		for k in data["active_missions"].keys():
			active_missions[int(k)] = data["active_missions"][k]
	
	fleet_changed.emit()
