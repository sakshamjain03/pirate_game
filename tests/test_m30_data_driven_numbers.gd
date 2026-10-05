extends GutTest
## M30 Wave 0 (0.19): three gameplay numbers lived in scripts (AGENTS.md: no
## hardcoded gameplay values) — the wind speed lerp in ShipMovement, the 20%
## gold loss in DeathScreen, and capture/sink notoriety in Island and
## ShipController. Each is now a Resource whose shipped defaults reproduce the
## old behaviour exactly, so M31 can tune them without touching code.


func test_wind_defaults_match_the_old_lerp() -> void:
	var cfg := WindConfigData.get_default()
	assert_eq(cfg.resource_path, WindConfigData.DEFAULT_PATH, "loads the shipped .tres, not the fallback")
	assert_almost_eq(cfg.headwind_speed_mult, 0.85, 0.0001)
	assert_almost_eq(cfg.tailwind_speed_mult, 1.15, 0.0001)


func test_defeat_penalty_defaults_to_twenty_percent() -> void:
	var data := DefeatPenaltyData.load_default()
	assert_eq(data.resource_path, DefeatPenaltyData.DEFAULT_PATH)
	assert_eq(data.gold_lost(1000), 200)
	assert_eq(data.gold_lost(7), 1, "floors like the old int(gold * 0.2)")


func test_notoriety_defaults_match_the_old_constants() -> void:
	var gains := NotorietyGainsData.get_default()
	assert_eq(gains.resource_path, NotorietyGainsData.DEFAULT_PATH)
	assert_eq(gains.island_capture, 15.0)
	assert_eq(gains.sink_empire_ship, 5.0)
	assert_eq(gains.sink_other_ship, 1.0)


func test_wind_call_site_reads_the_config() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/world/ShipMovement.gd")
	assert_string_contains(src, "WindConfigData.get_default()")
	assert_false(src.contains("lerp(0.85"), "the wind lerp must not be hardcoded")


func test_no_hardcoded_copies_remain() -> void:
	var death := FileAccess.get_file_as_string("res://scripts/ui/DeathScreen.gd")
	assert_false(death.contains("* 0.2)"), "DeathScreen must read DefeatPenaltyData")
	var island := FileAccess.get_file_as_string("res://scripts/world/Island.gd")
	assert_false(island.contains("add_notoriety(15"), "Island must read NotorietyGainsData")
	var ship := FileAccess.get_file_as_string("res://scripts/world/ShipController.gd")
	assert_false(ship.contains("add_notoriety(5") or ship.contains("add_notoriety(1."),
		"ShipController must read NotorietyGainsData")
