extends GutTest

func test_faction_data_has_consequence_fields() -> void:
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	assert_not_null(navy, "RoyalNavy.tres should exist")

	# Test that consequence fields are accessible
	assert_true(typeof(navy.sink_reputation_loss) == TYPE_INT, "sink_reputation_loss should be an int")
	assert_true(typeof(navy.boarding_reputation_loss) == TYPE_INT, "boarding_reputation_loss should be an int")
	assert_true(typeof(navy.hunter_cooldown_seconds) == TYPE_FLOAT, "hunter_cooldown_seconds should be a float")
	assert_true(typeof(navy.tribute_cost_gold) == TYPE_INT, "tribute_cost_gold should be an int")
	assert_true(typeof(navy.tribute_cooldown_seconds) == TYPE_FLOAT, "tribute_cooldown_seconds should be a float")
	assert_true(typeof(navy.raid_frequency_mult) == TYPE_FLOAT, "raid_frequency_mult should be a float")

func test_faction_data_script_defaults() -> void:
	# Create a new FactionData instance to test the script defaults
	var faction = FactionData.new()

	# Check script defaults
	assert_eq(faction.sink_reputation_loss, 0, "sink_reputation_loss script default should be 0")
	assert_eq(faction.boarding_reputation_loss, 0, "boarding_reputation_loss script default should be 0")
	assert_eq(faction.hunter_cooldown_seconds, 120.0, "hunter_cooldown_seconds script default should be 120.0")
	assert_eq(faction.tribute_cost_gold, 500, "tribute_cost_gold script default should be 500")
	assert_eq(faction.tribute_cooldown_seconds, 300.0, "tribute_cooldown_seconds script default should be 300.0")
	assert_eq(faction.raid_frequency_mult, 1.0, "raid_frequency_mult script default should be 1.0")

func test_empire_factions_have_reputation_loss() -> void:
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	var spain = load("res://resources/factions/SpanishEmpire.tres") as FactionData

	# Empire factions should have non-zero losses configured
	assert_true(navy.sink_reputation_loss > 0, "Royal Navy should have positive sink_reputation_loss")
	assert_true(spain.sink_reputation_loss > 0, "Spanish Empire should have positive sink_reputation_loss")
	assert_true(navy.boarding_reputation_loss > 0, "Royal Navy should have positive boarding_reputation_loss")
	assert_true(spain.boarding_reputation_loss > 0, "Spanish Empire should have positive boarding_reputation_loss")

func test_art_seam_fields_exist() -> void:
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData

	# Art seam fields should exist and be empty by default
	assert_eq(navy.flag_texture_path, "", "flag_texture_path should exist and be empty by default")
	assert_eq(navy.sail_texture_path, "", "sail_texture_path should exist and be empty by default")

func test_merchant_guild_has_no_reputation_loss() -> void:
	var guild = load("res://resources/factions/MerchantGuild.tres") as FactionData

	# Merchant Guild should not have reputation loss for sinking their ships
	# (they're not empire faction, so no reputation consequence)
	assert_eq(guild.sink_reputation_loss, 0, "Merchant Guild should have 0 sink_reputation_loss by default")
	assert_eq(guild.boarding_reputation_loss, 0, "Merchant Guild should have 0 boarding_reputation_loss by default")
