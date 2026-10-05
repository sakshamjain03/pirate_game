extends GutTest
## M29 Checkpoint B (headful review, 2026-10-05): approaching Skull Cove — Blackjaw
## Morrow's haven, Ch2's capture target — read "Skull Cove · Unclaimed", because
## the island was authored ENEMY with no owner_faction. A null owner also skips
## M29 B.3's previous-owner reputation loss on capture. Every ENEMY island must
## name the faction that holds it.

const ISLAND_DIR := "res://resources/world/"


func test_every_enemy_island_names_its_owner() -> void:
	var dir := DirAccess.open(ISLAND_DIR)
	assert_not_null(dir, "resources/world/ must exist")
	var checked := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load(ISLAND_DIR + file_name)
		if not (res is IslandData):
			continue
		var data := res as IslandData
		if data.island_type != IslandData.IslandType.ENEMY:
			continue
		checked += 1
		assert_not_null(data.owner_faction,
			"%s is ENEMY but has no owner_faction" % file_name)
	assert_gt(checked, 0, "expected at least one ENEMY island")


func test_skull_cove_is_held_by_the_pirate_clans() -> void:
	var data := load(ISLAND_DIR + "SkullCove.tres") as IslandData
	assert_not_null(data)
	assert_not_null(data.owner_faction)
	assert_eq(data.owner_faction.faction_id, "pirate_clans")
	var display: Dictionary = FactionManager.get_island_owner_display(data)
	assert_ne(display.get("name", ""), "Unclaimed")
