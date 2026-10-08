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


## Pincer: slot 0 at +90 (the player's starboard beam), slot 1 at -90 (port).
## The player sits at the origin facing -Z, so starboard is +X.
func _pincer(first: String, second: String) -> EncounterData:
	var d := _encounter()
	d.squad = [_slot(first, 1), _slot(second, 1)]
	var tactic := SquadTacticData.new()
	tactic.formation = SquadTacticData.Formation.PINCER
	tactic.slot_bearings_deg = [90.0, -90.0]
	d.squad_tactic = tactic
	return d


## Where this hull steers to once its bearing filter has settled.
func _settled_ideal(ai) -> Vector3:
	# EnemyAI's target is typed ShipController: stand a bare hull in for the
	# player at the origin, facing -Z (identity basis), AI removed and frozen.
	var target := load(ENEMY_SCENE).instantiate() as ShipController
	var own_ai := target.get_node_or_null("EnemyAI")
	if own_ai:
		target.remove_child(own_ai)
		own_ai.free()
	target.freeze = true
	add_child_autoqfree(target)
	target.global_transform = Transform3D.IDENTITY
	ai.player_ship = target
	var p := Vector3.ZERO
	for i in range(40):
		p = ai._tactic_ideal_position(1.0, 60.0)
	return p


func test_pincer_spawns_each_hull_on_its_own_side() -> void:
	assert_true(_mgr.start_encounter(_pincer(RAIDER, TANK)))
	for e in _mgr._enemies:
		var ai = e.get_node("EnemyAI")
		var want: float = 1.0 if int(ai.ai_profile.role) == AIProfileData.Role.RAIDER else -1.0
		assert_eq(signf(e.global_position.x), want,
			"slot %s spawns on its bearing's side (x=%.1f)" % [ai.ai_profile.resource_path, e.global_position.x])


func test_a_signed_bearing_holds_its_side_even_from_the_wrong_one() -> void:
	# Both hulls are STANDARD-tactic profiles (HarassingSloop, AggressiveGalleon):
	# the squad bearing still governs where they sail.
	assert_true(_mgr.start_encounter(_pincer(RAIDER, TANK)))
	for e in _mgr._enemies:
		var ai = e.get_node("EnemyAI")
		var bearing_sign: float = 1.0 if int(ai.ai_profile.role) == AIProfileData.Role.RAIDER else -1.0
		# Put the hull on the OPPOSITE side: an unsigned bearing would keep it
		# there; the squad's signed one brings it round to its own side.
		e.global_position = Vector3(-bearing_sign * 50.0, 0.0, 0.0)
		ai._bearing_valid = false
		assert_true(ai._holds_squad_bearing(), "a STANDARD hull in a squad holds its slot")
		var ideal := _settled_ideal(ai)
		assert_eq(signf(ideal.x), bearing_sign,
			"bearing %+d: ideal point on that side (x=%.1f)" % [int(bearing_sign * 90.0), ideal.x])
		assert_almost_eq(absf(ideal.z), 0.0, 1.0, "on the beam, not ahead/astern")


func test_shared_profiles_are_never_mutated_by_a_bearing() -> void:
	var shared: AIProfileData = load(RAIDER)
	var before := float(shared.preferred_bearing_deg)
	assert_true(_mgr.start_encounter(_pincer(RAIDER, TANK)))
	assert_eq(float(shared.preferred_bearing_deg), before)
	for ai in _spawned_ais():
		assert_true(ai.has_squad_bearing)


func test_slots_sail_their_own_hull_class() -> void:
	var d := _encounter()
	var sloop_slot := _slot(RAIDER, 1)
	sloop_slot.ship_stats = load("res://resources/ships/Sloop.tres")
	var galleon_slot := _slot(TANK, 1)
	galleon_slot.ship_stats = load("res://resources/ships/Galleon.tres")
	d.squad = [sloop_slot, galleon_slot]
	assert_true(_mgr.start_encounter(d))
	var ids := {}
	for e in _mgr._enemies:
		var role := int(e.get_node("EnemyAI").ai_profile.role)
		ids[role] = e.ship_stats.ship_id
		assert_ne(e.ship_stats, sloop_slot.ship_stats, "a duplicate, never the shared resource")
		assert_ne(e.ship_stats, galleon_slot.ship_stats)
	assert_eq(ids[AIProfileData.Role.RAIDER], sloop_slot.ship_stats.ship_id)
	assert_eq(ids[AIProfileData.Role.TANK], galleon_slot.ship_stats.ship_id)


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

## The squads the heat tiers actually field (not whatever else sits in the dir).
func _heat_squads() -> Array:
	var out: Array = []
	for t in _load_dir(HEAT_DIR).filter(func(r): return r is HeatTierData):
		for sq in t.squad_pool:
			if not out.has(sq):
				out.append(sq)
	return out


func test_six_authored_squads_are_mixed_and_within_cap() -> void:
	var squads := _heat_squads()
	assert_eq(squads.size(), 6, "the heat tiers field 6 distinct squads")
	for sq in squads:
		assert_true(sq.resource_path.begins_with(SQUAD_DIR), sq.resource_path)
	var ids := {}
	for sq in squads:
		var hulls := {}
		for slot in sq.slots:
			assert_not_null(slot.ship_stats, "%s: every slot names its hull class" % sq.squad_id)
			if slot.ship_stats:
				hulls[slot.ship_stats.ship_id] = true
		assert_gte(hulls.size(), 2, "%s mixes hull classes" % sq.squad_id)
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
	# Strictly harder, not merely flat: the top half of the ladder fields more
	# hulls than the bottom half, and the top tier at least one more than T0.
	var avgs: Array = []
	for t in tiers:
		var total := 0.0
		for sq in t.squad_pool:
			total += sq.hull_count()
		avgs.append(total / float(t.squad_pool.size()))
	var half := avgs.size() / 2
	var low := 0.0
	var high := 0.0
	for i in range(half):
		low += avgs[i]
		high += avgs[avgs.size() - 1 - i]
	assert_gt(high, low, "top-half tiers average more hulls than bottom-half tiers %s" % str(avgs))
	assert_gte(avgs.back() - avgs[0], 1.0, "the top tier fields at least one more hull than T0 %s" % str(avgs))


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
