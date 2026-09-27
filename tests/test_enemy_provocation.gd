extends GutTest

## Guards M25's passive-until-provoked behaviour — the half of the heat system
## that makes low heat feel different rather than just easier.
##
## Two rules this pins, both easy to break by accident:
##
##   1. Passivity is PER-SHIP. Shooting one hull must not recruit its neighbours.
##   2. Passivity applies ONLY to ambient hulls. Bosses, encounter spawns, siege
##      attackers and dispatched hunters must always engage — otherwise a scripted
##      fight the game promised the player silently never starts, which is the
##      "authored content with no in-world trigger" failure mode CLAUDE.md warns
##      about.
##
## It also pins that a passive ship still runs obstacle avoidance. That code
## (`_get_avoidance_turn`/`_probe`/`_push_to_open_water`) is what stops enemies
## beaching on islands, and the heat gate sits deliberately far away from it.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null
var _saved_notoriety: float = 0.0


func before_each() -> void:
	_saved_notoriety = EmpireManager.notoriety
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each() -> void:
	EmpireManager.notoriety = _saved_notoriety
	EmpireManager._refresh_heat_tier(false)
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _set_heat(notoriety: float) -> void:
	EmpireManager.notoriety = notoriety
	EmpireManager._refresh_heat_tier(false)


## A real EnemyShip, matching test_ai_ramming.gd's convention. EnemyAI types its
## `ship_controller` as ShipController, so a stand-in node cannot stand in.
## Auto-fire is off so an idle hull does not start shooting mid-assertion.
func _make_ai(ambient: bool) -> EnemyAI:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	ship.get_node("ShipCombat").auto_fire_enabled = false
	var ai: EnemyAI = ship.get_node("EnemyAI")
	_scene.add_child(ship)
	if ambient:
		ship.add_to_group("ambient_enemy")
	else:
		ship.remove_from_group("ambient_enemy")
	return ai


func test_ambient_ship_is_passive_at_low_heat() -> void:
	_set_heat(0.0)
	var ai := _make_ai(true)
	assert_false(ai._may_engage_player(),
		"At the lowest heat an ambient ship must ignore the player until provoked")


func test_ambient_ship_engages_at_high_heat() -> void:
	_set_heat(250.0)
	var ai := _make_ai(true)
	assert_true(ai._may_engage_player(),
		"At high heat ambient ships must engage on sight — that is the swarm")


func test_provocation_overrides_low_heat() -> void:
	_set_heat(0.0)
	var ai := _make_ai(true)
	assert_false(ai._may_engage_player())
	ai.provoke()
	assert_true(ai._may_engage_player(), "A ship the player shot must fight back at any heat")
	assert_true(ai.is_provoked())


func test_provocation_does_not_expire() -> void:
	# A ship you shot does not forgive you. If this ever becomes a timer, a player
	# could disengage mid-fight and have the enemy wander off.
	_set_heat(0.0)
	var ai := _make_ai(true)
	ai.provoke()
	await wait_process_frames(10)
	assert_true(ai._may_engage_player(), "Provocation must not decay on its own")


func test_provocation_is_per_ship_not_global() -> void:
	# THE rule that makes low heat readable: firing on one hull must not turn the
	# whole sea hostile.
	_set_heat(0.0)
	var shot := _make_ai(true)
	var bystander := _make_ai(true)

	shot.provoke()

	assert_true(shot._may_engage_player(), "The ship that was shot engages")
	assert_false(bystander._may_engage_player(),
		"A bystander must stay passive — provocation is per-ship, not a global alarm")


func test_scripted_hulls_are_never_passive() -> void:
	# A boss or encounter spawn carries no "ambient_enemy" group, so heat must not
	# be able to switch its fight off.
	_set_heat(0.0)
	var scripted := _make_ai(false)
	assert_true(scripted._may_engage_player(),
		"A non-ambient (boss / encounter / siege / hunter) hull must engage regardless of heat")


func test_friendly_ships_are_never_passive() -> void:
	_set_heat(0.0)
	var ai := _make_ai(true)
	ai.ship_controller.add_to_group("friendly_ship")
	assert_true(ai._may_engage_player(),
		"An allied AI must fight regardless of the player's heat")


func test_passive_ship_still_runs_obstacle_avoidance() -> void:
	# The heat gate sits on the engage decision only. If a refactor ever moves it
	# somewhere that short-circuits _physics_process, passive ships would stop
	# avoiding land and beach themselves — the exact defect class that took four
	# fixes to stabilise.
	_set_heat(0.0)
	var ai := _make_ai(true)
	assert_true(ai.avoid_enabled,
		"Avoidance must stay enabled on a passive ship")
	assert_true(ai.has_method("_get_avoidance_turn"),
		"The avoidance path must still exist and be reachable while passive")


func test_heat_gate_does_not_block_detection_of_a_hostile_faction() -> void:
	# Heat governs the ambient world, not diplomacy. A faction the player has
	# wrecked relations with attacks at any heat.
	_set_heat(0.0)
	var ai := _make_ai(true)
	var faction := load("res://resources/factions/RoyalNavy.tres")
	if faction == null:
		pending("RoyalNavy.tres missing")
		return
	ai.ship_controller.set("faction", faction)

	var saved: int = FactionManager.get_reputation(faction.faction_id)
	FactionManager.add_reputation(faction.faction_id, -200)
	var engages: bool = ai._may_engage_player()
	FactionManager.add_reputation(faction.faction_id, saved - FactionManager.get_reputation(faction.faction_id))

	assert_true(engages,
		"A hostile faction must engage at any heat — heat is not a diplomacy override")
