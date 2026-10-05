extends GutTest

## Test that damage reduction (from Brace) applies to both hull AND crew (requirement W1-1.3)
## This is the fix for: apply_impact uses modified_amount for hull but original amount for crew

var brace_data: BraceData


func before_each():
	brace_data = load("res://resources/balance/Brace.tres") as BraceData
	assert_not_null(brace_data, "BraceData must exist")


func test_damage_reduction_applies_to_crew_and_hull():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_crew = 20.0
	
	var dmg: ShipDamage = ShipDamage.new()
	dmg.ship_stats = stats
	
	# Create a parent node with CombatModifiers
	var parent_node = Node3D.new()
	var modifiers_node = CombatModifiers.new()
	modifiers_node.name = "CombatModifiers"  # Explicitly set the name so get_node_or_null finds it
	parent_node.add_child(modifiers_node)
	parent_node.add_child(dmg)
	add_child_autoqfree(parent_node)
	
	# Apply damage without reduction to establish baseline
	dmg.apply_impact(20.0, 0.1)  # 20 hull damage, 10% crew = 2 crew damage
	assert_almost_eq(dmg.hull, 80.0, 0.1, "Initial hull should be 80")
	assert_almost_eq(dmg.crew, 18.0, 0.1, "Initial crew should be 18")
	
	var hull_before = dmg.hull
	var crew_before = dmg.crew
	
	# Now apply damage reduction via CombatModifiers (simulating Brace)
	# Reduction of 0.4 means damage becomes 60% (1.0 - 0.4 = 0.6)
	modifiers_node.set_persistent_layer(&"brace", {"damage_taken": 0.6})
	
	# Apply the same damage amount with reduction active
	dmg.apply_impact(20.0, 0.1)  # Should deal 20 * 0.6 = 12 hull, 12 * 0.1 = 1.2 crew
	
	# Verify both hull and crew took the same proportion of reduction
	# Before fix: hull would be reduced correctly, crew would not
	# After fix: both should be reduced by the same factor (0.6)
	var hull_loss = hull_before - dmg.hull
	var crew_loss = crew_before - dmg.crew
	
	# With 20 damage and 0.6 multiplier, we expect 12 hull loss
	assert_almost_eq(hull_loss, 12.0, 0.1, "Hull should lose 12.0 (20 * 0.6)")
	# Crew loss should also be affected by the multiplier: 12 * 0.1 = 1.2
	assert_almost_eq(crew_loss, 1.2, 0.1, "Crew should lose 1.2 (20 * 0.6 * 0.1)")
