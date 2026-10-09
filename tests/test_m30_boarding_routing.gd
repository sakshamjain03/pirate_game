extends GutTest
## M30 Wave 2 (2.1): BoardingSystem.begin_boarding() routing and the shared
## _apply_outcome tail.
##   - Quick boarding (setting) and an overwhelming crew take the instant path.
##   - Anything else locks the target and emits boarding_started, resolving
##     nothing until resolve_tactical() is called by the overlay.
##   - boarding_resolved fires exactly once on every path (it has four listeners).
##   - LootTableData.roll(rng) is replayable.
## tests/test_boarding.gd and test_m29_boarding_loot_once.gd cover the unchanged
## attempt_boarding() path and must pass unmodified.

class MockShipParent extends RigidBody3D:
	pass

var _system: BoardingSystem
var _player: Node
var _enemy: Node
var _created_test_scene: Node3D = null
var _prev_quick: bool = false
var _prev_resources: Dictionary = {}


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_prev_quick = SettingsManager.quick_boarding
	SettingsManager.quick_boarding = false
	_prev_resources = ResourceManager.current_resources.duplicate()

	_system = BoardingSystem.new()
	var bd := BoardingData.new()
	var profile := BoardingDeckProfile.new()
	var foe := DefenderData.new()
	foe.hp = 4
	profile.defenders = [foe, foe, foe]
	bd.default_profile = profile
	_system.boarding_data = bd
	get_tree().current_scene.add_child(_system)

	_player = _make_ship(true, 100.0)
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 100.0)  # 120 vs 100: the player wins a comparison, nowhere near 3x
	_system._eligible_enemy = _enemy


func after_each() -> void:
	SettingsManager.quick_boarding = _prev_quick
	ResourceManager.current_resources = _prev_resources.duplicate()
	if is_instance_valid(_system):
		_system.free()
	for p in get_tree().get_nodes_in_group("player_ship"):
		if is_instance_valid(p): p.free()
	for e in get_tree().get_nodes_in_group("enemy_ship"):
		if is_instance_valid(e): e.free()
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.free()
	_created_test_scene = null


func _make_ship(is_player: bool, max_crew: float) -> Node:
	var parent := MockShipParent.new()
	parent.add_to_group("player_ship" if is_player else "enemy_ship")
	var stats := ShipStats.new()
	stats.max_crew = max_crew
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	get_tree().current_scene.add_child(parent)
	return parent


func _set_crews(player_crew: float, enemy_crew: float) -> void:
	_player.get_node("ShipDamage").crew = player_crew
	_enemy.get_node("ShipDamage").crew = enemy_crew


# === Routing ===

func test_quick_setting_takes_the_instant_path() -> void:
	SettingsManager.quick_boarding = true
	watch_signals(_system)
	assert_true(_system.begin_boarding())
	assert_signal_emitted_with_parameters(_system, "boarding_routed", ["quick"])
	assert_signal_not_emitted(_system, "boarding_started")
	assert_signal_emit_count(_system, "boarding_resolved", 1)
	assert_false(_system.is_boarding_active())


func test_overwhelming_crew_takes_the_instant_path() -> void:
	_set_crews(100.0, 20.0)  # 120 >= 3 x 20
	watch_signals(_system)
	assert_true(_system.begin_boarding())
	assert_signal_emitted_with_parameters(_system, "boarding_routed", ["overwhelm"])
	assert_signal_not_emitted(_system, "boarding_started")
	assert_signal_emit_count(_system, "boarding_resolved", 1)


func test_an_even_fight_locks_the_target_and_resolves_nothing() -> void:
	watch_signals(_system)
	assert_true(_system.begin_boarding())
	assert_signal_emit_count(_system, "boarding_started", 1)
	assert_signal_not_emitted(_system, "boarding_routed")
	assert_signal_not_emitted(_system, "boarding_resolved", "the battle has not been played")
	assert_true(_system.is_boarding_active())
	assert_same(_system._locked_enemy, _enemy)
	assert_false(_enemy.get_node("ShipDamage").is_destroyed())


func test_with_no_deck_profile_a_tactical_boarding_falls_back_to_the_instant_path() -> void:
	_system.boarding_data.default_profile = null
	watch_signals(_system)
	assert_true(_system.begin_boarding())
	assert_signal_not_emitted(_system, "boarding_started")
	assert_signal_emit_count(_system, "boarding_resolved", 1)


func test_a_tactical_boarding_builds_its_battle_from_the_deck() -> void:
	_system.begin_boarding()
	assert_not_null(_system.battle)
	assert_not_null(_system.deck)
	assert_eq(_system.battle.defenders.size(), 3)
	_system.resolve_tactical("colours", true)
	assert_null(_system.battle, "cleared with the lock")


func test_begin_is_refused_while_a_boarding_is_open_and_with_no_target() -> void:
	assert_true(_system.begin_boarding())
	assert_false(_system.begin_boarding(), "no second battle on top of the first")
	_system.cancel_boarding()
	assert_false(_system.is_boarding_active())
	_system._eligible_enemy = null
	assert_false(_system.begin_boarding(), "nothing in range to board")


func test_begin_refuses_an_already_destroyed_hull() -> void:
	_enemy.get_node("ShipDamage").hull = 0.0
	_enemy.get_node("ShipDamage").mark_destroyed()
	assert_false(_system.begin_boarding())
	assert_false(_system.is_boarding_active())


# === Tactical resolution ===

func test_a_won_battle_pays_out_through_the_shared_tail_once() -> void:
	_system.begin_boarding()
	watch_signals(_system)
	_system.resolve_tactical("colours", true)
	assert_signal_emit_count(_system, "boarding_resolved", 1)
	assert_signal_emit_count(_system, "boarding_outcome", 1)
	var args: Array = get_signal_parameters(_system, "boarding_outcome")
	assert_eq(args[0], "colours")
	assert_true(args[1]["success"])
	assert_same(args[1]["enemy"], _enemy)
	assert_true(_enemy.get_node("ShipDamage").is_destroyed(), "the beaten hull is destroyed via ShipDamage")
	assert_true(_enemy.get_meta("loot_claimed", false), "ShipController must not drop the loot a second time")
	assert_eq(_enemy.get_meta("boarding_outcome", ""), "colours", "the prize path (2.8) reads the outcome off the hull")
	assert_false(_system.is_boarding_active(), "the lock clears")
	assert_eq(_player.get_node("ShipDamage").crew, 90.0, "win crew-loss fraction of max crew")


func test_a_lost_battle_costs_crew_and_spares_the_enemy() -> void:
	_system.begin_boarding()
	watch_signals(_system)
	_system.resolve_tactical("cut_loose", false, {"crew_loss_fraction": 0.2})
	assert_signal_emit_count(_system, "boarding_resolved", 1)
	assert_signal_emit_count(_system, "boarding_outcome", 1)
	assert_signal_emitted_with_parameters(_system, "boarding_resolved", [false, {}, "", ""])
	assert_false(_enemy.get_node("ShipDamage").is_destroyed())
	assert_eq(_player.get_node("ShipDamage").crew, 80.0, "the details override the default loss")
	assert_false(_system.is_boarding_active())


func test_resolve_without_an_open_battle_does_nothing() -> void:
	watch_signals(_system)
	_system.resolve_tactical("colours", true)
	assert_signal_not_emitted(_system, "boarding_resolved")
	assert_false(_enemy.get_node("ShipDamage").is_destroyed())


func test_an_outcome_multiplier_scales_the_loot() -> void:
	ResourceManager.current_resources["gold"] = 0
	_system.begin_boarding()
	_system.resolve_tactical("hold", true, {"rng": _seeded(7), "loot_mult": 1.0})
	var plain: int = ResourceManager.current_resources["gold"]

	ResourceManager.current_resources["gold"] = 0
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 100.0)
	_system._eligible_enemy = _enemy
	_system.begin_boarding()
	_system.resolve_tactical("hold", true, {"rng": _seeded(7), "loot_mult": 2.0})
	var doubled: int = ResourceManager.current_resources["gold"]
	assert_gt(plain, 0, "precondition: the loot table paid gold")
	assert_gt(doubled, plain, "same seed, bigger multiplier, bigger payout")


# === Every path fires boarding_resolved exactly once ===

func test_every_path_fires_boarding_resolved_exactly_once() -> void:
	# instant: setting
	SettingsManager.quick_boarding = true
	watch_signals(_system)
	_system.begin_boarding()
	assert_signal_emit_count(_system, "boarding_resolved", 1, "quick")
	SettingsManager.quick_boarding = false

	# instant: overwhelm
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 20.0)
	_system._eligible_enemy = _enemy
	_system.begin_boarding()
	assert_signal_emit_count(_system, "boarding_resolved", 2, "overwhelm")

	# direct attempt (the pre-M30 API)
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 100.0)
	_system._eligible_enemy = _enemy
	_system.attempt_boarding()
	assert_signal_emit_count(_system, "boarding_resolved", 3, "attempt_boarding")

	# tactical
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 100.0)
	_system._eligible_enemy = _enemy
	_system.begin_boarding()
	_system.resolve_tactical("colours", true)
	_system.resolve_tactical("colours", true)  # a stray second call must not double-pay
	assert_signal_emit_count(_system, "boarding_resolved", 4, "tactical, even if resolved twice")
	assert_signal_emit_count(_system, "boarding_outcome", 4)


# === Seeded loot ===

func _seeded(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


func test_loot_roll_is_replayable_with_a_seed() -> void:
	var table: LootTableData = load("res://resources/loot/StandardEnemyLoot.tres")
	var a := table.roll(_seeded(42))
	var b := table.roll(_seeded(42))
	assert_eq(a, b, "same seed, same loot")
	var differs := false
	for s in range(1, 30):
		if table.roll(_seeded(s)) != a:
			differs = true
			break
	assert_true(differs, "different seeds do change the roll")


func test_loot_roll_without_a_seed_still_works() -> void:
	var table: LootTableData = load("res://resources/loot/StandardEnemyLoot.tres")
	var loot := table.roll()
	assert_true(loot is Dictionary)
	for k in loot:
		assert_gt(int(loot[k]), 0, "zero rolls are omitted, as before")


# === The setting ===

func test_quick_boarding_setting_defaults_off_and_round_trips() -> void:
	assert_false(SettingsManager.DEFAULT_QUICK_BOARDING, "Three Bells is the default")
	var prev_path: String = SettingsManager._settings_path
	SettingsManager._settings_path = "user://test_quick_boarding.cfg"
	SettingsManager.quick_boarding = true
	SettingsManager.save_settings()
	SettingsManager.quick_boarding = false
	SettingsManager.load_settings()
	assert_true(SettingsManager.quick_boarding, "persisted under [gameplay]")
	SettingsManager._settings_path = prev_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_quick_boarding.cfg"))
