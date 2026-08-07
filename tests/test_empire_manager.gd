extends GutTest

var empire_manager: Node
var _saved_resources: Dictionary

func before_each():
	empire_manager = load("res://scripts/managers/EmpireManager.gd").new()
	add_child_autoqfree(empire_manager)
	_saved_resources = ResourceManager.current_resources.duplicate()

	# Need to call _ready manually if not in tree, but add_child_autoqfree puts it in tree
	# so _ready is called.
	await wait_process_frames(1)

func after_each():
	ResourceManager.current_resources = _saved_resources.duplicate()

func test_notoriety_decays_after_idle():
	empire_manager.add_notoriety(50.0)
	assert_eq(empire_manager.notoriety, 50.0, "Should have 50 notoriety initially")
	
	empire_manager._last_gain_unix = int(Time.get_unix_time_from_system()) - 660 
	
	await wait_process_frames(5)
	
	assert_true(empire_manager.notoriety < 50.0, "Notoriety should have decayed, it was: " + str(empire_manager.notoriety))
	
func test_notoriety_does_not_decay_before_idle():
	empire_manager.add_notoriety(50.0)
	
	empire_manager._last_gain_unix = int(Time.get_unix_time_from_system()) - 300 
	
	await wait_process_frames(5)
	
	assert_eq(empire_manager.notoriety, 50.0, "Notoriety should not have decayed yet")

func test_notoriety_clamps_to_zero():
	empire_manager.add_notoriety(0.0001) # Very small amount
	
	empire_manager._last_gain_unix = int(Time.get_unix_time_from_system()) - 660 
	
	await wait_process_frames(5)
	
	assert_eq(empire_manager.notoriety, 0.0, "Notoriety should be exactly 0 after decaying below 0")

func test_region_activation():
	watch_signals(empire_manager)
	
	assert_true(empire_manager.is_region_active("beginner_waters"), "Region 1 should be active initially")
	assert_false(empire_manager.is_region_active("contested_waters"), "Region 2 should not be active initially")
	
	empire_manager.add_notoriety(60.0)
	
	assert_true(empire_manager.is_region_active("contested_waters"), "Region 2 should activate at 60 notoriety")
	assert_signal_emitted_with_parameters(empire_manager, "region_activated", ["contested_waters"])
	assert_signal_emit_count(empire_manager, "region_activated", 1, "Should emit exactly once for Region 2")
	
	empire_manager.add_notoriety(5.0)
	assert_signal_emit_count(empire_manager, "region_activated", 1, "Should not emit again for Region 2")

func test_defense_score_baseline():
	empire_manager.home_island_id = "test_island"
	var score = empire_manager._compute_defense_score()
	assert_eq(score, 0.0, "Baseline defense score should be 0")

func test_defense_score_with_fortress():
	empire_manager.home_island_id = "test_island"
	
	var island = load("res://scripts/world/Island.gd").new()
	island.name = "test_island"
	var island_data = load("res://scripts/world/IslandData.gd").new()
	island_data.island_id = "test_island"
	island.island_data = island_data
	
	var fortress = load("res://scripts/world/BuildingData.gd").new()
	fortress.building_id = "fortress"
	island.built_buildings.append(fortress)
	
	get_tree().root.add_child(island)
	
	var score = empire_manager._compute_defense_score()
	assert_eq(score, 20.0, "Defense score should be 20 with a fortress")
	
	island.queue_free()

func test_resolve_raid_repelled():
	empire_manager.home_island_id = "test_island"
	empire_manager.notoriety = 0.0 # Low attack score
	
	# Mock an island with a fortress (defense score 20)
	var island = load("res://scripts/world/Island.gd").new()
	island.name = "test_island"
	var island_data = load("res://scripts/world/IslandData.gd").new()
	island_data.island_id = "test_island"
	island.island_data = island_data
	
	var fortress = load("res://scripts/world/BuildingData.gd").new()
	fortress.building_id = "fortress"
	island.built_buildings.append(fortress)
	
	var watchtower = load("res://scripts/world/BuildingData.gd").new()
	watchtower.building_id = "watchtower"
	island.built_buildings.append(watchtower)
	get_tree().root.add_child(island)
	
	var attacking_faction = load("res://resources/factions/RoyalNavy.tres")
	var region = load("res://scripts/world/RegionData.gd").new()
	region.tier = 0 # Low tier -> low attack score (0 * 25 + 0 = 0)
	
	var report = empire_manager._resolve_raid(attacking_faction, region)
	
	assert_true(report.repelled, "Raid should be repelled")
	assert_eq(report.stolen.size(), 0, "No resources should be stolen")
	
	island.queue_free()

func test_resolve_raid_not_repelled():
	empire_manager.home_island_id = "test_island"
	empire_manager.notoriety = 500.0 # High attack score (500 * 0.3 = 150)
	ResourceManager.current_resources = {"gold": 1000, "wood": 100, "iron": 40, "rum": 20, "research": 0}

	var attacking_faction = load("res://resources/factions/RoyalNavy.tres")
	var region = load("res://scripts/world/RegionData.gd").new()
	region.tier = 3 # High tier -> high attack score (3 * 25 + 150 = 225)

	var report = empire_manager._resolve_raid(attacking_faction, region)

	assert_false(report.repelled, "Raid should not be repelled")
	assert_eq(report.faction_id, "royal_navy", "Faction ID should be royal_navy")

	# Regression guard: _resolve_raid must actually read/deduct via ResourceManager's
	# real API (current_resources / spend_resource), not a nonexistent get_current_resources().
	assert_true(report.stolen.size() > 0,
		"an unrepelled raid with nonzero stored resources must steal something")
	assert_true(report.stolen.has("gold"), "gold should be present in current_resources and thus stealable")
	assert_eq(report.stolen["gold"], 1000 - ResourceManager.get_resource("gold"),
		"the stolen amount reported must match what was actually deducted from ResourceManager")
	assert_true(ResourceManager.get_resource("gold") < 1000,
		"ResourceManager's gold must actually be decremented by the raid, not just reported")

func test_save_load_round_trip():
	empire_manager.notoriety = 87.5
	empire_manager._region_active = {"beginner_waters": true, "contested_waters": true, "imperial_waters": false}
	empire_manager.home_island_id = "port_royal"
	empire_manager._last_raid_check_unix = 1234567890
	empire_manager.pending_raid_report = {"faction_id": "royal_navy", "repelled": false, "stolen": {"gold": 50}}

	var save_data = empire_manager.get_save_data()

	var reloaded = load("res://scripts/managers/EmpireManager.gd").new()
	add_child_autoqfree(reloaded)
	await wait_process_frames(1)
	reloaded.load_save_data(save_data)

	assert_eq(reloaded.notoriety, 87.5, "notoriety should round-trip")
	assert_true(reloaded.is_region_active("contested_waters"), "active region flag should round-trip")
	assert_false(reloaded.is_region_active("imperial_waters"), "dormant region flag should round-trip")
	assert_eq(reloaded.home_island_id, "port_royal", "home_island_id should round-trip")
	assert_eq(reloaded._last_raid_check_unix, 1234567890, "_last_raid_check_unix should round-trip")
	assert_eq(reloaded.pending_raid_report["faction_id"], "royal_navy", "pending_raid_report should round-trip")
	assert_eq(reloaded.pending_raid_report["stolen"]["gold"], 50, "pending_raid_report contents should round-trip exactly")
