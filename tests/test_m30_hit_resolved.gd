extends GutTest

# test_m30_hit_resolved.gd
# Task 0.18: ShipDamage emits hit_resolved signal with correct parameters

var _dmg: ShipDamage
var _stats: ShipStats


func before_each():
	_stats = ShipStats.new()
	_stats.max_health = 100.0
	_stats.max_sails = 50.0
	_stats.max_crew = 20.0

	_dmg = ShipDamage.new()
	_dmg.ship_stats = _stats
	_dmg.hull = 100.0
	_dmg.sails = 50.0
	_dmg.crew = 20.0


func test_hit_resolved_signal_exists():
	# Verify the signal exists
	assert_has_signal(_dmg, "hit_resolved")


func test_hit_resolved_emitted_on_apply_hit():
	# Verify signal is emitted when apply_hit is called
	watch_signals(_dmg)

	var ammo = load("res://resources/combat/ammo/RoundShot.tres")
	_dmg.apply_hit(20.0, ammo, Vector3.BACK)

	assert_signal_emitted(_dmg, "hit_resolved")


func test_hit_resolved_emitted_on_apply_impact():
	# Verify signal is emitted when apply_impact is called
	watch_signals(_dmg)

	_dmg.apply_impact(15.0, 0.5, 0.0, 0.0)

	assert_signal_emitted(_dmg, "hit_resolved")
