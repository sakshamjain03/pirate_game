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
## M25 - FALLBACKS ONLY. The live cap and cadence come from the current heat tier
## (resources/balance/HeatCurve.tres, via EmpireManager), so ambient danger tracks
## the trouble the player has caused instead of sitting at a flat 5 forever. These
## are used only when the heat curve is unavailable: a spawner instanced outside
## the world, or a failed resource load.
@export var max_enemies: int = 5
@export var initial_enemies: int = 3

@export_group("Spawning")
@export var spawn_interval: float = 30.0
@export var min_spawn_distance: float = 60.0
@export var max_spawn_distance: float = 120.0
## Measured from island *centre*, so this must clear the island's own collision
## radius (38u since the docs/21 §2 scale-up) plus room for a hull — at the old
## 25.0 the check passed for points well inside the terrain, spawning ships
## inside islands.
@export var min_distance_from_islands: float = 55.0

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

## M26 — when valid, replaces the heat-tier lookup (and the empire/notoriety
## strength scaling) for every ambient spawn. Called with no arguments; returns
## {"cap": int, "interval": float, "strength": float, "pool": Array[PackedScene]}.
## Set by MaelstromRun; left invalid in the campaign, where nothing here changes.
var spawn_profile_override: Callable = Callable()

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
	# Clamped to the heat cap so a brand-new player (tier 0, cap 2) does not open
	# the game surrounded by three hostiles - the initial burst must never exceed
	# what the current tier allows.
	var to_spawn = mini(initial_enemies, get_active_max_enemies()) - _active_enemies.size()
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

	if _active_enemies.size() < get_active_max_enemies():
		_spawn_timer += delta
		if _spawn_timer >= get_active_spawn_interval():
			_spawn_timer = 0.0
			_spawn_enemy()

func _spawn_enemy() -> void:
	if _active_enemies.size() >= get_active_max_enemies():
		return
		
	if not enemy_scene:
		return
	
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return  # Could not find a valid position

	if spawn_profile_override.is_valid():
		_spawn_from_profile(spawn_profile_override.call(), spawn_pos)
		return

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


## M26 — a profile-driven spawn: hull from the profile's pool, strength from the
## profile instead of region/notoriety/heat, always engaging. Faction is still
## rolled so hulls keep their colours and AI behaviour.
func _spawn_from_profile(profile: Dictionary, spawn_pos: Vector3) -> void:
	var scene: PackedScene = enemy_scene
	var pool: Array = profile.get("pool", [])
	if not pool.is_empty():
		var picked = pool.pick_random()
		if picked:
			scene = picked
	var enemy := _instantiate_scaled(scene, float(profile.get("strength", 1.0)))
	if enemy == null:
		return
	if "faction" in enemy and available_factions.size() > 0:
		enemy.faction = available_factions.pick_random()
	_add_engaging(enemy, spawn_pos)


## M26 — spawns one specific scene (a Maelstrom band's boss) at a safe distance,
## scaled by `strength`, always engaging. Returns the hull, or null on failure.
func spawn_scene(scene: PackedScene, strength: float = 1.0) -> Node3D:
	if not scene or not _enemies_container:
		return null
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return null
	var enemy := _instantiate_scaled(scene, strength)
	if enemy == null:
		return null
	_add_engaging(enemy, spawn_pos)
	return enemy


func _instantiate_scaled(scene: PackedScene, strength: float) -> Node3D:
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		push_error("EnemySpawner: scene '%s' is not a Node3D" % scene.resource_path)
		return null
	if enemy.get("ship_stats"):
		# Duplicate, never mutate the shared .tres (Requirement 3.5).
		enemy.ship_stats = enemy.ship_stats.duplicate(true)
		enemy.ship_stats.max_health *= strength
		enemy.ship_stats.cannon_damage *= strength
	return enemy


func _add_engaging(enemy: Node3D, spawn_pos: Vector3) -> void:
	_enemies_container.add_child(enemy)
	_place_upright(enemy, spawn_pos, randf() * TAU)
	# Not ambient: heat-tier passivity (EnemyAI._may_engage_player) must never
	# apply — every Maelstrom hull engages unprovoked (Requirement 3.3).
	_track_enemy(enemy, false)
	var ai = enemy.get_node_or_null("EnemyAI")
	if ai and ai.has_method("provoke"):
		ai.provoke()
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

## `ambient` marks a hull as part of the background population, which is the only
## kind that heat is allowed to make passive (EnemyAI._may_engage_player). Hunters
## dispatched at the player, boss hulls and encounter/siege spawns are scripted and
## must always engage, or a fight the game promised would silently never start.
func _track_enemy(enemy: Node3D, ambient: bool = true) -> void:
	if ambient:
		enemy.add_to_group("ambient_enemy")
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

## M25 - the current heat tier, or null outside the world / if the curve failed
## to load. Every caller must handle null by falling back to its @export.
func _heat_tier() -> HeatTierData:
	if EmpireManager and EmpireManager.has_method("get_heat_tier"):
		return EmpireManager.get_heat_tier()
	return null


## Live ambient cap - the heart of the wanted-level feel: 2 hulls when the player
## is unknown, 8 when they are a Nemesis.
func get_active_max_enemies() -> int:
	if spawn_profile_override.is_valid():
		return int(spawn_profile_override.call().get("cap", max_enemies))
	var tier := _heat_tier()
	return tier.max_ambient_enemies if tier else max_enemies


func get_active_spawn_interval() -> float:
	if spawn_profile_override.is_valid():
		return float(spawn_profile_override.call().get("interval", spawn_interval))
	var tier := _heat_tier()
	return tier.spawn_interval_seconds if tier else spawn_interval


func compute_spawn_multiplier(region_tier: int) -> float:
	var current_notoriety = 0.0
	if EmpireManager:
		current_notoriety = EmpireManager.notoriety
	var base: float = 1.0 + max(0, region_tier - 1) * 0.3 + current_notoriety * 0.002
	# Heat composes with the existing region/notoriety scaling rather than
	# replacing it: region tier says "these waters are dangerous", heat says
	# "and they are hunting YOU".
	var tier := _heat_tier()
	if tier:
		base *= tier.enemy_strength_multiplier
	return base

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

	_track_enemy(enemy, false)   # a hunter is dispatched at the player, never passive
	enemy_spawned.emit(enemy)

	# Force targeting player
	if enemy.has_method("set_target") and _player_ship:
		enemy.set_target(_player_ship)
