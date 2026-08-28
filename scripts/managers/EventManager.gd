extends Node

signal world_event_triggered(event_name: String, data: Dictionary)

enum EventPriority {
	LOW,
	MEDIUM,
	HIGH,
	CRITICAL
}

var active_events: Array = []
var discovered_islands: Array = []

@export var min_event_interval: float = 60.0
@export var max_event_interval: float = 120.0
@export var spawn_distance: float = 100.0

var _timer: float = 0.0
var _next_event_time: float = 0.0
var _player_ship: Node3D = null
var _ocean_events: Array[EventData] = []

func _ready() -> void:
	_load_ocean_events()
	_schedule_next_event()

func _process(delta: float) -> void:
	if not get_tree().current_scene or get_tree().current_scene.name != "World":
		return
		
	if not _player_ship:
		_player_ship = get_tree().get_first_node_in_group("player_ship")
		
	if _player_ship and is_instance_valid(_player_ship):
		_timer += delta
		if _timer >= _next_event_time:
			_trigger_random_ocean_event()
			_schedule_next_event()

func trigger_event(event_name: String, data: Dictionary = {}, priority: EventPriority = EventPriority.MEDIUM) -> void:
	# Check for duplicates or priority rules if needed
	active_events.append({"name": event_name, "data": data, "priority": priority})
	_sort_events()
	_process_next_event()

func _sort_events() -> void:
	# Sort by priority, CRITICAL first
	active_events.sort_custom(func(a, b): return a["priority"] > b["priority"])

func _process_next_event() -> void:
	if active_events.is_empty():
		return
		
	var next_event = active_events.pop_front()
	emit_signal("world_event_triggered", next_event["name"], next_event["data"])
	
	# For now we process immediately, but this could be a queue that waits for UI

func handle_docking_event(island_id: String) -> void:
	if not discovered_islands.has(island_id):
		discovered_islands.append(island_id)
		trigger_event("island_discovered", {"island_id": island_id}, EventPriority.HIGH)
	
	trigger_event("ship_docked", {"island_id": island_id}, EventPriority.MEDIUM)

# --- OCEAN EVENTS (M7) ---

func _load_ocean_events() -> void:
	## Load all EventData resources from resources/world/events/ using the same
	## DirAccess scan pattern EmpireManager uses for regions — reused, not
	## reinvented (AGENTS.md principle).
	var dir = DirAccess.open("res://resources/world/events/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var event = load("res://resources/world/events/" + file_name) as EventData
				if event:
					_ocean_events.append(event)
			file_name = dir.get_next()
	else:
		push_warning("EventManager: Could not load event data from resources/world/events/")

func _schedule_next_event() -> void:
	_timer = 0.0
	_next_event_time = randf_range(min_event_interval, max_event_interval)

func _trigger_random_ocean_event() -> void:
	if not _player_ship or not is_instance_valid(_player_ship):
		return

	if _ocean_events.is_empty():
		return

	## Gate + weight events by the player's current region tier, reusing the
	## same nearest-island lookup pattern as EnemySpawner rather than a
	## second region-lookup mechanism.
	var player_region_tier = _get_player_region_tier()

	var eligible_events: Array[EventData] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0

	for event in _ocean_events:
		if event.min_region_tier <= player_region_tier:
			eligible_events.append(event)
			weights.append(event.weight)
			total_weight += event.weight

	if eligible_events.is_empty():
		# Should not happen under normal authoring (Beginner Waters events are
		# tier 1), but fall back to the first loaded event rather than doing
		# nothing — and give it a matching weight entry so the indexed lookup
		# below can't run off the end of an empty weights array.
		eligible_events.append(_ocean_events[0])
		weights.append(1.0)
		total_weight = 1.0

	var roll = randf() * total_weight
	var current = 0.0
	var picked_event: EventData = eligible_events[0]
	for i in range(eligible_events.size()):
		current += weights[i]
		if roll <= current:
			picked_event = eligible_events[i]
			break

	match picked_event.event_id:
		"merchant_convoy":
			_spawn_merchant_convoy()
		"floating_treasure":
			_spawn_floating_treasure()
		"ghost_ship_boss":
			_spawn_ghost_ship_boss()
		"iron_vulture_boss":
			_spawn_iron_vulture_boss()
		"fortunes_toll_boss":
			_spawn_fortunes_toll_boss()
		"drifting_wreckage":
			_spawn_drifting_wreckage()
		"smugglers_cache":
			_spawn_smugglers_cache()
		"pirate_raiding_party":
			_spawn_pirate_raiding_party()
		"royal_navy_patrol":
			_spawn_royal_navy_patrol()
		"favorable_winds":
			_apply_temporary_wind_modifier(1.6, 45.0)
		"becalmed":
			_apply_temporary_wind_modifier(0.0, 30.0)
		_:
			push_warning("EventManager: Unknown event_id '%s'" % picked_event.event_id)

func _get_player_region_tier() -> int:
	## Reuse the nearest-island pattern (same as EnemySpawner) to find the
	## player's current region tier. Defaults to tier 1 (Beginner Waters,
	## always available) if the player or region can't be resolved.
	if not _player_ship:
		return 1

	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty():
		return 1

	var closest_island = null
	var min_dist = INF
	for island in islands:
		var d = island.global_position.distance_to(_player_ship.global_position)
		if d < min_dist:
			min_dist = d
			closest_island = island

	if closest_island and EmpireManager:
		var region = EmpireManager.get_region_for_island(closest_island.get_island_id())
		if region:
			return region.tier

	return 1

func _get_random_spawn_pos() -> Vector3:
	var angle = randf() * TAU
	var base_pos = _player_ship.global_position
	return Vector3(
		base_pos.x + cos(angle) * spawn_distance,
		1.0, 
		base_pos.z + sin(angle) * spawn_distance
	)

func _spawn_merchant_convoy() -> void:
	trigger_event("merchant_convoy_spotted", {}, EventPriority.HIGH)
	
	var enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	var merchant_faction = load("res://resources/factions/MerchantGuild.tres")
	
	if not enemy_scene or not merchant_faction:
		return
		
	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if not container:
		container = get_tree().current_scene
		
	for i in range(3):
		var ship = enemy_scene.instantiate()
		if "faction" in ship:
			ship.faction = merchant_faction
			
		container.add_child(ship)
		var offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		ship.global_position = center + offset
		ship.global_rotation.y = randf() * TAU

func _spawn_floating_treasure() -> void:
	trigger_event("floating_treasure_spotted", {}, EventPriority.MEDIUM)
	
	var loot_scene = load("res://scenes/combat/LootDrop.tscn")
	if not loot_scene:
		return

	if AudioManager: AudioManager.play_sound("treasure_found")

	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene

	for i in range(5):
		var loot = loot_scene.instantiate()
		container.add_child(loot)
		
		var offset = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		loot.global_position = Vector3(center.x + offset.x, 1.5, center.z + offset.z)
		
		if loot.has_method("set"):
			loot.loot_data = {
				"gold": randi_range(50, 200),
				"wood": randi_range(10, 30),
				"iron": randi_range(5, 15),
				"rum": randi_range(2, 10)
			}

func _spawn_ghost_ship_boss() -> void:
	trigger_event("ghost_ship_spotted", {}, EventPriority.HIGH)
	
	var enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	var ghost_faction = load("res://resources/factions/GhostFaction.tres")
	var ghost_stats = load("res://resources/enemies/GhostShipStats.tres")
	
	if not enemy_scene or not ghost_faction or not ghost_stats:
		return
		
	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if not container:
		container = get_tree().current_scene
		
	var ship = enemy_scene.instantiate()
	ship.add_to_group("boss_ship")
	
	if "faction" in ship:
		ship.faction = ghost_faction
	if "ship_stats" in ship:
		ship.ship_stats = ghost_stats
		
	container.add_child(ship)
	ship.global_position = center
	ship.global_rotation.y = randf() * TAU
	
	# Scale it up slightly to look intimidating
	ship.scale = Vector3(1.5, 1.5, 1.5)

func _spawn_iron_vulture_boss() -> void:
	## M11 Requirement 5 — an ambient boss, following _spawn_ghost_ship_boss()'s
	## proven pattern rather than the EncounterData/EncounterManager path,
	## which is only actually consumed by the chapter-gated bosses (Intransigent/
	## Cárdenas). Unlike Ghost Ship, this boss has its own dedicated scene with
	## ship_stats/ai_profile already wired in, so no override dance is needed.
	trigger_event("iron_vulture_spotted", {}, EventPriority.HIGH)

	var enemy_scene = load("res://scenes/world/IronVultureBoss.tscn")
	if not enemy_scene:
		return

	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if not container:
		container = get_tree().current_scene

	var ship = enemy_scene.instantiate()
	ship.add_to_group("boss_ship")
	container.add_child(ship)
	ship.global_position = center
	ship.global_rotation.y = randf() * TAU

func _spawn_fortunes_toll_boss() -> void:
	## M11 Requirement 5 — see _spawn_iron_vulture_boss()'s note above; same
	## dedicated-scene ambient pattern.
	trigger_event("fortunes_toll_spotted", {}, EventPriority.HIGH)

	var enemy_scene = load("res://scenes/world/FortunesTollBoss.tscn")
	if not enemy_scene:
		return

	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if not container:
		container = get_tree().current_scene

	var ship = enemy_scene.instantiate()
	ship.add_to_group("boss_ship")
	container.add_child(ship)
	ship.global_position = center
	ship.global_rotation.y = randf() * TAU

# --- M11 Requirement 7 — world events expansion ---

func _spawn_loot(count: int, gold_range: Vector2i, wood_range: Vector2i, iron_range: Vector2i) -> void:
	## Shared by _spawn_drifting_wreckage()/_spawn_smugglers_cache() — the same
	## LootDrop.tscn scattering _spawn_floating_treasure() already does, just
	## parameterized instead of copy-pasted per event.
	var loot_scene = load("res://scenes/combat/LootDrop.tscn")
	if not loot_scene:
		return

	if AudioManager: AudioManager.play_sound("treasure_found")

	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene

	for i in range(count):
		var loot = loot_scene.instantiate()
		container.add_child(loot)

		var offset = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		loot.global_position = Vector3(center.x + offset.x, 1.5, center.z + offset.z)

		if loot.has_method("set"):
			loot.loot_data = {
				"gold": randi_range(gold_range.x, gold_range.y),
				"wood": randi_range(wood_range.x, wood_range.y),
				"iron": randi_range(iron_range.x, iron_range.y),
				"rum": randi_range(1, 6),
			}

func _spawn_drifting_wreckage() -> void:
	trigger_event("drifting_wreckage_spotted", {}, EventPriority.MEDIUM)
	_spawn_loot(3, Vector2i(15, 60), Vector2i(5, 15), Vector2i(2, 8))

func _spawn_smugglers_cache() -> void:
	trigger_event("smugglers_cache_spotted", {}, EventPriority.MEDIUM)
	_spawn_loot(7, Vector2i(60, 220), Vector2i(15, 40), Vector2i(8, 25))

func _spawn_hostile_ships(faction_path: String, count: int) -> void:
	## Shared by _spawn_pirate_raiding_party()/_spawn_royal_navy_patrol() — the
	## same enemy-ship-scattering _spawn_merchant_convoy() already does for a
	## friendly faction, parameterized for a hostile one instead.
	var enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	var faction = load(faction_path)
	if not enemy_scene or not faction:
		return

	var center = _get_random_spawn_pos()
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if not container:
		container = get_tree().current_scene

	for i in range(count):
		var ship = enemy_scene.instantiate()
		if "faction" in ship:
			ship.faction = faction

		container.add_child(ship)
		var offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		ship.global_position = center + offset
		ship.global_rotation.y = randf() * TAU

func _spawn_pirate_raiding_party() -> void:
	trigger_event("pirate_raiding_party_spotted", {}, EventPriority.HIGH)
	_spawn_hostile_ships("res://resources/factions/PirateClans.tres", 2)

func _spawn_royal_navy_patrol() -> void:
	trigger_event("royal_navy_patrol_spotted", {}, EventPriority.HIGH)
	_spawn_hostile_ships("res://resources/factions/RoyalNavy.tres", 2)

func _get_player_region() -> RegionData:
	## Mirrors _get_player_region_tier()'s nearest-island lookup but returns
	## the RegionData itself, needed to mutate wind_strength temporarily.
	if not _player_ship:
		return null
	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty():
		return null
	var closest_island = null
	var min_dist = INF
	for island in islands:
		var d = island.global_position.distance_to(_player_ship.global_position)
		if d < min_dist:
			min_dist = d
			closest_island = island
	if closest_island and EmpireManager:
		return EmpireManager.get_region_for_island(closest_island.get_island_id())
	return null

func _apply_temporary_wind_modifier(multiplier: float, duration: float) -> void:
	## M11 Requirement 7/2 tie-in — "Favorable Winds"/"Becalmed" temporarily
	## scale the player's current region's wind_strength, then restore the
	## exact original value on a timer. RegionData is a shared Resource (the
	## same instance ShipMovement/WorldHUD read), so this mutates and restores
	## it directly rather than keeping a second parallel "current wind" value —
	## same caution EnvironmentController's own weather code already documents
	## about not letting temporary changes compound.
	var region = _get_player_region()
	if not region:
		return
	if AudioManager: AudioManager.play_sound("wind_shift")
	trigger_event("wind_shifted", {"multiplier": multiplier}, EventPriority.LOW)
	var original_strength = region.wind_strength
	region.wind_strength = clampf(original_strength * multiplier, 0.0, 1.0) if multiplier > 0.0 else 0.0
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(region):
			region.wind_strength = original_strength)
