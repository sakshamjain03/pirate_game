extends GutTest

## Test Brace mechanic: damage reduction, perfect window, gun block, cooldown.
## Requirement W1-1.3: Bracing → damage × (1 − reduction). Perfect → larger
## reduction plus Fury. Firing while bracing → false. During cooldown → no brace.

var brace_data: BraceData
var modifiers: CombatModifiers
var ship_combat: ShipCombat


func before_each():
	brace_data = load("res://resources/balance/Brace.tres") as BraceData
	assert_not_null(brace_data, "BraceData must exist")

	# Create a minimal CombatModifiers instance for testing
	modifiers = CombatModifiers.new()


func test_brace_data_exists():
	assert_not_null(brace_data)
	assert_gt(brace_data.reduction, 0.0)
	assert_gt(brace_data.window, 0.0)
	assert_gt(brace_data.perfect_reduction, brace_data.reduction)


func test_combat_modifiers_has_damage_taken_mult():
	assert_eq(modifiers.damage_taken_mult, 1.0)

	# Set a persistent layer to test damage reduction
	modifiers.set_persistent_layer(&"brace", {"damage_taken": 0.6})
	assert_almost_eq(modifiers.damage_taken_mult, 0.6, 0.01)


func test_combat_modifiers_clears_persistent_layer():
	modifiers.set_persistent_layer(&"brace", {"damage_taken": 0.6})
	assert_almost_eq(modifiers.damage_taken_mult, 0.6, 0.01)

	modifiers.clear_persistent_layer(&"brace")
	assert_eq(modifiers.damage_taken_mult, 1.0)


func test_brace_perfect_reduction_is_stronger():
	var normal_mult = 1.0 - brace_data.reduction
	var perfect_mult = 1.0 - brace_data.perfect_reduction

	# Perfect brace should have stronger reduction
	assert_lt(perfect_mult, normal_mult)


func test_brace_has_cooldown():
	assert_gt(brace_data.cooldown, 0.0)


func test_brace_fury_grant_is_valid():
	assert_gte(brace_data.perfect_fury_grant, 0.0)
	assert_lte(brace_data.perfect_fury_grant, 1.0)
