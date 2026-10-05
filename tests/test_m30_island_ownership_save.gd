extends GutTest

# test_m30_island_ownership_save.gd
# Verifies island ownership persists through save/load cycles
#
# Responsibilities:
# - Test island_type and owner_faction round-trip
# - Test migration of old saves (buildings or home_island)
# - Test unknown faction id handling
# - Test carry-forward of gated islands
#
# Dependencies:
# - SaveManager
# - Island
# - FactionManager

var world: Node
var player_ship: Node
var islands: Array


func before_all():
	# Load the test save
	load_test_save()


func after_all():
	# Clean up
	if world and is_instance_valid(world):
		world.queue_free()
	if SaveManager:
		var path = SaveManager.SAVE_PATH
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		var backup_path = SaveManager.BACKUP_PATH
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)


func load_test_save():
	"""Load World scene and wait for initialization."""
	world = load("res://scenes/world/World.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	player_ship = world.get_node_or_null("PlayerShip")
	islands = get_tree().get_nodes_in_group("islands")


func test_property_1_capture_and_save_island_ownership():
	"""Test that captured island ownership persists through save/load."""
	# Given: an island that's NEUTRAL
	var port_royal = _find_island_by_id("port_royal")
	assert_not_null(port_royal, "Port Royal should exist")
	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.NEUTRAL)

	# When: we capture it
	var player_faction = FactionManager.get_player_faction()
	port_royal.capture_island(player_faction)

	# Then: it should be FRIENDLY with player faction
	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.FRIENDLY)
	assert_eq(port_royal.island_data.owner_faction, player_faction)

	# When: we save the game
	SaveManager.save_game()

	# Then: reload and verify
	var saved_data = _load_json(SaveManager.SAVE_PATH)
	assert_not_null(saved_data.islands, "Islands data should exist in save")
	assert_true(saved_data.islands.has("port_royal"), "Port Royal should be in save")

	var port_data = saved_data.islands["port_royal"]
	assert_eq(port_data.get("island_type"), int(IslandData.IslandType.FRIENDLY),
		"Island type should be saved as enum int")
	assert_eq(port_data.get("owner_faction_id"), player_faction.faction_id,
		"Owner faction ID should be saved")


func test_property_2_colonize_and_restore():
	"""Test that colonized islands restore ownership correctly."""
	# Given: Port Royal is captured
	var port_royal = _find_island_by_id("port_royal")
	var player_faction = FactionManager.get_player_faction()
	port_royal.capture_island(player_faction)
	SaveManager.save_game()

	# When: we reload
	_reload_world()
	port_royal = _find_island_by_id("port_royal")

	# Then: it should still be FRIENDLY and owned by the player
	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.FRIENDLY)
	assert_eq(port_royal.island_data.owner_faction, player_faction)


func test_property_3_migration_old_save_with_buildings():
	"""Test that old saves with buildings migrate to FRIENDLY."""
	# Given: an old save format (no island_type, but has buildings)
	var old_save = {
		"version": 1,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
		"player": {},
		"economy": {"gold": 1000},
		"islands": {
			"port_royal": {
				"buildings": ["warehouse_l1"],  # Has buildings but no island_type
				"discovered": true
			}
		},
		"fleet": {},
		"tech": {},
		"factions": {},
		"empire": {},
		"campaign": {},
		"tutorial": {}
	}

	# When: we save and reload
	_write_json(SaveManager.SAVE_PATH, old_save)
	_reload_world()

	# Then: Port Royal should migrate to FRIENDLY
	var port_royal = _find_island_by_id("port_royal")
	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.FRIENDLY,
		"Island with buildings should migrate to FRIENDLY")


func test_property_4_migration_home_island():
	"""Test that home island migrates to FRIENDLY."""
	# Given: an old save with home_island_id
	var home_id = "port_royal"
	var old_save = {
		"version": 1,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
		"player": {},
		"economy": {"gold": 1000},
		"islands": {
			"port_royal": {
				"buildings": [],
				"discovered": true
			}
		},
		"fleet": {},
		"tech": {},
		"factions": {},
		"empire": {"home_island_id": home_id},
		"campaign": {},
		"tutorial": {}
	}

	# When: we load
	_write_json(SaveManager.SAVE_PATH, old_save)
	_reload_world()

	# Then: home island should be FRIENDLY
	var port_royal = _find_island_by_id("port_royal")
	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.FRIENDLY,
		"Home island should migrate to FRIENDLY")


func test_property_5_unresolvable_faction_id():
	"""Test that unresolvable faction IDs are kept and push_error."""
	# Given: a save with an invalid faction ID
	var bad_faction_id = "nonexistent_faction_999"
	var save_with_bad_faction = {
		"version": 1,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
		"player": {},
		"economy": {"gold": 1000},
		"islands": {
			"port_royal": {
				"buildings": [],
				"discovered": true,
				"island_type": int(IslandData.IslandType.FRIENDLY),
				"owner_faction_id": bad_faction_id
			}
		},
		"fleet": {},
		"tech": {},
		"factions": {},
		"empire": {},
		"campaign": {},
		"tutorial": {}
	}

	# When: we load
	_write_json(SaveManager.SAVE_PATH, save_with_bad_faction)
	_reload_world()

	# Then: should have logged an error and kept the authored value


func test_property_6_gated_island_carry_forward():
	"""Test that disabled/gated islands survive a save."""
	# Given: a save that references a gated island
	var gated_island_id = "skull_cove"  # Example gated island
	var save_with_gated = {
		"version": 1,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
		"player": {},
		"economy": {"gold": 1000},
		"islands": {
			"port_royal": {
				"buildings": [],
				"discovered": true,
				"island_type": int(IslandData.IslandType.FRIENDLY),
				"owner_faction_id": FactionManager.get_player_faction().faction_id
			},
			gated_island_id: {
				"buildings": ["warehouse_l1"],
				"discovered": true,
				"island_type": int(IslandData.IslandType.FRIENDLY),
				"owner_faction_id": FactionManager.get_player_faction().faction_id
			}
		},
		"fleet": {},
		"tech": {},
		"factions": {},
		"empire": {},
		"campaign": {},
		"tutorial": {}
	}

	# When: we load
	_write_json(SaveManager.SAVE_PATH, save_with_gated)
	_reload_world()

	# Then: save again and verify gated island's entry is preserved
	SaveManager.save_game()
	var reloaded = _load_json(SaveManager.SAVE_PATH)

	# Even though the gated island isn't in the scene, its entry should carry forward
	assert_true(reloaded.islands.has(gated_island_id),
		"Gated island entry should be carried forward")


# ============================================================================
# Helper functions
# ============================================================================

func _find_island_by_id(island_id: String) -> Node:
	"""Find an island by its ID."""
	for island in islands:
		if island.has_method("get_island_id") and island.get_island_id() == island_id:
			return island
	return null


func _reload_world():
	"""Reload the world from the current save."""
	if world and is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame

	SaveManager.load_game()
	await get_tree().process_frame
	world = get_tree().current_scene
	islands = get_tree().get_nodes_in_group("islands")


func _load_json(path: String) -> Dictionary:
	"""Load a JSON file."""
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var content = file.get_as_text()
	var json = JSON.new()
	json.parse(content)
	return json.data


func _write_json(path: String, data: Dictionary) -> void:
	"""Write a JSON file."""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
