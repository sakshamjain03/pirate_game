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

@export_group("Damage Visuals")
## `docs/navalCombat.md` §7's "visible critical state before sinking" — the one
## piece of the damage model that was still just a documented gap. Below this
## hull fraction, smoke starts drifting off the deck.
@export_range(0.0, 1.0) var hull_damaged_threshold: float = 0.5
## Below this, the hull itself darkens — planking scorched, not just smoking.
@export_range(0.0, 1.0) var hull_critical_threshold: float = 0.25
## M10 Requirement 6 — the one remaining open item from `docs/navalCombat.md`
## §7: a distinct near-destruction state below critical, so a badly-damaged
## hull visibly looks like it's about to sink rather than just staying at
## the same critical look all the way to 0. Visual only — a rotation offset
## on the hull model, never the parent ShipController's own transform, so
## BuoyancySimulator's float physics and FiringSolver's arc geometry (both of
## which read the ship's real transform) are unaffected.
@export_range(0.0, 1.0) var hull_sinking_threshold: float = 0.10
@export var sinking_list_degrees: float = 9.0
@export var scorch_tint_color: Color = Color(0.12, 0.10, 0.09)
@export_range(0.0, 1.0) var scorch_tint_strength: float = 0.55

# Wake particles found at runtime
var _wake: GPUParticles3D
var _model_instance: Node3D
var target_sail_angle: float = 0.0

# Damage visuals: the toon material KenneyMaterialApplier assigns is a
# ShaderMaterial keyed by an "albedo" shader param, not a StandardMaterial3D —
# so the scorch tint has to blend that same param rather than touch
# albedo_color. Cached once per surface, right after the applier's own pass,
# so repeated tint updates always blend from the clean color instead of
# compounding against whatever the last tint left behind.
var _clean_albedo: Dictionary = {}
var _damage: Node = null
var _smoke: GPUParticles3D = null

func _ready() -> void:
	if not controller:
		controller = get_parent() as ShipController

	if controller:
		controller.ship_speed_changed.connect(_on_speed_changed)
		controller.ship_stats_changed.connect(_rebuild_model)

	# Find wake particles in parent ship's WakeSpawnPoint
	_wake = _find_wake_particles()

	var parent = get_parent()
	_damage = parent.get_node_or_null("ShipDamage") if parent else null
	if _damage and not _damage.pool_changed.is_connected(_on_damage_pool_changed):
		_damage.pool_changed.connect(_on_damage_pool_changed)

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

	# `sails` was never assigned in any ship scene, so the lean-animation
	# loop in _process() always had nothing to act on. Auto-discovering any
	# sail-named node in the freshly loaded hull means it works the moment a
	# model actually has one, with no per-ship scene wiring required.
	sails = _find_sail_nodes(_model_instance)

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

	# A rebuild (ship purchase/switch) always yields a fresh hull, but re-derive
	# the tint from whatever ShipDamage currently reports rather than assuming
	# "clean" — the two must never independently disagree about hull state.
	_cache_clean_albedo()
	if _damage and _damage.ship_stats:
		_on_damage_pool_changed("hull", _damage.hull, _damage.get_pool_maximum("hull"))

func _apply_color_to_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		# Try to keep basic shading
		mat.roughness = 0.8
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_color_to_meshes(child, color)


func _find_sail_nodes(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	_collect_sail_nodes(root, found)
	return found

func _collect_sail_nodes(node: Node, found: Array[Node3D]) -> void:
	if node is Node3D and "sail" in node.name.to_lower():
		found.append(node)
	for child in node.get_children():
		_collect_sail_nodes(child, found)

func _on_damage_pool_changed(pool: String, current: float, maximum: float) -> void:
	if pool != "hull":
		return
	var pct: float = current / max(maximum, 1.0)
	var is_sinking := pct < hull_sinking_threshold and pct > 0.0
	_update_smoke(pct < hull_damaged_threshold and pct > 0.0, is_sinking)
	_apply_damage_tint(scorch_tint_strength if pct < hull_critical_threshold else 0.0)
	_apply_list(sinking_list_degrees if is_sinking else 0.0)


func _cache_clean_albedo() -> void:
	_clean_albedo.clear()
	if _model_instance:
		_collect_clean_albedo(_model_instance)


func _collect_clean_albedo(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var albedo = mat.get_shader_parameter("albedo")
				if albedo is Color:
					_clean_albedo["%d:%d" % [mi.get_instance_id(), i]] = albedo
	for child in node.get_children():
		_collect_clean_albedo(child)


func _apply_damage_tint(severity: float) -> void:
	## Blends each surface's own cached clean color toward `scorch_tint_color`.
	## Reads from `_clean_albedo`, never from the material's current value, so
	## healing back above the threshold restores the original color exactly
	## rather than drifting after repeated hits.
	if _model_instance:
		_apply_damage_tint_to(_model_instance, severity)


func _apply_damage_tint_to(node: Node, severity: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var key := "%d:%d" % [mi.get_instance_id(), i]
				if _clean_albedo.has(key):
					var clean: Color = _clean_albedo[key]
					mat.set_shader_parameter("albedo", clean.lerp(scorch_tint_color, severity))
	for child in node.get_children():
		_apply_damage_tint_to(child, severity)


func _ensure_smoke() -> GPUParticles3D:
	if _smoke and is_instance_valid(_smoke):
		return _smoke
	_smoke = GPUParticles3D.new()
	_smoke.name = "DamageSmoke"
	_smoke.amount = 10
	_smoke.lifetime = 1.4
	_smoke.emitting = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.5)
	quad.material = quad_mat
	_smoke.draw_pass_1 = quad

	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 20.0
	proc.gravity = Vector3(0, 0.5, 0)
	proc.initial_velocity_min = 0.5
	proc.initial_velocity_max = 1.1
	proc.scale_min = 0.5
	proc.scale_max = 1.1
	_smoke.process_material = proc

	add_child(_smoke)
	_smoke.position = Vector3(0.0, 2.4, 0.0)
	return _smoke


func _update_smoke(should_emit: bool, heavy: bool = false) -> void:
	var smoke := _ensure_smoke()
	smoke.emitting = should_emit
	# Heavier smoke for the sinking band: bigger, faster-moving puffs on the
	# same particle system rather than a second one — resizing `amount`
	# requires recreating the particle buffer, so intensity is conveyed
	# through velocity/scale instead.
	var proc := smoke.process_material as ParticleProcessMaterial
	if proc:
		if heavy:
			proc.initial_velocity_min = 0.9
			proc.initial_velocity_max = 1.8
			proc.scale_min = 0.9
			proc.scale_max = 1.6
		else:
			proc.initial_velocity_min = 0.5
			proc.initial_velocity_max = 1.1
			proc.scale_min = 0.5
			proc.scale_max = 1.1


func _apply_list(degrees: float) -> void:
	if _model_instance:
		_model_instance.rotation.z = deg_to_rad(degrees)


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
