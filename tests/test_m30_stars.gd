extends GutTest
## M30 Wave 1 (1.13): Sortie Stars. An encounter awards 1–3 cosmetic stars for
## meeting authored conditions. Conditions evaluate on resolve from what really
## happened in THIS battle (hits on the player's ShipDamage, elapsed time), the
## count is emitted (`stars_awarded`), shown in the result announcement and
## kept as the best per encounter in CampaignManager's save, which is JSON. No
## campaign gate ever reads them.

const ENEMY_SCENE := "res://scenes/world/EnemyShip.tscn"
const ROUND_SHOT := "res://resources/combat/ammo/RoundShot.tres"
const ENCOUNTER_DIR := "res://resources/combat/encounters"

class MockPlayer extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false

class MockSpawner extends Node:
	var spawning_enabled: bool = true
	var enemy_scene: PackedScene = null
	var _enemies_container: Node = null

class MockHud extends Node:
	var announced: Array = []
	func announce_event(text: String) -> void:
		announced.append(text)

var _root: Node
var _mgr: EncounterManager
var _player: MockPlayer
var _dmg: ShipDamage
var _hud: MockHud
var _created_test_scene: Node3D = null
var _saved_campaign: Dictionary
var _awarded: Array = []


func before_each() -> void:
	_saved_campaign = CampaignManager.get_save_data().duplicate(true)
	CampaignManager._encounter_best_stars.clear()
	_awarded.clear()
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
	_mgr.stars_awarded.connect(func(id, n, total): _awarded.append([id, n, total]))
	_hud = MockHud.new()
	_hud.add_to_group("hud")
	add_child_autoqfree(_hud)
	_player = MockPlayer.new()
	_player.add_to_group("player_ship")
	_player.freeze = true
	_dmg = ShipDamage.new()
	_dmg.name = "ShipDamage"
	var stats := ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 20.0
	_dmg.ship_stats = stats
	_player.add_child(_dmg)
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO


func after_each() -> void:
	if is_instance_valid(_mgr) and _mgr.stars_awarded.is_connected(CampaignManager._on_stars_awarded):
		_mgr.stars_awarded.disconnect(CampaignManager._on_stars_awarded)
	if is_instance_valid(_mgr) and _mgr.ship_destroyed.is_connected(CampaignManager._on_ship_destroyed):
		_mgr.ship_destroyed.disconnect(CampaignManager._on_ship_destroyed)
	CampaignManager.load_save_data(_saved_campaign)
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _encounter(id: String = "star_fight") -> EncounterData:
	var d := EncounterData.new()
	d.encounter_id = id
	d.display_name = "Star Fight"
	d.objective = EncounterData.Objective.DESTROY_ALL
	d.enemy_scene = load(ENEMY_SCENE)
	d.enemy_count = 1
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	d.upgrade_offers = 0
	d.ambient_clear_radius = 0.0
	d.disengage_distance = 600.0
	return d


func _star_condition(kind: int, target: float = 0.0) -> StarConditionData:
	var s := StarConditionData.new()
	s.condition = kind
	s.target_value = target
	return s


func _hit(amount: float) -> void:
	_dmg.apply_hit(amount, load(ROUND_SHOT), Vector3.RIGHT)


# === Evaluation, from what really happened ===

func test_each_condition_kind_evaluates() -> void:
	var d := _encounter()
	d.star_conditions = [
		_star_condition(StarConditionData.Condition.VICTORY),
		_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0),
		_star_condition(StarConditionData.Condition.PERFECT_DEFENSE),
		_star_condition(StarConditionData.Condition.ZERO_LOSSES),
	]
	assert_true(_mgr.start_encounter(d))
	_mgr._tick_active(1.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 4, "a clean, quick win earns every condition")


func test_quick_victory_reads_the_battle_clock() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0)]
	assert_true(_mgr.start_encounter(d))
	_mgr._tick_active(25.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "won at 25 s, inside 30 s")

	var d2 := _encounter("slow_fight")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0)]
	assert_true(_mgr.start_encounter(d2))
	_mgr._tick_active(20.0)
	_mgr._tick_active(15.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "won at 35 s, outside 30 s; the clock restarted per battle")


func test_a_real_hit_during_the_battle_loses_perfect_defense() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE)]
	assert_true(_mgr.start_encounter(d))
	_hit(10.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "a cannon hit this battle costs the star")


func test_perfect_defense_ignores_max_hull_boosts_and_old_damage() -> void:
	# A captain's health bonus lifts the effective max above ShipStats.max_health:
	# a hit must still count, even though hull stays above the base max.
	var cap := CaptainData.new()
	cap.base_health_modifier = 1.5
	_player.active_captain = cap
	_dmg.hull = _dmg.get_effective_max_health()
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE)]
	assert_true(_mgr.start_encounter(d))
	_hit(10.0)
	assert_gt(_dmg.hull, 100.0, "precondition: hull still above the base max")
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "boosted hull: the hit still counts")

	# Damage from before the battle is not this battle's damage.
	_player.active_captain = null
	_dmg.hull = 40.0
	var d2 := _encounter("came_in_hurt")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE)]
	assert_true(_mgr.start_encounter(d2))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "started damaged, took nothing: star earned")


func test_crew_lost_in_a_collision_loses_zero_losses() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.ZERO_LOSSES)]
	assert_true(_mgr.start_encounter(d))
	_dmg.apply_impact(10.0, 0.5)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "crew lost this battle")

	var d2 := _encounter("clean")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.ZERO_LOSSES)]
	assert_true(_mgr.start_encounter(d2))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "the last battle's losses do not carry over")


func test_hits_after_the_battle_are_not_tracked() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE)]
	assert_true(_mgr.start_encounter(d))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	_hit(10.0)
	assert_eq(_mgr._player_damage_taken, 0.0, "the hit_resolved hook is dropped on resolve")


func test_stars_only_awarded_on_victory() -> void:
	var d := _encounter("no_victory")
	d.star_conditions = [_star_condition(StarConditionData.Condition.VICTORY)]
	assert_true(_mgr.start_encounter(d))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.DEFEAT))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "no stars on defeat")

	var d2 := _encounter("escaped")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.VICTORY)]
	assert_true(_mgr.start_encounter(d2))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.ESCAPED))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "no stars on escape")
	assert_eq(_awarded.size(), 0, "stars_awarded is a victory-only signal")


# === Emitted, shown, recorded ===

func test_victory_emits_stars_and_shows_them_in_the_result() -> void:
	var d := _encounter("shown")
	d.star_conditions = [
		_star_condition(StarConditionData.Condition.VICTORY),
		_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0),
		_star_condition(StarConditionData.Condition.PERFECT_DEFENSE),
	]
	assert_true(_mgr.start_encounter(d))
	_hit(5.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_awarded, [["shown", 2, 3]])
	var result: String = _hud.announced.back()
	assert_string_contains(result, "VICTORY")
	assert_string_contains(result, "★★☆", "the result popup shows 2 of 3 stars")
	assert_string_contains(result, "2/3")


func test_campaign_records_the_best_from_the_encounter_signal() -> void:
	CampaignManager._connect_encounter_manager(_mgr)
	var d := _encounter("recorded")
	d.star_conditions = [
		_star_condition(StarConditionData.Condition.VICTORY),
		_star_condition(StarConditionData.Condition.PERFECT_DEFENSE),
	]
	assert_true(_mgr.start_encounter(d))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(CampaignManager.get_encounter_best_stars("recorded"), 2, "recorded via stars_awarded")
	assert_string_contains(_hud.announced.back(), "2 ★ total",
		"the result shows the cosmetic total, this result included")

	# A worse clear later never lowers it.
	assert_true(_mgr.start_encounter(d))
	_hit(10.0)
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(CampaignManager.get_encounter_best_stars("recorded"), 2, "best kept across a worse result")


func test_best_is_kept_and_a_zero_never_erases_it() -> void:
	CampaignManager.record_encounter_stars("a", 3)
	CampaignManager.record_encounter_stars("a", 1)
	CampaignManager.record_encounter_stars("a", 0)
	assert_eq(CampaignManager.get_encounter_best_stars("a"), 3)
	CampaignManager.record_encounter_stars("b", 1)
	CampaignManager.record_encounter_stars("b", 2)
	assert_eq(CampaignManager.get_encounter_best_stars("b"), 2, "a better result raises it")
	assert_eq(CampaignManager.get_total_stars(), 5, "cosmetic total = sum of bests")


# === Persisted (omitted when empty) ===

func test_best_stars_survive_a_json_save_round_trip() -> void:
	CampaignManager.record_encounter_stars("ambush", 3)
	CampaignManager.record_encounter_stars("convoy_raid", 1)
	var data := JSON.parse_string(JSON.stringify(CampaignManager.get_save_data())) as Dictionary
	CampaignManager._encounter_best_stars.clear()
	CampaignManager.load_save_data(data)
	assert_eq(CampaignManager.get_encounter_best_stars("ambush"), 3)
	assert_eq(CampaignManager.get_encounter_best_stars("convoy_raid"), 1)
	assert_eq(typeof(CampaignManager._encounter_best_stars["ambush"]), TYPE_INT, "coerced back to int")
	assert_eq(CampaignManager.get_total_stars(), 4)


func test_save_omits_the_section_when_no_stars() -> void:
	assert_false(CampaignManager.get_save_data().has("encounter_best_stars"), "no section when empty")
	CampaignManager.record_encounter_stars("x", 0)
	assert_false(CampaignManager.get_save_data().has("encounter_best_stars"), "a 0-star result writes nothing")
	CampaignManager.record_encounter_stars("x", 1)
	assert_true(CampaignManager.get_save_data().has("encounter_best_stars"))


func test_malformed_saved_entries_are_dropped_not_kept_as_junk() -> void:
	CampaignManager.load_save_data({"encounter_best_stars": {
		"good": 2.0, "junk": ["<Resource#-9223372011571509947>"], "word": "three"}})
	assert_eq(CampaignManager.get_encounter_best_stars("good"), 2)
	assert_false(CampaignManager._encounter_best_stars.has("junk"))
	assert_false(CampaignManager._encounter_best_stars.has("word"))


# === Authored content ===

func test_every_authored_encounter_awards_one_to_three_stars() -> void:
	var checked := 0
	for f in DirAccess.get_files_at(ENCOUNTER_DIR):
		if not f.ends_with(".tres"):
			continue
		var e := load(ENCOUNTER_DIR.path_join(f)) as EncounterData
		if not e:
			continue
		checked += 1
		assert_between(e.star_conditions.size(), 1, 3, "%s authors 1-3 star conditions" % f)
		# Worst possible win still earns at least one star; a perfect one earns all.
		_mgr._battle_elapsed = 1.0e6
		_mgr._player_damage_taken = 1.0e6
		_mgr._player_crew_lost = 1.0e6
		assert_gte(_mgr._evaluate_stars(e).size(), 1, "%s: any victory earns a star" % f)
		_mgr._battle_elapsed = 0.0
		_mgr._player_damage_taken = 0.0
		_mgr._player_crew_lost = 0.0
		assert_eq(_mgr._evaluate_stars(e).size(), e.star_conditions.size(), "%s: every star reachable" % f)
	assert_gt(checked, 0)


# === Never a gate ===

## Star state may only be read by the star system itself (and the briefing's
## hint). Campaign gating (chapters, objectives, encounter eligibility) must
## never reference it.
func test_no_campaign_gate_reads_stars() -> void:
	var star_ids := RegEx.create_from_string("best_stars|total_stars|stars_awarded|star_conditions|StarCondition")
	var allowed := {
		"res://scripts/combat/EncounterManager.gd": true,
		"res://scripts/combat/EncounterData.gd": true,
		"res://scripts/combat/StarConditionData.gd": true,
		"res://scripts/managers/CampaignManager.gd": true,
	}
	var offenders: Array = []
	_scan("res://scripts", star_ids, allowed, offenders)
	assert_eq(offenders, [], "only the star system references stars")

	# Inside CampaignManager, only the star functions and save/load touch them.
	var cm := FileAccess.get_file_as_string("res://scripts/managers/CampaignManager.gd")
	var star_funcs := ["get_save_data", "load_save_data", "_connect_encounter_manager",
		"_on_stars_awarded", "record_encounter_stars", "get_encounter_best_stars",
		"get_total_stars", "_parse_best_stars"]
	var current := ""
	for line in cm.split("\n"):
		if line.begins_with("func "):
			current = line.trim_prefix("func ").split("(")[0]
		if current != "" and star_ids.search(line) and not star_funcs.has(current):
			offenders.append("CampaignManager.%s: %s" % [current, line.strip_edges()])
	assert_eq(offenders, [], "no chapter/objective function reads stars")


func _scan(dir_path: String, re: RegEx, allowed: Dictionary, offenders: Array) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub), re, allowed, offenders)
	for f in DirAccess.get_files_at(dir_path):
		if not f.ends_with(".gd"):
			continue
		var path := dir_path.path_join(f)
		if allowed.has(path):
			continue
		if re.search(FileAccess.get_file_as_string(path)):
			offenders.append(path)
