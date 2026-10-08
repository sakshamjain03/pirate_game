extends GutTest
## M30 Wave 1 (1.9, W1-2.1): the Spyglass Briefing. When an encounter starts it
## shows the roster as role icons, and — gated by the best owned Watchtower
## level — the formation, the weaknesses and the star-2 hint. The player picks
## an opening ammo per side and 1 of 3 Preparations; EncounterManager applies
## them to the player's ship for THIS battle only.
## Setup mirrors test_m30_stars.gd (MockPlayer/MockSpawner) with a real
## ShipCombat + CombatModifiers on the player.

const ENEMY_SCENE := "res://scenes/world/EnemyShip.tscn"
const RAKER := "res://resources/combat/ai_profiles/Raker.tres"
const RAIDER := "res://resources/combat/ai_profiles/HarassingSloop.tres"
const ROUND := "res://resources/combat/ammo/RoundShot.tres"
const CHAIN := "res://resources/combat/ammo/ChainShot.tres"
const GRAPE := "res://resources/combat/ammo/GrapeShot.tres"

class MockPlayer extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false

class MockSpawner extends Node:
	var spawning_enabled: bool = true
	var enemy_scene: PackedScene = null
	var _enemies_container: Node = null

class MockIslandData extends Resource:
	var owned := false
	func is_owned_by_player() -> bool:
		return owned

class MockIsland extends Node:
	var island_data: MockIslandData
	var watchtower := 0
	func get_building_level(base_id: String) -> int:
		return watchtower if base_id == "watchtower" else 0

var _root: Node
var _mgr: EncounterManager
var _player: MockPlayer
var _combat: ShipCombat
var _mods: CombatModifiers
var _created_test_scene: Node3D = null


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_root = Node.new()
	_root.name = "Systems"
	add_child_autoqfree(_root)
	var spawner := MockSpawner.new()
	spawner.name = "EnemySpawner"
	spawner._enemies_container = _root
	spawner.enemy_scene = load(ENEMY_SCENE)
	_root.add_child(spawner)
	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	_mgr.ambient_enabled = false
	_root.add_child(_mgr)

	_player = MockPlayer.new()
	_player.add_to_group("player_ship")
	_player.freeze = true
	var stats := ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 20.0
	stats.fire_rate = 0.5
	var dmg := ShipDamage.new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	_player.add_child(dmg)
	_mods = CombatModifiers.new()
	_mods.name = "CombatModifiers"
	_player.add_child(_mods)
	for marker_name in ["PortMarker1", "StarboardMarker1"]:
		var m := Node3D.new()
		m.name = marker_name
		_player.add_child(m)
	_combat = ShipCombat.new()
	_combat.name = "ShipCombat"
	_combat.ship_stats = stats
	_player.add_child(_combat)
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO
	_combat.set_ammo(load(ROUND))


func after_each() -> void:
	get_tree().paused = false
	_mgr.watchtower_level_override = -1
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _slot(profile_path: String) -> SquadSlotData:
	var s := SquadSlotData.new()
	s.hull_scene = load(ENEMY_SCENE)
	s.ai_profile = load(profile_path)
	return s


func _star(kind: int, target: float = 0.0) -> StarConditionData:
	var s := StarConditionData.new()
	s.condition = kind
	s.target_value = target
	return s


## A raker + a raider in a named pincer, with a star-2 of "win within 120 s".
func _encounter() -> EncounterData:
	var d := EncounterData.new()
	d.encounter_id = "spy_fight"
	d.display_name = "Spy Fight"
	d.objective = EncounterData.Objective.DESTROY_ALL
	d.squad = [_slot(RAKER), _slot(RAIDER)]
	var tactic := SquadTacticData.new()
	tactic.formation = SquadTacticData.Formation.PINCER
	tactic.display_name = "Jaws"
	tactic.slot_bearings_deg = [150.0, -90.0]
	d.squad_tactic = tactic
	d.star_conditions = [_star(StarConditionData.Condition.VICTORY),
		_star(StarConditionData.Condition.QUICK_VICTORY, 120.0)]
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	d.upgrade_offers = 0
	d.ambient_clear_radius = 0.0
	d.disengage_distance = 600.0
	return d


func _cfg() -> SpyglassBriefingData:
	return _mgr.get_briefing_config()


func _prep(id: String) -> PreparationData:
	for p in _cfg().preparations:
		if p.preparation_id == id:
			return p
	return null


func _fired_ball_ammo(side: String) -> AmmoData:
	var scene := get_tree().current_scene
	var before := scene.get_children()
	assert_true(_combat.fire_broadside(side), "%s broadside fires" % side)
	for c in scene.get_children():
		if not before.has(c) and "ammo" in c and c.ammo is AmmoData:
			var a: AmmoData = c.ammo
			c.queue_free()
			return a
	return null


# === Intel, gated by the Watchtower ===

func test_no_watchtower_shows_only_the_roster() -> void:
	_mgr.watchtower_level_override = 0
	assert_true(_mgr.start_encounter(_encounter()))
	var b := _mgr.build_briefing()
	assert_eq(b["intel_level"], 0)
	assert_eq(b["roster"].size(), 2, "one roster entry per hull")
	var roles: Array = b["roster"].map(func(r): return r["role"])
	roles.sort()
	assert_eq(roles, ["BALANCED", "RAIDER"])
	for r in b["roster"]:
		assert_eq(r["icon"], _cfg().role_icons[r["role"]], "role shown as its icon")
	assert_true(b["formation_locked"])
	assert_eq(b["formation"], "")
	assert_true(b["weaknesses_locked"])
	assert_eq(b["weaknesses"], [])
	assert_true(b["star_hint_locked"])
	assert_eq(b["star_hint"], "")


func test_each_watchtower_level_reveals_its_intel_line() -> void:
	assert_true(_mgr.start_encounter(_encounter()))
	var cfg := _cfg()

	_mgr.watchtower_level_override = cfg.formation_intel_level
	var b := _mgr.build_briefing()
	assert_false(b["formation_locked"])
	assert_eq(b["formation"], "Jaws", "formation named at its level")
	assert_eq(b["weaknesses_locked"], cfg.formation_intel_level < cfg.weakness_intel_level)

	_mgr.watchtower_level_override = cfg.weakness_intel_level
	b = _mgr.build_briefing()
	assert_false(b["weaknesses_locked"])
	assert_has(b["weaknesses"], cfg.tactic_weaknesses["STERN_RAKER"], "a raker's weakness is its tactic's")
	assert_has(b["weaknesses"], cfg.role_weaknesses["RAIDER"], "a STANDARD hull's weakness is its role's")

	_mgr.watchtower_level_override = cfg.star_hint_intel_level
	b = _mgr.build_briefing()
	assert_false(b["star_hint_locked"])
	assert_eq(b["star_hint"], "Win within 120 s", "the 2nd authored star condition")

	_mgr.watchtower_level_override = cfg.star_hint_intel_level - 1
	assert_true(_mgr.build_briefing()["star_hint_locked"], "one level short keeps it hidden")


func test_intel_comes_from_the_best_owned_watchtower() -> void:
	_mgr.watchtower_level_override = -1
	var levels := [[true, 1], [true, 3], [false, 5]]
	for spec in levels:
		var island := MockIsland.new()
		island.island_data = MockIslandData.new()
		island.island_data.owned = spec[0]
		island.watchtower = spec[1]
		island.add_to_group("islands")
		add_child_autoqfree(island)
	assert_eq(_mgr.get_watchtower_level(), 3, "best OWNED level; a rival's level 5 does not count")
	assert_true(_mgr.start_encounter(_encounter()))
	var b := _mgr.build_briefing()
	assert_eq(b["intel_level"], 3)
	assert_false(b["star_hint_locked"], "level 3 reaches the star hint")


func test_no_briefing_without_a_running_encounter() -> void:
	assert_eq(_mgr.build_briefing(), {})
	assert_false(_mgr.apply_briefing(_cfg().preparations[0], null, null))


# === The pick, applied ===

func test_three_authored_preparations_each_change_their_multiplier() -> void:
	var cfg := _cfg()
	assert_eq(cfg.preparations.size(), 3, "1 of 3 Preparations")
	var by_effect := {
		BattleUpgradeData.Effect.DAMAGE: "damage_mult",
		BattleUpgradeData.Effect.RELOAD_SPEED: "fire_rate_mult",
		BattleUpgradeData.Effect.SHIP_SPEED: "speed_mult",
	}
	var ids := {}
	for prep in cfg.preparations:
		assert_false(ids.has(prep.preparation_id), "unique id %s" % prep.preparation_id)
		ids[prep.preparation_id] = true
		assert_true(prep.effect.upgrade_id.begins_with("prep_"), "never stacks with an in-battle offer")
		assert_true(by_effect.has(prep.effect.effect), "%s has a tested effect" % prep.preparation_id)
		var field: String = by_effect[prep.effect.effect]

		assert_true(_mgr.start_encounter(_encounter()))
		assert_eq(float(_mods.get(field)), 1.0, "neutral before the pick")
		assert_true(_mgr.apply_briefing(prep, null, null))
		assert_almost_eq(float(_mods.get(field)), prep.effect.magnitude, 0.0001,
			"%s moves %s" % [prep.preparation_id, field])
		assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
		assert_eq(float(_mods.get(field)), 1.0, "%s lasts this battle only" % prep.preparation_id)


func test_a_preparation_the_briefing_does_not_offer_is_refused() -> void:
	assert_true(_mgr.start_encounter(_encounter()))
	var rogue := PreparationData.new()
	rogue.preparation_id = "rogue"
	rogue.effect = BattleUpgradeData.new()
	rogue.effect.magnitude = 3.0
	assert_false(_mgr.apply_briefing(rogue, null, null))
	assert_eq(_mods.damage_mult, 1.0, "nothing applied")


func test_opening_ammo_is_per_side_and_lasts_one_battle() -> void:
	assert_true(_mgr.start_encounter(_encounter()))
	var chain: AmmoData = load(CHAIN)
	var grape: AmmoData = load(GRAPE)
	assert_true(_mgr.apply_briefing(null, chain, grape))
	assert_eq(_fired_ball_ammo("port"), chain, "port guns open with chain shot")
	assert_eq(_fired_ball_ammo("starboard"), grape, "starboard guns open with grape shot")

	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_combat.get_ammo_for_side("port"), _combat.current_ammo, "cleared on resolve")
	assert_eq(_combat.get_ammo_for_side("starboard"), _combat.current_ammo)


func test_choosing_a_load_mid_fight_replaces_the_opening_loads() -> void:
	assert_true(_mgr.start_encounter(_encounter()))
	assert_true(_mgr.apply_briefing(null, load(CHAIN), load(GRAPE)))
	_combat.cycle_ammo()
	assert_eq(_combat.get_ammo_for_side("port"), _combat.current_ammo)
	assert_eq(_combat.get_ammo_for_side("starboard"), _combat.current_ammo)


# === The screen ===

func test_the_briefing_opens_on_encounter_start_and_engage_applies_the_pick() -> void:
	var screen := SpyglassBriefing.new()
	add_child_autoqfree(screen)
	screen.bind_encounter_manager(_mgr)
	_mgr.watchtower_level_override = 0
	assert_false(screen.visible)

	assert_true(_mgr.start_encounter(_encounter()))
	assert_true(screen.visible, "opens on encounter_started")
	assert_true(get_tree().paused, "the squad does not close in while the player reads")
	assert_string_contains(screen._roster.text, _cfg().role_icons["RAIDER"])
	assert_string_contains(screen._formation.text, "Watchtower Lv %d" % _cfg().formation_intel_level,
		"locked lines say which level reveals them")
	assert_eq(screen._prep_buttons.size(), 3, "three Preparation cards")

	var pick: PreparationData = _cfg().preparations[1]
	screen.select_preparation(1)
	screen.cycle_ammo("port")  # round -> chain
	screen.confirm()
	assert_false(screen.visible)
	assert_false(get_tree().paused, "Engage unpauses")
	assert_has(_mods.get_applied_upgrades(), pick.effect, "the chosen Preparation is on the ship")
	assert_eq(_combat.get_ammo_for_side("port").resource_path, CHAIN)
	assert_eq(_combat.get_ammo_for_side("starboard").resource_path, ROUND, "untouched side keeps its load")


func test_full_intel_fills_every_line() -> void:
	var screen := SpyglassBriefing.new()
	add_child_autoqfree(screen)
	screen.bind_encounter_manager(_mgr)
	_mgr.watchtower_level_override = 5
	assert_true(_mgr.start_encounter(_encounter()))
	assert_string_contains(screen._formation.text, "Jaws")
	assert_string_contains(screen._weaknesses.text, _cfg().tactic_weaknesses["STERN_RAKER"])
	assert_string_contains(screen._star_hint.text, "Win within 120 s")
	screen.confirm()


func test_a_fight_that_ends_while_open_closes_it() -> void:
	var screen := SpyglassBriefing.new()
	add_child_autoqfree(screen)
	screen.bind_encounter_manager(_mgr)
	assert_true(_mgr.start_encounter(_encounter()))
	assert_true(screen.visible)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.ESCAPED))
	assert_false(screen.visible)
	assert_false(get_tree().paused)


func test_freeing_the_screen_while_open_never_leaves_the_game_paused() -> void:
	var screen := SpyglassBriefing.new()
	add_child(screen)
	screen.bind_encounter_manager(_mgr)
	assert_true(_mgr.start_encounter(_encounter()))
	assert_true(get_tree().paused)
	remove_child(screen)  # the World unloading under an open briefing
	screen.free()
	assert_false(get_tree().paused)
