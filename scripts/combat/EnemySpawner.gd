class_name EnemySpawner extends Node

## Purpose: Manages the lifecycle of enemy ships in the world.
## Responsibilities: Spawns enemies at safe distances, replaces destroyed ones, caps population,
##   weights faction selection by reputation. Applies M4 empire scaling: compute_spawn_multiplier()
##   scales an empire-faction ship's effective max_health/cannon_damage by region tier + notoriety
##   at spawn time (via a duplicated ShipStats instance, never mutating the shared resource);
##   non-empire factions always spawn at multiplier 1.0.
## Dependencies: EnemyShip.tscn, player_ship group, FactionData.is_empire, EmpireManager.notoriety
##
## Limitations:
##   - No spawn zones or region-specific enemy types yet
##
## TODO:
##   - M8: Region-specific enemy types
##   - M10: Named pirate captain enemies

signal enemy_spawned(enemy: Node3D)
signal enemy_destroyed(enemy: Node3D)

@export_group("Population")
@export var max_enemies: int = 5
@export var initial_enemies: int = 3

@export_group("Spawning")
@export var spawn_interval: float = 30.0
@export var min_spawn_distance: float = 60.0
@export var max_spawn_distance: float = 120.0
@export var min_distance_from_islands: float = 25.0

@export_group("Variety")
@export var enemy_scene: PackedScene = preload("res://scenes/world/EnemyShip.tscn")

var _active_enemies: Array[Node3D] = []
var _spawn_timer: float = 0.0
var _player_ship: Node3D = null
var _enemies_container: Node3D = null
var available_factions: Array[Resource] = []

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_player_ship = get_tree().get_first_node_in_group("player_ship")
	
	# Load factions
	var f1 = load("res://resources/factions/PirateClans.tres")
	if f1: available_factions.append(f1)
	var f2 = load("res://resources/factions/RoyalNavy.tres")
	if f2: available_factions.append(f2)
	var f3 = load("res://resources/factions/MerchantGuild.tres")
	if f3: available_factions.append(f3)
	
	# Find or create the Enemies container in the scene
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return
	_enemies_container = current_scene.get_node_or_null("Enemies")
	if not _enemies_container:
		_enemies_container = Node3D.new()
		_enemies_container.name = "Enemies"
		current_scene.add_child(_enemies_container)
	
	# Register any existing enemies already placed in the scene
	for child in _enemies_container.get_children():
		if child.is_in_group("enemy_ship"):
			_track_enemy(child)
	
	# Spawn initial enemies if we don't have enough
	var to_spawn = initial_enemies - _active_enemies.size()
	for i in range(to_spawn):
		_spawn_enemy()

func _process(delta: float) -> void:
	# Clean up destroyed enemies from our tracking list in-place. Avoids
	# allocating a new Array + Callable closure every single frame, which
	# .filter() would do (perf: avoid repeated per-frame allocations).
	for i in range(_active_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_active_enemies[i]):
			_active_enemies.remove_at(i)

	# Spawn replacements on a timer
	if _active_enemies.size() < max_enemies:
		_spawn_timer += delta
		if _spawn_timer >= spawn_interval:
			_spawn_timer = 0.0
			_spawn_enemy()

func _spawn_enemy() -> void:
	if _active_enemies.size() >= max_enemies:
		return
		
	if not enemy_scene:
		return
	
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return  # Could not find a valid position
	
	var enemy = enemy_scene.instantiate()
	
	if available_factions.size() > 0:
		var chosen_faction = null
		if FactionManager:
			var total_weight = 0.0
			var weights = []
			for f in available_factions:
				var rep = FactionManager.get_reputation(f.faction_id)
				var weight = max(10.0, 100.0 - rep) # Hostile factions have higher weight
				weights.append(weight)
				total_weight += weight
				
			var roll = randf() * total_weight
			var current = 0.0
			for i in range(available_factions.size()):
				current += weights[i]
				if roll <= current:
					chosen_faction = available_factions[i]
					break
		else:
			chosen_faction = available_factions.pick_random()
			
		if "faction" in enemy:
			enemy.faction = chosen_faction
			
			if chosen_faction and chosen_faction.get("is_empire"):
				var tier = _get_region_tier_for_position(spawn_pos)
				var mult = compute_spawn_multiplier(tier)
				
				if enemy.get("ship_stats"):
					enemy.ship_stats = enemy.ship_stats.duplicate()
					enemy.ship_stats.max_health *= mult
					enemy.ship_stats.cannon_damage *= mult
					
	_enemies_container.add_child(enemy)
	enemy.global_position = spawn_pos
	
	# Randomize initial facing direction
	enemy.global_rotation.y = randf() * TAU
	
	_track_enemy(enemy)
	enemy_spawned.emit(enemy)

func _track_enemy(enemy: Node3D) -> void:
	_active_enemies.append(enemy)
	
	# Connect to ship_destroyed signal if available
	if enemy.has_signal("ship_destroyed"):
		enemy.ship_destroyed.connect(func(): _on_enemy_destroyed(enemy))

func _on_enemy_destroyed(enemy: Node3D) -> void:
	enemy_destroyed.emit(enemy)
	# The enemy will queue_free itself via ShipController._on_died()
	# Our _process() will clean it from the tracking list

func _find_spawn_position() -> Vector3:
	## Find a position that is:
	## - Far enough from the player
	## - Far enough from islands
	## - On the ocean surface (y = 0.3, ship settles just below this)
	
	for attempt in range(10):
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		
		var base_pos = Vector3.ZERO
		if _player_ship and is_instance_valid(_player_ship):
			base_pos = _player_ship.global_position
		
		var candidate = Vector3(
			base_pos.x + cos(angle) * distance,
			0.3,
			base_pos.z + sin(angle) * distance
		)
		
		# Check distance from islands
		var too_close = false
		var islands = get_tree().get_nodes_in_group("islands")
		for island in islands:
			if island.global_position.distance_to(candidate) < min_distance_from_islands:
				too_close = true
				break
		
		if not too_close:
			return candidate
	
	# Fallback: just pick a random spot
	return Vector3(randf_range(-100, 100), 0.3, randf_range(-100, 100))

func _get_region_tier_for_position(pos: Vector3) -> int:
	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty():
		return 1
		
	var closest_island = null
	var min_dist = INF
	for island in islands:
		var d = island.global_position.distance_to(pos)
		if d < min_dist:
			min_dist = d
			closest_island = island
			
	if closest_island and EmpireManager:
		var region = EmpireManager.get_region_for_island(closest_island.get_island_id())
		if region:
			return region.tier
			
	return 1

func compute_spawn_multiplier(region_tier: int) -> float:
	var current_notoriety = 0.0
	if EmpireManager:
		current_notoriety = EmpireManager.notoriety
	return 1.0 + max(0, region_tier - 1) * 0.3 + current_notoriety * 0.002

func get_active_enemy_count() -> int:
	return _active_enemies.size()

func spawn_hunter(faction: Resource) -> void:
	if not enemy_scene:
		return
		
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return
		
	var enemy = enemy_scene.instantiate()
	if "faction" in enemy:
		enemy.faction = faction
		
		if faction and faction.get("is_empire"):
			var tier = _get_region_tier_for_position(spawn_pos)
			var mult = compute_spawn_multiplier(tier)
			print("EnemySpawner: Spawning empire faction! mult=", mult)
			
			if enemy.get("ship_stats"):
				enemy.ship_stats = enemy.ship_stats.duplicate(true)
				print("EnemySpawner: duplicated ship_stats. Original max_health=", enemy.ship_stats.max_health)
				enemy.ship_stats.max_health *= mult
				enemy.ship_stats.cannon_damage *= mult
				print("EnemySpawner: after scaling max_health=", enemy.ship_stats.max_health)
			else:
				print("EnemySpawner: enemy.get('ship_stats') is null")
		else:
			print("EnemySpawner: not empire faction")
		
	_enemies_container.add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.global_rotation.y = randf() * TAU
	
	_track_enemy(enemy)
	enemy_spawned.emit(enemy)
	
	# Force targeting player
	if enemy.has_method("set_target") and _player_ship:
		enemy.set_target(_player_ship)
		
	if faction:
		print("Hunter spawned from faction: ", faction.get("faction_name"))
