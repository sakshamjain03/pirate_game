extends GutTest

## Test Fury mechanic: fills from hits, rakes, perfect braces, kills.
## Requirement W1-2.4: Fury fills from hits, rakes, Perfect Brace and kills, as
## extra fill on the existing special timer. At 1.0 the special is ready early.

var fury_data: FuryData
var brace_data: BraceData


func before_each():
	fury_data = load("res://resources/balance/Fury.tres") as FuryData
	brace_data = load("res://resources/balance/Brace.tres") as BraceData
	assert_not_null(fury_data, "FuryData must exist")
	assert_not_null(brace_data, "BraceData must exist")


func test_fury_data_exists():
	assert_not_null(fury_data)
	assert_gt(fury_data.fury_per_hit, 0.0)
	assert_gt(fury_data.rake_multiplier, 0.0)
	assert_gt(fury_data.fury_on_kill, 0.0)


func test_fury_rake_multiplier_is_higher():
	# Rakes should fill more fury than regular hits
	assert_gt(fury_data.rake_multiplier, 1.0)


func test_fury_on_kill_is_significant():
	# Killing should grant a meaningful amount of fury
	assert_gt(fury_data.fury_on_kill, 0.0)
	assert_lte(fury_data.fury_on_kill, 1.0)


func test_brace_grants_fury():
	# Perfect brace should grant fury
	assert_gt(brace_data.perfect_fury_grant, 0.0)
	assert_lte(brace_data.perfect_fury_grant, 1.0)


func test_fury_fill_rate_is_positive():
	assert_gt(fury_data.fury_fill_rate, 0.0)


func test_fury_data_values_are_reasonable():
	# Sanity checks on the values
	assert_lte(fury_data.fury_per_hit, 0.1, "fury_per_hit should be small")
	assert_lt(fury_data.fury_on_perfect_brace, 1.0, "fury_on_perfect_brace should be less than max")


## Test that at 1.0 fury the special is ready early (requirement W1-2.4)
## The special can be ready via two paths: is_special_broadside_ready() or fury >= 1.0.
## This test verifies the fury >= 1.0 path works.
func test_special_ready_at_full_fury():
	var ship_node = Node3D.new()
	var ship_stats_obj = load("res://resources/ships/Sloop.tres") as ShipStats
	var ship_combat = ShipCombat.new()
	ship_combat.ship_stats = ship_stats_obj
	
	# Create a minimal scene tree for ship_combat
	var root = Node3D.new()
	root.add_child(ship_node)
	ship_node.add_child(ship_combat)
	
	# Get the tree ready
	if get_tree():
		get_tree().root.add_child(root)
	
	# First, ensure the special broadside is NOT ready by giving it a cooldown
	# This way we isolate testing the fury path
	ship_combat._special_cooldown_remaining = 5.0
	ship_combat.fury = 0.0
	assert_false(ship_combat.is_special_ready(), "should not be ready with 0 fury and cooldown active")
	
	# Now set fury to 1.0 - should be ready despite the cooldown
	ship_combat.fury = 1.0
	assert_true(ship_combat.is_special_ready(), "should be ready when fury >= 1.0, even with cooldown")
	
	# Clean up
	if get_tree():
		root.queue_free()


## Test that rakes fill more fury than plain hits (requirement W1-2.4)
## This verifies the gameplay behavior that rake_multiplier > 1.0 in FuryData
func test_rake_fills_more_than_plain_hit():
	# Calculate expected fury gains
	var fury_from_plain_hit = fury_data.fury_per_hit
	var fury_from_rake = fury_data.fury_per_hit * fury_data.rake_multiplier
	
	# Verify that rakes grant more fury
	assert_gt(fury_from_rake, fury_from_plain_hit, 
		"A rake should grant more fury than a plain hit")
	
	# Sanity check: the multiplier should be reasonable (between 1.0 and 10)
	assert_gt(fury_data.rake_multiplier, 1.0)
	assert_lt(fury_data.rake_multiplier, 10.0)
