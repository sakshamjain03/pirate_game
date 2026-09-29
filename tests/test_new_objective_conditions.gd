extends GutTest

# test_new_objective_conditions.gd
# M28 Task 6 — the seven ObjectiveData.Condition values appended after
# SURVIVE_RAID, each tracked by CampaignManager from a signal, and each only
# while its chapter is current. Also pins every existing chapter objective's
# condition INT: Condition is int-serialized in the .tres files, so an inserted
# (rather than appended) value would silently re-target them all.

class FakeAI extends Node:
	var provoked := false
	func is_provoked() -> bool:
		return provoked

class MockEnemy extends Node3D:
	var faction: Resource = null

## Every shipped/authored chapter objective's condition int, captured from the
## .tres files immediately BEFORE M28 appended its values (2026-09-30).
const EXISTING_CONDITION_INTS := {
	"1.1": 8, "1.2": 6, "1.3": 0, "1.4": 0, "1.5": 0, "1.6": 3, "1.7": 0, "1.8": 9, "1.9": 2,
	"2.1": 3, "2.2": 0, "2.3": 10, "2.4": 4, "2.5": 0, "2.6": 2, "2.7": 6, "2.8": 12,
	"3.1": 3, "3.2": 0, "3.3": 0, "3.4": 14, "3.5": 10, "3.6": 2, "3.7": 4,
	"4.1": 7, "4.2": 3, "4.3": 0, "4.4": 11, "4.5": 10, "4.6": 5, "4.7": 6, "4.8": 4,
	"5.1": 8, "5.2": 3, "5.3": 10, "5.4": 2, "5.5": 5, "5.6": 6, "5.7": 4, "5.8": 10,
	"6.1": 7, "6.2": 3, "6.3": 8, "6.4": 13, "6.5": 4,
	"7.1": 3, "7.2": 6, "7.3": 13, "7.4": 4,
	"9.1": 3, "9.2": 13, "9.3": 4,
	"10.1": 3, "10.2": 2, "10.3": 12, "10.4": 4,
}
const CHAPTERS_DIR := "res://resources/campaign/chapters/"

var _saved_chapters: Array
var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _saved_heat_level: int
var _saved_ammo_id: String
var _saved_crippled: Dictionary
var _saved_docking: Node
var _saved_ship_index: int
var _saved_captain_index: int
var _saved_rep: Dictionary


func before_each():
	_saved_chapters = CampaignManager.chapters.duplicate()
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	_saved_heat_level = CampaignManager._last_heat_level
	_saved_ammo_id = CampaignManager._player_ammo_id
	_saved_crippled = CampaignManager._crippled_ship_ids.duplicate()
	_saved_docking = CampaignManager._docking_system
	_saved_ship_index = FleetManager.active_ship_index
	_saved_captain_index = FleetManager.active_captain_index
	_saved_rep = FactionManager.reputation_scores.duplicate()

	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	CampaignManager._crippled_ship_ids.clear()


func after_each():
	CampaignManager.chapters = _saved_chapters.duplicate()
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	CampaignManager._last_heat_level = _saved_heat_level
	CampaignManager._player_ammo_id = _saved_ammo_id
	CampaignManager._crippled_ship_ids = _saved_crippled.duplicate()
	CampaignManager._docking_system = _saved_docking
	FleetManager.active_ship_index = _saved_ship_index
	FleetManager.active_captain_index = _saved_captain_index
	FactionManager.reputation_scores = _saved_rep.duplicate()


func _objective(id: String, condition: int, target_id := "", count := 1, value := 0.0) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.condition = condition
	o.target_id = target_id
	o.target_count = count
	o.target_value = value
	return o


## ch1 holds the objective under test plus a pending anchor (so the chapter
## never completes mid-test); ch2 holds the same condition, gated behind ch1,
## to prove a non-current chapter's objective never progresses.
func _start(objective: ObjectiveData) -> void:
	var anchor := _objective("anchor", ObjectiveData.Condition.DOCK_AT_ISLAND, "nowhere")
	var ch1 := ChapterData.new()
	ch1.chapter_id = "ch1"
	ch1.chapter_number = 1
	var ch1_objectives: Array[ObjectiveData] = [objective, anchor]
	ch1.objectives = ch1_objectives
	var ch2 := ChapterData.new()
	ch2.chapter_id = "ch2"
	ch2.chapter_number = 2
	ch2.required_previous_chapter = "ch1"
	var twin := objective.duplicate() as ObjectiveData
	twin.objective_id = "later." + objective.objective_id
	var ch2_objectives: Array[ObjectiveData] = [twin]
	ch2.objectives = ch2_objectives
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager._catch_up()


func _done(id: String) -> bool:
	return CampaignManager._completed_objective_ids.has(id)


func _later_progress(id: String) -> int:
	return int(CampaignManager._objective_progress.get("later." + id, 0))


# === Enum stability ===

func test_new_conditions_are_appended_after_survive_raid():
	assert_eq(ObjectiveData.Condition.SURVIVE_RAID, 14, "existing values keep their integers")
	assert_eq(ObjectiveData.Condition.SWAP_AMMO, 15)
	assert_eq(ObjectiveData.Condition.CRIPPLE_SAILS, 16)
	assert_eq(ObjectiveData.Condition.LOWER_HEAT, 17)
	assert_eq(ObjectiveData.Condition.ASSIGN_CAPTAIN, 18)
	assert_eq(ObjectiveData.Condition.CHANGE_REPUTATION, 19)
	assert_eq(ObjectiveData.Condition.SET_COURSE, 20)
	assert_eq(ObjectiveData.Condition.REPAIR_SHIP, 21)


func test_every_existing_chapter_objective_still_resolves_the_same_condition():
	var found := {}
	var dir := DirAccess.open(CHAPTERS_DIR)
	assert_not_null(dir)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var chapter := load(CHAPTERS_DIR + file_name) as ChapterData
		for o in chapter.objectives:
			if EXISTING_CONDITION_INTS.has(o.objective_id):
				found[o.objective_id] = true
				assert_eq(int(o.condition), EXISTING_CONDITION_INTS[o.objective_id],
					"objective %s must keep condition %d" % [o.objective_id, EXISTING_CONDITION_INTS[o.objective_id]])
	assert_eq(found.size(), EXISTING_CONDITION_INTS.size(),
		"every pre-M28 objective id must still exist (ids are never renumbered)")


# === SWAP_AMMO ===

func test_swap_ammo_counts_a_swap_to_the_target_ammo():
	_start(_objective("1.10", ObjectiveData.Condition.SWAP_AMMO, "chain"))
	CampaignManager._player_ammo_id = "round"
	CampaignManager._on_player_ammo_changed(load("res://resources/combat/ammo/GrapeShot.tres"))
	assert_false(_done("1.10"), "grape is not the target")
	CampaignManager._on_player_ammo_changed(load("res://resources/combat/ammo/ChainShot.tres"))
	assert_true(_done("1.10"))
	assert_eq(_later_progress("1.10"), 0, "a later chapter's objective never progresses")


func test_swap_ammo_ignores_setting_the_ammo_already_loaded():
	## set_ammo() also runs on load/ship swap; re-setting the same shot is not a swap.
	_start(_objective("1.10", ObjectiveData.Condition.SWAP_AMMO, "chain"))
	CampaignManager._player_ammo_id = "chain"
	CampaignManager._on_player_ammo_changed(load("res://resources/combat/ammo/ChainShot.tres"))
	assert_false(_done("1.10"))


func test_swap_ammo_is_seeded_from_the_loaded_ammo_at_world_ready():
	var ship := Node3D.new()
	ship.add_to_group("player_ship")
	var combat: Node = load("res://scripts/world/ShipCombat.gd").new()
	combat.name = "ShipCombat"
	combat.current_ammo = load("res://resources/combat/ammo/ChainShot.tres")
	ship.add_child(combat)
	add_child_autoqfree(ship)
	CampaignManager._connect_player_ship()
	assert_eq(CampaignManager._player_ammo_id, "chain")
	assert_true(combat.ammo_changed.is_connected(CampaignManager._on_player_ammo_changed))


# === CRIPPLE_SAILS ===

func _enemy(provoked: bool) -> MockEnemy:
	var enemy := MockEnemy.new()
	var faction := FactionData.new()
	faction.faction_id = "pirate_clans"
	enemy.faction = faction
	var damage := ShipDamage.new()
	damage.name = "ShipDamage"
	enemy.add_child(damage)
	var ai := FakeAI.new()
	ai.name = "EnemyAI"
	ai.provoked = provoked
	enemy.add_child(ai)
	return enemy


func test_cripple_sails_counts_a_provoked_enemy_once():
	_start(_objective("2.9", ObjectiveData.Condition.CRIPPLE_SAILS, "pirate_clans", 2))
	var enemy := _enemy(true)
	add_child_autoqfree(enemy)
	CampaignManager._watch_enemy(enemy)
	var damage: ShipDamage = enemy.get_node("ShipDamage")
	damage.pool_changed.emit("sails", 10.0, 50.0)
	assert_eq(int(CampaignManager._objective_progress.get("2.9", 0)), 0, "sails not yet at zero")
	damage.pool_changed.emit("sails", 0.0, 50.0)
	damage.pool_changed.emit("sails", 0.0, 50.0)
	assert_eq(int(CampaignManager._objective_progress.get("2.9", 0)), 1, "one ship counts once")
	assert_eq(_later_progress("2.9"), 0)


func test_cripple_sails_ignores_an_enemy_the_player_never_fought():
	_start(_objective("2.9", ObjectiveData.Condition.CRIPPLE_SAILS))
	var enemy := _enemy(false)
	add_child_autoqfree(enemy)
	CampaignManager._watch_enemy(enemy)
	enemy.get_node("ShipDamage").pool_changed.emit("sails", 0.0, 50.0)
	assert_false(_done("2.9"))


func test_cripple_sails_watches_enemies_that_enter_the_tree_later():
	## Island defenders and encounter ships have no spawn signal CampaignManager
	## can use; the "enemy_ship" group + node_added catches all of them.
	if not get_tree().node_added.is_connected(CampaignManager._on_node_added):
		get_tree().node_added.connect(CampaignManager._on_node_added)
	_start(_objective("2.9", ObjectiveData.Condition.CRIPPLE_SAILS))
	var enemy := _enemy(true)
	enemy.add_to_group("enemy_ship")
	add_child_autoqfree(enemy)
	await wait_process_frames(1)
	enemy.get_node("ShipDamage").pool_changed.emit("sails", 0.0, 50.0)
	assert_true(_done("2.9"))


# === LOWER_HEAT ===

func test_lower_heat_completes_on_a_downward_tier_crossing_only():
	_start(_objective("3.8", ObjectiveData.Condition.LOWER_HEAT))
	CampaignManager._last_heat_level = 1
	var up := HeatTierData.new()
	up.tier = 2
	CampaignManager._on_heat_tier_changed(up)
	assert_false(_done("3.8"), "rising heat is not lowering it")
	var down := HeatTierData.new()
	down.tier = 1
	CampaignManager._on_heat_tier_changed(down)
	assert_true(_done("3.8"))
	assert_eq(_later_progress("3.8"), 0)


# === ASSIGN_CAPTAIN ===

func test_assign_captain_needs_a_captain():
	_start(_objective("3.9", ObjectiveData.Condition.ASSIGN_CAPTAIN))
	FleetManager.active_ship_changed.emit(null, null)
	assert_false(_done("3.9"))
	FleetManager.active_ship_changed.emit(null, CaptainData.new())
	assert_true(_done("3.9"))
	assert_eq(_later_progress("3.9"), 0)


func test_set_active_ship_emits_active_ship_changed():
	## The signal was declared but never emitted: IslandMenu wrote the indices
	## directly. set_active_ship() is now the one write path.
	watch_signals(FleetManager)
	FleetManager.set_active_ship(0)
	assert_signal_emitted(FleetManager, "active_ship_changed")
	assert_eq(FleetManager.active_ship_index, 0)


# === CHANGE_REPUTATION ===

func test_change_reputation_completes_at_the_threshold_for_its_faction():
	_start(_objective("4.10", ObjectiveData.Condition.CHANGE_REPUTATION, "merchant_guild", 1, 35.0))
	FactionManager.reputation_changed.emit("royal_navy", 90)
	assert_false(_done("4.10"), "another faction's standing does not count")
	FactionManager.reputation_changed.emit("merchant_guild", 30)
	assert_false(_done("4.10"))
	FactionManager.reputation_changed.emit("merchant_guild", 35)
	assert_true(_done("4.10"))


func test_change_reputation_is_reachable_by_one_real_tribute():
	## Content check: merchant rep starts at 20, one tribute adds
	## TRIBUTE_REPUTATION_GAIN — 4.10's authored threshold must be within reach.
	assert_true(20 + FactionManager.TRIBUTE_REPUTATION_GAIN >= 35)


# === SET_COURSE ===

func test_set_course_counts_the_target_island():
	_start(_objective("4.9", ObjectiveData.Condition.SET_COURSE, "pelican_cay"))
	var other := IslandData.new()
	other.island_id = "tortuga"
	CampaignManager._on_course_requested(other)
	assert_false(_done("4.9"))
	var cay := IslandData.new()
	cay.island_id = "pelican_cay"
	CampaignManager._on_course_requested(cay)
	assert_true(_done("4.9"))
	assert_eq(_later_progress("4.9"), 0)


# === REPAIR_SHIP ===

func _player_damage() -> ShipDamage:
	var damage := ShipDamage.new()
	var stats := ShipStats.new()
	stats.max_health = 100.0
	damage.ship_stats = stats
	damage.hull = 40.0
	autoqfree(damage)
	damage.repaired.connect(CampaignManager._on_player_repaired)
	return damage


func _docked(is_docked: bool) -> void:
	var docking := DockingSystem.new()
	autoqfree(docking)
	docking.current_state = DockingSystem.DockState.DOCKED if is_docked else DockingSystem.DockState.FREE
	CampaignManager._docking_system = docking


func test_repair_ship_counts_a_repair_while_docked():
	_start(_objective("2.10", ObjectiveData.Condition.REPAIR_SHIP))
	_docked(true)
	_player_damage().repair("hull", 20.0)
	assert_true(_done("2.10"))
	assert_eq(_later_progress("2.10"), 0)


func test_repair_ship_ignores_a_repair_at_sea():
	_start(_objective("2.10", ObjectiveData.Condition.REPAIR_SHIP))
	_docked(false)
	_player_damage().repair("hull", 20.0)
	assert_false(_done("2.10"))


func test_repair_ship_ignores_buying_or_switching_a_ship():
	## A bought/swapped hull arrives via restore_all() — the hull rises while
	## docked, but that is not a repair.
	_start(_objective("2.10", ObjectiveData.Condition.REPAIR_SHIP))
	_docked(true)
	var damage := _player_damage()
	damage.restore_all()
	assert_eq(damage.hull, 100.0)
	assert_false(_done("2.10"))
