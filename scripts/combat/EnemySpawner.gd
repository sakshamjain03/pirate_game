class_name EnemySpawner extends Node

## Purpose: Manages the lifecycle of enemy ships in the world.
## Responsibilities: Spawns enemies at safe distances, replaces destroyed ones, caps population,
##   weights faction selection by reputation. Applies M4 empire scaling: compute_spawn_multiplier()
##   scales an empire-faction ship's effective max_health/cannon_damage by region tier + notoriety
##   at spawn time (via a duplicated ShipStats instance, never mutating the shared resource);
##   non-empire factions always spawn at multiplier 1.0. Selects enemy ship types per region
##   (M10 Requirement 5) from RegionData.enemy_ship_pool, or falls back to default scene stats.
## Dependencies: EnemyShip.tscn, player_ship group, FactionData.is_empire, EmpireManager.notoriety,
##               RegionData.enemy_ship_pool
##
## TODO:
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

## Ambient spawning is paused by `EncounterManager` for the duration of a bounded
## encounter: the point of an encounter is a known composition, and a background
## spawner trickling extra hulls in would keep polluting it (and would make the
## DESTROY_ALL objective unwinnable). `spawn_hunter()` deliberately ignores this —
## a faction hunter is a directed consequence of the player's own reputation.
@export var spawning_enabled: bool = true

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
	if not spawning_enabled:
		return

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
					## M10 Requirement 5 — if this region has an enemy ship pool,
					## pick a random ship type from it. Otherwise fall back to the
					## enemy scene's built-in default stats.
					var region = _get_region_for_position(spawn_pos)
					if region and not region.enemy_ship_pool.is_empty():
						var picked_stats = region.enemy_ship_pool.pick_random()
						if picked_stats:
							enemy.ship_stats = picked_stats.duplicate()
					else:
						enemy.ship_stats = enemy.ship_stats.duplicate()
					enemy.ship_stats.max_health *= mult
					enemy.ship_stats.cannon_damage *= mult

	_enemies_container.add_child(enemy)
	_place_upright(enemy, spawn_pos, randf() * TAU)

	_track_enemy(enemy)
	enemy_spawned.emit(enemy)


func _place_upright(enemy: Node3D, spawn_pos: Vector3, yaw: float) -> void:
	## Set position and facing in a single explicit basis assignment.
	##
	## This used to be `global_position = ...` followed by
	## `global_rotation.y = randf() * TAU`. Assigning a single Euler component
	## on a RigidBody3D reads the current basis, decomposes it to Euler angles,
	## substitutes y, and recomposes — so any roll/pitch already present is
	## folded back in rather than cleared, and the body starts tilted. Building
	## the basis from scratch guarantees a dead-level hull with only yaw.
	enemy.global_transform = Transform3D(Basis(Vector3.UP, yaw), spawn_pos)
	if enemy is RigidBody3D:
		# Clear any velocity inherited from the instantiated scene state, so a
		# freshly spawned ship isn't already rolling when buoyancy first runs.
		enemy.linear_velocity = Vector3.ZERO
		enemy.angular_velocity = Vector3.ZERO

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
	
	var base_pos = Vector3.ZERO
	if _player_ship and is_instance_valid(_player_ship):
		base_pos = _player_ship.global_position

	# Track the roomiest candidate seen so we have a sane answer if none of the
	# attempts fully clears the islands. The previous fallback was a hardcoded
	# Vector3(randf_range(-100, 100), 0.3, randf_range(-100, 100)) box centred on
	# the world origin — which since the 2026-08-14 map reposition (docs/11_WORLD_MAP.md
	# §4a) is the *home island itself*, so it dropped enemies on top of Port Royal.
	# Keeping the best attempt needs no magic numbers at all, and always lands in
	# the player's neighbourhood regardless of how large the map grows.
	var best_candidate := Vector3.ZERO
	var best_clearance := -INF
	var islands := get_tree().get_nodes_in_group("islands")

	for attempt in range(10):
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, max_spawn_distance)

		var candidate = Vector3(
			base_pos.x + cos(angle) * distance,
			0.3,
			base_pos.z + sin(angle) * distance
		)

		# Clearance = distance to the nearest island; INF when there are none.
		var clearance := INF
		for island in islands:
			clearance = minf(clearance, island.global_position.distance_to(candidate))

		if clearance >= min_distance_from_islands:
			return candidate

		if clearance > best_clearance:
			best_clearance = clearance
			best_candidate = candidate

	return best_candidate

func _get_region_for_position(pos: Vector3) -> RegionData:
	## Get the full RegionData for the region containing the closest island to pos.
	## Reuse this for both tier lookup and enemy ship pool lookup.
	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty():
		return null

	var closest_island = null
	var min_dist = INF
	for island in islands:
		var d = island.global_position.distance_to(pos)
		if d < min_dist:
			min_dist = d
			closest_island = island

	if closest_island and EmpireManager:
		return EmpireManager.get_region_for_island(closest_island.get_island_id())

	return null

func _get_region_tier_for_position(pos: Vector3) -> int:
	## Convenience wrapper: get tier from the region, or 1 if no region found.
	var region = _get_region_for_position(pos)
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

			if enemy.get("ship_stats"):
				## M10 Requirement 5 — apply regional ship pool same as _spawn_enemy().
				var region = _get_region_for_position(spawn_pos)
				if region and not region.enemy_ship_pool.is_empty():
					var picked_stats = region.enemy_ship_pool.pick_random()
					if picked_stats:
						enemy.ship_stats = picked_stats.duplicate(true)
				else:
					enemy.ship_stats = enemy.ship_stats.duplicate(true)
				enemy.ship_stats.max_health *= mult
				enemy.ship_stats.cannon_damage *= mult

	_enemies_container.add_child(enemy)
	_place_upright(enemy, spawn_pos, randf() * TAU)

	_track_enemy(enemy)
	enemy_spawned.emit(enemy)

	# Force targeting player
	if enemy.has_method("set_target") and _player_ship:
		enemy.set_target(_player_ship)
