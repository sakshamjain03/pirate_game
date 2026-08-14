extends Node

## Purpose: Drives the M4 empire-escalation loop — notoriety, region activation, and raids.
## Responsibilities: Tracks notoriety (with idle decay); loads the 3 RegionData resources and
##   activates each once notoriety crosses its threshold; computes home-island defense score
##   (buildings + Defend Home fleet) and empire attack score; periodically rolls and resolves
##   raids against the home island, deducting stolen resources on a loss; persists all of the
##   above via get_save_data()/load_save_data().
## Dependencies: RegionData resources (resources/world/regions/), Island.gd (built_buildings,
##   island id lookup), FleetManager (get_ships_defending_home), ResourceManager (raid theft).

signal notoriety_changed(new_value: float)
signal region_activated(region_id: String)
signal island_captured(island_id: String)

var notoriety: float = 0.0
var _last_gain_unix: int = 0
var _regions: Array[RegionData] = []
var _region_active: Dictionary = {}
var home_island_id: String = ""
var pending_raid_report = null
var _last_raid_check_unix: int = 0

signal raid_resolved(report: Dictionary)

func _ready() -> void:
	set_process(true)
	_last_gain_unix = int(Time.get_unix_time_from_system())
	
	var dir = DirAccess.open("res://resources/world/regions/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var region = load("res://resources/world/regions/" + file_name) as RegionData
				if region:
					_regions.append(region)
					# Region 1 is true, others false initially
					_region_active[region.id] = (region.tier == 1)
			file_name = dir.get_next()
			
	notoriety_changed.connect(_check_region_activation)

func is_region_active(region_id: String) -> bool:
	return _region_active.get(region_id, false)

func get_region_for_island(island_id: String) -> RegionData:
	for region in _regions:
		if island_id in region.island_ids:
			return region
	return null

func _check_region_activation(new_notoriety: float) -> void:
	for region in _regions:
		if not _region_active.get(region.id, false):
			if new_notoriety >= region.activation_notoriety_threshold:
				_region_active[region.id] = true
				region_activated.emit(region.id)

func _process(delta: float) -> void:
	if notoriety <= 0.0:
		return
		
	var now = int(Time.get_unix_time_from_system())
	# Decay if more than 10 minutes have passed since last gain
	if now - _last_gain_unix > 600:
		var old = notoriety
		notoriety -= (1.0 / 60.0) * delta
		if notoriety < 0.0:
			notoriety = 0.0
			
		# To avoid spamming signals every frame with micro-changes, 
		# We'll emit the signal, but in a real game we might throttle this.
		# The prompt says "decreases at a slow rate ... clamped to 0.0" 
		# so emitting is fine since UI lerps anyway.
		notoriety_changed.emit(notoriety)

	# Also check raid periodically
	if _last_raid_check_unix == 0:
		_last_raid_check_unix = now
	elif now - _last_raid_check_unix > 900: 
		_last_raid_check_unix = now
		_check_raid()

func notify_island_captured(island_id: String) -> void:
	island_captured.emit(island_id)

signal island_tier_changed(island_id: String, new_tier: int)

func notify_island_tier_changed(island_id: String, new_tier: int) -> void:
	island_tier_changed.emit(island_id, new_tier)

func add_notoriety(amount: float) -> void:
	if amount > 0.0:
		_last_gain_unix = int(Time.get_unix_time_from_system())
		
	notoriety += amount
	if notoriety < 0.0:
		notoriety = 0.0
	notoriety_changed.emit(notoriety)

func _compute_defense_score() -> float:
	if home_island_id.is_empty():
		return 0.0
		
	var target_island = null
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("get_island_id") and island.get_island_id() == home_island_id:
			target_island = island
			break
			
	if not target_island:
		return 0.0
		
	var fortress_tier: float = 1.0 if target_island.has_building("fortress") else 0.0
	var watchtower_tier: float = 1.0 if target_island.has_building("watchtower") else 0.0
	
	var num_ships_defending_home: int = 0
	# Task 18 will update num_ships_defending_home via FleetManager
	if FleetManager.has_method("get_ships_defending_home"):
		num_ships_defending_home = FleetManager.get_ships_defending_home()
	
	return (fortress_tier * 20.0) + (watchtower_tier * 15.0) + (10.0 * float(num_ships_defending_home))

func _compute_attack_score() -> float:
	var highest_tier = 1
	for region in _regions:
		if is_region_active(region.id) and region.tier > highest_tier:
			highest_tier = region.tier
	return float(highest_tier * 25.0) + (notoriety * 0.3)

func _get_faction_by_id(f_id: String) -> Resource:
	var dir = DirAccess.open("res://resources/factions/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load("res://resources/factions/" + file_name)
				if res and res.get("faction_id") == f_id:
					return res
			file_name = dir.get_next()
	return null

func _check_raid() -> void:
	if home_island_id.is_empty():
		return
	
	var active_empire_regions = []
	for region in _regions:
		if is_region_active(region.id):
			var faction = _get_faction_by_id(region.dominant_faction)
			if faction and faction.get("is_empire") == true:
				active_empire_regions.append(region)
				
	if active_empire_regions.is_empty():
		return
		
	# Reverted probability floor
	var prob = clamp(notoriety / 200.0, 0.05, 0.25)
	if randf() <= prob:
		# Pick the highest tier empire region to raid
		var attacking_region = active_empire_regions[0]
		for r in active_empire_regions:
			if r.tier > attacking_region.tier:
				attacking_region = r
		
		var attacking_faction = _get_faction_by_id(attacking_region.dominant_faction)
		if attacking_faction:
			var report = _resolve_raid(attacking_faction, attacking_region)
			pending_raid_report = report
			raid_resolved.emit(report)

func _resolve_raid(attacking_faction: Resource, region: RegionData) -> Dictionary:
	var defense_score = _compute_defense_score()
	var attack_score = _compute_attack_score()
	
	var repelled = defense_score >= attack_score
	var stolen = {}
	
	if not repelled:
		var steal_fraction = clamp((attack_score - defense_score) / attack_score, 0.05, 0.25)
		var current_resources = ResourceManager.current_resources
		for res_name in current_resources.keys():
			var current_amount = current_resources[res_name]
			var amount = floor(current_amount * steal_fraction)
			if amount > 0:
				stolen[res_name] = int(amount)
				ResourceManager.spend_resource(res_name, int(amount))
	
	var faction_id = attacking_faction.get("faction_id") if attacking_faction else "unknown"
	return {
		"faction_id": faction_id,
		"repelled": repelled,
		"stolen": stolen,
		"timestamp_unix": int(Time.get_unix_time_from_system())
	}

func get_save_data() -> Dictionary:
	return {
		"notoriety": notoriety,
		"region_active": _region_active.duplicate(),
		"home_island_id": home_island_id,
		"last_raid_check_unix": _last_raid_check_unix,
		"pending_raid_report": pending_raid_report
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("notoriety"):
		notoriety = float(data["notoriety"])
	if data.has("region_active") and typeof(data["region_active"]) == TYPE_DICTIONARY:
		_region_active = data["region_active"].duplicate()
	if data.has("home_island_id"):
		home_island_id = str(data["home_island_id"])
	if data.has("last_raid_check_unix"):
		_last_raid_check_unix = int(data["last_raid_check_unix"])
	if data.has("pending_raid_report"):
		pending_raid_report = data["pending_raid_report"]
		
	notoriety_changed.emit(notoriety)
