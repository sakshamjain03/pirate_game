extends GutTest

# test_cold_start.gd
# D58 (superseded): a genuinely new game used to start owning no island and no
# production, gated behind an unreachable 1000-gold colonize cost against a
# 200-gold starting purse. That was fixed by force-owning Port Royal on new
# game (World._seed_port_royal_as_home(), now deleted).
#
# Per the "claim your first island" redesign, Port Royal is no longer
# force-owned — it stays NEUTRAL and undefended, exactly like Tortuga,
# "pirate-friendly" but not the player's. The same cold-start softlock is
# instead avoided by pricing Port Royal's Colonize action (IslandMenu) low
# enough to be reachable from the starting purse, and by capture_island()
# already being generic: whichever island is captured first becomes home,
# with no special-casing left in World.gd. These tests guard that
# resolution instead of the deleted seeding method.

var _saved_home_island_id: String


func before_each():
	_saved_home_island_id = EmpireManager.home_island_id
	EmpireManager.home_island_id = ""


func after_each():
	EmpireManager.home_island_id = _saved_home_island_id


func test_port_royal_starts_neutral_and_unowned():
	var port_royal: IslandData = load("res://resources/world/PortRoyal.tres")
	assert_eq(port_royal.island_type, IslandData.IslandType.NEUTRAL,
		"Port Royal must not be pre-owned on a new game — the player claims it")
	assert_false(port_royal.is_owned_by_player())


func test_port_royals_colonize_cost_is_reachable_from_the_starting_purse():
	var port_royal: IslandData = load("res://resources/world/PortRoyal.tres")
	var starting_gold: int = int(ResourceManager.current_resources.get("gold", 0))
	assert_lte(port_royal.colonize_cost_gold, starting_gold,
		("Port Royal's Colonize cost (%d) must be affordable from the %d-gold starting purse " +
		"or the D58 cold-start softlock returns in a new form")
		% [port_royal.colonize_cost_gold, starting_gold])


func test_claiming_port_royal_sets_it_as_home_with_no_special_casing():
	# Island.gd's capture_island() is generic (test_cartagena_buildable.gd already
	# proves this for Cartagena) — this just confirms Port Royal goes through the
	# exact same unmodified path now that World.gd no longer force-seeds it.
	var island: Node = load("res://scripts/world/Island.gd").new()
	island.island_data = load("res://resources/world/PortRoyal.tres").duplicate()
	add_child_autoqfree(island)

	island.capture_island(load("res://resources/factions/PlayerFaction.tres"))

	assert_eq(island.island_data.island_type, IslandData.IslandType.FRIENDLY)
	assert_eq(EmpireManager.home_island_id, "port_royal",
		"Claiming Port Royal must set it as home, exactly like any other island's first capture")
