extends GutTest

# test_encounters.gd
# Slice 2 — the encounter lifecycle (docs/navalCombat.md §15/§16/§17).
# Before this, combat had no boundary at all: one continuous scene, an ambient
# spawner, and a kill that dropped a crate. These tests pin start → objective →
# victory/defeat/escape → rewards → back to the world.

class MockPlayer extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false

class MockSpawner extends Node:
	var spawning_enabled: bool = true
	var enemy_scene: PackedScene = null
	var _enemies_container: Node = null

var _root: Node
var _mgr: EncounterManager
var _spawner: MockSpawner
var _player: MockPlayer
var _resources_backup: Dictionary


func before_each():
	# ResourceManager is a real autoload whose current_resources accumulates
	# across the whole suite run — nothing resets it between test files. A
	# gold-reward assertion here can fail purely because an earlier file's
	# tests already pushed gold to its 5000 cap by the time this file runs,
	# independent of whether _grant_rewards() itself works. Force a known,
	# cap-safe starting state and restore whatever was there afterward — same
	# backup/restore discipline test_cold_start.gd/test_region_gates.gd
	# already use for SaveManager/EmpireManager.
	_resources_backup = ResourceManager.current_resources.duplicate()
	ResourceManager.current_resources = {"gold": 200, "wood": 50, "iron": 20, "rum": 10, "research": 0}

	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene

	_root = Node.new()
	_root.name = "Systems"
	add_child_autoqfree(_root)

	_spawner = MockSpawner.new()
	_spawner.name = "EnemySpawner"
	_spawner._enemies_container = _root
	_root.add_child(_spawner)

	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	# Ambient scheduling off by default: these tests drive start_encounter()
	# explicitly so nothing fires on a wall-clock timer mid-assertion.
	_mgr.ambient_enabled = false
	_root.add_child(_mgr)

	_player = MockPlayer.new()
	_player.add_to_group("player_ship")
	_player.freeze = true
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = _player_stats()
	_player.add_child(dmg)
	var mods = CombatModifiers.new()
	mods.name = "CombatModifiers"
	_player.add_child(mods)
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO


func after_each():
	ResourceManager.current_resources = _resources_backup


func _player_stats() -> ShipStats:
	var s = ShipStats.new()
	s.max_health = 100.0
	s.max_sails = 100.0
	s.max_crew = 20.0
	return s


func _encounter(count: int = 2, objective: int = EncounterData.Objective.DESTROY_ALL) -> EncounterData:
	var d = EncounterData.new()
	d.encounter_id = "test_fight"
	d.display_name = "Test Fight"
	d.kind = EncounterData.Kind.ENCOUNTER
	d.objective = objective
	d.objective_count = 1
	d.enemy_count = count
	d.enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	d.loot_table = load("res://resources/loot/StandardEnemyLoot.tres")
	d.bonus_gold = 100
	d.captain_xp = 25
	d.notoriety_reward = 3.0
	d.upgrade_offers = 2
	d.upgrade_interval = 0.05
	d.time_limit = 0.0
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	return d


func _pool() -> Array[BattleUpgradeData]:
	var out: Array[BattleUpgradeData] = []
	for f in ["HeavyVolley", "RapidReload", "EmergencyRepairs", "FullSail", "LongNines"]:
		out.append(load("res://resources/combat/upgrades/%s.tres" % f))
	return out


func _freeze_enemies() -> void:
	## No Ocean exists here, so BuoyancySimulator would shove spawned hulls
	## around and could drift them past the disengage radius mid-test.
	for e in _mgr._enemies:
		if is_instance_valid(e) and e is RigidBody3D:
			e.freeze = true


# === start / composition ===

func test_starting_an_encounter_spawns_its_composition_and_goes_active():
	var d = _encounter(3)
	watch_signals(_mgr)

	assert_true(_mgr.start_encounter(d), "start_encounter should succeed")
	assert_true(_mgr.is_active(), "The manager should report an active fight")
	assert_eq(_mgr._enemies.size(), 3, "The authored enemy_count must be spawned")
	assert_signal_emitted(_mgr, "encounter_started", "...and announce itself")

func test_an_encounter_pauses_ambient_spawning_and_restores_it_afterwards():
	## A DESTROY_ALL objective is unwinnable if a background spawner keeps
	## trickling hulls into the fight.
	assert_true(_spawner.spawning_enabled, "Precondition: ambient spawning is on")
	_mgr.start_encounter(_encounter(1))
	assert_false(_spawner.spawning_enabled, "Ambient spawning pauses during a fight")

	_mgr.abandon()
	assert_true(_spawner.spawning_enabled, "...and resumes once the fight is over")

func test_a_second_encounter_cannot_start_while_one_is_live():
	assert_true(_mgr.start_encounter(_encounter(1)))
	assert_false(_mgr.start_encounter(_encounter(1)),
		"Only one bounded fight at a time — otherwise 'the current battle' is meaningless")

func test_an_ambush_rings_the_player_instead_of_clustering_ahead():
	var d = _encounter(4)
	d.kind = EncounterData.Kind.AMBUSH
	_mgr.start_encounter(d)
	_freeze_enemies()

	# Spread of bearings should cover more than one quadrant for a ring.
	var angles: Array[float] = []
	for e in _mgr._enemies:
		var v: Vector3 = e.global_position - _player.global_position
		angles.append(atan2(v.z, v.x))
	assert_gt(angles.size(), 1, "Precondition: multiple attackers")
	var span: float = angles.max() - angles.min()
	assert_gt(span, PI * 0.5, "An ambush must surround the player, not queue up on one bearing")

func test_strength_multiplier_never_mutates_the_shared_ship_stats():
	## EnemySpawner's duplicate-never-mutate rule: a ShipStats resource is shared
	## by every hull of that class, so scaling it in place buffs the whole fleet
	## permanently.
	var shared: ShipStats = load("res://resources/enemies/EnemyShipStats.tres")
	var health_before: float = shared.max_health

	var d = _encounter(1)
	d.strength_multiplier = 3.0
	_mgr.start_encounter(d)

	assert_eq(shared.max_health, health_before,
		"The shared EnemyShipStats resource must be untouched")
	var enemy = _mgr._enemies[0]
	assert_almost_eq(enemy.ship_stats.max_health, health_before * 3.0, 0.01,
		"...while this encounter's hull is genuinely stronger")


# === objective / victory ===

func test_destroying_the_composition_wins_and_pays_out():
	var d = _encounter(2)
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))

	for e in _mgr._enemies.duplicate():
		e.get_node("ShipDamage").mark_destroyed()
		_mgr._on_encounter_enemy_destroyed(e)
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Sinking the whole composition ends the fight")
	assert_signal_emitted(_mgr, "encounter_ended", "...and emits the outcome")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_true(params[0], "The outcome must be a victory")
	assert_gt(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"Victory must actually credit the reward, not just report it")

func test_destroy_count_wins_early_without_sinking_everything():
	var d = _encounter(4, EncounterData.Objective.DESTROY_COUNT)
	d.objective_count = 2
	_mgr.start_encounter(d)
	_freeze_enemies()

	var first_two = _mgr._enemies.duplicate().slice(0, 2)
	for e in first_two:
		_mgr._on_encounter_enemy_destroyed(e)
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Two of four is enough for a DESTROY_COUNT objective")

func test_objective_progress_is_reported_as_kills_land():
	var d = _encounter(3, EncounterData.Objective.DESTROY_COUNT)
	d.objective_count = 3
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	_mgr._on_encounter_enemy_destroyed(_mgr._enemies[0])
	assert_signal_emitted(_mgr, "objective_progress", "Progress must be observable")

func test_captain_xp_is_awarded_on_victory():
	var cap = CaptainData.new()
	cap.captain_id = "test_cap"
	cap.level = 1
	cap.current_xp = 0
	FleetManager.owned_captains.append(cap)
	var prior_index: int = FleetManager.active_captain_index
	FleetManager.active_captain_index = FleetManager.owned_captains.size() - 1

	var d = _encounter(1)
	d.captain_xp = 40
	_mgr.start_encounter(d)
	_freeze_enemies()
	_mgr._on_encounter_enemy_destroyed(_mgr._enemies[0])
	await wait_process_frames(2)

	assert_gt(cap.current_xp + (cap.level - 1) * 100, 0,
		"A won fight must feed captain progression")

	FleetManager.owned_captains.erase(cap)
	FleetManager.active_captain_index = prior_index


# === defeat / escape ===

func test_losing_the_player_ship_ends_the_fight_as_a_defeat():
	watch_signals(_mgr)
	_mgr.start_encounter(_encounter(2))
	_freeze_enemies()

	_player.get_node("ShipDamage").mark_destroyed()
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "A sunk player ends the fight")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_false(params[0], "...as a defeat, not a victory")
	assert_true(params[1].is_empty(), "Defeat pays nothing")

func test_defeat_leaves_permanent_progression_alone():
	## docs/navalCombat.md §17: "try a better strategy", never "you lost 3 hours".
	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()
	_player.get_node("ShipDamage").mark_destroyed()
	await wait_process_frames(2)
	assert_eq(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"Losing an encounter must not confiscate resources")

func test_sailing_far_enough_away_for_long_enough_breaks_off_the_fight():
	var d = _encounter(2)
	d.disengage_distance = 100.0
	d.disengage_grace = 0.05
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	_player.global_position = Vector3(500, 0, 0)
	await wait_seconds(0.3)

	assert_false(_mgr.is_active(), "Breaking off is a legitimate tactical choice")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_false(params[0], "An escape is not a victory")

func test_briefly_straying_outside_the_radius_does_not_end_the_fight():
	var d = _encounter(2)
	d.disengage_distance = 100.0
	d.disengage_grace = 30.0
	_mgr.start_encounter(d)
	_freeze_enemies()

	_player.global_position = Vector3(500, 0, 0)
	await wait_process_frames(3)
	_player.global_position = Vector3.ZERO
	await wait_process_frames(3)

	assert_true(_mgr.is_active(),
		"The grace period exists so a wide turn is not mistaken for fleeing")

func test_protect_target_resolves_defeat_when_the_escort_sinks_first():
	## Slice 5: PROTECT_TARGET previously just aliased DESTROY_ALL — there was no
	## actual escorted hull, so it could never be lost this way.
	var d = _encounter(2, EncounterData.Objective.PROTECT_TARGET)
	d.escort_scene = load("res://scenes/world/EnemyShip.tscn")
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	assert_not_null(_mgr._protect_target, "An escort must actually be spawned")
	_mgr._protect_target.get_node("ShipDamage").mark_destroyed()
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Losing the escort ends the fight")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_false(params[0], "...as a defeat, even though the raiders are still afloat")

func test_protect_target_resolves_victory_when_the_raiders_die_first():
	var d = _encounter(1, EncounterData.Objective.PROTECT_TARGET)
	d.escort_scene = load("res://scenes/world/EnemyShip.tscn")
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	_mgr._on_encounter_enemy_destroyed(_mgr._enemies[0])
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Clearing the raiders ends the fight")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_true(params[0], "...as a victory, with the escort still alive")

func test_the_escort_never_fights_back_and_is_not_the_players_own_auto_fire_target():
	var d = _encounter(1, EncounterData.Objective.PROTECT_TARGET)
	d.escort_scene = load("res://scenes/world/EnemyShip.tscn")
	_mgr.start_encounter(d)
	_freeze_enemies()

	var escort = _mgr._protect_target
	assert_true(escort.is_in_group("friendly_ship"),
		"The escort must read as friendly to FiringSolver.are_hostile()")
	assert_false(escort.is_in_group("enemy_ship"),
		"...and not remain grouped as a hostile hull")
	assert_null(escort.get_node_or_null("EnemyAI"),
		"A protected hull is a target, not a combatant")
	assert_false(escort.get_node("ShipCombat").auto_fire_enabled,
		"...so it must never open fire itself")

func test_a_defense_encounter_spawns_a_fighting_ally_not_a_passive_target():
	## Slice 7: unlike the escort (Slice 5), an ally keeps its EnemyAI and
	## auto-fire — it's tactical aid, not something to protect.
	var d = _encounter(1, EncounterData.Objective.PROTECT_TARGET)
	d.escort_scene = load("res://scenes/world/EnemyShip.tscn")
	d.ally_scene = load("res://scenes/world/EnemyShip.tscn")
	d.ally_count = 1
	_mgr.start_encounter(d)
	_freeze_enemies()

	assert_eq(_mgr._allies.size(), 1, "The authored ally_count must be spawned")
	var ally = _mgr._allies[0]
	assert_true(ally.is_in_group("friendly_ship"), "An ally reads as friendly to FiringSolver")
	assert_false(ally.is_in_group("enemy_ship"), "...and not as a hostile hull")
	assert_not_null(ally.get_node_or_null("EnemyAI"), "Unlike the escort, an ally keeps its AI")
	assert_true(ally.get_node("ShipCombat").auto_fire_enabled, "...and its guns")

func test_allies_are_cleared_when_the_battle_ends():
	var d = _encounter(1)
	d.ally_scene = load("res://scenes/world/EnemyShip.tscn")
	d.ally_count = 2
	_mgr.start_encounter(d)
	_freeze_enemies()
	var allies = _mgr._allies.duplicate()
	assert_eq(allies.size(), 2, "Precondition: both allies spawned")

	_mgr._on_encounter_enemy_destroyed(_mgr._enemies[0])
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Precondition: the fight ended")
	for a in allies:
		assert_true(not is_instance_valid(a) or a.is_queued_for_deletion(),
			"Allies are scoped to this battle and must not linger in the world after it ends")

func test_survive_time_objective_is_won_by_outlasting_the_clock():
	var d = _encounter(1, EncounterData.Objective.SURVIVE_TIME)
	d.time_limit = 0.1
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	await wait_seconds(0.4)
	assert_false(_mgr.is_active(), "The clock should have run out")
	var params = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_true(params[0], "Outlasting a SURVIVE_TIME clock is a win")


# === upgrade cadence (the hook Slice 3 consumes) ===

func test_upgrade_offers_fire_on_the_authored_cadence_and_then_stop():
	var d = _encounter(2)
	d.upgrade_offers = 2
	d.upgrade_interval = 0.05
	_mgr.upgrade_pool = _pool()
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	await wait_seconds(0.4)
	assert_eq(get_signal_emit_count(_mgr, "upgrade_offer_requested"), 2,
		"Exactly the authored number of offers, not a repeating timer")

func test_an_offer_carries_the_choices_the_player_picks_from():
	var d = _encounter(2)
	d.upgrade_offers = 1
	d.upgrade_interval = 0.05
	_mgr.upgrade_pool = _pool()
	_mgr.choices_per_offer = 3
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()

	await wait_seconds(0.25)
	var params = get_signal_parameters(_mgr, "upgrade_offer_requested", 0)
	assert_eq(params[0].size(), 3, "An offer must arrive with its choices attached")
	assert_eq(params[1], 1, "...numbered")
	assert_eq(params[2], 1, "...out of the authored total")

func test_a_chosen_upgrade_takes_effect_and_is_gone_when_the_battle_ends():
	## The defining property of docs/navalCombat.md §11: upgrades "exist only during
	## the current battle". A build that leaked would become permanent progression.
	_mgr.upgrade_pool = _pool()
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()

	var mods := _mgr.get_player_modifiers()
	assert_not_null(mods, "The player ship must carry CombatModifiers")

	var heavy: BattleUpgradeData = load("res://resources/combat/upgrades/HeavyVolley.tres")
	assert_true(_mgr.apply_upgrade_choice(heavy), "Picking a card must apply it")
	assert_gt(mods.damage_mult, 1.0, "...and it must actually be in effect")

	_mgr._on_encounter_enemy_destroyed(_mgr._enemies[0])
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Precondition: the fight is over")
	assert_eq(mods.damage_mult, 1.0, "The build must not survive the battle")
	assert_eq(mods.get_applied_upgrades().size(), 0, "...nor be remembered")

func test_a_losing_battle_also_clears_the_build():
	_mgr.upgrade_pool = _pool()
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()
	var mods := _mgr.get_player_modifiers()
	_mgr.apply_upgrade_choice(load("res://resources/combat/upgrades/FullSail.tres"))
	assert_gt(mods.speed_mult, 1.0, "Precondition: the upgrade is live")

	_player.get_node("ShipDamage").mark_destroyed()
	await wait_process_frames(2)
	assert_eq(mods.speed_mult, 1.0, "Losing must clear the build too, not preserve it")

func test_an_offer_never_includes_an_upgrade_the_player_has_maxed():
	## A choice card that would do nothing is worse than one fewer card.
	_mgr.upgrade_pool = _pool()
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()

	var heavy: BattleUpgradeData = load("res://resources/combat/upgrades/HeavyVolley.tres")
	for _i in range(heavy.max_stacks):
		_mgr.apply_upgrade_choice(heavy)
	assert_false(_mgr.get_player_modifiers().can_apply(heavy), "Precondition: maxed out")

	for _attempt in range(12):
		assert_false(_mgr.roll_upgrade_choices(3).has(heavy),
			"A maxed upgrade must be filtered out of new offers")

func test_an_offer_contains_no_duplicates():
	_mgr.upgrade_pool = _pool()
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()
	for _attempt in range(12):
		var choices := _mgr.roll_upgrade_choices(3)
		var ids: Array[String] = []
		for c in choices:
			assert_false(ids.has(c.upgrade_id), "The same card must not appear twice in one offer")
			ids.append(c.upgrade_id)

func test_rolling_more_choices_than_the_pool_holds_returns_what_exists():
	_mgr.upgrade_pool = _pool()  # 5 upgrades
	_mgr.start_encounter(_encounter(1))
	_freeze_enemies()
	var choices := _mgr.roll_upgrade_choices(50)
	assert_eq(choices.size(), 5, "Must degrade gracefully rather than loop forever")

func test_no_upgrade_offers_when_the_encounter_authors_none():
	var d = _encounter(1)
	d.upgrade_offers = 0
	watch_signals(_mgr)
	_mgr.start_encounter(d)
	_freeze_enemies()
	await wait_seconds(0.25)
	assert_signal_not_emitted(_mgr, "upgrade_offer_requested",
		"upgrade_offers = 0 must mean a plain fight")


# === authored content ===

func test_every_authored_encounter_is_loadable_and_coherent():
	var paths := [
		"res://resources/combat/encounters/Skirmish.tres",
		"res://resources/combat/encounters/ConvoyRaid.tres",
		"res://resources/combat/encounters/Ambush.tres",
		"res://resources/combat/encounters/EliteHunters.tres",
		"res://resources/combat/encounters/GhostShipBoss.tres",
		"res://resources/combat/encounters/Defense.tres",
		"res://resources/combat/encounters/IntransigentBoss.tres",
		"res://resources/combat/encounters/CardenasBoss.tres",
	]
	for p in paths:
		var d: EncounterData = load(p)
		assert_not_null(d, "%s must load as EncounterData" % p)
		assert_ne(d.encounter_id, "", "%s needs an id" % p)
		assert_not_null(d.enemy_scene, "%s needs a composition to spawn" % p)
		assert_gt(d.enemy_count, 0, "%s needs at least one hull" % p)
		assert_not_null(d.loot_table, "%s needs a loot table or victory pays nothing" % p)
		assert_gt(d.spawn_distance_max, d.spawn_distance_min,
			"%s spawn band must be a real range" % p)
		if d.objective == EncounterData.Objective.DESTROY_COUNT:
			assert_true(d.objective_count <= d.enemy_count,
				"%s asks for more kills than it spawns" % p)
		if d.objective == EncounterData.Objective.PROTECT_TARGET:
			assert_not_null(d.escort_scene,
				"%s is a PROTECT_TARGET encounter with nothing authored to protect" % p)
		if d.ally_count > 0:
			assert_not_null(d.ally_scene,
				"%s authors ally_count > 0 but no ally_scene to spawn" % p)

func test_boss_encounter_replaces_the_old_world_event_timer():
	## WorldEventManager's entire job was a 5-minute boss timer. It is deleted;
	## the boss is now content.
	var boss: EncounterData = load("res://resources/combat/encounters/GhostShipBoss.tres")
	assert_eq(boss.kind, EncounterData.Kind.BOSS, "The ghost ship is a Boss-kind encounter")
	assert_eq(boss.enemy_scene.resource_path, "res://scenes/world/BossShip.tscn",
		"...and still spawns the authored boss hull")
	assert_gt(boss.upgrade_offers, 2,
		"docs/navalCombat.md §12: a boss offers more meaningful choices than a normal fight")
	assert_false(FileAccess.file_exists("res://scripts/managers/WorldEventManager.gd"),
		"The superseded WorldEventManager must be gone, not left as a duplicate system")


# === chapter-gated ambient bosses (M7.5) ===
# Chapter 4/5's dedicated bosses (HMS Intransigent, Cárdenas' flagship) are
# real DEFEAT_BOSS objectives (Ch4/Ch5 tasks.md) but had no in-world trigger
# at all — reachable only via a manual start_encounter() call, so neither
# chapter was actually completable by a real player. Gating them into the
# ambient pool by `required_chapter_id` is the fix; these pin the gate itself.

func test_chapter_gated_encounter_is_excluded_before_its_chapter():
	var saved_index = CampaignManager.current_chapter_index
	var saved_chapters = CampaignManager.chapters.duplicate()
	CampaignManager.chapters = []
	CampaignManager.current_chapter_index = -1

	var gated := _encounter(1)
	gated.required_chapter_id = "ch4_the_admirals_gambit"
	_mgr.encounter_pool = [gated]
	_mgr.ambient_enabled = true
	_mgr._ambient_timer = _mgr.ambient_interval

	_mgr._start_random_ambient()
	assert_false(_mgr.is_active(),
		"A chapter-gated encounter must not be a candidate before its chapter is current")

	CampaignManager.chapters = saved_chapters
	CampaignManager.current_chapter_index = saved_index

func test_chapter_gated_encounter_is_eligible_once_its_chapter_is_current():
	var saved_index = CampaignManager.current_chapter_index
	var saved_chapters = CampaignManager.chapters.duplicate()
	var ch := ChapterData.new()
	ch.chapter_id = "ch4_the_admirals_gambit"
	ch.chapter_number = 4
	CampaignManager.chapters = [ch]
	CampaignManager.current_chapter_index = 0

	var gated := _encounter(1)
	gated.required_chapter_id = "ch4_the_admirals_gambit"
	_mgr.encounter_pool = [gated]
	_mgr.ambient_enabled = true
	_mgr._ambient_timer = _mgr.ambient_interval

	_mgr._start_random_ambient()
	assert_true(_mgr.is_active(),
		"Once its chapter is current, the gated encounter must be reachable ambiently")

	CampaignManager.chapters = saved_chapters
	CampaignManager.current_chapter_index = saved_index

func test_both_authored_chapter_bosses_are_gated_to_their_own_chapter():
	var intransigent: EncounterData = load("res://resources/combat/encounters/IntransigentBoss.tres")
	var cardenas: EncounterData = load("res://resources/combat/encounters/CardenasBoss.tres")
	assert_eq(intransigent.required_chapter_id, "ch4_the_admirals_gambit",
		"HMS Intransigent must only be ambiently reachable during Chapter 4")
	assert_eq(cardenas.required_chapter_id, "ch5_the_silver_fleet",
		"Cárdenas' flagship must only be ambiently reachable during Chapter 5")
