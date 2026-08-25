extends Node

## Purpose: Global manager for the player's fleet (M6/M8).
## Responsibilities: Tracks owned ships, owned captains, current active ship, background
##   trade/patrol missions, per-ship "Defend Home" flags (M4) — get_ships_defending_home()
##   excludes the currently active ship and any ship on a mission, for EmpireManager's defense
##   score — and per-ship level/module progression (M8, `docs/navalCombat.md` §13).
## Dependencies: ShipStats, OwnedShipData, ShipModuleData, CaptainData, ResourceManager,
##   EmpireManager (defense score consumer)

signal fleet_changed()
signal active_ship_changed(ship_stats: ShipStats, captain: CaptainData)
signal captain_recruited(captain: CaptainData)

## Each entry wraps a shared `ShipStats` template plus per-instance level/module
## state — a `ShipStats` resource is shared by every hull of its class, so two
## owned Sloops must not share one mutable record.
var owned_ships: Array[OwnedShipData] = []
var owned_captains: Array[CaptainData] = []
var active_ship_index: int = 0
var active_captain_index: int = 0
var defend_home_ship_indices: Array = []

# Dictionary mapping ship_index (int) -> { "captain_index": int, "mission_type": String, "timer": float }
var active_missions: Dictionary = {}

func _ready() -> void:
	# Give the player a starter ship if empty. Must match PlayerShip.tscn's
	# own ship_stats (Sloop) — a mismatch here previously made the Shipyard
	# tab show a phantom Dinghy as "Owned" and the actual Sloop the player
	# was sailing as still buyable.
	if owned_ships.size() == 0:
		var starter = load("res://resources/ships/Sloop.tres")
		if starter:
			var starter_owned := OwnedShipData.new()
			starter_owned.ship_stats = starter
			owned_ships.append(starter_owned)
			
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
		if cap_idx < 0 or cap_idx >= owned_captains.size():
			continue
		var cap = owned_captains[cap_idx]

		# Give XP to captain
		cap.add_xp(10)
		
		# Generate resources
		if mission["mission_type"] == "trade":
			var amount = 10 * cap.level
			ResourceManager.add_resource("gold", amount)
		elif mission["mission_type"] == "patrol":
			if FactionManager.has_method("add_reputation"):
				FactionManager.add_reputation("merchant_guild", 1)

func assign_mission(ship_index: int, captain_index: int, mission_type: String) -> void:
	if ship_index == active_ship_index: return # Active ship cannot run background missions
	active_missions[ship_index] = {
		"captain_index": captain_index,
		"mission_type": mission_type,
		"timer": 0.0
	}
	fleet_changed.emit()

func set_defend_home(ship_index: int, defend: bool) -> void:
	if defend:
		if not defend_home_ship_indices.has(ship_index):
			defend_home_ship_indices.append(ship_index)
	else:
		if defend_home_ship_indices.has(ship_index):
			defend_home_ship_indices.erase(ship_index)
	fleet_changed.emit()

func is_defending_home(ship_index: int) -> bool:
	return defend_home_ship_indices.has(ship_index)

func get_ships_defending_home() -> int:
	var count = 0
	for idx in defend_home_ship_indices:
		if idx != active_ship_index and not is_on_mission(idx):
			count += 1
	return count

func unassign_mission(ship_index: int) -> void:
	if active_missions.has(ship_index):
		active_missions.erase(ship_index)
		fleet_changed.emit()

func is_on_mission(ship_index: int) -> bool:
	return active_missions.has(ship_index)

func add_ship(ship: ShipStats) -> void:
	if owns_ship_stats(ship):
		return
	var owned := OwnedShipData.new()
	owned.ship_stats = ship
	owned_ships.append(owned)
	fleet_changed.emit()


func owns_ship_stats(ship: ShipStats) -> bool:
	## The Shipyard roster is a catalog of shared `ShipStats` templates, so
	## "do I already own this hull" has to compare against each entry's
	## template, not identity of the `OwnedShipData` wrapper.
	for o in owned_ships:
		if o and o.ship_stats == ship:
			return true
	return false

func add_captain(captain: CaptainData) -> void:
	if not captain in owned_captains:
		owned_captains.append(captain)
		fleet_changed.emit()
		captain_recruited.emit(captain)

func get_active_ship() -> ShipStats:
	## Returns the ship's EFFECTIVE stats (template + level/module bonuses) —
	## every existing caller (IslandMenu's ship-switch, SaveManager's fleet
	## load) already treats this as a plain ShipStats to assign onto the player,
	## so the wrapper stays internal rather than changing that contract.
	var owned := get_active_owned_ship()
	return owned.get_effective_stats() if owned else null


func get_active_owned_ship() -> OwnedShipData:
	if active_ship_index >= 0 and active_ship_index < owned_ships.size():
		return owned_ships[active_ship_index]
	return null


func level_up_ship(index: int) -> bool:
	if index < 0 or index >= owned_ships.size():
		return false
	var owned := owned_ships[index]
	if owned.level >= OwnedShipData.MAX_LEVEL:
		return false
	var cost := owned.get_level_up_cost()
	if not ResourceManager or not ResourceManager.can_afford(cost) or not ResourceManager.spend_resources(cost):
		return false
	owned.level += 1
	fleet_changed.emit()
	_refresh_ship_on_deck(index)
	return true


func equip_module(index: int, module: ShipModuleData) -> bool:
	if index < 0 or index >= owned_ships.size() or not module:
		return false
	var cost := {"gold": module.cost_gold, "wood": module.cost_wood, "iron": module.cost_iron}
	if not ResourceManager or not ResourceManager.can_afford(cost) or not ResourceManager.spend_resources(cost):
		return false
	owned_ships[index].equip_module(module)
	fleet_changed.emit()
	_refresh_ship_on_deck(index)
	return true


func _refresh_ship_on_deck(index: int) -> void:
	## Leveling/equipping the ship the player is currently sailing must be felt
	## immediately, not just on the next ship switch — mirrors the assignment
	## IslandMenu's own ship-purchase flow already does.
	if index != active_ship_index:
		return
	var player = get_tree().get_first_node_in_group("player_ship")
	if player and "ship_stats" in player:
		player.ship_stats = get_active_ship()

func get_active_captain() -> CaptainData:
	if active_captain_index >= 0 and active_captain_index < owned_captains.size():
		return owned_captains[active_captain_index]
	return null

func get_save_data() -> Dictionary:
	var ship_data = []
	for o in owned_ships:
		if o:
			ship_data.append(o.get_save_data())

	var cap_paths = []
	for c in owned_captains:
		cap_paths.append(c.resource_path)
		
	return {
		"owned_ships": ship_data,
		"owned_captains": cap_paths,
		"active_ship_index": active_ship_index,
		"active_captain_index": active_captain_index,
		"active_missions": active_missions.duplicate(true),
		"defend_home_ship_indices": defend_home_ship_indices.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	owned_ships.clear()
	owned_captains.clear()
	active_missions.clear()
	
	if data.has("owned_ships"):
		for entry in data["owned_ships"]:
			if entry is Dictionary:
				owned_ships.append(OwnedShipData.from_save_data(entry))
			elif entry is String and ResourceLoader.exists(entry):
				# Pre-M8 save format: a flat ship path, no level/modules yet.
				var legacy := OwnedShipData.new()
				legacy.ship_stats = load(entry)
				owned_ships.append(legacy)
				
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
			
	defend_home_ship_indices.clear()
	if data.has("defend_home_ship_indices"):
		for idx in data["defend_home_ship_indices"]:
			defend_home_ship_indices.append(int(idx))
	
	fleet_changed.emit()
