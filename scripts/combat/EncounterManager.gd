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
var _ambient_timer: float = 0.0
var _offers_made: int = 0
var _offer_timer: float = 0.0
var _disengage_timer: float = 0.0
var _resolving: bool = false


func _ready() -> void:
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

func start_encounter(data: EncounterData) -> bool:
	if not data or is_active():
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

	# Ambient spawning pauses for the duration: the point of a bounded encounter
	# is a known composition, which a background spawner would keep polluting.
	if _spawner and "spawning_enabled" in _spawner:
		_spawner.spawning_enabled = false

	_spawn_composition(data)
	if data.objective == EncounterData.Objective.PROTECT_TARGET:
		_spawn_escort(data)
	_spawn_allies(data)

	# An encounter that could not place a single hull is not an encounter.
	if _enemies.is_empty() and data.objective != EncounterData.Objective.SURVIVE_TIME:
		_restore_spawning()
		active_encounter = null
		return false

	_announce(data.announce_text)
	encounter_started.emit(data)
	objective_progress.emit(0, get_objective_total())
	return true


func abandon() -> void:
	if is_active():
		_resolve(Outcome.ESCAPED)


func _tick_active(delta: float) -> void:
	_elapsed += delta

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

	if outcome == Outcome.VICTORY:
		rewards = _grant_rewards(data)
		_announce("VICTORY — %s\n%s" % [data.display_name, _describe_rewards(rewards)])
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


func _despawn_remaining() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()


# === Composition ===

func _spawn_composition(data: EncounterData) -> void:
	var scene: PackedScene = data.enemy_scene
	if not scene and _spawner and "enemy_scene" in _spawner:
		scene = _spawner.enemy_scene
	if not scene:
		push_error("EncounterManager: encounter '%s' has no enemy scene" % data.encounter_id)
		return

	var container: Node = _spawner.get("_enemies_container") if _spawner else null
	if not container or not is_instance_valid(container):
		container = get_tree().current_scene

	for i in range(data.enemy_count):
		var enemy = scene.instantiate() as Node3D
		if not enemy:
			continue
		container.add_child(enemy)
		enemy.global_transform = Transform3D(
			Basis(Vector3.UP, randf() * TAU), _pick_spawn_position(data, i, data.enemy_count))
		if enemy is RigidBody3D:
			enemy.linear_velocity = Vector3.ZERO
			enemy.angular_velocity = Vector3.ZERO

		_apply_strength(enemy, data)
		_track(enemy)


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
	## Weighted, no duplicates within an offer, and never offers something the
	## player has already maxed out — a choice screen showing an option that does
	## nothing is worse than showing fewer options.
	var out: Array[BattleUpgradeData] = []
	var mods := get_player_modifiers()

	var available: Array[BattleUpgradeData] = []
	for u in upgrade_pool:
		if u and (mods == null or mods.can_apply(u)):
			available.append(u)

	while out.size() < count and not available.is_empty():
		var total: float = 0.0
		for u in available:
			total += u.weight
		var roll: float = randf() * total
		var acc: float = 0.0
		var picked: BattleUpgradeData = available[available.size() - 1]
		for u in available:
			acc += u.weight
			if roll <= acc:
				picked = u
				break
		out.append(picked)
		available.erase(picked)

	return out


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
		if e and CampaignManager.is_chapter_current(e.required_chapter_id):
			candidates.append(e)
	if candidates.is_empty():
		return
	start_encounter(candidates.pick_random())


func _announce(text: String) -> void:
	# Group lookup, not a node path: the WorldHUD instance is named "WorldUI" in
	# World.tscn, so a "%WorldHUD" lookup always resolved to null.
	var hud = get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud and hud.has_method("announce_event"):
		hud.announce_event(text)
