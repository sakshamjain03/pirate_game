extends GutTest

## Guards the map geometry described in docs/11_WORLD_MAP.md.
##
## This file exists because of D59: tier-2 Skull Cove was authored 54u from the home
## island while tier-1 Tortuga sat 94u out, so distance stopped signalling danger —
## the map's primary spatial read. Nothing in the suite asserted anything about where
## islands are, so the inversion survived every prior pass. These tests fail loudly if
## a future island move breaks the ring bands, the minimum spacing, or the two-way
## island<->region relationship.
##
## Note: island placement lives in World.tscn's transforms; IslandData.world_position
## mirrors it for code that must reason about distance without walking the scene tree.
## test_world_position_matches_the_scene_transform is what keeps the two honest.

const ISLAND_PATHS := {
	"port_royal": "res://resources/world/PortRoyal.tres",
	"tortuga": "res://resources/world/Tortuga.tres",
	"skull_cove": "res://resources/world/SkullCove.tres",
	"frozen_island": "res://resources/world/FrozenIsland.tres",
	"volcano_island": "res://resources/world/VolcanoIsland.tres",
	"cartagena_outpost": "res://resources/world/CartagenaOutpost.tres",
}

const REGION_PATHS := [
	"res://resources/world/regions/BeginnerWaters.tres",
	"res://resources/world/regions/ContestedWaters.tres",
	"res://resources/world/regions/ImperialWaters.tres",
]

## Ring bands per region tier, in world units from the home island — docs/11_WORLD_MAP.md §4a.
const TIER_BANDS := {
	1: Vector2(60.0, 110.0),
	2: Vector2(140.0, 180.0),
	3: Vector2(220.0, 270.0),
}

const HOME_ISLAND_ID := "port_royal"

## Islands must not overlap: the beach/terrain union radius is ~13.7u (see D25), so
## two islands need >= 40u between centres to leave navigable water between them.
const MIN_ISLAND_SPACING := 40.0

var _islands: Dictionary = {}   # island_id -> IslandData
var _regions: Array = []        # RegionData


func before_all() -> void:
	for id in ISLAND_PATHS:
		var data = load(ISLAND_PATHS[id])
		assert_not_null(data, "Island resource missing: %s" % ISLAND_PATHS[id])
		_islands[id] = data
	for path in REGION_PATHS:
		var region = load(path)
		assert_not_null(region, "Region resource missing: %s" % path)
		_regions.append(region)


func _region_for_tier(tier: int) -> Resource:
	for region in _regions:
		if region.tier == tier:
			return region
	return null


func _distance_from_home(data: Resource) -> float:
	var home: Resource = _islands[HOME_ISLAND_ID]
	# Explicit annotations throughout this file: property access on a `Resource` yields
	# Variant, and this project promotes "inferred from Variant" to a parse error (D43).
	var distance: float = data.world_position.distance_to(home.world_position)
	return distance


func test_every_island_declares_a_region() -> void:
	for id in _islands:
		assert_false(
			str(_islands[id].region_id).is_empty(),
			"Island '%s' has no region_id — the world map cannot place it" % id
		)


func test_island_region_relationship_is_two_way() -> void:
	# RegionData.island_ids and IslandData.region_id must agree. Either alone is a
	# one-way link that can silently drift out of sync.
	for id in _islands:
		var region_id: String = _islands[id].region_id
		var matched := false
		for region in _regions:
			if region.id == region_id:
				matched = true
				assert_true(
					region.island_ids.has(id),
					"Island '%s' claims region '%s', but that region's island_ids does not list it"
					% [id, region_id]
				)
		assert_true(matched, "Island '%s' names region '%s', which does not exist" % [id, region_id])


func test_home_island_is_at_the_origin() -> void:
	assert_eq(
		_islands[HOME_ISLAND_ID].world_position,
		Vector2.ZERO,
		"The home island anchors every distance in the map spec; it must sit at the origin"
	)


func test_island_distance_matches_its_region_tier() -> void:
	# This is the D59 guard: region tier and distance from home must agree, so that
	# sailing further always means sailing into more danger.
	for id in _islands:
		if id == HOME_ISLAND_ID:
			continue
		var data: Resource = _islands[id]
		var region := _region_for_tier(-1)
		for r in _regions:
			if r.id == data.region_id:
				region = r
		assert_not_null(region, "No region resource for island '%s'" % id)
		var band: Vector2 = TIER_BANDS[region.tier]
		var distance := _distance_from_home(data)
		assert_between(
			distance, band.x, band.y,
			"Island '%s' (region tier %d) is %.1fu from home, outside its %.0f-%.0fu ring band"
			% [id, region.tier, distance, band.x, band.y]
		)


func test_higher_tier_regions_are_strictly_further_out() -> void:
	# Stronger than the per-island band check: no tier-N island may be closer to home
	# than any tier-(N-1) island, whatever the bands happen to be tuned to.
	var furthest_by_tier := {}
	var nearest_by_tier := {}
	for id in _islands:
		if id == HOME_ISLAND_ID:
			continue
		var tier := 0
		for r in _regions:
			if r.id == _islands[id].region_id:
				tier = r.tier
		var distance := _distance_from_home(_islands[id])
		if not furthest_by_tier.has(tier) or distance > furthest_by_tier[tier]:
			furthest_by_tier[tier] = distance
		if not nearest_by_tier.has(tier) or distance < nearest_by_tier[tier]:
			nearest_by_tier[tier] = distance

	var tiers: Array = furthest_by_tier.keys()
	tiers.sort()
	for i in range(tiers.size() - 1):
		var inner: int = tiers[i]
		var outer: int = tiers[i + 1]
		assert_gt(
			nearest_by_tier[outer], furthest_by_tier[inner],
			"Tier %d's nearest island (%.1fu) is closer than tier %d's furthest (%.1fu) — distance no longer signals danger"
			% [outer, nearest_by_tier[outer], inner, furthest_by_tier[inner]]
		)


func test_islands_do_not_overlap() -> void:
	var ids: Array = _islands.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Resource = _islands[ids[i]]
			var b: Resource = _islands[ids[j]]
			var distance: float = a.world_position.distance_to(b.world_position)
			assert_gte(
				distance, MIN_ISLAND_SPACING,
				"Islands '%s' and '%s' are only %.1fu apart (minimum %.0fu) — their terrain would merge"
				% [ids[i], ids[j], distance, MIN_ISLAND_SPACING]
			)


func test_world_position_matches_the_scene_transform() -> void:
	# IslandData.world_position is a mirror of World.tscn's authored transform. If the
	# two drift, every distance calculation in code silently disagrees with what the
	# player actually sails through.
	var world: Node3D = load("res://scenes/world/World.tscn").instantiate()
	add_child_autoqfree(world)
	await wait_process_frames(2)

	var islands_node := world.get_node_or_null("Islands")
	assert_not_null(islands_node, "World.tscn should have an Islands node")

	var seen := 0
	for child in islands_node.get_children():
		var data = child.get("island_data")
		if data == null:
			continue
		var authored := Vector2(child.transform.origin.x, child.transform.origin.z)
		assert_almost_eq(
			authored, data.world_position, Vector2(0.5, 0.5),
			"Island '%s' sits at %s in World.tscn but declares world_position %s"
			% [data.island_id, authored, data.world_position]
		)
		seen += 1

	assert_eq(seen, ISLAND_PATHS.size(), "Expected every authored island to be checked")


func test_authored_player_spawn_is_clear_of_every_island() -> void:
	# Asserts the *authored* spawn in World.tscn, deliberately without instantiating the
	# scene. PlayerShip is a RigidBody3D and the physics server does not honour the
	# authored transform on spawn — measured 2026-08-14, it reports the world origin
	# instead (logged as D60). That is a runtime bug to fix separately; this test's job
	# is to guard the layout data, which must be right either way. Once D60 is fixed,
	# this can also assert the runtime position.
	var scene_text := FileAccess.get_file_as_string("res://scenes/world/World.tscn")
	assert_false(scene_text.is_empty(), "Could not read World.tscn")

	var spawn := _parse_authored_origin(scene_text, "PlayerShip")
	assert_ne(spawn, Vector2.INF, "Could not find PlayerShip's authored transform in World.tscn")

	for id in _islands:
		var island: Resource = _islands[id]
		var distance: float = spawn.distance_to(island.world_position)
		assert_gte(
			distance, MIN_ISLAND_SPACING,
			"Player spawns %.1fu from '%s' — inside its terrain, so the ship starts beached"
			% [distance, id]
		)


## Pulls the XZ translation out of the `transform = Transform3D(...)` line that follows
## a given node header in a .tscn file. Returns Vector2.INF if not found.
func _parse_authored_origin(scene_text: String, node_name: String) -> Vector2:
	var lines := scene_text.split("\n")
	var found_node := false
	for line in lines:
		if line.begins_with("[node name=\"%s\"" % node_name):
			found_node = true
			continue
		if not found_node:
			continue
		if line.begins_with("transform = Transform3D("):
			var inner := line.get_slice("(", 1).get_slice(")", 0)
			var parts := inner.split(",")
			if parts.size() < 12:
				return Vector2.INF
			return Vector2(float(parts[9]), float(parts[11]))
		if line.begins_with("["):
			break  # next node started; this one had no transform override
	return Vector2.INF
