class_name ShipCombat extends Node

## Purpose: Manages combat logic for ships (health, firing).
## Responsibilities: Takes damage, emits health signals, handles firing cannons.
## Dependencies: ShipStats, Cannonball.tscn

signal health_changed(new_health: float, max_health: float)
signal died()
signal fired(side: String)

@export var ship_stats: ShipStats
@export var current_ammo: AmmoData

func set_ammo(ammo: AmmoData) -> void:
	current_ammo = ammo

var cannonball_scene: PackedScene = preload("res://scenes/combat/Cannonball.tscn")
var floating_damage_scene: PackedScene = preload("res://scenes/ui/FloatingDamage.tscn")
var cannon_model_scene: PackedScene = preload("res://assets/models/cannon.glb")

var can_fire_port: bool = true
var can_fire_starboard: bool = true

# References to marker nodes on the ship where cannonballs spawn
var port_markers: Array[Node3D] = []
var starboard_markers: Array[Node3D] = []

var _fallback_health: float = -1.0

var current_health: float:
	get:
		var parent = get_parent()
		var dmg = parent.get_node_or_null("ShipDamage") if parent else null
		if dmg:
			return dmg.hull
		return _fallback_health

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
	for marker in port_markers + starboard_markers:
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

func fire_broadside(side: String) -> bool:
	if not ship_stats:
		return false
		
	var parent = get_parent()
	var dmg = parent.get_node_or_null("ShipDamage") if parent else null
	if dmg and dmg.crew <= 0.0:
		return false

	if side == "port" and not can_fire_port:
		return false
	if side == "starboard" and not can_fire_starboard:
		return false

	var markers = port_markers if side == "port" else starboard_markers
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
				
			ball.damage = ship_stats.cannon_damage * dmg_mod
			ball.source_ship = parent
			ball.ammo = ammo_data
		
		# Launch direction comes from the ship hull's own basis rather than the
		# marker's own rotation
		var parent = get_parent()
		var forward = Vector3.RIGHT
		if parent is Node3D:
			forward = parent.global_transform.basis.x.normalized()
		if side == "port":
			forward = -forward
			
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
			
	var cooldown_time = 1.0 / max(rate, 0.1)
	
	if side == "port":
		can_fire_port = false
		get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_port = true)
	else:
		can_fire_starboard = false
		get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_starboard = true)
