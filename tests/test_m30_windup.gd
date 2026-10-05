extends GutTest
## M30 Wave 1 (1.4): the broadside wind-up. A hostile hull's AUTO-FIRE no
## longer goes off the instant its arc locks: it emits
## `broadside_windup(side, duration, target)` and holds fire for
## AIDifficultyData.broadside_windup_seconds, then fires only if the target is
## still in the arc. Player-side hulls (AIDifficultyData.for_ship() == null)
## have no wind-up. fire_broadside() itself is untouched and synchronous
## (test_ship_combat.gd relies on that).
##
## The combat/solver nodes are stepped by hand with a fixed delta so the timing
## assertions are exact rather than frame-rate dependent.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false
	func fire_cannons(side: String) -> void:
		var c = get_node_or_null("ShipCombat")
		if c: c.fire_broadside(side)

const WINDUP := 0.6
const DT := 0.05

var _created_test_scene: Node3D = null
var _saved_profile: AIDifficultyData = null
var _stats: ShipStats
var _fired: Array = []
var _windups: Array = []


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_saved_profile = SettingsManager._ai_difficulty_profile
	var diff := AIDifficultyData.new()
	diff.broadside_windup_seconds = WINDUP
	SettingsManager._ai_difficulty_profile = diff
	_stats = ShipStats.new()
	_stats.max_health = 200.0
	_stats.max_crew = 20.0
	_stats.max_sails = 100.0
	_stats.cannon_damage = 10.0
	_stats.fire_rate = 0.5
	_stats.cannon_range = 100.0
	_stats.firing_arc_degrees = 30.0
	_fired = []
	_windups = []


func after_each() -> void:
	SettingsManager._ai_difficulty_profile = _saved_profile
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _make_ship(group: String, pos: Vector3) -> MockShip:
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
	var marker := Node3D.new()
	marker.name = "StarboardMarker1"
	ship.add_child(marker)
	var marker2 := Node3D.new()
	marker2.name = "PortMarker1"
	ship.add_child(marker2)
	var combat := ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = _stats
	combat.cannon_config = CannonConfigData.new()
	combat.cannon_config.ripple_interval = 0.0
	ship.add_child(combat)
	add_child_autoqfree(ship)
	ship.global_position = pos
	# Driven by hand below.
	combat.set_physics_process(false)
	solver.set_physics_process(false)
	return ship


## The shooter at the origin, a hostile target dead on its starboard beam.
func _setup(shooter_group: String) -> Dictionary:
	var target_group := "enemy_ship" if shooter_group == "player_ship" else "player_ship"
	var shooter := _make_ship(shooter_group, Vector3.ZERO)
	var target := _make_ship(target_group, Vector3(20, 0, 0))
	var combat: ShipCombat = shooter.get_node("ShipCombat")
	combat.auto_fire_enabled = true
	combat.fired.connect(func(side): _fired.append(side))
	combat.broadside_windup.connect(func(side, duration, tgt): _windups.append([side, duration, tgt]))
	return {"shooter": shooter, "target": target, "combat": combat,
		"solver": shooter.get_node("FiringSolver")}


func _step(s: Dictionary, seconds: float) -> void:
	var steps := int(round(seconds / DT))
	for i in steps:
		s["solver"].force_rescan()
		s["combat"]._physics_process(DT)


func test_hostile_auto_fire_waits_for_the_windup() -> void:
	var s := _setup("enemy_ship")
	_step(s, DT)
	assert_eq(_windups.size(), 1, "arc lock with the reload ready starts one wind-up")
	assert_eq(_windups[0][0], "starboard")
	assert_almost_eq(float(_windups[0][1]), WINDUP, 0.001, "duration comes from AIDifficultyData")
	assert_eq(_windups[0][2], s["target"], "the wind-up names who it is aimed at")
	assert_true(_fired.is_empty(), "no shot on the lock frame")
	_step(s, WINDUP - 0.15)
	assert_true(_fired.is_empty(), "still holding fire before the wind-up elapses")
	assert_eq(_windups.size(), 1, "the wind-up is not restarted every frame")
	_step(s, 0.25)
	assert_eq(_fired, ["starboard"], "fires once the wind-up has elapsed")


func test_windup_is_cancelled_when_the_target_leaves_the_arc() -> void:
	var s := _setup("enemy_ship")
	watch_signals(s["combat"])
	_step(s, DT)
	assert_eq(_windups.size(), 1)
	# Target slips round to dead astern — out of the broadside arc.
	s["target"].global_position = Vector3(0, 0, 20)
	_step(s, WINDUP + 0.2)
	assert_true(_fired.is_empty(), "a target that left the arc is not fired at")
	assert_signal_emitted(s["combat"], "broadside_windup_cancelled")


func test_player_hull_fires_immediately() -> void:
	var s := _setup("player_ship")
	_step(s, DT)
	assert_eq(_fired, ["starboard"], "player-side hulls have no wind-up")
	assert_true(_windups.is_empty(), "and never telegraph one")
	assert_eq(s["combat"].get_broadside_windup_seconds(), 0.0)


func test_fire_broadside_is_still_synchronous_on_a_hostile_hull() -> void:
	var s := _setup("enemy_ship")
	assert_true(s["combat"].fire_broadside("starboard"),
		"a direct fire_broadside() call is not gated by the wind-up")
	assert_eq(_fired, ["starboard"])
	assert_true(_windups.is_empty())


func test_every_difficulty_authors_a_windup() -> void:
	var paths := ResourceLookup.list_resource_paths("res://resources/combat/ai_difficulty")
	assert_eq(paths.size(), 4, "Relaxed, Normal, Hard, Brutal")
	var values := {}
	for p in paths:
		var d := load(p) as AIDifficultyData
		assert_not_null(d, p)
		assert_gt(d.broadside_windup_seconds, 0.0, "%s authors a wind-up" % p)
		values[d.display_name] = d.broadside_windup_seconds
		var text := FileAccess.get_file_as_string(p)
		assert_string_contains(text, "broadside_windup_seconds", "explicitly authored in %s" % p)
	# Harder enemies telegraph for less time.
	assert_gt(values["Relaxed"], values["Brutal"])
