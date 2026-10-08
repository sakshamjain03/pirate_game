extends GutTest
## M30 Wave 1 (1.12) — Fury, through the real hit path. Verify bullets
## (tasks.md 1.12 / requirement W1-2.4):
##   * Rakes fill more than plain hits — two equal-damage ShipDamage.apply_hit()
##     calls from the shooter, one from astern and one on the beam.
##   * At 1.0 the special is ready early — fire_special_broadside() succeeds
##     during its cooldown, spends the Fury, and a second one is refused.
##   * test_battle_upgrades.gd:206-218 passes unmodified (run alongside).
## Plus: kills add fury_on_kill, other ships' hits add nothing, Fury fills only
## from hit_resolved (no direct writes), and it resets on death/encounter end.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false
	func fire_cannons(side: String) -> void:
		var c = get_node_or_null("ShipCombat")
		if c: c.fire_broadside(side)

var _created_test_scene: Node3D = null
var _stats: ShipStats
var _ammo: AmmoData
var _fury: FuryData


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_stats = ShipStats.new()
	_stats.max_health = 1000.0
	_stats.max_crew = 20.0
	_stats.max_sails = 100.0
	_stats.cannon_damage = 10.0
	_stats.fire_rate = 0.5
	_stats.cannon_range = 100.0
	_stats.firing_arc_degrees = 30.0
	_stats.special_broadside_cooldown = 10.0
	# Equal damage from every facing, so only the rake multiplier differs.
	_stats.stern_crit_multiplier = 1.0
	_stats.broadside_armor_multiplier = 1.0
	_ammo = AmmoData.new()
	_fury = FuryData.new()
	_fury.fury_per_hit = 0.01
	_fury.rake_multiplier = 2.0
	_fury.fury_on_kill = 0.3
	_fury.fury_on_perfect_brace = 0.25


func after_each() -> void:
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _make_ship(group: String, pos: Vector3, fury: FuryData = null) -> MockShip:
	var ship := MockShip.new()
	ship.freeze = true
	if group != "":
		ship.add_to_group(group)
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = _stats
	ship.add_child(dmg)
	var mods := CombatModifiers.new()
	mods.name = "CombatModifiers"
	ship.add_child(mods)
	var solver := FiringSolver.new()
	solver.name = "FiringSolver"
	solver.ship_stats = _stats
	ship.add_child(solver)
	for marker_name in ["StarboardMarker1", "PortMarker1"]:
		var marker := Node3D.new()
		marker.name = marker_name
		ship.add_child(marker)
	var combat := ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = _stats
	combat.fury_data = fury
	combat.cannon_config = CannonConfigData.new()
	combat.cannon_config.ripple_interval = 0.0
	combat.auto_fire_enabled = false
	ship.add_child(combat)
	add_child_autoqfree(ship)
	ship.global_position = pos
	combat.set_physics_process(false)
	solver.set_physics_process(false)
	return ship


func _hit(target: Node, amount: float, from_dir: Vector3, source: Node) -> void:
	target.get_node("ShipDamage").apply_hit(amount, _ammo, from_dir, source)


func test_a_rake_fills_more_than_an_equal_beam_hit() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var c: ShipCombat = shooter.get_node("ShipCombat")
	var target := _make_ship("enemy_ship", Vector3(30, 0, 0))   # spawned after the shooter
	var hull: ShipDamage = target.get_node("ShipDamage")

	var before := hull.hull
	_hit(target, 10.0, Vector3(1, 0, 0), shooter)   # on the beam
	assert_almost_eq(before - hull.hull, 10.0, 0.001, "precondition: beam hit lands 10")
	var beam_fill := c.fury
	assert_almost_eq(beam_fill, 10.0 * _fury.fury_per_hit, 0.0001, "a plain hit fills by hull damage")

	before = hull.hull
	_hit(target, 10.0, Vector3(0, 0, 1), shooter)   # from dead astern
	assert_almost_eq(before - hull.hull, 10.0, 0.001, "precondition: the rake does equal damage")
	var rake_fill := c.fury - beam_fill
	assert_gt(rake_fill, beam_fill, "a rake fills more than a plain hit")
	assert_almost_eq(rake_fill, beam_fill * _fury.rake_multiplier, 0.0001)


func test_hulls_already_in_the_tree_are_heard_too() -> void:
	var target := _make_ship("enemy_ship", Vector3(30, 0, 0))   # spawned BEFORE the shooter
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	_hit(target, 10.0, Vector3(1, 0, 0), shooter)
	assert_almost_eq(shooter.get_node("ShipCombat").fury, 0.1, 0.0001)


func test_only_the_shooters_own_hits_count() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var other := _make_ship("enemy_ship", Vector3(-30, 0, 0))
	var target := _make_ship("enemy_ship", Vector3(30, 0, 0))
	_hit(target, 10.0, Vector3(1, 0, 0), other)
	_hit(target, 10.0, Vector3(1, 0, 0), null)
	_hit(shooter, 10.0, Vector3(1, 0, 0), other)   # being hit is not landing a hit
	assert_eq(shooter.get_node("ShipCombat").fury, 0.0)


func test_a_kill_adds_fury_on_kill() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var target := _make_ship("enemy_ship", Vector3(30, 0, 0))
	target.get_node("ShipDamage").hull = 5.0
	_hit(target, 10.0, Vector3(1, 0, 0), shooter)
	assert_true(target.get_node("ShipDamage").is_destroyed(), "precondition: the hit sank it")
	assert_almost_eq(shooter.get_node("ShipCombat").fury,
		5.0 * _fury.fury_per_hit + _fury.fury_on_kill, 0.0001,
		"the killing blow adds its hull damage plus fury_on_kill")


func test_full_fury_fires_the_special_early_and_is_spent() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var c: ShipCombat = shooter.get_node("ShipCombat")
	assert_true(c.fire_special_broadside(), "precondition: the timer-ready special fires")
	assert_false(c.fire_special_broadside(), "precondition: then it is on cooldown")
	watch_signals(c)
	c.add_fury(1.0)
	assert_signal_emitted(c, "special_broadside_ready", "full Fury announces the special as ready")
	assert_true(c.is_special_ready())
	assert_true(c.fire_special_broadside(), "at Fury 1.0 the special fires during its cooldown")
	assert_eq(c.fury, 0.0, "a Fury-readied special spends the Fury")
	assert_false(c.fire_special_broadside(), "and the next one is refused until refilled")


func test_a_timer_ready_special_leaves_fury_alone() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var c: ShipCombat = shooter.get_node("ShipCombat")
	c.add_fury(0.5)
	assert_true(c.fire_special_broadside())
	assert_almost_eq(c.fury, 0.5, 0.0001)


func test_fury_resets_on_death_and_at_encounter_end() -> void:
	var shooter := _make_ship("player_ship", Vector3.ZERO, _fury)
	var c: ShipCombat = shooter.get_node("ShipCombat")
	c.add_fury(0.6)
	shooter.get_node("CombatModifiers").reset()   # what EncounterManager._resolve does
	assert_eq(c.fury, 0.0, "Fury lasts one battle")
	c.add_fury(0.6)
	c.die()
	assert_eq(c.fury, 0.0, "a sunk hull loses its Fury")


func test_the_player_hull_loads_authored_fury_and_hostiles_do_not() -> void:
	var player := _make_ship("player_ship", Vector3.ZERO)
	var enemy := _make_ship("enemy_ship", Vector3(30, 0, 0))
	var authored := load("res://resources/balance/Fury.tres") as FuryData
	assert_not_null(authored)
	assert_eq(player.get_node("ShipCombat").fury_data, authored)
	assert_null(enemy.get_node("ShipCombat").fury_data, "AI hulls gather no Fury")
	_hit(player, 10.0, Vector3(1, 0, 0), enemy)
	assert_eq(enemy.get_node("ShipCombat").fury, 0.0)


func test_authored_fury_data_is_sane() -> void:
	var data := load("res://resources/balance/Fury.tres") as FuryData
	assert_gt(data.fury_per_hit, 0.0)
	assert_gt(data.rake_multiplier, 1.0, "rakes must fill more than plain hits")
	assert_gt(data.fury_on_kill, 0.0)
	assert_gt(data.fury_on_perfect_brace, 0.0)
	assert_lte(data.fury_on_perfect_brace, 1.0)
