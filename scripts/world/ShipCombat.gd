class_name ShipCombat extends Node

## Purpose: Manages combat logic for ships (health, firing).
## Responsibilities: Takes damage, emits health signals, handles firing cannons.
## Dependencies: ShipStats, Cannonball.tscn

signal health_changed(new_health: float, max_health: float)
signal died()
signal fired(side: String)
## Emitted when a side gains or loses a valid target in its firing arc. This is
## what drives the broadside indicator in `WorldHUD` — the player needs to see
## alignment *before* the guns speak, not only after (`docs/navalCombat.md` §5.2).
signal arc_lock_changed(side: String, locked: bool)
signal special_broadside_fired()
signal special_broadside_ready()

@export var ship_stats: ShipStats
@export var current_ammo: AmmoData
## When true, this ship fires automatically as soon as a hostile is inside a
## side's arc and that side has reloaded — the model `docs/navalCombat.md` §4
## locks in. Player skill moves from tapping to positioning. Off leaves the
## pre-rework manual trigger as the only way to fire, which is how
## `tests/test_ship_combat.gd` still exercises `fire_broadside()` directly.
@export var auto_fire_enabled: bool = true

func set_ammo(ammo: AmmoData) -> void:
	current_ammo = ammo

var cannonball_scene: PackedScene = preload("res://scenes/combat/Cannonball.tscn")
var floating_damage_scene: PackedScene = preload("res://scenes/ui/FloatingDamage.tscn")
var cannon_model_scene: PackedScene = preload("res://assets/models/cannon.glb")

var can_fire_port: bool = true
var can_fire_starboard: bool = true
var can_fire_bow: bool = true
var can_fire_stern: bool = true

# References to marker nodes on the ship where cannonballs spawn
var port_markers: Array[Node3D] = []
var starboard_markers: Array[Node3D] = []
## Chaser mounts (`docs/navalCombat.md` §3) — empty on any hull that doesn't
## author a BowMarker/SternMarker node, regardless of `ship_stats.has_*_chaser`.
var bow_markers: Array[Node3D] = []
var stern_markers: Array[Node3D] = []

var _fallback_health: float = -1.0

var current_health: float:
	get:
		var dmg = _get_damage()
		if dmg:
			return dmg.hull
		return _fallback_health
	set(value):
		## M6 made this property getter-only when it became a proxy onto
		## ShipDamage.hull, but left five callers still assigning to it —
		## ShipController.respawn(), ShipController._apply_tech_modifiers(),
		## DockingSystem._process_healing(), SaveManager.load_game() and
		## IslandMenu's ship-purchase path. All five silently wrote to nothing,
		## which is why respawn produced an unkillable hull-0 ship and shipyard
		## repair did not repair. Forwarding here fixes all of them at once and
		## keeps `current_health` a legitimate part of the public API that
		## test_ship_combat.gd and EnemyAI already read.
		var dmg = _get_damage()
		if dmg:
			var delta_hp: float = value - dmg.hull
			if delta_hp > 0.0:
				dmg.repair("hull", delta_hp)
			elif delta_hp < 0.0:
				dmg.hull = maxf(value, 0.0)
				dmg.pool_changed.emit("hull", dmg.hull, dmg.get_pool_maximum("hull"))
		else:
			_fallback_health = value

func _get_damage() -> Node:
	var parent = get_parent()
	return parent.get_node_or_null("ShipDamage") if parent else null

func _get_solver() -> FiringSolver:
	var parent = get_parent()
	if not parent:
		return null
	return parent.get_node_or_null("FiringSolver") as FiringSolver

func _get_modifiers() -> CombatModifiers:
	var parent = get_parent()
	if not parent:
		return null
	return parent.get_node_or_null("CombatModifiers") as CombatModifiers

## Damage multiplier applied to the next volley. The special broadside uses this
## rather than mutating ship_stats.cannon_damage, because a ShipStats resource is
## shared by every ship of that class — the same duplicate-never-mutate rule
## `EnemySpawner.compute_spawn_multiplier()` follows.
var _volley_damage_multiplier: float = 1.0
var _special_cooldown_remaining: float = 0.0
var _arc_locked := {"port": false, "starboard": false, "bow": false, "stern": false}

func _ready() -> void:
	if not ship_stats:
		push_warning("ShipCombat: No ShipStats assigned.")
		return
		
	var parent = get_parent()
	# Find markers. Expecting them to be named "PortMarkerX" or "StarboardMarkerX"
	if parent:
		for child in parent.get_children():
			if child is Node3D:
				if child.name.begins_with("PortMarker"):
					port_markers.append(child)
				elif child.name.begins_with("StarboardMarker"):
					starboard_markers.append(child)
				elif child.name.begins_with("BowMarker"):
					bow_markers.append(child)
				elif child.name.begins_with("SternMarker"):
					stern_markers.append(child)
					
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg:
		if not dmg.is_connected("destroyed", Callable(self, "die")):
			dmg.destroyed.connect(Callable(self, "die"))
		if not dmg.is_connected("pool_changed", Callable(self, "_on_pool_changed")):
			dmg.pool_changed.connect(Callable(self, "_on_pool_changed"))
			
		call_deferred("emit_signal", "health_changed", dmg.hull, dmg.get_effective_max_health())
	else:
		# Fallback for tests that do not mock ShipDamage
		var health_mod = 1.0
		if parent and "active_captain" in parent and parent.active_captain:
			health_mod = parent.active_captain.health_modifier
			
		if parent and parent.is_in_group("player_ship") and get_tree().root.has_node("TechManager"):
			var TechManager = get_tree().root.get_node("TechManager")
			health_mod *= TechManager.global_health_mod
			
		_fallback_health = ship_stats.max_health * health_mod
		call_deferred("emit_signal", "health_changed", _fallback_health, ship_stats.max_health)

	_spawn_cannon_models()

func _on_pool_changed(pool: String, current: float, maximum: float) -> void:
	if pool == "hull":
		health_changed.emit(current, maximum)

func _spawn_cannon_models() -> void:
	if not cannon_model_scene:
		return
	# Bow/stern mounts exist on the shared PlayerShip/EnemyShip scenes regardless
	# of which ShipStats is currently equipped (hulls swap stats, not scenes), so
	# whether a chaser is actually there to model is a `ship_stats` question, not
	# a "does the marker node exist" one.
	var chaser_markers: Array[Node3D] = []
	if ship_stats.has_bow_chaser:
		chaser_markers.append_array(bow_markers)
	if ship_stats.has_stern_chaser:
		chaser_markers.append_array(stern_markers)
	for marker in port_markers + starboard_markers + chaser_markers:
		var cannon = cannon_model_scene.instantiate()
		marker.add_child(cannon)
		# cannon.glb is a ~2-unit cube with a centred pivot, which on a 4.6-wide
		# hull rendered as an oversized grey block floating beside the deck with
		# half its body buried below it. Scale it to something a gun port could
		# plausibly hold, and lift it by half its scaled height so it rests ON
		# the deck rather than straddling it.
		if cannon is Node3D:
			const CANNON_SCALE := 0.45
			cannon.scale = Vector3.ONE * CANNON_SCALE
			cannon.position.y += CANNON_SCALE
		var applier = preload("res://scripts/components/KenneyMaterialApplier.gd").new()
		cannon.add_child(applier)

func take_damage(amount: float, ammo: AmmoData = null, hit_direction: Vector3 = Vector3.ZERO) -> void:
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg:
		# Use default round shot if no ammo is provided (for tests or legacy calls)
		var hit_ammo = ammo if ammo else load("res://resources/combat/ammo/RoundShot.tres")
		dmg.apply_hit(amount, hit_ammo, hit_direction)
	else:
		if _fallback_health <= 0: return
		var max_hp = ship_stats.max_health
		if parent and "active_captain" in parent and parent.active_captain:
			max_hp *= parent.active_captain.health_modifier
			
		if parent and parent.is_in_group("player_ship") and get_tree().root.has_node("TechManager"):
			var TechManager = get_tree().root.get_node("TechManager")
			max_hp *= TechManager.global_health_mod
			
		_fallback_health -= amount
		health_changed.emit(_fallback_health, max_hp)
		
		if _fallback_health <= 0:
			_fallback_health = 0.0
			die()

	# Spawn floating text
	if floating_damage_scene:
		var text = floating_damage_scene.instantiate()
		text.damage_amount = amount
		get_tree().current_scene.add_child(text)
		
		# Position slightly above the ship with random jitter
		var jitter = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		text.global_position = parent.global_position + Vector3(0, 3.0, 0) + jitter

func die() -> void:
	died.emit()
	# Handled by ShipController._on_died(), connected to this signal.


func _physics_process(delta: float) -> void:
	if _special_cooldown_remaining > 0.0:
		_special_cooldown_remaining -= delta
		if _special_cooldown_remaining <= 0.0:
			_special_cooldown_remaining = 0.0
			special_broadside_ready.emit()

	var solver := _get_solver()
	if not solver:
		return

	# Publish arc state every frame regardless of auto-fire, so the indicator
	# still reads correctly for a ship with auto-fire switched off. Bow/stern
	# only enter rotation for a hull that actually carries that mount.
	var sides: Array[String] = [FiringSolver.SIDE_PORT, FiringSolver.SIDE_STARBOARD]
	if not bow_markers.is_empty() and ship_stats.has_bow_chaser:
		sides.append(FiringSolver.SIDE_BOW)
	if not stern_markers.is_empty() and ship_stats.has_stern_chaser:
		sides.append(FiringSolver.SIDE_STERN)

	for side in sides:
		var locked: bool = solver.is_aligned(side)
		if locked != _arc_locked[side]:
			_arc_locked[side] = locked
			arc_lock_changed.emit(side, locked)

	if not auto_fire_enabled:
		return

	var parent = get_parent()
	if parent and "is_docked" in parent and parent.is_docked:
		return

	# Automatic fire: the reload gate is the existing per-side cooldown, and the
	# aim gate is the solver. Nothing else — positioning is the whole skill.
	for side in sides:
		if _arc_locked[side]:
			_fire_through_controller(side)


func _fire_through_controller(side: String) -> void:
	## Route through ShipController.fire_cannons() when possible so recoil, smoke
	## and the cannon SFX fire too — those live on the controller and would be
	## silently lost if auto-fire called fire_broadside() directly.
	var parent = get_parent()
	if parent and parent.has_method("fire_cannons"):
		parent.fire_cannons(side)
	else:
		fire_broadside(side)


func is_special_broadside_ready() -> bool:
	return _special_cooldown_remaining <= 0.0


func get_special_cooldown_fraction() -> float:
	## 0.0 = just fired, 1.0 = ready. For the HUD.
	if not ship_stats or ship_stats.special_broadside_cooldown <= 0.0:
		return 1.0
	var elapsed: float = ship_stats.special_broadside_cooldown - _special_cooldown_remaining
	return clamp(elapsed / ship_stats.special_broadside_cooldown, 0.0, 1.0)


func fire_special_broadside() -> bool:
	## The player-timed full volley of `docs/navalCombat.md` §4: both sides at
	## once, at a damage premium, ignoring the per-side reload but gated on its
	## own longer cooldown. This is the active verb that replaces tapping.
	if not ship_stats or not is_special_broadside_ready():
		return false

	var dmg = _get_damage()
	if dmg and dmg.crew <= 0.0:
		return false

	var parent = get_parent()
	if parent and "is_docked" in parent and parent.is_docked:
		return false

	var solver := _get_solver()
	if solver:
		solver.force_rescan()

	_volley_damage_multiplier = ship_stats.special_broadside_damage_multiplier
	# Bypass the reload gate — that is what makes this a *special*.
	var was_port := can_fire_port
	var was_starboard := can_fire_starboard
	can_fire_port = true
	can_fire_starboard = true

	var any := false
	for side in [FiringSolver.SIDE_PORT, FiringSolver.SIDE_STARBOARD]:
		if not (port_markers if side == FiringSolver.SIDE_PORT else starboard_markers).is_empty():
			_fire_through_controller(side)
			any = true

	_volley_damage_multiplier = 1.0

	if not any:
		can_fire_port = was_port
		can_fire_starboard = was_starboard
		return false

	var mods := _get_modifiers()
	var cd_mult: float = mods.special_cooldown_mult if mods else 1.0
	_special_cooldown_remaining = ship_stats.special_broadside_cooldown * cd_mult
	special_broadside_fired.emit()
	return true


func fire_broadside(side: String) -> bool:
	if not ship_stats:
		return false
		
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg and dmg.crew <= 0.0:
		return false

	var can_fire := {"port": can_fire_port, "starboard": can_fire_starboard,
		"bow": can_fire_bow, "stern": can_fire_stern}
	if side in can_fire and not can_fire[side]:
		return false

	var markers_by_side := {"port": port_markers, "starboard": starboard_markers,
		"bow": bow_markers, "stern": stern_markers}
	var markers: Array[Node3D] = markers_by_side.get(side, [])
	var fired_any = false

	for marker in markers:
		_spawn_cannonball(marker, side)
		fired_any = true

	if fired_any:
		fired.emit(side)
		_start_cooldown(side)

	return fired_any

func _spawn_cannonball(marker: Node3D, side: String) -> void:
	if not cannonball_scene:
		return

	_spawn_muzzle_flash(marker)
	
	var ammo_data = current_ammo if current_ammo else load("res://resources/combat/ammo/RoundShot.tres")

	for i in range(ammo_data.projectiles_per_cannon):
		var ball = cannonball_scene.instantiate() as RigidBody3D
		# Add to main world, not as child of ship
		get_tree().current_scene.add_child(ball)
		
		ball.global_transform = marker.global_transform
		
		if ball is Cannonball:
			var dmg_mod = 1.0
			var parent = get_parent()
			if parent and "active_captain" in parent and parent.active_captain:
				dmg_mod = parent.active_captain.damage_modifier
				
			if parent and parent.is_in_group("player_ship") and get_tree().root.has_node("TechManager"):
				var TechManager = get_tree().root.get_node("TechManager")
				dmg_mod *= TechManager.global_damage_mod
				
			# Temporary battle upgrades and captain abilities stack in here,
			# alongside the captain passive and tech modifiers already applied
			# above — never by mutating the shared ShipStats resource.
			var mods := _get_modifiers()
			if mods:
				dmg_mod *= mods.damage_mult

			var base_damage: float = ship_stats.chaser_damage \
				if (side == FiringSolver.SIDE_BOW or side == FiringSolver.SIDE_STERN) \
				else ship_stats.cannon_damage
			ball.damage = base_damage * dmg_mod * _volley_damage_multiplier
			ball.source_ship = parent
			ball.ammo = ammo_data

		# Launch direction comes from the ship hull's own basis rather than the
		# marker's own rotation. Broadside guns fire along the beam (basis.x);
		# chasers fire along the keel (basis.z) instead.
		var parent = get_parent()
		var forward = Vector3.RIGHT
		if parent is Node3D:
			match side:
				FiringSolver.SIDE_BOW:
					forward = -parent.global_transform.basis.z.normalized()
				FiringSolver.SIDE_STERN:
					forward = parent.global_transform.basis.z.normalized()
				FiringSolver.SIDE_PORT:
					forward = -parent.global_transform.basis.x.normalized()
				_:
					forward = parent.global_transform.basis.x.normalized()
			
		if ammo_data.spread_degrees > 0.0:
			var spread_rad = deg_to_rad(ammo_data.spread_degrees)
			var angle = randf_range(-spread_rad * 0.5, spread_rad * 0.5)
			forward = forward.rotated(Vector3.UP, angle)

		# Also inherit ship's velocity if possible
		var base_vel = Vector3.ZERO
		if parent is RigidBody3D:
			base_vel = parent.linear_velocity

		ball.linear_velocity = base_vel + (forward * ship_stats.cannon_speed * ammo_data.speed_mult)

func _spawn_muzzle_flash(marker: Node3D) -> void:
	## A brief bright point light at the cannon mouth — there was previously
	## no visual event at the firing point at all beyond the ball itself.
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.4)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = marker.global_position

	var tween = flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _start_cooldown(side: String) -> void:
	var rate = ship_stats.fire_rate
	
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg and "optimal_crew_fraction" in ship_stats:
		var crew_pct = dmg.crew / max(ship_stats.max_crew, 1.0)
		if crew_pct < ship_stats.optimal_crew_fraction and ship_stats.optimal_crew_fraction > 0.0:
			var penalty = crew_pct / ship_stats.optimal_crew_fraction
			rate *= max(penalty, 0.1)
			
	# "Rapid Reload"-style upgrades multiply the rate here rather than writing to
	# ship_stats.fire_rate, which is shared by every hull of this class.
	var mods := _get_modifiers()
	if mods:
		rate *= mods.fire_rate_mult

	var cooldown_time = 1.0 / max(rate, 0.1)

	match side:
		FiringSolver.SIDE_PORT:
			can_fire_port = false
			get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_port = true)
		FiringSolver.SIDE_BOW:
			can_fire_bow = false
			get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_bow = true)
		FiringSolver.SIDE_STERN:
			can_fire_stern = false
			get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_stern = true)
		_:
			can_fire_starboard = false
			get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_starboard = true)
