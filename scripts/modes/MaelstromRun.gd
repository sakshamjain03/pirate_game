class_name MaelstromRun extends Node

## Purpose: one Maelstrom run (M26) — the endless survival mode's state machine.
## Responsibilities: tracks time survived, drives EnemySpawner through the authored
##   MaelstromCurveData band for that time, turns every kill into floating pickups,
##   routes pickups (plunder -> run XP, repair, timed power-up, powder keg), queues
##   level-up offers for UpgradeChoiceScreen, and ends the run when the ship sinks.
## Dependencies: MaelstromCurveData, EnemySpawner (child), CombatModifiers (player
##   child), LootDrop, UpgradeChoiceScreen (binding contract), SaveManager.
##
## Isolation (Requirement 2): everything here is scene-local and freed with the
## scene. The only campaign-visible write is SaveManager.save_maelstrom_result()
## at the end of a run — never SaveManager.save_game(), which would write whatever
## default state the managers hold when the run was started from the main menu.

## UpgradeChoiceScreen's binding contract (same shape as EncounterManager's).
signal upgrade_offer_requested(choices: Array, offer_index: int, total_offers: int)
## Also part of that contract: closes an open choice panel if the ship sinks.
signal encounter_ended(victory: bool, rewards: Dictionary)
signal run_ended(summary: Dictionary)
signal stats_changed()

enum State { READY, RUNNING, OFFERING, ENDED }

const MAELSTROM_SCENE := "res://scenes/modes/Maelstrom.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@export var curve: MaelstromCurveData = preload("res://resources/balance/MaelstromCurve.tres")
@export var loot_scene: PackedScene = preload("res://scenes/combat/LootDrop.tscn")
@export var spawner_path: NodePath = ^"EnemySpawner"
## Optional; bound at _ready when present.
@export var choice_screen_path: NodePath
## Optional; a MeshInstance3D with a CylinderMesh, sized to curve.arena_radius so
## the wall you see is exactly where the push starts (one source for the number).
@export var storm_wall_path: NodePath

var state: State = State.READY
var elapsed: float = 0.0
var kills: int = 0
var level: int = 1
var xp: float = 0.0
var eights_earned: int = 0

var _pending_offers: int = 0
var _band_index: int = -1
var _player: RigidBody3D = null
var _modifiers: CombatModifiers = null
var _spawner: EnemySpawner = null


func _ready() -> void:
	# Defensive: the main menu already set it. Every kill/pickup guard reads this.
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	_spawner = get_node_or_null(spawner_path) as EnemySpawner
	if _spawner:
		# Set synchronously, before the spawner's deferred _initialize() sizes its
		# first wave from get_active_max_enemies().
		_spawner.spawn_profile_override = _profile
		_spawner.enemy_destroyed.connect(_on_enemy_destroyed)
	else:
		push_error("MaelstromRun: no EnemySpawner at '%s'" % spawner_path)
	var screen = get_node_or_null(choice_screen_path) if not choice_screen_path.is_empty() else null
	if screen and screen.has_method("bind_encounter_manager"):
		screen.bind_encounter_manager(self)
	var wall = get_node_or_null(storm_wall_path) if not storm_wall_path.is_empty() else null
	if wall is MeshInstance3D and wall.mesh is CylinderMesh:
		var mesh: CylinderMesh = wall.mesh.duplicate()
		mesh.top_radius = curve.arena_radius
		mesh.bottom_radius = curve.arena_radius
		wall.mesh = mesh
	bind_player(get_tree().get_first_node_in_group("player_ship") as RigidBody3D)
	state = State.RUNNING


func bind_player(player: RigidBody3D) -> void:
	_player = player
	if not _player:
		push_error("MaelstromRun: no player_ship in the scene")
		return
	_modifiers = _player.get_node_or_null("CombatModifiers") as CombatModifiers
	if _modifiers:
		_modifiers.reset()   # a fresh build every run, even if the ship node is reused
	_apply_active_hull()
	if _player.has_signal("ship_destroyed") and not _player.ship_destroyed.is_connected(_end_run):
		_player.ship_destroyed.connect(_end_run)


func _apply_active_hull() -> void:
	## Requirement 1.3 — the player's active hull, read-only. FleetManager is only
	## populated from the save once World has loaded this session; on a cold start
	## it holds its own starter Sloop, which is what PlayerShip.tscn carries anyway.
	var stats: ShipStats = FleetManager.get_active_ship() if FleetManager.has_method("get_active_ship") else null
	if stats and "ship_stats" in _player and _player.ship_stats != stats:
		_player.ship_stats = stats
	var dmg = _player.get_node_or_null("ShipDamage")
	if dmg and dmg.has_method("repair"):
		for pool in ["hull", "sails", "crew"]:
			dmg.repair(pool, dmg.get_pool_maximum(pool))


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if state == State.ENDED or state == State.READY:
		return
	elapsed += delta
	var idx := curve.band_index_at(elapsed)
	if idx != _band_index:
		_enter_band(idx)
	_maybe_offer()


func _physics_process(_delta: float) -> void:
	## The storm wall: past arena_radius the sea itself shoves the ship back in.
	## A plain central force from outside — ShipMovement/BuoyancySimulator are
	## untouched (CLAUDE.md fragile areas).
	if state == State.ENDED or not is_instance_valid(_player):
		return
	var flat := Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	var over := flat.length() - curve.arena_radius
	if over > 0.0:
		_player.apply_central_force(-flat.normalized() * curve.storm_push_force * _player.mass * (1.0 + over * 0.1))


func _enter_band(idx: int) -> void:
	_band_index = idx
	var band: MaelstromBandData = curve.bands[idx]
	if band.boss_scene and _spawner:
		_spawner.spawn_scene(band.boss_scene, band.strength_multiplier)
	stats_changed.emit()


func _profile() -> Dictionary:
	## EnemySpawner.spawn_profile_override — read live, so a band change applies
	## to the very next spawn with no re-binding.
	var band := curve.band_at(elapsed)
	if not band:
		return {"cap": 0, "interval": 999.0, "strength": 1.0, "pool": []}
	return {
		"cap": band.max_enemies,
		"interval": band.spawn_interval,
		"strength": band.strength_multiplier,
		"pool": band.ship_pool,
	}


func get_band_index() -> int:
	return _band_index


# ------------------------------------------------------------------ kills + pickups

func _on_enemy_destroyed(enemy: Node3D) -> void:
	if state == State.ENDED:
		return
	var pos: Vector3 = enemy.global_position if is_instance_valid(enemy) else Vector3.ZERO
	_on_kill(pos)


func _on_kill(pos: Vector3) -> void:
	## Requirement 4.1 — every kill scatters one or more rolled pickups.
	kills += 1
	var n := randi_range(curve.drops_per_kill.x, curve.drops_per_kill.y)
	for i in range(n):
		var drop := _roll_drop()
		if not drop.is_empty():
			_spawn_pickup(drop, pos)
	stats_changed.emit()


func _roll_drop() -> Dictionary:
	var total := 0.0
	for d in curve.drops:
		total += float(d.get("weight", 0.0))
	if total <= 0.0:
		return {}
	var roll := randf() * total
	for d in curve.drops:
		roll -= float(d.get("weight", 0.0))
		if roll <= 0.0:
			return d
	return curve.drops.back()


func _spawn_pickup(data: Dictionary, at: Vector3) -> LootDrop:
	var drop := loot_scene.instantiate() as LootDrop
	drop.loot_data = data.duplicate(true)
	drop.lifetime = curve.pickup_lifetime
	var radius_mult: float = _modifiers.pickup_radius_mult if _modifiers else 1.0
	drop.pickup_range = curve.base_pickup_radius * radius_mult
	drop.magnet_range = drop.pickup_range * curve.magnet_range_mult
	# Set before entering the tree: LootDrop caches its bob height in _ready().
	var jitter := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	drop.position = Vector3(at.x, 1.5, at.z) + jitter
	drop.collected.connect(_on_pickup_collected.bind(drop))
	_pickup_parent().add_child(drop)
	return drop


func _pickup_parent() -> Node:
	var p := get_parent()
	return p if p is Node3D else get_tree().current_scene


func _on_pickup_collected(data: Dictionary, drop: LootDrop) -> void:
	_on_pickup(data, drop.global_position if is_instance_valid(drop) else Vector3.ZERO)


func _on_pickup(data: Dictionary, at: Vector3 = Vector3.ZERO) -> void:
	## Requirement 4.2. None of these branches touches ResourceManager.
	if state == State.ENDED:
		return
	match str(data.get("kind", "")):
		"plunder":
			add_plunder(float(data.get("amount", 0.0)))
		"repair":
			if _modifiers:
				_modifiers.repair_pool("hull", float(data.get("amount", 0.0)))
		"powerup":
			if _modifiers:
				_modifiers.add_timed_effect(data.get("effect", {}), float(data.get("duration", 0.0)))
		"keg":
			_detonate_keg(at)
		var other:
			push_error("MaelstromRun: unknown pickup kind '%s'" % other)
	stats_changed.emit()


func _detonate_keg(at: Vector3) -> void:
	## Area damage through each hull's normal ShipCombat.take_damage() path, so a
	## keg kill sinks, drops and counts exactly like a cannon kill.
	if AudioManager: AudioManager.play_sound("explosion")
	if not _spawner:
		return
	for enemy in _spawner._active_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(at) > curve.keg_radius:
			continue
		var combat = enemy.get_node_or_null("ShipCombat")
		if combat and combat.has_method("take_damage"):
			combat.take_damage(curve.keg_damage)


func add_plunder(amount: float) -> void:
	## Requirement 5.4 — several thresholds crossed at once queue several offers.
	xp += amount
	while xp >= curve.xp_for_level(level):
		xp -= curve.xp_for_level(level)
		level += 1
		_pending_offers += 1
	stats_changed.emit()


func xp_fraction() -> float:
	return clampf(xp / float(curve.xp_for_level(level)), 0.0, 1.0)


# ------------------------------------------------------------------ level-up offers

func pending_offers() -> int:
	return _pending_offers


func _maybe_offer() -> void:
	if state != State.RUNNING or _pending_offers <= 0:
		return
	var choices := pick_choices()
	if choices.is_empty():
		# Every upgrade is maxed out — nothing left to offer, so don't hang.
		_pending_offers = 0
		return
	state = State.OFFERING
	upgrade_offer_requested.emit(choices, level, 0)


func pick_choices() -> Array:
	## Weighted sample without replacement from the authored pool, never a
	## maxed-out upgrade — the shared roll EncounterManager also uses (M30 0.15).
	return UpgradeRoller.roll(curve.upgrade_pool, curve.choices_per_offer, _modifiers)


func apply_upgrade_choice(upgrade: BattleUpgradeData) -> void:
	if _modifiers:
		_modifiers.apply_upgrade(upgrade)
	_pending_offers = maxi(0, _pending_offers - 1)
	if state == State.OFFERING:
		state = State.RUNNING   # the next queued offer goes out on the next frame
	stats_changed.emit()


# ------------------------------------------------------------------ run end

func end_run_early() -> void:
	## The HUD's "abandon" button: a quit still counts as a finished run.
	_end_run()


func _end_run() -> void:
	if state == State.ENDED:
		return
	var was_offering := state == State.OFFERING
	state = State.ENDED
	if _spawner:
		_spawner.spawning_enabled = false
	if was_offering:
		encounter_ended.emit(false, {})
	eights_earned = curve.eights_for(elapsed)
	var record: Dictionary = {}
	if SaveManager.has_method("save_maelstrom_result"):
		record = SaveManager.save_maelstrom_result(eights_earned, elapsed, level)
	run_ended.emit({
		"seconds": elapsed,
		"kills": kills,
		"level": level,
		"eights": eights_earned,
		"best_seconds": float(record.get("best_seconds", elapsed)),
		"best_level": int(record.get("best_level", level)),
		"runs": int(record.get("runs", 1)),
	})


func retry() -> void:
	get_tree().paused = false
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	SceneManager.change_scene_with_fade(MAELSTROM_SCENE)


func quit_to_menu() -> void:
	## Requirement 1.4 — CAMPAIGN is restored before any other scene loads.
	get_tree().paused = false
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	SceneManager.change_scene_with_fade(MAIN_MENU_SCENE)
