class_name ShipVisuals extends Node3D

## Purpose: Manages all ship visual effects — sail animation, wake particles, damage visuals.
## Responsibilities: Responds to speed/turn signals from ShipController and animates accordingly.
##                   Also owns loading the tier-specific hull model + material (ship_stats.model_path
##                   / material_path), rebuilding it whenever ship_stats is swapped (e.g. ship upgrades).
## Dependencies: ShipController (parent), WakeParticles child (optional)

const DEFAULT_MODEL_PATH := "res://assets/models/ship-pirate-small.glb"

@export var controller: ShipController
@export var sails: Array[Node3D]
@export var sail_turn_speed: float  = 2.0
@export var max_sail_angle: float   = 30.0  # degrees

# Wake particles found at runtime
var _wake: GPUParticles3D
var _model_instance: Node3D
var target_sail_angle: float = 0.0

func _ready() -> void:
	if not controller:
		controller = get_parent() as ShipController

	if controller:
		controller.ship_speed_changed.connect(_on_speed_changed)
		controller.ship_stats_changed.connect(_rebuild_model)

	# Find wake particles in parent ship's WakeSpawnPoint
	_wake = _find_wake_particles()

	_rebuild_model()


func _rebuild_model() -> void:
	## Load the hull model + material for the ship's current tier and swap
	## it in, replacing whatever was previously loaded.
	if _model_instance:
		_model_instance.queue_free()
		_model_instance = null

	var model_path := DEFAULT_MODEL_PATH
	var material_path := ""
	if controller and controller.ship_stats:
		if not controller.ship_stats.model_path.is_empty():
			model_path = controller.ship_stats.model_path
		material_path = controller.ship_stats.material_path

	var model_scene: PackedScene = load(model_path)
	if not model_scene:
		push_error("ShipVisuals: could not load ship model at %s" % model_path)
		return

	_model_instance = model_scene.instantiate()
	add_child(_model_instance)
	move_child(_model_instance, 0)

	# Colorize the freshly loaded hull only — flag/ropes keep their own look.
	var applier := preload("res://scripts/components/KenneyMaterialApplier.gd").new()
	applier.material_path = material_path
	_model_instance.add_child(applier)
	
	# Apply Faction colors
	if controller and "faction" in controller and controller.faction:
		var faction = controller.faction
		var flag = find_child("*Flag*", true, false)
		if flag:
			_apply_color_to_meshes(flag, faction.sail_color)

func _apply_color_to_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		# Try to keep basic shading
		mat.roughness = 0.8
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_color_to_meshes(child, color)


func _find_wake_particles() -> GPUParticles3D:
	## Look for a WakeParticles node in the parent ship scene
	var parent = get_parent()
	if not parent:
		return null
	var spawn = parent.find_child("WakeSpawnPoint", true, false)
	if spawn:
		var wake_scene = load("res://scenes/world/WakeParticles.tscn") as PackedScene
		if wake_scene:
			var wake = wake_scene.instantiate()
			spawn.add_child(wake)
			return wake as GPUParticles3D
	return null


func _process(delta: float) -> void:
	if not controller:
		return

	# Sail lean animation based on current turn input
	var turn_input = controller.current_turn_input
	target_sail_angle = -turn_input * deg_to_rad(max_sail_angle)

	for sail in sails:
		if sail:
			var cur = sail.rotation.y
			sail.rotation.y = lerp_angle(cur, target_sail_angle, sail_turn_speed * delta)


func _on_speed_changed(speed: float) -> void:
	if not _wake:
		return
	var normalized = clamp(speed / max(controller.ship_stats.max_speed, 0.01), 0.0, 1.0)
	_wake.emitting      = normalized > 0.08
	_wake.amount_ratio  = normalized
