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

func _ready() -> void:
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

func _schedule_next_event() -> void:
	_timer = 0.0
	_next_event_time = randf_range(min_event_interval, max_event_interval)

func _trigger_random_ocean_event() -> void:
	if not _player_ship or not is_instance_valid(_player_ship):
		return
		
	var event_type = randi() % 3 # Increased from 2 to 3
	match event_type:
		0:
			_spawn_merchant_convoy()
		1:
			_spawn_floating_treasure()
		2:
			_spawn_ghost_ship_boss()

func _get_random_spawn_pos() -> Vector3:
	var angle = randf() * TAU
	var base_pos = _player_ship.global_position
	return Vector3(
		base_pos.x + cos(angle) * spawn_distance,
		1.0, 
		base_pos.z + sin(angle) * spawn_distance
	)

func _spawn_merchant_convoy() -> void:
	print("EventManager: Triggering Merchant Convoy!")
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
	print("EventManager: Triggering Floating Treasure!")
	trigger_event("floating_treasure_spotted", {}, EventPriority.MEDIUM)
	
	var loot_scene = load("res://scenes/combat/LootDrop.tscn")
	if not loot_scene:
		return
		
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
	print("EventManager: A chilling fog rolls in... The Ghost Ship appears!")
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
