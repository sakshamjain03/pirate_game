class_name ShipController extends RigidBody3D

## Purpose: Top-level controller for the player ship.
## Responsibilities: Orchestrates movement, buoyancy, and visual sub-systems; handles dock/undock,
##   cannon fire VFX, loot drop and respawn on death. On a ship's death, grants EmpireManager
##   notoriety — +5 if the destroyed ship's faction is_empire, else +1 (M4).
## Dependencies: ShipMovement, BuoyancySimulator, ShipVisuals (children), EmpireManager

signal ship_speed_changed(speed: float)
signal ship_health_changed(current: float, maximum: float)
signal ship_destroyed()
signal ship_docked()
signal ship_undocked()
signal ship_stats_changed()

@export var ship_stats: ShipStats:
	set(value):
		ship_stats = value
		# Only react once the node is actually in the tree — during initial
		# scene instantiation this setter fires before @onready vars exist.
		if is_inside_tree():
			_apply_ship_stats()
			ship_stats_changed.emit()
@export var active_captain: CaptainData
@export var faction: Resource

@onready var movement: ShipMovement = $ShipMovement
@onready var buoyancy: BuoyancySimulator = $BuoyancySimulator
@onready var model: Node3D = get_node_or_null("ShipModel")
@onready var combat: Node = get_node_or_null("ShipCombat")

var current_forward_input: float = 0.0
var current_turn_input: float = 0.0
var is_docked: bool = false

# Snapshot of the model node's authored local transform (it can carry a
# baked mirror/rotation, e.g. PlayerShip's ShipModel), so the sinking
# sequence has something exact to restore to on respawn instead of
# assuming identity.
var _model_initial_transform: Transform3D

func _ready() -> void:
	if not model:
		for child in get_children():
			if child.name.contains("ship") or child is Node3D and child.name != "FloatPoints":
				model = child
				break

	if model:
		_model_initial_transform = model.transform

	# Use a soft warning instead of assert so the ship still spawns during dev
	if not ship_stats:
		push_warning("ShipController: No ShipStats resource assigned — using defaults.")
		ship_stats = ShipStats.new()

	if combat:
		combat.health_changed.connect(_on_health_changed)
		combat.died.connect(_on_died)
		
	if is_in_group("player_ship") and TechManager:
		TechManager.tech_recalculated.connect(_apply_tech_modifiers)

	_apply_ship_stats()


func _apply_recoil(is_port: bool) -> void:
	# Firing a broadside kicks the hull toward the OPPOSITE side (Newton's
	# third law) and gives it a brief heel, rather than the previous zero
	# kick / zero heel on every shot.
	var recoil_dir = global_transform.basis.x.normalized() * (1.0 if is_port else -1.0)
	apply_central_impulse(recoil_dir * mass * 0.15)

	if model:
		var target_roll = deg_to_rad(4.0) * (1.0 if is_port else -1.0)
		var tween = create_tween()
		tween.tween_property(model, "rotation:z", target_roll, 0.08).set_trans(Tween.TRANS_SINE)
		tween.tween_property(model, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _spawn_cannon_smoke(is_port: bool) -> void:
	var smoke = CPUParticles3D.new()
	smoke.emitting = false
	smoke.one_shot = true
	smoke.amount = 16
	smoke.lifetime = 1.5
	smoke.explosiveness = 0.8
	smoke.spread = 45.0
	smoke.gravity = Vector3(0, 1, 0)
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 5.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = mat
	smoke.mesh = mesh
	
	add_child(smoke)
	
	if is_port:
		smoke.position = Vector3(-1, 1, 0)
		smoke.direction = Vector3(-1, 0, 0)
	else:
		smoke.position = Vector3(1, 1, 0)
		smoke.direction = Vector3(1, 0, 0)
		
	smoke.emitting = true
	
	# Cleanup
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())

func _apply_ship_stats() -> void:
	## Propagate stats to sub-systems (so they don't need individual
	## assignments) and refresh physics properties. Re-run whenever
	## ship_stats is swapped at runtime (e.g. buying a new ship tier).
	if movement:
		movement.ship_stats = ship_stats
	if buoyancy:
		buoyancy.ship_stats = ship_stats
	if combat:
		combat.ship_stats = ship_stats

	mass = ship_stats.mass
	# ship_stats.linear_damp/angular_damp are intentionally NOT applied here.
	# ShipMovement's forward-speed servo is clamped to reach exactly
	# max_speed on its own; Godot's built-in RigidBody damping was fighting
	# that servo with a constant counter-deceleration, capping real terminal
	# speed at acceleration/linear_damp (~4 m/s) regardless of the authored
	# max_speed (~30). Turning has the same story — ShipMovement now servos
	# angular_velocity directly rather than applying torque, so angular_damp
	# would only fight that the same way.

	if is_in_group("player_ship"):
		_apply_tech_modifiers()

func _apply_tech_modifiers() -> void:
	if not TechManager:
		return
		
	if combat and ship_stats:
		var max_hp = ship_stats.max_health
		if active_captain:
			max_hp *= active_captain.health_modifier
		max_hp *= TechManager.global_health_mod
		
		# Only update max_hp if full health, or proportionally. 
		# For simplicity, we just clamp current_health and emit change
		if combat.current_health > max_hp:
			combat.current_health = max_hp
		if combat.has_signal("health_changed"):
			combat.health_changed.emit(combat.current_health, max_hp)

func _physics_process(delta: float) -> void:
	if is_docked:
		return

	if movement:
		movement.apply_movement(current_forward_input, current_turn_input, delta)

	if buoyancy:
		buoyancy.apply_buoyancy(delta)

	# Emit speed signal for HUD
	var speed = linear_velocity.length()
	ship_speed_changed.emit(speed)

func set_input(forward: float, turn: float) -> void:
	if not is_docked:
		current_forward_input = clamp(forward, -1.0, 1.0)
		current_turn_input = clamp(turn, -1.0, 1.0)

func dock() -> void:
	is_docked = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	current_forward_input = 0.0
	current_turn_input = 0.0
	ship_docked.emit()

func undock() -> void:
	is_docked = false
	ship_undocked.emit()

func fire_cannons(side: String) -> void:
	if not combat or is_docked:
		return

	# Determine spawn positions based on side
	var is_port = (side.to_lower() == "port")

	if combat.fire_broadside(side):
		_spawn_cannon_smoke(is_port)
		_apply_recoil(is_port)
		if AudioManager: AudioManager.play_sound("cannon")

func _on_health_changed(new_health: float, max_health: float) -> void:
	## Forward health info so HUD and other systems can react
	ship_health_changed.emit(new_health, max_health)

func _on_died() -> void:
	## Handle ship destruction
	is_docked = true  # Stop all input processing
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

	_play_sinking_sequence()

	# If this is an enemy, drop loot and despawn
	if not is_in_group("player_ship"):
		_spawn_loot()
		
		# Add notoriety based on faction
		if EmpireManager and faction:
			if faction.get("is_empire"):
				EmpireManager.add_notoriety(5.0)
			else:
				EmpireManager.add_notoriety(1.0)
		
	_spawn_explosion()
	if AudioManager: AudioManager.play_sound("explosion")
	
	# Emit signal before freeing so listeners can react
	ship_destroyed.emit()
	
	if not is_in_group("player_ship"):
		# Long enough for the sinking sequence below to actually play before
		# the ship (and its still-animating model) is freed out from under it.
		get_tree().create_timer(2.0).timeout.connect(queue_free)
	else:
		# Player died — let WorldHUD handle the death screen
		pass

func _play_sinking_sequence() -> void:
	if not model:
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(model, "position:y", model.position.y - 3.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "rotation:x", model.rotation.x + deg_to_rad(20.0), 1.6) \
		.set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func(): if is_instance_valid(model): model.visible = false)

func _spawn_explosion() -> void:
	var explosion = CPUParticles3D.new()
	explosion.emitting = false
	explosion.one_shot = true
	explosion.amount = 30
	explosion.lifetime = 2.0
	explosion.explosiveness = 0.9
	explosion.spread = 180.0
	explosion.gravity = Vector3(0, -2, 0)
	explosion.initial_velocity_min = 5.0
	explosion.initial_velocity_max = 15.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 1.0) # Orange fire
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	mesh.material = mat
	explosion.mesh = mesh
	
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	explosion.emitting = true
	
	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(func(): if is_instance_valid(explosion): explosion.queue_free())

func _spawn_loot() -> void:
	## Spawn a floating loot crate at the ship's death position
	var loot_scene = load("res://scenes/combat/LootDrop.tscn") as PackedScene
	if not loot_scene:
		return

	var loot = loot_scene.instantiate()
	get_tree().current_scene.add_child(loot)
	loot.global_position = Vector3(global_position.x, 1.5, global_position.z)

	# Randomize loot contents based on ship stats and faction
	if loot.has_method("set") and ship_stats:
		var loot_table: LootTableData = null
		
		if is_in_group("boss_ship"):
			loot_table = load("res://resources/loot/BossLoot.tres")
		elif "faction" in self and self.faction and self.faction.get("faction_id") == "merchant_guild":
			loot_table = load("res://resources/loot/MerchantLoot.tres")
		else:
			loot_table = load("res://resources/loot/StandardEnemyLoot.tres")
			
		if loot_table:
			loot.loot_data = loot_table.roll()
		else:
			# Fallback
			loot.loot_data = {"gold": 50, "wood": 10}

func respawn(location: Vector3) -> void:
	## Restores the ship state and teleports to the given location
	global_position = location
	global_rotation = Vector3.ZERO
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	is_docked = false
	freeze = false
	
	if model:
		model.visible = true
		# Undo the sinking sequence's list/sink so a respawned ship doesn't
		# come back still tilted and partially submerged.
		model.transform = _model_initial_transform

	if combat and ship_stats:
		combat.current_health = ship_stats.max_health
		combat.health_changed.emit(combat.current_health, ship_stats.max_health)


