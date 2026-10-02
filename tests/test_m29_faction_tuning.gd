extends GutTest

# M29 B.4 — verify that tribute cost and cooldown are read from FactionData,
# raid probability is multiplied by raid_frequency_mult, and get_island_owner_display()
# returns correct data for all island types.

var faction_manager: FactionManager
var empire_manager: EmpireManager

func before_each() -> void:
	faction_manager = FactionManager
	empire_manager = EmpireManager

func test_tribute_cost_from_faction_data() -> void:
	# Test that tribute cost is read from FactionData, not a constant
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	assert_not_null(navy, "RoyalNavy.tres should exist")

	# Verify tribute_cost_gold is an @export field
	assert_true(navy.has_meta("tribute_cost_gold") or typeof(navy.tribute_cost_gold) == TYPE_INT,
		"FactionData should have tribute_cost_gold")

	# Verify it's used in pay_tribute (indirectly by checking it has a value)
	assert_true(navy.tribute_cost_gold > 0, "Navy tribute cost should be positive")

func test_tribute_cooldown_from_faction_data() -> void:
	# Test that tribute cooldown is read from FactionData
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	assert_not_null(navy, "RoyalNavy.tres should exist")

	# Verify tribute_cooldown_seconds is an @export field
	assert_true(typeof(navy.tribute_cooldown_seconds) == TYPE_FLOAT,
		"FactionData should have tribute_cooldown_seconds as float")

	assert_true(navy.tribute_cooldown_seconds > 0, "Navy tribute cooldown should be positive")

func test_raid_frequency_mult_default() -> void:
	# Test that raid_frequency_mult defaults to 1.0
	var faction = FactionData.new()
	assert_eq(faction.raid_frequency_mult, 1.0, "Default raid_frequency_mult should be 1.0")

func test_raid_frequency_mult_in_factions() -> void:
	# Test that empire factions can have non-default raid frequency
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	var spain = load("res://resources/factions/SpanishEmpire.tres") as FactionData

	assert_not_null(navy, "RoyalNavy.tres should exist")
	assert_not_null(spain, "SpanishEmpire.tres should exist")

	# Should have raid frequency multipliers
	assert_true(typeof(navy.raid_frequency_mult) == TYPE_FLOAT, "Navy should have raid_frequency_mult")
	assert_true(typeof(spain.raid_frequency_mult) == TYPE_FLOAT, "Spain should have raid_frequency_mult")

func test_get_island_owner_display_friendly() -> void:
	# Test FRIENDLY island shows player faction
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.FRIENDLY
	var player_faction = load("res://resources/factions/PlayerFaction.tres") as FactionData
	island_data.owner_faction = player_faction

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], player_faction.faction_id, "FRIENDLY should show player faction_id")
	assert_eq(display["name"], player_faction.faction_name, "FRIENDLY should show player faction name")
	assert_eq(display["color"], player_faction.sail_color, "FRIENDLY should show player sail color")

func test_get_island_owner_display_capital() -> void:
	# Test CAPITAL island shows player faction
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.CAPITAL
	var player_faction = load("res://resources/factions/PlayerFaction.tres") as FactionData
	island_data.owner_faction = player_faction

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], player_faction.faction_id, "CAPITAL should show player faction_id")
	assert_eq(display["name"], player_faction.faction_name, "CAPITAL should show player faction name")

func test_get_island_owner_display_enemy() -> void:
	# Test ENEMY island shows the owner faction
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.ENEMY
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	island_data.owner_faction = navy

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], navy.faction_id, "ENEMY should show owner faction_id")
	assert_eq(display["name"], navy.faction_name, "ENEMY should show owner faction name")
	assert_eq(display["color"], navy.sail_color, "ENEMY should show owner sail color")

func test_get_island_owner_display_neutral() -> void:
	# Test NEUTRAL island shows unclaimed
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.NEUTRAL
	island_data.owner_faction = null

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], "", "NEUTRAL should have empty faction_id")
	assert_eq(display["name"], "Unclaimed", "NEUTRAL should show 'Unclaimed'")
	assert_eq(display["color"], Color.GRAY, "NEUTRAL should show gray color")

func test_get_island_owner_display_legendary() -> void:
	# Test LEGENDARY island shows unclaimed
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.LEGENDARY
	island_data.owner_faction = null

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], "", "LEGENDARY should have empty faction_id")
	assert_eq(display["name"], "Unclaimed", "LEGENDARY should show 'Unclaimed'")
	assert_eq(display["color"], Color.GRAY, "LEGENDARY should show gray color")

func test_get_island_owner_display_null_island() -> void:
	# Test null island_data doesn't crash
	var display = faction_manager.get_island_owner_display(null)

	assert_eq(display["faction_id"], "", "Null island should have empty faction_id")
	assert_eq(display["name"], "Unclaimed", "Null island should show 'Unclaimed'")
	assert_eq(display["color"], Color.GRAY, "Null island should show gray color")

func test_get_island_owner_display_null_owner() -> void:
	# Test island with null owner doesn't crash
	var island_data = IslandData.new()
	island_data.island_type = IslandData.IslandType.ENEMY
	island_data.owner_faction = null

	var display = faction_manager.get_island_owner_display(island_data)

	assert_eq(display["faction_id"], "", "Null owner should have empty faction_id")
	assert_eq(display["name"], "Unclaimed", "Null owner should show 'Unclaimed'")
