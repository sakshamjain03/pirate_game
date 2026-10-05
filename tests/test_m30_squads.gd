extends GutTest
## M30 Wave 1 (1.7): squads. An encounter can author a mixed composition
## (EncounterData.squad: hull + AI profile + count per slot, plus a
## SquadTacticData giving each slot a bearing). Each hull gets its profile
## BEFORE add_child (EnemyAI applies it in _ready), at most 4 hostiles spawn,
## an empty squad keeps the old enemy_scene/enemy_count path, and heat tiers
## hold squad pools so higher heat means harder compositions.
## Setup mirrors test_m30_encounter_exclusive.gd (MockPlayer/MockSpawner).

const ENEMY_SCENE := "res://scenes/world/EnemyShip.tscn"
const RAIDER := "res://resources/combat/ai_profiles/HarassingSloop.tres"
const TENDER := "res://resources/combat/ai_profiles/SupportGalleon.tres"
const TANK := "res://resources/combat/ai_profiles/AggressiveGalleon.tres"
const SQUAD_DIR := "res://resources/combat/squads"
const HEAT_DIR := "res://resources/balance/heat_tiers"

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
var _player: MockPlayer
var _created_test_scene: Node3D = null
## Roles read off each hull's EnemyAI at the instant it enters the tree —
## before its _ready() — which is what "profile set before add_child" means.
var _roles_on_enter: Array = []


func before_each() -> void:
	_roles_on_enter.clear()
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_root = Node.new()
	_root.name = "Systems"
	add_child_autoqfree(_root)
	_root.child_entered_tree.connect(_on_child_entered)
	var spawner := MockSpawner.new()
	spawner.name = "EnemySpawner"
	spawner._enemies_container = _root
	_root.add_child(spawner)
	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	_mgr.ambient_enabled = false
	_root.add_child(_mgr)
	_player = MockPlayer.new()
	_player.add_to_group("player_ship")
	_player.freeze = true
	var dmg: ShipDamage = ShipDamage.new()
	dmg.name = "ShipDamage"
	var stats := ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 20.0
	dmg.ship_stats = stats
	_player.add_child(dmg)
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO


func after_each() -> void:
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _on_child_entered(node: Node) -> void:
	var ai = node.get_node_or_null("EnemyAI")
	if ai == null:
		return
	# is_node_ready() is false here: this runs before the hull's _ready().
	_roles_on_enter.append({
		"role": int(ai.ai_profile.role) if ai.ai_profile else -1,
		"ready": ai.is_node_ready(),
	})


func _slot(profile_path: String, count: int, scene_path: String = ENEMY_SCENE) -> SquadSlotData:
	var s := SquadSlotData.new()
	s.hull_scene = load(scene_path) if scene_path != "" else null
	s.ai_profile = load(profile_path)
	s.count = count
	return s


func _encounter(id: String = "squad_fight") -> EncounterData:
	var d := EncounterData.new()
	d.encounter_id = id
	d.display_name = "Squad Fight"
	d.objective = EncounterData.Objective.DESTROY_ALL
	d.enemy_scene = null
	d.enemy_count = 2
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	d.upgrade_offers = 0
	d.ambient_clear_radius = 0.0
	return d


func _spawned_ais() -> Array:
	var out: Array = []
	for e in _mgr._enemies:
		out.append(e.get_node("EnemyAI"))
	return out


func _load_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append(load(dir_path.path_join(f)))
	return out


# === Spawning ===

func test_squad_spawns_mixed_hulls_with_profiles_set_before_ready() -> void:
	var d := _encounter()
	d.squad = [_slot(RAIDER, 1), _slot(TENDER, 2)]
	assert_true(_mgr.start_encounter(d), "a squad encounter with no enemy_scene starts")
	assert_eq(_mgr._enemies.size(), 3, "1 raider + 2 tenders")
	var roles: Array = []
	for ai in _spawned_ais():
		roles.append(int(ai.ai_profile.role))
	roles.sort()
	assert_eq(roles, [AIProfileData.Role.RAIDER, AIProfileData.Role.SUPPORT, AIProfileData.Role.SUPPORT])
	# EnemyAI._ready() applied the slot profile, not the scene's StandardEnemy.
	var tender: AIProfileData = load(TENDER)
	var tender_ais := _spawned_ais().filter(func(ai): return int(ai.ai_profile.role) == AIProfileData.Role.SUPPORT)
	assert_eq(tender_ais.size(), 2)
	assert_almost_eq(float(tender_ais[0].aggression), tender.aggression, 0.0001,
		"the slot profile was applied in _ready")
	# Profile visible at tree entry, before _ready.
	assert_eq(_roles_on_enter.size(), 3)
	for r in _roles_on_enter:
		assert_false(r["ready"], "observed before the hull's _ready")
		assert_ne(r["role"], AIProfileData.Role.BALANCED, "slot profile already set at tree entry")


func test_squad_hostile_count_is_capped_at_four() -> void:
	var d := _encounter()
	d.squad = [_slot(RAIDER, 2), _slot(TANK, 2), _slot(TENDER, 2)]
	assert_true(_mgr.start_encounter(d))
	assert_eq(_mgr._enemies.size(), EncounterManager.MAX_SQUAD_HOSTILES)
	assert_eq(EncounterManager.MAX_SQUAD_HOSTILES, 4)
	# The cap keeps slot order: the tenders (last slot) are the ones cut.
	for ai in _spawned_ais():
		assert_ne(int(ai.ai_profile.role), AIProfileData.Role.SUPPORT)


func test_empty_squad_falls_back_to_enemy_scene_and_count() -> void:
	var d := _encounter()
	d.enemy_scene = load(ENEMY_SCENE)
	d.enemy_count = 2
	assert_true(d.squad.is_empty())
	assert_true(_mgr.start_encounter(d))
	assert_eq(_mgr._enemies.size(), 2)
	for ai in _spawned_ais():
		assert_eq(ai.ai_profile.resource_path,
			"res://resources/combat/ai_profiles/StandardEnemy.tres", "the scene's own profile")


func test_slot_without_hull_scene_uses_encounter_enemy_scene() -> void:
	var d := _encounter()
	d.enemy_scene = load(ENEMY_SCENE)
	d.squad = [_slot(TANK, 1, "")]
	assert_true(_mgr.start_encounter(d))
	assert_eq(_mgr._enemies.size(), 1)
	assert_eq(int(_spawned_ais()[0].ai_profile.role), AIProfileData.Role.TANK)


func test_tactic_gives_each_slot_its_bearing() -> void:
	var d := _encounter()
	d.squad = [_slot(RAIDER, 1), _slot(TANK, 1)]
	var tactic := SquadTacticData.new()
	tactic.formation = SquadTacticData.Formation.PINCER
	tactic.slot_bearings_deg = [90.0, -90.0]
	d.squad_tactic = tactic
	assert_true(_mgr.start_encounter(d))
	var by_role := {}
	for ai in _spawned_ais():
		by_role[int(ai.ai_profile.role)] = ai
	assert_eq(float(by_role[AIProfileData.Role.RAIDER].get_meta(&"squad_bearing_deg")), 90.0)
	assert_eq(float(by_role[AIProfileData.Role.TANK].get_meta(&"squad_bearing_deg")), -90.0)
	# When AIProfileData carries preferred_bearing_deg (M30 1.1), the override
	# lands on a per-hull duplicate, never on the shared resource.
	var shared: AIProfileData = load(RAIDER)
	if "preferred_bearing_deg" in shared:
		assert_eq(float(by_role[AIProfileData.Role.RAIDER].ai_profile.get("preferred_bearing_deg")), 90.0)
		assert_ne(by_role[AIProfileData.Role.RAIDER].ai_profile, shared)


# === Validation ===

func test_validate_accepts_squad_without_enemy_scene() -> void:
	var d := _encounter()
	assert_ne(_mgr._validate(d), "", "no squad and no enemy_scene is still invalid")
	d.squad = [_slot(RAIDER, 1)]
	assert_eq(_mgr._validate(d), "", "a squad is a composition on its own")


func test_validate_rejects_slot_with_no_hull_anywhere() -> void:
	var d := _encounter()
	d.squad = [_slot(RAIDER, 1, "")]
	assert_string_contains(_mgr._validate(d), "squad slot 0")


# === Authored content ===

func test_six_authored_squads_are_mixed_and_within_cap() -> void:
	var squads := _load_dir(SQUAD_DIR).filter(func(r): return r is SquadData)
	assert_gte(squads.size(), 6, "6 squads authored under %s" % SQUAD_DIR)
	var ids := {}
	for sq in squads:
		assert_ne(sq.squad_id, "", sq.resource_path)
		assert_false(ids.has(sq.squad_id), "duplicate squad_id %s" % sq.squad_id)
		ids[sq.squad_id] = true
		assert_not_null(sq.tactic, "%s has a tactic" % sq.squad_id)
		assert_lte(sq.hull_count(), EncounterManager.MAX_SQUAD_HOSTILES, sq.squad_id)
		var roles := {}
		for slot in sq.slots:
			assert_not_null(slot.hull_scene, "%s slot has a hull" % sq.squad_id)
			assert_not_null(slot.ai_profile, "%s slot has a profile" % sq.squad_id)
			roles[int(slot.ai_profile.role)] = true
		assert_gte(roles.size(), 2, "%s is a mixed composition" % sq.squad_id)
		if sq.tactic:
			assert_eq(sq.tactic.slot_bearings_deg.size(), sq.slots.size(),
				"%s: one bearing per slot" % sq.squad_id)


func test_heat_tiers_hold_squad_pools_that_harden_with_heat() -> void:
	var tiers := _load_dir(HEAT_DIR).filter(func(r): return r is HeatTierData)
	tiers.sort_custom(func(a, b): return a.tier < b.tier)
	assert_gte(tiers.size(), 6)
	var prev := 0.0
	for t in tiers:
		assert_false(t.squad_pool.is_empty(), "tier %d has a squad pool" % t.tier)
		var total := 0.0
		for sq in t.squad_pool:
			total += sq.hull_count()
		var avg := total / float(t.squad_pool.size())
		assert_gte(avg, prev, "tier %d is no easier than the tier below" % t.tier)
		prev = avg
	var first_avg := 0.0
	for sq in tiers[0].squad_pool:
		first_avg += sq.hull_count()
	first_avg /= float(tiers[0].squad_pool.size())
	assert_gt(prev, first_avg, "the top tier fields more hulls than the bottom one")


func test_ambient_picker_puts_a_heat_squad_on_opted_in_encounters() -> void:
	var squad := SquadData.new()
	squad.squad_id = "probe"
	squad.slots = [_slot(RAIDER, 1), _slot(TANK, 1)]
	squad.tactic = SquadTacticData.new()
	var tier := HeatTierData.new()
	tier.squad_pool = [squad]

	var e := _encounter()
	e.enemy_scene = load(ENEMY_SCENE)
	e.use_heat_squad = true
	var picked := _mgr.encounter_with_heat_squad(e, tier)
	assert_ne(picked, e, "the authored resource is never mutated")
	assert_true(e.squad.is_empty())
	assert_eq(picked.squad.size(), 2)
	assert_eq(picked.squad_tactic, squad.tactic)
	assert_eq(picked.encounter_id, e.encounter_id)

	var opted_out := _encounter()
	opted_out.use_heat_squad = false
	assert_eq(_mgr.encounter_with_heat_squad(opted_out, tier), opted_out)
	assert_eq(_mgr.encounter_with_heat_squad(e, null), e, "no tier, no change")


func test_authored_ambient_encounters_opt_into_heat_squads() -> void:
	for path in ["res://resources/combat/encounters/Skirmish.tres",
			"res://resources/combat/encounters/Ambush.tres"]:
		var e: EncounterData = load(path)
		assert_true(e.use_heat_squad, path)
