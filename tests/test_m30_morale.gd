extends GutTest
## M30 Wave 2 (2.6): enemy morale, wavering, striking the colours, the Take Prize verb and
## the Dread/Renown axis.
##   - MoraleComponent drains from crew lost, rakes (player guns only) and the squad leader
##     sinking, telegraphs WAVERING, then FLEES (rigging intact) or STRIKES (rigging shot away,
##     or nerve below the strike line). Bosses never break.
##   - A struck ship stops firing and is takeable at any hull through the Take Prize verb; its
##     boarding deck opens with the Colours already weakened.
##   - EmpireManager's Dread/Renown axis round-trips and is omitted from the save at zero.

class MockShip extends Node3D:
	var inputs: Array = []
	func set_input(a: float, b: float) -> void:
		inputs.append([a, b])

class FakeCombat extends Node:
	# Autoload listeners (e.g. campaign objectives) connect to every enemy hull's ShipCombat.
	signal died
	signal health_changed(current: float, maximum: float)
	var auto_fire_enabled: bool = true

class FakeAI extends Node:
	var fled: bool = false
	func order_flee() -> void:
		fled = true

const GRAPE := "res://resources/combat/ammo/GrapeShot.tres"
const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D
var _prev_scene: Node
var _data: MoraleData
var _prev_axis: float = 0.0
var _prev_notoriety: float = 0.0
var _prev_resources: Dictionary = {}
var _prev_quick: bool = false
var _made: Array = []


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "MoraleWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_data = MoraleData.new()
	_prev_axis = EmpireManager.axis
	_prev_notoriety = EmpireManager.notoriety
	_prev_resources = ResourceManager.current_resources.duplicate()
	_prev_quick = SettingsManager.quick_boarding
	SettingsManager.quick_boarding = false
	EmpireManager.axis = 0.0
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")
	_made = []


func after_each() -> void:
	EmpireManager.axis = _prev_axis
	EmpireManager.notoriety = _prev_notoriety
	ResourceManager.current_resources = _prev_resources.duplicate()
	SettingsManager.quick_boarding = _prev_quick
	for n in _made:
		if is_instance_valid(n):
			n.free()
	for g in [&"player_ship", &"enemy_ship", &"struck_ship", &"boss_ship"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		get_tree().root.remove_child(_scene)
		_scene.free()
	_scene = null


## An enemy hull with just what MoraleComponent talks to.
func _enemy(boss: bool = false, max_crew: float = 100.0) -> MockShip:
	var ship := MockShip.new()
	ship.add_to_group("enemy_ship")
	if boss:
		ship.add_to_group("boss_ship")
	var stats := ShipStats.new()
	stats.max_crew = max_crew
	stats.display_name = "Mock Hull"
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	ship.add_child(dmg)
	var combat := FakeCombat.new()
	combat.name = "ShipCombat"
	ship.add_child(combat)
	var ai := FakeAI.new()
	ai.name = "EnemyAI"
	ship.add_child(ai)
	var morale := MoraleComponent.new()
	morale.name = "MoraleComponent"
	morale.data = _data
	ship.add_child(morale)
	_scene.add_child(ship)
	_made.append(ship)
	return ship


func _morale(ship: Node) -> MoraleComponent:
	return ship.get_node("MoraleComponent")


func _hit(ship: Node, deltas: Dictionary, facing: StringName = &"beam", source: Node = null) -> void:
	ship.get_node("ShipDamage").hit_resolved.emit(source, facing, deltas, &"round", PackedStringArray())


func _player() -> Node:
	var p := Node3D.new()
	p.add_to_group("player_ship")
	_scene.add_child(p)
	_made.append(p)
	return p


# === The data ===

func test_the_authored_morale_resource_loads_with_a_sensible_ladder() -> void:
	var d: MoraleData = load(MoraleData.DEFAULT_PATH)
	assert_not_null(d)
	assert_gt(d.start, d.wavering_threshold)
	assert_gt(d.wavering_threshold, d.strike_threshold, "a crew wavers before it strikes")
	assert_gt(d.waver_seconds, 0.0, "the telegraph has a duration")


# === Draining ===

func test_losing_crew_drains_morale_in_proportion() -> void:
	var ship := _enemy()
	_hit(ship, {"crew": 30.0})
	assert_almost_eq(_morale(ship).value, 100.0 - 0.3 * _data.crew_loss_drain, 0.001)


func test_a_player_rake_drains_and_other_hits_do_not() -> void:
	var ship := _enemy()
	var player := _player()
	_hit(ship, {"hull": 10.0}, &"beam", player)
	assert_eq(_morale(ship).value, 100.0, "a broadside is not a rake")
	_hit(ship, {"hull": 10.0}, &"stern", player)
	assert_eq(_morale(ship).value, 100.0 - _data.rake_drain)
	_hit(ship, {"hull": 10.0}, &"bow", player)
	assert_eq(_morale(ship).value, 100.0 - 2.0 * _data.rake_drain, "bow rakes count too")
	_hit(ship, {"hull": 10.0}, &"stern", null)
	assert_eq(_morale(ship).value, 100.0 - 2.0 * _data.rake_drain, "a collision or stray hit is not the player's rake")


func test_the_squad_leader_sinking_shakes_every_crew_but_not_the_leader_itself() -> void:
	var leader := _enemy()
	var follower := _enemy()
	get_tree().call_group("morale_component", "notify_leader_sunk", leader)
	assert_eq(_morale(follower).value, 100.0 - _data.leader_sunk_drain)
	assert_eq(_morale(leader).value, 100.0, "the leader does not drain itself")


func test_real_grape_shot_through_shipdamage_drains_morale() -> void:
	var ship := _enemy()
	var player := _player()
	ship.get_node("ShipDamage").apply_hit(40.0, load(GRAPE), Vector3.FORWARD, player)
	assert_lt(_morale(ship).value, 100.0, "grape kills crew, and crew loss costs nerve")


func test_morale_never_leaves_zero_to_one_hundred() -> void:
	var ship := _enemy()
	_hit(ship, {"crew": 100000.0})
	assert_eq(_morale(ship).value, 0.0)
	assert_eq(_morale(ship).morale_fraction(), 0.0)
	assert_eq(_morale(_enemy()).morale_fraction(), 1.0)


# === Wavering, then fleeing or striking ===

func test_dropping_to_the_threshold_telegraphs_wavering_once() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	watch_signals(m)
	m.drain(_data.start - _data.wavering_threshold - 1.0)
	assert_eq(m.state, MoraleComponent.State.STEADY, "not yet")
	assert_signal_not_emitted(m, "wavering_started")
	m.drain(1.0)
	assert_eq(m.state, MoraleComponent.State.WAVERING)
	assert_signal_emit_count(m, "wavering_started", 1)
	assert_signal_emitted_with_parameters(m, "wavering_started", [_data.waver_seconds])
	m.drain(1.0)
	assert_signal_emit_count(m, "wavering_started", 1, "the telegraph is not repeated")


func test_a_wavering_crew_with_its_rigging_runs() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	var dmg = ship.get_node("ShipDamage")
	dmg.sails = dmg.get_pool_maximum("sails")
	watch_signals(m)
	m.drain(_data.start - _data.wavering_threshold)
	m._process(_data.waver_seconds - 0.1)
	assert_eq(m.state, MoraleComponent.State.WAVERING, "still wavering until the telegraph runs out")
	m._process(0.2)
	assert_eq(m.state, MoraleComponent.State.FLED)
	assert_true(ship.get_node("EnemyAI").fled, "EnemyAI is ordered to flee")
	assert_signal_emit_count(m, "fled", 1)
	assert_false(ship.get_meta(&"struck", false))


func test_a_wavering_crew_with_its_sails_shot_away_strikes_instead_of_running() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	var dmg = ship.get_node("ShipDamage")
	dmg.sails = dmg.get_pool_maximum("sails") * 0.1  # chain shot did its work
	m.drain(_data.start - _data.wavering_threshold)
	m._process(_data.waver_seconds + 0.1)
	assert_eq(m.state, MoraleComponent.State.STRUCK)
	assert_false(ship.get_node("EnemyAI").fled, "it cannot run")


func test_a_crew_below_the_strike_line_strikes_even_with_its_rigging() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	var dmg = ship.get_node("ShipDamage")
	dmg.sails = dmg.get_pool_maximum("sails")
	m.drain(_data.start - _data.strike_threshold + 1.0)
	m._process(_data.waver_seconds + 0.1)
	assert_eq(m.state, MoraleComponent.State.STRUCK)


# === A struck ship ===

func test_a_struck_ship_stops_firing_and_waits_to_be_taken() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	watch_signals(m)
	m.strike()
	assert_eq(m.state, MoraleComponent.State.STRUCK)
	assert_true(m.is_struck())
	assert_false(ship.get_node("ShipCombat").auto_fire_enabled, "no more broadsides")
	assert_false(ship.get_node("EnemyAI").is_processing(), "its AI is stood down")
	assert_false(ship.get_node("EnemyAI").is_physics_processing())
	assert_eq(ship.inputs.back(), [0.0, 0.0], "helm and sail let go")
	assert_true(ship.get_meta(&"struck", false))
	assert_true(ship.is_in_group(&"struck_ship"))
	assert_signal_emit_count(m, "struck", 1)
	m.strike()
	assert_signal_emit_count(m, "struck", 1, "striking twice is still once")


func test_morale_stops_changing_once_the_crew_has_broken() -> void:
	var ship := _enemy()
	var m := _morale(ship)
	m.strike()
	var v := m.value
	m.drain(50.0)
	assert_eq(m.value, v)
	var runner := _enemy()
	_morale(runner).flee()
	var rv := _morale(runner).value
	_morale(runner).drain(50.0)
	assert_eq(_morale(runner).value, rv)


func test_bosses_never_waver_or_strike() -> void:
	var boss := _enemy(true)
	var m := _morale(boss)
	assert_false(m.can_break)
	m.drain(100.0)
	assert_eq(m.state, MoraleComponent.State.STEADY)
	m._process(100.0)
	assert_eq(m.state, MoraleComponent.State.STEADY)
	assert_eq(m.value, 0.0, "the morale number still moves; the boss just does not break")


# === Enemy hulls carry a MoraleComponent; the player does not ===

func test_enemy_hulls_get_a_morale_component_and_the_players_does_not() -> void:
	var enemy := ENEMY_SHIP.instantiate()
	_scene.add_child(enemy)
	_made.append(enemy)
	assert_not_null(enemy.get_node_or_null("MoraleComponent"), "ShipController adds one to enemy hulls")
	var player := ENEMY_SHIP.instantiate()
	player.remove_from_group("enemy_ship")
	player.add_to_group("player_ship")
	_scene.add_child(player)
	_made.append(player)
	assert_null(player.get_node_or_null("MoraleComponent"))


# === Take Prize ===

func _boarding_rig(struck: bool, morale_value: float = 100.0) -> Dictionary:
	var system := BoardingSystem.new()
	system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(system)
	_made.append(system)
	var player := _player()
	var pstats := ShipStats.new()
	pstats.max_crew = 100.0
	var pdmg = load("res://scripts/world/ShipDamage.gd").new()
	pdmg.name = "ShipDamage"
	pdmg.ship_stats = pstats
	player.add_child(pdmg)
	pdmg.crew = 100.0
	var enemy := _enemy()
	enemy.get_node("ShipDamage").crew = 100.0
	_morale(enemy).value = morale_value
	if struck:
		_morale(enemy).strike()
	return {"system": system, "player": player, "enemy": enemy}


func test_a_struck_ship_is_takeable_at_full_hull_and_an_unbroken_one_is_not() -> void:
	var rig := _boarding_rig(false)
	var system: BoardingSystem = rig["system"]
	system._check_eligibility()
	assert_null(system._eligible_enemy, "full hull, nerve intact: nothing to board")
	_morale(rig["enemy"]).strike()
	system._check_eligibility()
	assert_same(system._eligible_enemy, rig["enemy"], "struck colours make it takeable at any hull")
	assert_true(system.can_take_prize())
	assert_false(system.can_board(), "a struck ship is taken, not fought")


func test_a_crippled_ship_that_has_not_struck_is_boarded_not_taken() -> void:
	var rig := _boarding_rig(false)
	var system: BoardingSystem = rig["system"]
	var dmg = rig["enemy"].get_node("ShipDamage")
	dmg.hull = dmg.get_pool_maximum("hull") * 0.1
	system._check_eligibility()
	assert_true(system.can_board())
	assert_false(system.can_take_prize())


func test_the_context_verb_offers_take_prize_for_a_struck_ship_and_board_otherwise() -> void:
	var rig := _boarding_rig(true)
	var system: BoardingSystem = rig["system"]
	var wm = load("res://scripts/managers/WorldManager.gd").new()
	_made.append(wm)
	wm._boarding_system = system
	wm._register_wave0_context_verbs()
	system._eligible_enemy = rig["enemy"]
	assert_eq(wm.get_context_verb(), &"take_prize")
	assert_eq(wm.get_context_label(&"take_prize"), "Take Prize")

	_morale(rig["enemy"]).state = MoraleComponent.State.STEADY
	rig["enemy"].remove_meta(&"struck")
	assert_eq(wm.get_context_verb(), &"board", "the same ship, not struck, is a Board")


func test_take_prize_opens_three_bells_with_the_colours_weakened() -> void:
	var struck_rig := _boarding_rig(true, 8.0)
	var s: BoardingSystem = struck_rig["system"]
	s._eligible_enemy = struck_rig["enemy"]
	assert_true(s.begin_boarding())
	assert_true(s.is_boarding_active(), "a tactical battle, not the instant path")
	var weak_morale: int = s.deck.morale
	assert_eq(weak_morale, s.boarding_data.strike_morale + 1, "one blow from striking")
	s.cancel_boarding()

	var steady_rig := _boarding_rig(false, 100.0)
	var t: BoardingSystem = steady_rig["system"]
	t._eligible_enemy = steady_rig["enemy"]
	assert_true(t.begin_boarding())
	assert_gt(t.deck.morale, weak_morale, "an unbroken crew boards at its profile morale")
	t.cancel_boarding()


func test_the_battle_of_a_struck_ship_ends_in_the_colours_within_the_first_bell() -> void:
	var rig := _boarding_rig(true, 8.0)
	var system: BoardingSystem = rig["system"]
	system._eligible_enemy = rig["enemy"]
	system.begin_boarding()
	var b := system.battle
	# The deck starts one point above the strike line. Cut down three men in the landing zone
	# (the officer will rally a few points back, so one blow is not enough, three is).
	var cutlass: BoardingActionData = system.boarding_data.actions[0]
	var men := b.defenders_in(b.zone)
	for i in mini(3, men.size()):
		assert_true(b.queue_action(cutlass, men[i].uid))
	b.ring_bell()
	assert_true(b.is_over(), "the first bell ends it")
	assert_eq(b.outcome["id"], "struck")
	assert_true(b.outcome["success"])


# === The Dread/Renown axis ===

func test_the_axis_is_omitted_from_the_save_at_zero_and_round_trips_otherwise() -> void:
	EmpireManager.axis = 0.0
	assert_false(EmpireManager.get_save_data().has("axis"), "an optional save key is omitted, not written as 0")
	EmpireManager.shift_axis(7.5)
	var saved := EmpireManager.get_save_data()
	assert_eq(saved["axis"], 7.5)
	EmpireManager.axis = 0.0
	EmpireManager.load_save_data(saved)
	assert_eq(EmpireManager.axis, 7.5)
	EmpireManager.load_save_data({"notoriety": 0.0})
	assert_eq(EmpireManager.axis, 0.0, "an older save has no axis: it resets instead of keeping a stale one")


func test_the_axis_is_signed_and_clamped() -> void:
	watch_signals(EmpireManager)
	EmpireManager.shift_axis(-4.0)
	assert_eq(EmpireManager.axis, -4.0, "negative is Renown")
	assert_signal_emitted(EmpireManager, "axis_changed")
	EmpireManager.shift_axis(10000.0)
	assert_eq(EmpireManager.axis, EmpireManager.AXIS_LIMIT)
	EmpireManager.shift_axis(-100000.0)
	assert_eq(EmpireManager.axis, -EmpireManager.AXIS_LIMIT)
	var before := EmpireManager.axis
	EmpireManager.shift_axis(0.0)
	assert_eq(EmpireManager.axis, before)


func test_taking_a_struck_ship_earns_renown_and_a_beaten_one_earns_none() -> void:
	var rig := _boarding_rig(true, 8.0)
	var system: BoardingSystem = rig["system"]
	system._eligible_enemy = rig["enemy"]
	system.begin_boarding()
	system.resolve_tactical("struck", true)
	assert_eq(EmpireManager.axis, -NotorietyGainsData.get_default().renown_take_prize)

	EmpireManager.axis = 0.0
	var plain := _boarding_rig(false)
	var s2: BoardingSystem = plain["system"]
	s2._eligible_enemy = plain["enemy"]
	s2.begin_boarding()
	s2.resolve_tactical("colours", true)
	assert_eq(EmpireManager.axis, 0.0, "boarding a ship that never surrendered is neither")


func test_sinking_a_struck_ship_earns_dread() -> void:
	var enemy := ENEMY_SHIP.instantiate()
	_scene.add_child(enemy)
	_made.append(enemy)
	enemy.set_meta(&"struck", true)
	enemy._on_died()
	assert_eq(EmpireManager.axis, NotorietyGainsData.get_default().dread_sink_struck)

	EmpireManager.axis = 0.0
	var other := ENEMY_SHIP.instantiate()
	_scene.add_child(other)
	_made.append(other)
	other.set_meta(&"struck", true)
	other.set_meta(&"boarding_outcome", "colours")  # taken by boarding, then it sinks as a wreck
	other._on_died()
	assert_eq(EmpireManager.axis, 0.0, "a ship that was boarded is not 'sunk after surrendering'")


func test_the_squad_leader_sinking_costs_the_rest_morale() -> void:
	var leader := ENEMY_SHIP.instantiate()
	var follower := ENEMY_SHIP.instantiate()
	_scene.add_child(leader)
	_scene.add_child(follower)
	_made.append(leader)
	_made.append(follower)
	leader.set_meta("squad_leader", true)
	var m: MoraleComponent = follower.get_node("MoraleComponent")
	var before := m.value
	leader._on_died()
	assert_lt(m.value, before)
