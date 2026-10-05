extends GutTest

# test_m30_range_velocity.gd
# Task 0.13: cannonball speed scales with range multiplier, direction stays basis-derived.

var _mods: CombatModifiers


func before_each():
	_mods = CombatModifiers.new()


func test_modifiers_range_mult_applies():
	# Verify that CombatModifiers properly exposes and recomputes range_mult
	assert_eq(_mods.range_mult, 1.0, "Default range_mult should be 1.0")

	# Apply a range multiplier upgrade
	var upgrade = BattleUpgradeData.new()
	upgrade.effect = BattleUpgradeData.Effect.CANNON_RANGE
	upgrade.magnitude = 1.2
	upgrade.upgrade_id = "test_range"
	upgrade.max_stacks = 1

	_mods.apply_upgrade(upgrade)
	assert_eq(_mods.range_mult, 1.2, "Range mult should be 1.2 after upgrade")


func test_range_multiplier_stacks():
	# Multiple range upgrades should stack multiplicatively
	_mods._base["range"] = 1.5
	_mods._recompute()

	assert_eq(_mods.range_mult, 1.5, "Range mult should be 1.5")

	# A second upgrade should stack multiplicatively
	var upgrade = BattleUpgradeData.new()
	upgrade.effect = BattleUpgradeData.Effect.CANNON_RANGE
	upgrade.magnitude = 1.2
	upgrade.upgrade_id = "test_range_2"
	upgrade.max_stacks = 1

	_mods.apply_upgrade(upgrade)
	assert_almost_eq(_mods.range_mult, 1.8, 0.001, "Range mult should be 1.5 * 1.2 = 1.8")


func test_reset_clears_range_modifiers():
	# Verify that reset() clears all modifiers including range
	_mods._base["range"] = 2.0
	_mods._recompute()
	assert_eq(_mods.range_mult, 2.0)

	_mods.reset()
	assert_eq(_mods.range_mult, 1.0, "Range mult should be 1.0 after reset")
