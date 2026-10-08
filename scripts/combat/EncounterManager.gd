class_name EncounterManager extends Node

## Purpose: gives a fight a beginning, an objective, an end and a payout.
## Responsibilities: spawn a composition, track its objective off existing signals,
##   suppress ambient spawning while a fight is live, drive upgrade-offer cadence,
##   resolve victory/defeat/escape, and grant rewards.
## Dependencies: EnemySpawner (composition + region scaling), ResourceManager,
##   EmpireManager (notoriety), FleetManager (captain XP), WorldHUD (announcements).
##
## Why this exists: `docs/navalCombat.md` §11–18 assume a *battle* — temporary
## upgrades that last "only during the current battle", a victory condition, a
## rewards moment, a return to the world. None of that could exist before, because
## `World.tscn` is one continuous scene where `EnemySpawner` simply keeps 3–5
## roamers alive forever and a kill only dropped a crate. This node is the battle
## boundary, added in place rather than as a separate battle scene so sailing stays
## seamless and the ocean/camera/HUD stack is reused unchanged.
##
## It also absorbs the old `WorldEventManager`, whose entire job was a 5-minute
## timer that spawned the boss — that is now just a Boss-kind EncounterData.

signal encounter_started(data: EncounterData)
signal encounter_ended(victory: bool, rewards: Dictionary)
signal objective_progress(current: int, total: int)
## Mirrors `EnemySpawner.enemy_destroyed(enemy)` for bounded-encounter kills —
## `EnemySpawner`'s own signal only covers its ambient roamers, never a
## composition or boss this manager spawned. `CampaignManager` (M7) listens to
## both so DESTROY_SHIPS/DEFEAT_BOSS objectives see every kill regardless of
## which system spawned the hull.
signal ship_destroyed(ship: Node3D)
## A set of temporary battle upgrades to choose between, emitted on the cadence the
## active EncounterData authors rather than on a fixed global timer
## (`docs/navalCombat.md` §12: ~30–60 s, deliberately not every ten seconds).
signal upgrade_offer_requested(choices: Array, offer_index: int, total_offers: int)
## M29 A.4: encounter startup failed validation
signal encounter_failed(encounter_id: String, reason: String)
## M30 1.13 — the Sortie Stars a won encounter earned (`stars` of `total`
## authored conditions). Emitted on VICTORY only, before `encounter_ended`.
## CampaignManager keeps the best per encounter id; stars are cosmetic and
## never gate campaign content.
signal stars_awarded(encounter_id: String, stars: int, total: int)
## M30 1.9 — the Spyglass Briefing's pick was applied to the player's ship.
signal briefing_applied(preparation_id: String, port_ammo_id: String, starboard_ammo_id: String)
## M30 0.16 — encounter_failed's reason when one is already running. Callers
## (and tests) see the refusal; the HUD stays quiet about it.
const REASON_BUSY := "busy"
## M30 1.7 (W1-1.4) — a squad never fields more than this many hostiles: a
## readable fight on a phone screen and the ship budget, not a balance number.
const MAX_SQUAD_HOSTILES := 4

enum Outcome { VICTORY, DEFEAT, ESCAPED }

## The pool the ambient scheduler draws from. Authored `.tres`, so adding an
## encounter type is a content change.
@export var encounter_pool: Array[EncounterData] = []
## Seconds between ambient encounter offers. Only fires when no fight is live.
@export var ambient_interval: float = 150.0
## Ambient encounters are suppressed until the player has been sailing this long,
## so a brand-new game is not jumped on at the dock.
@export var ambient_initial_delay: float = 60.0
@export var ambient_enabled: bool = true

@export_group("Battle Upgrades")
## The pool temporary in-battle upgrade offers are drawn from
## (`docs/navalCombat.md` §11). Lives here because this node already owns the
## cadence; giving upgrades their own manager would add a second thing that has to
## know when a battle starts and stops.
@export var upgrade_pool: Array[BattleUpgradeData] = []
## How many upgrades to put in front of the player per offer.
@export_range(2, 4) var choices_per_offer: int = 3

var active_encounter: EncounterData = null

var _spawner: Node = null
var _player: Node3D = null
var _enemies: Array[Node3D] = []
var _protect_target: Node3D = null
var _allies: Array[Node3D] = []
var _kills: int = 0
var _elapsed: float = 0.0
var _centre: Vector3 = Vector3.ZERO
## M30 0.16 — ambient hulls parked for the current encounter (see _park_ambient).
var _parked: Array = []
var _ambient_timer: float = 0.0
var _offers_made: int = 0
var _offer_timer: float = 0.0
var _disengage_timer: float = 0.0
var _resolving: bool = false
## M30 1.13 — battle stats for star condition evaluation. Damage and crew
## loss are summed from the player's `ShipDamage.hit_resolved` during THIS
## battle (the applied deltas), so a tech-boosted max hull or a fight started
## already damaged reads the same as any other.
var _battle_elapsed: float = 0.0
var _player_damage_taken: float = 0.0
var _player_crew_lost: float = 0.0
var _last_encounter_stars: Array = []
var _tracked_damage: ShipDamage = null
## M30 1.9 — the Spyglass Briefing's tuning (preparations, intel gates).
## Null loads BRIEFING_CONFIG_PATH.
const BRIEFING_CONFIG_PATH := "res://resources/combat/SpyglassBriefing.tres"
@export var briefing_config: SpyglassBriefingData
## Test seam: >= 0 replaces the owned-Watchtower lookup.
var watchtower_level_override: int = -1


func _ready() -> void:
	# M29 J.2 — WorldHUD finds this scene node by group to hear encounter_failed.
	add_to_group("encounter_manager")
	_ambient_timer = -ambient_initial_delay
	# Sibling lookup, the same way Island.gd finds Systems/DockingSystem.
	_spawner = get_parent().get_node_or_null("EnemySpawner") if get_parent() else null


func is_active() -> bool:
	return active_encounter != null


func get_objective_total() -> int:
	if not active_encounter:
		return 0
	match active_encounter.objective:
		EncounterData.Objective.DESTROY_COUNT:
			return active_encounter.objective_count
		EncounterData.Objective.DESTROY_ALL:
			return _enemies.size() + _kills
	return 1


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_ship")

	if is_active():
		_tick_active(delta)
	elif ambient_enabled and _player and is_instance_valid(_player):
		_ambient_timer += delta
		if _ambient_timer >= ambient_interval:
			_ambient_timer = 0.0
			_start_random_ambient()


# === Lifecycle ===

## M29 A.4: Validate encounter data before spawn. Returns empty string if valid, error reason otherwise.
func _validate(data: EncounterData) -> String:
	if not data:
		return "null data"

	# Check for missing composition
	var scene = data.enemy_scene
	if not scene and _spawner and "enemy_scene" in _spawner:
		scene = _spawner.enemy_scene
	if not data.squad.is_empty():
		# M30 1.7 — a squad is a composition on its own; every slot needs a hull
		# (its own, or the encounter's/spawner's fallback).
		for i in range(data.squad.size()):
			var slot: SquadSlotData = data.squad[i]
			if not slot:
				return "encounter_id=%s: squad slot %d is empty" % [data.encounter_id, i]
			if not slot.hull_scene and not scene:
				return "encounter_id=%s: squad slot %d has no hull_scene" % [data.encounter_id, i]
	elif not scene:
		return "encounter_id=%s: missing enemy_scene" % data.encounter_id

	# Check objective-specific requirements
	match data.objective:
		EncounterData.Objective.PROTECT_TARGET:
			if not data.escort_scene:
				return "encounter_id=%s: PROTECT_TARGET missing escort_scene" % data.encounter_id
		EncounterData.Objective.SURVIVE_TIME:
			if data.time_limit <= 0:
				return "encounter_id=%s: SURVIVE_TIME with time_limit <= 0" % data.encounter_id
		EncounterData.Objective.DESTROY_COUNT:
			if data.objective_count <= 0:
				return "encounter_id=%s: DESTROY_COUNT with target <= 0" % data.encounter_id

	return ""  # Valid

func start_encounter(data: EncounterData) -> bool:
	if not data:
		return false
	# M30 0.16 (B6) — one encounter at a time. A second used to return false
	# silently, which callers could not tell from a broken encounter.
	if is_active():
		encounter_failed.emit(data.encounter_id, REASON_BUSY)
		return false

	# M29 A.4: validate before anything else — bad data is bad with or without a
	# player ship, and must fail loudly rather than start an unwinnable fight.
	var validation_error := _validate(data)
	if validation_error != "":
		push_error(validation_error)
		_restore_spawning()
		encounter_failed.emit(data.encounter_id, validation_error)
		return false

	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_ship")
	if not _player:
		return false

	active_encounter = data
	_enemies.clear()
	_protect_target = null
	_allies.clear()
	_kills = 0
	_elapsed = 0.0
	_offers_made = 0
	_offer_timer = 0.0
	_disengage_timer = 0.0
	_resolving = false
	_centre = _player.global_position
	## M30 1.13 — initialize star tracking
	_battle_elapsed = 0.0
	_player_damage_taken = 0.0
	_player_crew_lost = 0.0
	_last_encounter_stars = []
	_track_player_damage()

	# Ambient spawning pauses for the duration: the point of a bounded encounter
	# is a known composition, which a background spawner would keep polluting.
	if _spawner and "spawning_enabled" in _spawner:
		_spawner.spawning_enabled = false

	_park_ambient(data)
	_spawn_composition(data)
	if data.objective == EncounterData.Objective.PROTECT_TARGET:
		_spawn_escort(data)
	_spawn_allies(data)

	# An encounter that could not place a single hull is not an encounter.
	if _enemies.is_empty() and data.objective != EncounterData.Objective.SURVIVE_TIME:
		_restore_spawning()
		active_encounter = null
		# M29 A.4: emit signal on post-spawn failure (escort spawn failure)
		encounter_failed.emit(data.encounter_id, "no enemies spawned")
		return false

	# M29 A.4: PROTECT_TARGET with no escort that actually spawned has nothing to
	# protect and could never resolve. Validation can't catch an escort scene that
	# fails to instantiate, so check the spawned node itself.
	if data.objective == EncounterData.Objective.PROTECT_TARGET 			and (_protect_target == null or not is_instance_valid(_protect_target)):
		push_error("encounter_id=%s: PROTECT_TARGET escort failed to spawn" % data.encounter_id)
		for enemy in _enemies:
			if is_instance_valid(enemy):
				enemy.queue_free()
		_enemies.clear()
		_restore_spawning()
		active_encounter = null
		encounter_failed.emit(data.encounter_id, "escort failed to spawn")
		return false

	_announce(data.announce_text)
	encounter_started.emit(data)
	objective_progress.emit(0, get_objective_total())
	return true


func abandon() -> void:
	if is_active():
		_resolve(Outcome.ESCAPED)


## M30 1.13 (test seam) — force encounter resolution with a specific outcome
func end_encounter(outcome: int) -> bool:
	if is_active():
		_resolve(outcome)
		return true
	return false


func _tick_active(delta: float) -> void:
	_elapsed += delta
	## M30 1.13 — track elapsed time for star conditions
	_battle_elapsed += delta


	for i in range(_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_enemies[i]):
			_enemies.remove_at(i)

	# Upgrade-offer cadence
	var data := active_encounter
	if _offers_made < data.upgrade_offers:
		_offer_timer += delta
		if _offer_timer >= data.upgrade_interval:
			_offer_timer = 0.0
			_offers_made += 1
			upgrade_offer_requested.emit(
				roll_upgrade_choices(choices_per_offer), _offers_made, data.upgrade_offers)

	# Defeat: the player's hull is gone. DeathScreen still owns what happens next
	# (`docs/navalCombat.md` §17 — never a game over), this just closes the fight.
	if _player and is_instance_valid(_player):
		var dmg = _player.get_node_or_null("ShipDamage")
		if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
			_resolve(Outcome.DEFEAT)
			return
	else:
		_resolve(Outcome.DEFEAT)
		return

	# A PROTECT_TARGET encounter fails the moment the escort sinks — the raiders
	# don't need to be cleared for that to be a loss.
	if data.objective == EncounterData.Objective.PROTECT_TARGET and _protect_target:
		if not is_instance_valid(_protect_target):
			_resolve(Outcome.DEFEAT)
			return
		var edmg = _protect_target.get_node_or_null("ShipDamage")
		if edmg and edmg.has_method("is_destroyed") and edmg.is_destroyed():
			_resolve(Outcome.DEFEAT)
			return

	# Time limit
	if data.time_limit > 0.0 and _elapsed >= data.time_limit:
		# Surviving the clock is the win condition for SURVIVE_TIME and a loss
		# (they got away / you ran out of time) for everything else.
		_resolve(Outcome.VICTORY if data.objective == EncounterData.Objective.SURVIVE_TIME
			else Outcome.ESCAPED)
		return

	# Objective
	match data.objective:
		EncounterData.Objective.DESTROY_ALL:
			if _enemies.is_empty():
				_resolve(Outcome.VICTORY)
				return
		EncounterData.Objective.DESTROY_COUNT:
			if _kills >= data.objective_count:
				_resolve(Outcome.VICTORY)
				return
		EncounterData.Objective.PROTECT_TARGET:
			if _enemies.is_empty():
				_resolve(Outcome.VICTORY)
				return
		EncounterData.Objective.SURVIVE_TIME:
			pass

	# Disengage — sailing away is a legitimate tactical choice, not a bug.
	if _player and is_instance_valid(_player):
		var dist: float = Vector2(_player.global_position.x - _centre.x,
			_player.global_position.z - _centre.z).length()
		if dist > data.disengage_distance:
			_disengage_timer += delta
			if _disengage_timer >= data.disengage_grace:
				_resolve(Outcome.ESCAPED)
		else:
			_disengage_timer = 0.0


func _resolve(outcome: int) -> void:
	if not is_active() or _resolving:
		return
	_resolving = true
	var data := active_encounter
	var rewards: Dictionary = {}

	_untrack_player_damage()
	_last_encounter_stars = []
	if outcome == Outcome.VICTORY:
		rewards = _grant_rewards(data)
		## M30 1.13 — evaluate star conditions on victory, record them (via the
		## signal) and show them in the result announcement.
		_last_encounter_stars = _evaluate_stars(data)
		var result := "VICTORY — %s" % data.display_name
		if not data.star_conditions.is_empty():
			stars_awarded.emit(data.encounter_id, _last_encounter_stars.size(),
				data.star_conditions.size())
			result += "\n" + describe_stars(_last_encounter_stars.size(), data.star_conditions.size())
			# The cosmetic total, read AFTER stars_awarded (CampaignManager records
			# on it synchronously), so it already includes this result.
			var campaign := get_node_or_null("/root/CampaignManager")
			if campaign and campaign.has_method("get_total_stars"):
				result += "  ·  %d ★ total" % int(campaign.get_total_stars())
		_announce("%s\n%s" % [result, _describe_rewards(rewards)])
	elif outcome == Outcome.ESCAPED:
		_announce("You broke off from %s." % data.display_name)
	else:
		_announce("Your ship was lost in %s." % data.display_name)

	# Anything the player did not sink sails off with the encounter rather than
	# lingering as ambient traffic with encounter-scaled stats.
	if outcome != Outcome.VICTORY:
		_despawn_remaining()

	# The escort and any allies are scoped to this battle either way — victory
	# doesn't leave a stray friendly hull sailing the open world forever.
	if _protect_target and is_instance_valid(_protect_target):
		_protect_target.queue_free()
	_protect_target = null
	for a in _allies:
		if is_instance_valid(a):
			a.queue_free()
	_allies.clear()

	# THE thing that makes battle upgrades temporary (`docs/navalCombat.md` §11:
	# "exist only during the current battle"). Cleared on every outcome, win or
	# lose, so a build never leaks into the next fight or into a save.
	var mods := get_player_modifiers()
	if mods:
		mods.reset()
	# M30 1.9 — the briefing's opening ammo is for this battle only.
	var combat := _player_combat()
	if combat:
		combat.clear_side_ammo()

	active_encounter = null
	_enemies.clear()
	_restore_spawning()
	_ambient_timer = 0.0
	if AudioManager:
		AudioManager.play_sound("victory" if outcome == Outcome.VICTORY else "defeat")
	encounter_ended.emit(outcome == Outcome.VICTORY, rewards)


func _restore_spawning() -> void:
	if _spawner and "spawning_enabled" in _spawner:
		_spawner.spawning_enabled = true
	_unpark_ambient()


func _track_player_damage() -> void:
	_untrack_player_damage()
	if not _player or not is_instance_valid(_player):
		return
	var dmg := _player.get_node_or_null("ShipDamage") as ShipDamage
	if dmg:
		dmg.hit_resolved.connect(_on_player_hit_resolved)
		_tracked_damage = dmg


func _untrack_player_damage() -> void:
	if is_instance_valid(_tracked_damage) \
			and _tracked_damage.hit_resolved.is_connected(_on_player_hit_resolved):
		_tracked_damage.hit_resolved.disconnect(_on_player_hit_resolved)
	_tracked_damage = null


func _on_player_hit_resolved(_source: Node, _facing: StringName, pool_deltas: Dictionary,
		_ammo_id: StringName, _hit_tags: PackedStringArray) -> void:
	_player_damage_taken += float(pool_deltas.get("hull", 0.0))
	_player_crew_lost += float(pool_deltas.get("crew", 0.0))


## "★★☆  Sortie Stars 2/3" — the result line for a won encounter.
static func describe_stars(earned: int, total: int) -> String:
	return "%s%s  Sortie Stars %d/%d" % ["★".repeat(earned), "☆".repeat(maxi(total - earned, 0)), earned, total]


## M30 1.13 — evaluate each star condition and return the earned ones.
func _evaluate_stars(data: EncounterData) -> Array:
	var earned: Array = []
	if not data or data.star_conditions.is_empty():
		return earned
	for cond: StarConditionData in data.star_conditions:
		if not cond:
			continue
		var passed := false
		match cond.condition:
			StarConditionData.Condition.VICTORY:
				passed = true
			StarConditionData.Condition.QUICK_VICTORY:
				## win within target_value seconds
				passed = _battle_elapsed <= cond.target_value
			StarConditionData.Condition.PERFECT_DEFENSE:
				## take 0 damage
				passed = _player_damage_taken <= 0.0
			StarConditionData.Condition.ZERO_LOSSES:
				## no crew lost
				passed = _player_crew_lost <= 0.0
		if passed:
			earned.append(cond)
	return earned


## M30 0.16 (B6) — ambient traffic near the centre sits the battle out:
## hidden, removed from physics (PROCESS_MODE_DISABLED drops a body from the
## space) and from the targeting groups, then restored where it was. A hull
## the player has already provoked stays in — it is part of this fight.
func _park_ambient(data: EncounterData) -> void:
	_parked.clear()
	if data.ambient_clear_radius <= 0.0:
		return
	for node in get_tree().get_nodes_in_group("ambient_enemy"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var offset: Vector3 = node.global_position - _centre
		if Vector2(offset.x, offset.z).length() > data.ambient_clear_radius:
			continue
		var ai = node.get_node_or_null("EnemyAI")
		if ai and ai.has_method("is_provoked") and ai.is_provoked():
			continue
		var groups: Array = []
		for g in ["enemy_ship", "ambient_enemy"]:
			if node.is_in_group(g):
				groups.append(g)
				node.remove_from_group(g)
		_parked.append({"node": node, "groups": groups,
			"process_mode": node.process_mode, "visible": node.visible})
		node.add_to_group("parked_ambient")
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.visible = false


func _unpark_ambient() -> void:
	for p in _parked:
		var node = p["node"]
		if not is_instance_valid(node):
			continue
		node.remove_from_group("parked_ambient")
		for g in p["groups"]:
			node.add_to_group(g)
		node.process_mode = p["process_mode"]
		node.visible = p["visible"]
	_parked.clear()


func _despawn_remaining() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()


# === Composition ===

func _spawn_composition(data: EncounterData) -> void:
	var scene: PackedScene = data.enemy_scene
	if not scene and _spawner and "enemy_scene" in _spawner:
		scene = _spawner.enemy_scene
	var plan := build_spawn_plan(data, scene)
	if plan.is_empty():
		push_error("EncounterManager: encounter '%s' has no enemy scene" % data.encounter_id)
		return

	var container: Node = _spawner.get("_enemies_container") if _spawner else null
	if not container or not is_instance_valid(container):
		container = get_tree().current_scene

	for i in range(plan.size()):
		var entry: Dictionary = plan[i]
		var enemy = (entry["scene"] as PackedScene).instantiate() as Node3D
		if not enemy:
			continue
		# M30 1.7 — EnemyAI reads ai_profile in _ready(), so a squad slot's
		# profile (and its formation bearing) must be on the node before add_child.
		_assign_slot_profile(enemy, entry, data.squad_tactic)
		container.add_child(enemy)
		var pos := _pick_spawn_position(data, i, plan.size())
		var slot_index: int = entry["slot"]
		if data.squad_tactic and data.squad_tactic.has_bearing_for_slot(slot_index):
			# Start each hull on its own slot's side of the player, so a pincer
			# opens split instead of both hulls crossing the player's bow first.
			pos = _formation_spawn_position(data, data.squad_tactic.bearing_for_slot(slot_index))
		enemy.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), pos)
		if enemy is RigidBody3D:
			enemy.linear_velocity = Vector3.ZERO
			enemy.angular_velocity = Vector3.ZERO

		_apply_strength(enemy, data)
		_track(enemy)


## M30 1.7 — what to spawn, in order: one `{scene, profile, slot}` per hull.
## A non-empty `data.squad` expands its slots (capped at MAX_SQUAD_HOSTILES,
## slot order kept, so the last slots are the ones cut); an empty squad is the
## pre-M30 `enemy_scene` × `enemy_count` with the scene's own profile.
## `fallback_scene` stands in for a slot (or encounter) without a hull scene.
static func build_spawn_plan(data: EncounterData, fallback_scene: PackedScene) -> Array:
	var plan: Array = []
	if data.squad.is_empty():
		if fallback_scene:
			for i in range(data.enemy_count):
				plan.append({"scene": fallback_scene, "profile": null, "slot": -1})
		return plan
	for slot_index in range(data.squad.size()):
		var slot: SquadSlotData = data.squad[slot_index]
		if not slot:
			push_error("EncounterManager: encounter '%s' squad slot %d is empty" % [data.encounter_id, slot_index])
			continue
		var scene: PackedScene = slot.hull_scene if slot.hull_scene else fallback_scene
		if not scene:
			push_error("EncounterManager: encounter '%s' squad slot %d has no hull scene" % [data.encounter_id, slot_index])
			continue
		for n in range(slot.count):
			if plan.size() >= MAX_SQUAD_HOSTILES:
				return plan
			plan.append({"scene": scene, "profile": slot.ai_profile, "slot": slot_index,
				"stats": slot.ship_stats})
	return plan


## Everything a squad slot decides about a hull, applied BEFORE add_child:
## EnemyAI reads its profile in _ready(), and ShipController applies ship_stats
## there too. The formation bearing goes on the hull's EnemyAI as a SIGNED
## per-hull value (`squad_bearing_deg`), never onto the shared profile, whose
## `preferred_bearing_deg` is unsigned and lets the hull pick its own side.
func _assign_slot_profile(enemy: Node3D, entry: Dictionary, tactic: SquadTacticData) -> void:
	var slot_index: int = entry["slot"]
	if slot_index < 0:
		return
	var stats: ShipStats = entry.get("stats")
	if stats and "ship_stats" in enemy:
		# Duplicate-never-mutate, as EnemySpawner does with enemy_ship_pool.
		enemy.ship_stats = stats.duplicate()
	var ai = enemy.get_node_or_null("EnemyAI")
	if not ai:
		return
	var profile: AIProfileData = entry["profile"]
	if profile:
		ai.ai_profile = profile
	if tactic != null and tactic.has_bearing_for_slot(slot_index):
		ai.squad_bearing_deg = tactic.bearing_for_slot(slot_index)
		ai.has_squad_bearing = true


func _spawn_escort(data: EncounterData) -> void:
	if not data.escort_scene:
		return
	var container: Node = _spawner.get("_enemies_container") if _spawner else null
	if not container or not is_instance_valid(container):
		container = get_tree().current_scene

	var escort := data.escort_scene.instantiate() as Node3D
	if not escort:
		return
	container.add_child(escort)
	escort.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), _centre)
	if escort is RigidBody3D:
		escort.linear_velocity = Vector3.ZERO
		escort.angular_velocity = Vector3.ZERO

	# A protected hull, not a combatant: on the player's side of `are_hostile()`
	# via `friendly_ship` without joining `player_ship` (which `BoardingSystem`/
	# `CameraRig` assume has exactly one member), and it never fights back.
	if escort.is_in_group("enemy_ship"):
		escort.remove_from_group("enemy_ship")
	escort.add_to_group("friendly_ship")
	var ai = escort.get_node_or_null("EnemyAI")
	if ai:
		# A hard free, not queue_free: callers (and this wave's own tests) expect
		# the escort to already read as AI-less the instant it is spawned.
		escort.remove_child(ai)
		ai.free()
	var combat = escort.get_node_or_null("ShipCombat")
	if combat and "auto_fire_enabled" in combat:
		combat.auto_fire_enabled = false

	_protect_target = escort


func _spawn_allies(data: EncounterData) -> void:
	if not data.ally_scene or data.ally_count <= 0:
		return
	var container: Node = _spawner.get("_enemies_container") if _spawner else null
	if not container or not is_instance_valid(container):
		container = get_tree().current_scene

	var anchor: Vector3 = _player.global_position if _player and is_instance_valid(_player) else _centre
	for i in range(data.ally_count):
		var ally := data.ally_scene.instantiate() as Node3D
		if not ally:
			continue
		if data.ally_profile:
			var ai = ally.get_node_or_null("EnemyAI")
			if ai:
				ai.ai_profile = data.ally_profile
		container.add_child(ally)
		var angle: float = (TAU / float(max(data.ally_count, 1))) * float(i)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 14.0
		ally.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), anchor + offset)
		if ally is RigidBody3D:
			ally.linear_velocity = Vector3.ZERO
			ally.angular_velocity = Vector3.ZERO

		# A combatant on the player's side, not a target: hostile-to-enemies via
		# `friendly_ship` (`FiringSolver.are_hostile()`) without literally joining
		# `player_ship`, which `BoardingSystem`/`CameraRig` assume has one member.
		# Unlike the escort, its `EnemyAI` and auto-fire stay on — it fights.
		if ally.is_in_group("enemy_ship"):
			ally.remove_from_group("enemy_ship")
		ally.add_to_group("friendly_ship")
		_allies.append(ally)


func _pick_spawn_position(data: EncounterData, index: int, total: int) -> Vector3:
	var dist: float = randf_range(data.spawn_distance_min, data.spawn_distance_max)
	var angle: float
	if data.kind == EncounterData.Kind.AMBUSH:
		# Ring the player — that is what makes an ambush an ambush.
		angle = (TAU / float(max(total, 1))) * float(index) + randf_range(-0.2, 0.2)
	else:
		# Clustered ahead, so the fight is something you sail into.
		var facing: float = _player.global_rotation.y if _player else 0.0
		angle = facing + PI + randf_range(-0.5, 0.5)
	return _centre + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


## M30 1.7 — a squad hull's spawn point: at its signed formation bearing off
## the player's bow (+ = starboard), the same convention EnemyAI holds it to.
func _formation_spawn_position(data: EncounterData, bearing_deg: float) -> Vector3:
	var dist: float = randf_range(data.spawn_distance_min, data.spawn_distance_max)
	var fwd := Vector3.FORWARD
	var right := Vector3.RIGHT
	if _player:
		fwd = -_player.global_transform.basis.z
		right = _player.global_transform.basis.x
	fwd.y = 0.0
	right.y = 0.0
	var b := deg_to_rad(bearing_deg)
	var dir := (fwd.normalized() * cos(b) + right.normalized() * sin(b)).normalized()
	return _centre + dir * dist


func _apply_strength(enemy: Node3D, data: EncounterData) -> void:
	## Duplicate-never-mutate: a ShipStats resource is shared by every ship of its
	## class, so scaling the shared copy would permanently buff every future hull.
	## Same rule EnemySpawner already follows.
	if data.strength_multiplier == 1.0:
		return
	if not ("ship_stats" in enemy) or not enemy.ship_stats:
		return
	var scaled: ShipStats = enemy.ship_stats.duplicate()
	scaled.max_health *= data.strength_multiplier
	scaled.cannon_damage *= data.strength_multiplier
	enemy.ship_stats = scaled


func _track(enemy: Node3D) -> void:
	_enemies.append(enemy)
	if enemy.has_signal("ship_destroyed"):
		enemy.ship_destroyed.connect(_on_encounter_enemy_destroyed.bind(enemy))


func _on_encounter_enemy_destroyed(enemy: Node3D) -> void:
	_kills += 1
	_enemies.erase(enemy)
	ship_destroyed.emit(enemy)
	if is_active():
		objective_progress.emit(_kills, get_objective_total())


# === Battle upgrades ===

func get_player_modifiers() -> CombatModifiers:
	if not _player or not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("CombatModifiers") as CombatModifiers


func roll_upgrade_choices(count: int) -> Array[BattleUpgradeData]:
	## Weighted, no duplicates within an offer, never a maxed-out upgrade — the
	## shared roll MaelstromRun also uses (M30 0.15).
	return UpgradeRoller.roll(upgrade_pool, count, get_player_modifiers())


func apply_upgrade_choice(upgrade: BattleUpgradeData) -> bool:
	## The single entry point the choice UI calls. Keeping it here means the UI
	## never has to find the player ship or know how an effect is implemented.
	var mods := get_player_modifiers()
	if not mods or not upgrade:
		return false
	if not mods.apply_upgrade(upgrade):
		return false
	_announce("%s  %s" % [upgrade.icon, upgrade.display_name])
	return true


# === Spyglass Briefing (M30 1.9, W1-2.1) ===

func get_briefing_config() -> SpyglassBriefingData:
	if not briefing_config:
		briefing_config = load(BRIEFING_CONFIG_PATH) as SpyglassBriefingData
		if not briefing_config:
			push_error("EncounterManager: briefing config %s is missing or not a SpyglassBriefingData" % BRIEFING_CONFIG_PATH)
	return briefing_config


## The best Watchtower level on any player-owned island (0 = none): the same
## best-owned-building lookup `TechManager.get_academy_level()` makes.
func get_watchtower_level() -> int:
	if watchtower_level_override >= 0:
		return watchtower_level_override
	if not is_inside_tree():
		return 0
	var best := 0
	for island in get_tree().get_nodes_in_group("islands"):
		if island.island_data and island.island_data.is_owned_by_player() \
				and island.has_method("get_building_level"):
			best = maxi(best, island.get_building_level("watchtower"))
	return best


## What the Spyglass Briefing shows for the live encounter. The roster (one
## role icon per hull) is always there; formation, weaknesses and the star-2
## hint each unlock at their `SpyglassBriefingData` Watchtower level and are
## otherwise blank with `*_locked` set (and the level that unlocks them).
## Empty when no encounter is running.
func build_briefing() -> Dictionary:
	if not is_active():
		return {}
	var cfg := get_briefing_config()
	var data := active_encounter
	var intel := get_watchtower_level()
	var roster: Array = []
	var weaknesses: Array = []
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		var ai = enemy.get_node_or_null("EnemyAI")
		var profile: AIProfileData = ai.ai_profile if ai else null
		var role_key: String = AIProfileData.Role.keys()[profile.role] if profile else "BALANCED"
		var tactic_key: String = AIProfileData.Tactic.keys()[profile.tactic] if profile else "STANDARD"
		roster.append({"role": role_key, "tactic": tactic_key,
			"icon": str(cfg.role_icons.get(role_key, "?")) if cfg else "?"})
		if cfg:
			var weak := ""
			if tactic_key != "STANDARD":
				weak = str(cfg.tactic_weaknesses.get(tactic_key, ""))
			if weak == "":
				weak = str(cfg.role_weaknesses.get(role_key, ""))
			if weak != "" and not weaknesses.has(weak):
				weaknesses.append(weak)

	var formation_level: int = cfg.formation_intel_level if cfg else 0
	var weakness_level: int = cfg.weakness_intel_level if cfg else 0
	var hint_level: int = cfg.star_hint_intel_level if cfg else 0
	var out := {
		"encounter_id": data.encounter_id,
		"title": data.display_name,
		"kind": data.get_kind_name(),
		"intel_level": intel,
		"roster": roster,
		"formation": "",
		"formation_locked": intel < formation_level,
		"formation_level": formation_level,
		"weaknesses": [],
		"weaknesses_locked": intel < weakness_level,
		"weaknesses_level": weakness_level,
		"star_hint": "",
		"star_hint_locked": intel < hint_level,
		"star_hint_level": hint_level,
		"preparations": cfg.preparations.duplicate() if cfg else [],
		"ammo_options": get_briefing_ammo_options(),
		"port_ammo": null,
		"starboard_ammo": null,
	}
	if not out["formation_locked"] and data.squad_tactic:
		out["formation"] = data.squad_tactic.get_formation_name()
	if not out["weaknesses_locked"]:
		out["weaknesses"] = weaknesses
	if not out["star_hint_locked"] and data.star_conditions.size() >= 2 and data.star_conditions[1]:
		out["star_hint"] = data.star_conditions[1].describe()
	var combat := _player_combat()
	if combat:
		out["port_ammo"] = combat.get_ammo_for_side("port")
		out["starboard_ammo"] = combat.get_ammo_for_side("starboard")
	return out


## The loads the briefing offers per side: the player's own ammo cycle.
func get_briefing_ammo_options() -> Array:
	var out: Array = []
	for path in ShipCombat.AMMO_CYCLE:
		var ammo := load(path) as AmmoData
		if ammo:
			out.append(ammo)
		else:
			push_error("EncounterManager: briefing ammo %s failed to load" % path)
	return out


## The briefing's pick: one Preparation (applied through CombatModifiers, so
## it lasts this battle only) and an opening load per side. Any argument may be
## null to leave that part as it is. False when no encounter is running or the
## preparation is not one the briefing offers.
func apply_briefing(preparation: PreparationData, port_ammo: AmmoData, starboard_ammo: AmmoData) -> bool:
	if not is_active():
		return false
	if preparation:
		var cfg := get_briefing_config()
		if not cfg or not cfg.preparations.has(preparation):
			push_error("EncounterManager: preparation '%s' is not offered by the briefing" % preparation.preparation_id)
			return false
		var mods := get_player_modifiers()
		if not preparation.effect or not mods or not mods.apply_upgrade(preparation.effect):
			push_error("EncounterManager: preparation '%s' could not be applied" % preparation.preparation_id)
			return false
	var combat := _player_combat()
	if combat:
		if port_ammo:
			combat.set_side_ammo("port", port_ammo)
		if starboard_ammo:
			combat.set_side_ammo("starboard", starboard_ammo)
	briefing_applied.emit(preparation.preparation_id if preparation else "",
		port_ammo.ammo_id if port_ammo else "", starboard_ammo.ammo_id if starboard_ammo else "")
	return true


func _player_combat() -> ShipCombat:
	if not _player or not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("ShipCombat") as ShipCombat


# === Rewards ===

func _grant_rewards(data: EncounterData) -> Dictionary:
	## Per-kill loot crates already exist (`ShipController._spawn_loot`); this is
	## the completion bonus on top, which is what makes finishing a fight worth
	## more than farming its first two hulls.
	var rewards: Dictionary = {}

	if data.loot_table:
		rewards = data.loot_table.roll()
	if data.bonus_gold > 0:
		rewards["gold"] = int(rewards.get("gold", 0)) + data.bonus_gold

	# Same class/notoriety scaling ShipController applies to kill drops, so the
	# two reward paths cannot drift apart.
	var mult: float = 1.0
	if EmpireManager:
		mult += EmpireManager.notoriety / 100.0
	mult *= data.strength_multiplier

	for key in rewards.keys():
		rewards[key] = int(round(float(rewards[key]) * mult))

	if ResourceManager:
		for key in rewards.keys():
			ResourceManager.add_resource(key, rewards[key])

	if data.notoriety_reward > 0.0 and EmpireManager:
		EmpireManager.add_notoriety(data.notoriety_reward)

	if data.captain_xp > 0 and FleetManager and FleetManager.has_method("get_active_captain"):
		var cap = FleetManager.get_active_captain()
		if cap and cap.has_method("add_xp"):
			cap.add_xp(data.captain_xp)
			rewards["captain_xp"] = data.captain_xp

	return rewards


func _describe_rewards(rewards: Dictionary) -> String:
	if rewards.is_empty():
		return "No spoils."
	var parts: PackedStringArray = []
	for key in ["gold", "wood", "iron", "rum", "captain_xp"]:
		if rewards.has(key) and int(rewards[key]) > 0:
			parts.append("%s %d" % [str(key).capitalize().replace("_", " "), int(rewards[key])])
	return " · ".join(parts)


# === Ambient scheduling ===

func _start_random_ambient() -> void:
	if encounter_pool.is_empty():
		return
	# M9 Requirement 5 (D69) — an ambient encounter previously fired cannons
	# with no on-screen acknowledgment while a tutorial/campaign dialogue beat
	# had focus (reproduced during Chapter 1's opening dialogue). Gate on the
	# same "is a blocking dialogue open" check WorldHUD uses to dim the combat
	# HUD, mirroring the existing required_chapter_id gate below rather than
	# adding a general focus-stack system.
	var tutorial = get_tree().get_first_node_in_group("tutorial_dialogue")
	if tutorial and tutorial.is_blocking():
		return
	var candidates: Array[EncounterData] = []
	for e in encounter_pool:
		if not e or not CampaignManager.is_chapter_current(e.required_chapter_id):
			continue
		# M14 Requirement 2.3 — same shape as the chapter gate just above.
		if not e.required_region_id.is_empty() and not EmpireManager.is_region_active(e.required_region_id):
			continue
		# M14 Requirement 6.1 — a single shared kill-switch check point that
		# covers every ambient encounter, present or future, without
		# per-encounter special-casing. Defaults to enabled (LiveOpsConfig's
		# own contract) so this is a no-op for every pre-M14 encounter too.
		if not LiveOpsConfig.is_content_enabled(e.encounter_id):
			continue
		candidates.append(e)
	if candidates.is_empty():
		return
	var tier: HeatTierData = null
	if EmpireManager and EmpireManager.has_method("get_heat_tier"):
		tier = EmpireManager.get_heat_tier()
	start_encounter(encounter_with_heat_squad(candidates.pick_random(), tier))


## M30 1.7 (W1-1.5) — an encounter that opts in (`use_heat_squad`) and has no
## squad of its own fights a squad drawn from the heat tier's pool. Returns a
## copy; the authored resource is shared and never mutated.
func encounter_with_heat_squad(data: EncounterData, tier: HeatTierData) -> EncounterData:
	if not data or not data.use_heat_squad or not data.squad.is_empty():
		return data
	if not tier or tier.squad_pool.is_empty():
		return data
	var squad: SquadData = tier.squad_pool.pick_random()
	if not squad or squad.slots.is_empty():
		push_error("EncounterManager: heat tier %d has an empty squad in its pool" % tier.tier)
		return data
	var copy := data.duplicate() as EncounterData
	copy.squad = squad.slots.duplicate()
	copy.squad_tactic = squad.tactic
	return copy


func _announce(text: String) -> void:
	# Group lookup, not a node path: the WorldHUD instance is named "WorldUI" in
	# World.tscn, so a "%WorldHUD" lookup always resolved to null.
	var hud = get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud and hud.has_method("announce_event"):
		hud.announce_event(text)
