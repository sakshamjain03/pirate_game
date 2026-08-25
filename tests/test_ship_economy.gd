extends GutTest

# test_ship_economy.gd
# M7 economy correction (D53/D54/D56): ship prices must come from authored data,
# not from `mass`, and every purchasable hull/captain must have a real identity
# and cost rather than a filename-derived name or an unset default.

const SHIP_PATHS := [
	"res://resources/ships/Dinghy.tres", "res://resources/ships/Sloop.tres",
	"res://resources/ships/Schooner.tres", "res://resources/ships/Corvette.tres",
	"res://resources/ships/Brigantine.tres", "res://resources/ships/Frigate.tres",
	"res://resources/ships/Galleon.tres", "res://resources/ships/ManOWar.tres",
]


func test_every_ship_has_authored_identity_and_cost():
	for p in SHIP_PATHS:
		var stats: ShipStats = load(p)
		assert_false(stats.ship_id.is_empty(), "%s must have a ship_id" % p)
		assert_false(stats.display_name.is_empty(), "%s must have a display_name" % p)
		assert_between(stats.ship_class, 1, 5, "%s must have a ship_class in 1..5" % p)
		assert_gt(stats.cost_gold, 0, "%s must have a real gold cost, not the mass formula" % p)
		assert_gt(stats.cost_wood, 0, "%s must have a real wood cost" % p)
		assert_gt(stats.cost_iron, 0, "%s must have a real iron cost" % p)


func test_ship_cost_ladder_rises_with_class():
	# The M7 target ladder is priced by ship_class, not by mass — a heavier hull
	# with a lower class must still be cheaper than a lighter, higher-class one.
	var by_class := {}
	for p in SHIP_PATHS:
		var stats: ShipStats = load(p)
		by_class[stats.ship_class] = stats.cost_gold

	var classes: Array = by_class.keys()
	classes.sort()
	for i in range(1, classes.size()):
		assert_gt(by_class[classes[i]], by_class[classes[i - 1]],
			"class %d must cost more gold than class %d" % [classes[i], classes[i - 1]])


func test_enemy_hulls_carry_ship_class_for_the_notoriety_ladder():
	var raider: ShipStats = load("res://resources/enemies/EnemyShipStats.tres")
	var ghost: ShipStats = load("res://resources/enemies/GhostShipStats.tres")
	assert_between(raider.ship_class, 1, 5)
	assert_between(ghost.ship_class, 1, 5)
	assert_gt(ghost.ship_class, raider.ship_class,
		"the unique boss hull must read as a higher tier than a standard raider")


func test_every_captain_has_an_authored_hire_cost():
	var dir := DirAccess.open("res://resources/captains")
	assert_not_null(dir, "resources/captains must exist")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var checked := 0
	while file_name != "":
		if file_name.ends_with(".tres"):
			var cap: CaptainData = load("res://resources/captains/%s" % file_name)
			if cap:
				checked += 1
				assert_gt(cap.hire_cost_gold, 0,
					"%s must have an authored hire_cost_gold" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_eq(checked, 20, "expected all 20 authored captains to be checked")
