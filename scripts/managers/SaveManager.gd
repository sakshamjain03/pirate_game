extends Node

## SaveManager
## Handles saving and loading player empire data.
## 
## Responsibilities:
## - Provide placeholder API for save/load functionality
## - Stub methods for future milestone implementation
## 
## Dependencies:
## - GameManager (for game state awareness)
## - ConfigFile (for JSON/text serialization - future)
## 
## Limitations:
## - Milestone 1: No persistent data is written
## - All methods are no-op stubs
## - does_save_data() always returns false
## 
## TODO:
## - M2: Implement save_game() with empire state serialization
## - M2: Implement load_game() with data deserialization
## - M2: Implement has_save_data() to check file existence
## - M3: Add save validation and version checking
## - M4: Implement cloud save fallback

const SAVE_PATH := "user://save_data.json"

var _save_timer: float = 0.0
var _auto_save_interval: float = 60.0

func _process(delta: float) -> void:
	if not get_tree().current_scene or get_tree().current_scene.name != "World":
		return
		
	_save_timer += delta
	if _save_timer >= _auto_save_interval:
		_save_timer = 0.0
		save_game()

func save_game() -> void:
	print("SaveManager: Saving game state...")
	var save_dict = {
		"player": {},
		"economy": {},
		"islands": {},
		"fleet": {},
		"tech": {},
		"factions": {}
	}
	
	# 1. Player State
	var player = get_tree().get_first_node_in_group("player_ship")
	if player and is_instance_valid(player):
		save_dict["player"]["pos_x"] = player.global_position.x
		save_dict["player"]["pos_y"] = player.global_position.y
		save_dict["player"]["pos_z"] = player.global_position.z
		save_dict["player"]["rot_y"] = player.global_rotation.y
		
		var combat = player.get_node_or_null("ShipCombat")
		if combat:
			save_dict["player"]["health"] = combat.current_health
			
		if "active_captain" in player and player.active_captain:
			save_dict["player"]["captain_id"] = player.active_captain.captain_id
	
	# 2. Economy State
	if ResourceManager.has_method("get_save_data"):
		save_dict["economy"] = ResourceManager.get_save_data()
		
	# 3. Islands State
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("get_island_id") and island.has_method("get_built_building_ids"):
			save_dict["islands"][island.get_island_id()] = island.get_built_building_ids()
			
	# 4. Fleet State
	if FleetManager.has_method("get_save_data"):
		save_dict["fleet"] = FleetManager.get_save_data()
			
	# 5. Tech State
	if TechManager.has_method("get_save_data"):
		save_dict["tech"] = TechManager.get_save_data()
			
	# 6. Faction State
	if FactionManager.has_method("get_save_data"):
		save_dict["factions"] = FactionManager.get_save_data()
			
	# Write to disk
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict, "\t")
		file.store_string(json_string)
		file.close()
		print("SaveManager: Game saved successfully.")
	else:
		push_error("SaveManager: Failed to open save file for writing.")

func load_game() -> void:
	print("SaveManager: Loading game state...")
	if not has_save_data():
		print("SaveManager: No save data found.")
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to open save file for reading.")
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("SaveManager: JSON Parse Error: ", json.get_error_message())
		return
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: Save data is not a valid dictionary.")
		return
		
	# 1. Player State
	if data.has("player"):
		var player_data = data["player"]
		var player = get_tree().get_first_node_in_group("player_ship")
		if player and is_instance_valid(player):
			# Transform
			var pos = Vector3(
				player_data.get("pos_x", 0.0),
				player_data.get("pos_y", 1.0),
				player_data.get("pos_z", 0.0)
			)
			player.global_position = pos
			player.global_rotation.y = player_data.get("rot_y", 0.0)
			
			# Health will be set after fleet loads
			
	# 2. Economy State
	if data.has("economy") and ResourceManager.has_method("load_save_data"):
		ResourceManager.load_save_data(data["economy"])
		
	# 3. Fleet State (do this before health to set proper max hp)
	if data.has("fleet") and FleetManager.has_method("load_save_data"):
		FleetManager.load_save_data(data["fleet"])
		var player = get_tree().get_first_node_in_group("player_ship")
		if player and is_instance_valid(player):
			var ship = FleetManager.get_active_ship()
			var cap = FleetManager.get_active_captain()
			if ship: player.ship_stats = ship
			if cap: player.active_captain = cap
			
			var combat = player.get_node_or_null("ShipCombat")
			if combat:
				var player_data = data.get("player", {})
				if player_data.has("health"):
					combat.current_health = player_data["health"]
					
				var max_hp = combat.ship_stats.max_health
				if cap: max_hp *= cap.health_modifier
				if combat.has_signal("health_changed"):
					combat.health_changed.emit(combat.current_health, max_hp)
					
	# 2. Economy State
	if data.has("economy") and ResourceManager.has_method("load_save_data"):
		ResourceManager.load_save_data(data["economy"])
		
	# 3. Islands State
	if data.has("islands"):
		var islands_data = data["islands"]
		var active_islands = get_tree().get_nodes_in_group("islands")
		for island in active_islands:
			var island_id = island.get_island_id() if island.has_method("get_island_id") else ""
			if island_id != "" and islands_data.has(island_id) and island.has_method("restore_buildings"):
				island.restore_buildings(islands_data[island_id])
				
	# 4. Tech State
	if data.has("tech") and TechManager.has_method("load_save_data"):
		TechManager.load_save_data(data["tech"])
		
	# 5. Faction State
	if data.has("factions") and FactionManager.has_method("load_save_data"):
		FactionManager.load_save_data(data["factions"])
				
	print("SaveManager: Game loaded successfully.")

func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save_data():
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
			print("SaveManager: Save data deleted.")
