class_name ShipCombat extends Node

## Purpose: Manages combat logic for ships (health, firing).
## Responsibilities: Takes damage, emits health signals, handles firing cannons.
## Dependencies: ShipStats, Cannonball.tscn

signal health_changed(new_health: float, max_health: float)
signal died()
signal fired(side: String)

@export var ship_stats: ShipStats

var cannonball_scene: PackedScene = preload("res://scenes/combat/Cannonball.tscn")
var floating_damage_scene: PackedScene = preload("res://scenes/ui/FloatingDamage.tscn")
var cannon_model_scene: PackedScene = preload("res://assets/models/cannon.glb")

var current_health: float = 100.0
var can_fire_port: bool = true
var can_fire_starboard: bool = true

# References to marker nodes on the ship where cannonballs spawn
var port_markers: Array[Node3D] = []
var starboard_markers: Array[Node3D] = []

func _ready() -> void:
	if not ship_stats:
		push_warning("ShipCombat: No ShipStats assigned.")
		return
		
	var parent = get_parent()
	var health_mod = 1.0
	if parent and "active_captain" in parent and parent.active_captain:
		health_mod = parent.active_captain.health_modifier
		
	if parent and parent.is_in_group("player_ship") and TechManager:
		health_mod *= TechManager.global_health_mod
		
	current_health = ship_stats.max_health * health_mod
	
	# Find markers. Expecting them to be named "PortMarkerX" or "StarboardMarkerX"
	if parent:
		for child in parent.get_children():
			if child is Node3D:
				if child.name.begins_with("PortMarker"):
					port_markers.append(child)
				elif child.name.begins_with("StarboardMarker"):
					starboard_markers.append(child)
					
	# Emit initial health
	call_deferred("emit_signal", "health_changed", current_health, ship_stats.max_health)

	_spawn_cannon_models()

func _spawn_cannon_models() -> void:
	## The markers themselves are bare, invisible Marker3D nodes — every ship
	## fired from what looked like an empty hull. Their forward direction
	## (-Z) now correctly points outward (see the marker-orientation fix),
	## so instancing the cannon at identity local rotation just works.
	if not cannon_model_scene:
		return
	for marker in port_markers + starboard_markers:
		var cannon = cannon_model_scene.instantiate()
		marker.add_child(cannon)
		var applier = preload("res://scripts/components/KenneyMaterialApplier.gd").new()
		cannon.add_child(applier)

func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
		
	var max_hp = ship_stats.max_health
	var parent = get_parent()
	if parent and "active_captain" in parent and parent.active_captain:
		max_hp *= parent.active_captain.health_modifier
		
	if parent and parent.is_in_group("player_ship") and TechManager:
		max_hp *= TechManager.global_health_mod
		
	current_health -= amount
	health_changed.emit(current_health, max_hp)
	
	# Spawn floating text
	if floating_damage_scene:
		var text = floating_damage_scene.instantiate()
		text.damage_amount = amount
		get_tree().current_scene.add_child(text)
		
		# Position slightly above the ship with random jitter
		var jitter = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		text.global_position = get_parent().global_position + Vector3(0, 3.0, 0) + jitter
	
	if current_health <= 0:
		current_health = 0
		die()

func die() -> void:
	died.emit()
	# Handled by ShipController._on_died(), connected to this signal.

func fire_broadside(side: String) -> bool:
	if not ship_stats:
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

	var ball = cannonball_scene.instantiate() as RigidBody3D
	# Add to main world, not as child of ship
	get_tree().current_scene.add_child(ball)
	
	ball.global_transform = marker.global_transform
	
	if ball is Cannonball:
		var dmg_mod = 1.0
		var parent = get_parent()
		if parent and "active_captain" in parent and parent.active_captain:
			dmg_mod = parent.active_captain.damage_modifier
			
		if parent and parent.is_in_group("player_ship") and TechManager:
			dmg_mod *= TechManager.global_damage_mod
			
		ball.damage = ship_stats.cannon_damage * dmg_mod
		ball.source_ship = parent
	
	# Launch direction comes from the ship hull's own basis rather than the
	# marker's own rotation — robust even if a ship scene's marker transforms
	# are ever re-authored incorrectly again (this exact class of bug hit all
	# 12 markers across all 3 ship scenes previously). +X is starboard, -X is
	# port (Godot's right-handed convention).
	var parent = get_parent()
	var forward = Vector3.RIGHT
	if parent is Node3D:
		forward = parent.global_transform.basis.x.normalized()
	if side == "port":
		forward = -forward

	# Also inherit ship's velocity if possible
	var base_vel = Vector3.ZERO
	if parent is RigidBody3D:
		base_vel = parent.linear_velocity

	ball.linear_velocity = base_vel + (forward * ship_stats.cannon_speed)

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
	var cooldown_time = 1.0 / max(ship_stats.fire_rate, 0.1)
	
	if side == "port":
		can_fire_port = false
		get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_port = true)
	else:
		can_fire_starboard = false
		get_tree().create_timer(cooldown_time).timeout.connect(func(): can_fire_starboard = true)
