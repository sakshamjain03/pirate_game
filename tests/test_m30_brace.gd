extends GutTest
## M30 Wave 1 (1.6) — Brace, driven the way play drives it. Verify bullets
## (tasks.md 1.6 / requirement W1-1.3):
##   * Bracing → damage × (1 − reduction)          (apply_brace, then apply_hit)
##   * Perfect → the larger reduction plus Fury     (a press in the last
##       perfect_window of a hostile wind-up aimed at the player, through
##       WorldManager's context verb)
##   * Firing while bracing → false                 (a hull WITH guns fires
##       before the brace and is refused during it, special included)
##   * During cooldown → no brace                   (the window expires through
##       _physics_process; the cooldown is the applied BraceData's)
## Plus the arbiter rules: Brace is offered only while a wind-up is aimed at the
## player and never while docked, so it cannot steal the Dock/Board press.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false
	func fire_cannons(side: String) -> void:
		var c = get_node_or_null("ShipCombat")
		if c: c.fire_broadside(side)

const WINDUP := 1.0
const DT := 0.05

var _created_test_scene: Node3D = null
var _saved_profile: AIDifficultyData = null
var _stats: ShipStats
var _ammo: AmmoData
var _brace: BraceData


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
	_stats.max_health = 1000.0
	_stats.max_crew = 20.0
	_stats.max_sails = 100.0
	_stats.cannon_damage = 10.0
	_stats.fire_rate = 0.5
	_stats.cannon_range = 100.0
	_stats.firing_arc_degrees = 30.0
	_stats.special_broadside_cooldown = 10.0
	_ammo = AmmoData.new()   # hull ×1, nothing else
	_brace = BraceData.new()
	_brace.reduction = 0.4
	_brace.perfect_reduction = 0.7
	_brace.window = 1.0
	_brace.perfect_window = 0.2
	_brace.cooldown = 2.0


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
	for marker_name in ["StarboardMarker1", "PortMarker1"]:
		var marker := Node3D.new()
		marker.name = marker_name
		ship.add_child(marker)
	var combat := ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = _stats
	combat.cannon_config = CannonConfigData.new()
	combat.cannon_config.ripple_interval = 0.0
	combat.auto_fire_enabled = false
	ship.add_child(combat)
	add_child_autoqfree(ship)
	ship.global_position = pos
	combat.set_physics_process(false)
	solver.set_physics_process(false)
	return ship


func _combat(ship: Node) -> ShipCombat:
	return ship.get_node("ShipCombat")


func _hull_loss_from_hit(ship: Node, amount: float) -> float:
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	var before := dmg.hull
	dmg.apply_hit(amount, _ammo, Vector3.ZERO)
	return before - dmg.hull


## A WorldManager with the player and one hostile that winds up at it.
func _setup_world() -> Dictionary:
	var player := _make_ship("player_ship", Vector3.ZERO)
	var enemy := _make_ship("enemy_ship", Vector3(20, 0, 0))
	var ecombat := _combat(enemy)
	ecombat.auto_fire_enabled = true
	var wm: Node = load("res://scripts/managers/WorldManager.gd").new()
	add_child_autoqfree(wm)
	wm.player_ship = player
	wm.tick_windup_tracker(0.0)   # first scan: start watching the hostile
	return {"player": player, "enemy": enemy, "wm": wm, "ecombat": ecombat,
		"esolver": enemy.get_node("FiringSolver")}


## Advances the hostile's auto-fire and WorldManager's wind-up tracker together.
func _step(w: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w["esolver"].force_rescan()
		w["ecombat"]._physics_process(DT)
		w["wm"].tick_windup_tracker(DT)


# --- damage × (1 − reduction) --------------------------------------------------

func test_bracing_multiplies_cannon_damage_by_one_minus_reduction() -> void:
	var ship := _make_ship("player_ship", Vector3.ZERO)
	assert_almost_eq(_hull_loss_from_hit(ship, 50.0), 50.0, 0.01, "baseline: unbraced hull takes the full hit")
	assert_true(_combat(ship).apply_brace(_brace), "the brace takes effect")
	assert_almost_eq(_hull_loss_from_hit(ship, 50.0), 50.0 * (1.0 - _brace.reduction), 0.01,
		"bracing: damage × (1 − reduction)")


func test_reduction_ends_with_the_window() -> void:
	var ship := _make_ship("player_ship", Vector3.ZERO)
	var c := _combat(ship)
	c.apply_brace(_brace)
	for i in int(round((_brace.window + DT) / DT)):
		c._physics_process(DT)
	assert_false(c.is_bracing, "the window closes on its own")
	assert_almost_eq(_hull_loss_from_hit(ship, 50.0), 50.0, 0.01, "full damage again after the window")


# --- Perfect → larger reduction plus Fury -----------------------------------------

func test_perfect_brace_late_in_a_windup_cuts_more_and_grants_fury() -> void:
	var w := _setup_world()
	var pc := _combat(w["player"])
	assert_not_null(pc.fury_data, "the player's hull gathers Fury")
	_step(w, DT)   # the hostile locks on and starts its wind-up
	assert_eq(w["wm"].get_context_verb(), &"brace", "a wind-up aimed at the player offers Brace")
	_step(w, WINDUP - _brace.perfect_window)   # inside the last perfect_window
	assert_eq(w["wm"].get_context_verb(), &"brace")
	w["wm"]._brace_data = _brace
	assert_eq(w["wm"]._context_arbiter.perform(), &"brace", "the context press braces")
	assert_true(pc.is_perfect_bracing, "a press in the last perfect_window is Perfect")
	assert_almost_eq(_hull_loss_from_hit(w["player"], 50.0), 50.0 * (1.0 - _brace.perfect_reduction), 0.01,
		"Perfect: damage × (1 − perfect_reduction)")
	assert_almost_eq(pc.fury, pc.fury_data.fury_on_perfect_brace, 0.001, "Perfect grants Fury")


func test_early_brace_is_not_perfect_and_grants_no_fury() -> void:
	var w := _setup_world()
	var pc := _combat(w["player"])
	w["wm"]._brace_data = _brace
	_step(w, DT)
	assert_eq(w["wm"]._context_arbiter.perform(), &"brace")
	assert_false(pc.is_perfect_bracing, "pressed with most of the wind-up left: a normal brace")
	assert_almost_eq(_hull_loss_from_hit(w["player"], 50.0), 50.0 * (1.0 - _brace.reduction), 0.01)
	assert_eq(pc.fury, 0.0, "only a Perfect Brace grants Fury")


# --- Brace only while threatened -------------------------------------------------

func test_brace_is_not_offered_without_a_windup_so_dock_keeps_the_button() -> void:
	var w := _setup_world()
	w["ecombat"].auto_fire_enabled = false   # no wind-up
	var docked := [0]
	w["wm"].register_context_provider(&"dock", func(): return true,
		func(): docked[0] += 1; return true, "Dock")
	_step(w, DT)
	assert_eq(w["wm"].get_context_verb(), &"dock", "no threat: Dock wins, Brace stays hidden")
	assert_eq(w["wm"]._context_arbiter.perform(), &"dock")
	assert_eq(docked[0], 1)
	assert_false(_combat(w["player"]).is_bracing, "the Dock press did not brace")


func test_brace_is_offered_only_while_the_windup_runs() -> void:
	var w := _setup_world()
	_step(w, DT)
	assert_eq(w["wm"].get_context_verb(), &"brace")
	_step(w, WINDUP + DT)   # the hostile fired: the threat is over
	assert_ne(w["wm"].get_context_verb(), &"brace", "no Brace once the wind-up has gone off")


func test_windup_aimed_elsewhere_does_not_offer_brace() -> void:
	var w := _setup_world()
	w["wm"].get_windup_tracker().target = null
	w["wm"].player_ship = _make_ship("", Vector3(500, 0, 500))   # a different hull
	_step(w, DT)
	assert_ne(w["wm"].get_context_verb(), &"brace", "only wind-ups aimed at the player count")


func test_no_brace_while_docked() -> void:
	var w := _setup_world()
	_step(w, DT)
	w["player"].is_docked = true
	assert_ne(w["wm"].get_context_verb(), &"brace", "never at anchor in port")


# --- guns blocked ---------------------------------------------------------------

func test_guns_fire_before_bracing_and_are_refused_during_it() -> void:
	var ship := _make_ship("player_ship", Vector3.ZERO)
	var c := _combat(ship)
	assert_true(c.fire_broadside("port"), "precondition: this hull's guns fire")
	assert_true(c.apply_brace(_brace))
	assert_false(c.fire_broadside("starboard"), "a reloaded side is refused while bracing")
	assert_false(c.fire_special_broadside(), "the special is refused while bracing too")
	assert_true(c.is_special_broadside_ready(), "...and its cooldown was not spent")


# --- cooldown -------------------------------------------------------------------

func test_cooldown_after_the_window_refuses_a_brace_until_it_runs_out() -> void:
	var ship := _make_ship("player_ship", Vector3.ZERO)
	var c := _combat(ship)
	assert_true(c.apply_brace(_brace))
	assert_false(c.apply_brace(_brace), "no second brace while one runs")
	for i in int(round((_brace.window + DT) / DT)):
		c._physics_process(DT)
	assert_false(c.is_bracing)
	assert_true(c.is_brace_on_cooldown(), "the window's close starts the cooldown")
	assert_almost_eq(c._brace_cooldown_remaining, _brace.cooldown, DT + 0.001,
		"the cooldown is the applied BraceData's, not a hardcoded file's")
	assert_false(c.apply_brace(_brace), "during cooldown → no brace")
	for i in int(round(_brace.cooldown / DT)) + 1:
		c._physics_process(DT)
	assert_false(c.is_brace_on_cooldown())
	assert_true(c.apply_brace(_brace), "braces again once the cooldown has run out")


func test_cancel_starts_the_cooldown_and_death_clears_it() -> void:
	var ship := _make_ship("player_ship", Vector3.ZERO)
	var c := _combat(ship)
	c.apply_brace(_brace)
	c.cancel_brace()
	assert_false(c.is_bracing)
	assert_true(c.is_brace_on_cooldown(), "cancelling early still costs the cooldown")
	c.die()
	assert_false(c.is_brace_on_cooldown(), "a sunk hull respawns with Brace ready")


func test_authored_brace_data_is_sane() -> void:
	var data := load("res://resources/balance/Brace.tres") as BraceData
	assert_not_null(data)
	assert_gt(data.reduction, 0.0)
	assert_gt(data.perfect_reduction, data.reduction, "Perfect is the larger reduction")
	assert_lte(data.perfect_reduction, 1.0)
	assert_gt(data.window, 0.0)
	assert_gt(data.perfect_window, 0.0)
	assert_lt(data.perfect_window, data.window)
	assert_gt(data.cooldown, 0.0)


func test_the_button_hears_when_brace_comes_and_goes() -> void:
	# MobileControls relabels the context button on this signal; Brace appears
	# and vanishes mid-sail with no ship signal of its own.
	var w := _setup_world()
	var seen: Array = []
	w["wm"].context_verb_changed.connect(func(v): seen.append(v))
	_step(w, DT)
	w["wm"]._publish_context_verb()
	_step(w, WINDUP + DT)
	w["wm"]._publish_context_verb()
	assert_eq(seen, [&"brace", &""], "announced when Brace wins and again when it goes")
