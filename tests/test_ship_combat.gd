extends GutTest

# test_ship_combat.gd
# Property-based tests for ShipCombat (D12 coverage: Combat).
# ShipCombat reads a few duck-typed properties off its parent ("active_captain",
# group "player_ship"), so tests use a tiny mock parent class instead of a real
# ShipController to keep the captain/tech modifier paths isolated and testable.

class MockShipParent extends Node3D:
	var active_captain: CaptainData = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene

func _make_ship(stats: ShipStats, captain: CaptainData = null) -> Dictionary:
	var parent = MockShipParent.new()
	parent.active_captain = captain

	var port_marker = Node3D.new()
	port_marker.name = "PortMarker1"
	var starboard_marker = Node3D.new()
	starboard_marker.name = "StarboardMarker1"

	var combat = ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = stats

	parent.add_child(port_marker)
	parent.add_child(starboard_marker)
	parent.add_child(combat)

	add_child_autoqfree(parent)
	return {"parent": parent, "combat": combat}

func test_ready_initializes_current_health_to_max_health():
	var stats = ShipStats.new()
	stats.max_health = 250.0
	var built = _make_ship(stats)
	await wait_process_frames(1)
	assert_eq(built["combat"].current_health, 250.0)

func test_take_damage_reduces_health_and_emits_signal():
	var stats = ShipStats.new()
	stats.max_health = 200.0
	var built = _make_ship(stats)
	await wait_process_frames(1)

	var combat = built["combat"]
	watch_signals(combat)
	combat.take_damage(60.0)

	assert_eq(combat.current_health, 140.0)
	assert_signal_emitted_with_parameters(combat, "health_changed", [140.0, 200.0])

func test_health_clamps_at_zero_and_die_fires_exactly_once():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	var built = _make_ship(stats)
	await wait_process_frames(1)

	var combat = built["combat"]
	watch_signals(combat)

	combat.take_damage(150.0)
	assert_eq(combat.current_health, 0.0, "health must clamp at 0, never go negative")
	assert_signal_emit_count(combat, "died", 1)

	combat.take_damage(10.0)
	assert_eq(combat.current_health, 0.0, "damage on an already-dead ship must be a no-op")
	assert_signal_emit_count(combat, "died", 1, "die() must never fire twice for the same ship")

func test_fire_broadside_gates_on_per_side_cooldown_independently():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.fire_rate = 0.5 # cooldown = 1 / 0.5 = 2.0s, long enough not to flake
	var built = _make_ship(stats)
	await wait_process_frames(1)

	var combat = built["combat"]
	assert_true(combat.fire_broadside("port"), "first shot on a side must succeed")
	assert_false(combat.fire_broadside("port"), "firing the same side again during cooldown must fail")
	assert_true(combat.fire_broadside("starboard"), "the opposite side's cooldown must be independent")

func test_captain_health_modifier_applied_on_ready():
	var stats = ShipStats.new()
	stats.max_health = 100.0

	var captain = CaptainData.new()
	captain.base_health_modifier = 1.0
	captain.level = 6 # health_modifier = base + (level-1)*0.1 = 1.5

	var built = _make_ship(stats, captain)
	await wait_process_frames(1)

	assert_almost_eq(built["combat"].current_health, 150.0, 0.01,
		"initial health must apply the parent's active_captain health_modifier")
