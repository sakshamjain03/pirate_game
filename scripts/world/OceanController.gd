class_name OceanController extends Node3D

## Purpose: Controls the ocean visual and simulation systems.
## Responsibilities: Applies OceanSettings to the water shader and wave generator.
## Dependencies: OceanSettings resource, WaveGenerator child, WaterMesh child

@export var ocean_settings: OceanSettings
@export var quality_level: int = 1 # 0: Low, 1: Medium, 2: High

@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var wave_generator: WaveGenerator = $WaveGenerator
var material: ShaderMaterial
var _base_sparkle_intensity: float = 0.35

func _ready() -> void:
	# Use defaults if no settings resource assigned — never crash
	if not ocean_settings:
		push_warning("OceanController: No OceanSettings resource — using defaults.")
		ocean_settings = OceanSettings.new()

	_setup_material()
	_apply_settings()
	_sync_quality_from_settings()
	SettingsManager.settings_changed.connect(_sync_quality_from_settings)

func _sync_quality_from_settings() -> void:
	quality_level = SettingsManager.graphics_quality
	_apply_quality()

func _process(_delta: float) -> void:
	_follow_camera()

func _follow_camera() -> void:
	## The water plane is a large but still finite 1000x1000 mesh centered at
	## the world origin — at a ship's cruising speed the player would sail
	## off its edge in well under a minute, and the edge is visible on the
	## horizon from anywhere near it. Re-centering it under the camera (not
	## the ship, so it stays centered even while the camera leads/lags
	## during a turn) keeps the edge permanently out of view. Snapping to a
	## grid aligned with wave_length keeps the Gerstner pattern — which is a
	## function of world position, independent of this node's transform —
	## from visibly popping as the plane re-centers.
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var grid: float = max(ocean_settings.wave_length, 1.0) if ocean_settings else 20.0
	var cam_pos := cam.global_position
	global_position.x = round(cam_pos.x / grid) * grid
	global_position.z = round(cam_pos.z / grid) * grid

func _setup_material() -> void:
	if not water_mesh or not water_mesh.mesh:
		push_error("OceanController: WaterMesh or its mesh is missing!")
		return

	# Check if a ShaderMaterial is already on the mesh surface
	var existing = water_mesh.get_surface_override_material(0)
	if existing is ShaderMaterial:
		material = existing
		return

	# Also check the mesh's own material
	var mesh_mat = water_mesh.mesh.surface_get_material(0)
	if mesh_mat is ShaderMaterial:
		material = mesh_mat as ShaderMaterial
		water_mesh.set_surface_override_material(0, material)
		return

	# Create a new ShaderMaterial with the water shader
	var water_shader = load("res://resources/shaders/water.gdshader")
	if water_shader:
		material = ShaderMaterial.new()
		material.shader = water_shader
		water_mesh.set_surface_override_material(0, material)
	else:
		push_error("OceanController: Could not load water.gdshader!")

func _apply_settings() -> void:
	if not material or not ocean_settings:
		return

	material.set_shader_parameter("wave_height", ocean_settings.wave_height)
	material.set_shader_parameter("wave_length", ocean_settings.wave_length)
	material.set_shader_parameter("wave_speed", ocean_settings.wave_speed)
	material.set_shader_parameter("wind_direction", ocean_settings.wind_direction)
	material.set_shader_parameter("water_color", ocean_settings.water_color)
	material.set_shader_parameter("transparency", ocean_settings.transparency)
	material.set_shader_parameter("reflectivity", ocean_settings.reflectivity)

	var authored_sparkle = material.get_shader_parameter("sparkle_intensity")
	if authored_sparkle != null:
		_base_sparkle_intensity = authored_sparkle

	if wave_generator:
		wave_generator.ocean_settings = ocean_settings

func _apply_quality() -> void:
	if not material or not ocean_settings:
		return

	# reflectivity/ROUGHNESS/METALLIC in the shader are inert with
	# specular_disabled set (intentional — the ocean uses a hand-rolled
	# sun-sparkle glint for its highlight rather than PBR specular, to stay
	# visually consistent with the toon-shaded rest of the scene), so the
	# quality ladder instead scales that sparkle pass, which is genuinely
	# visible and is the more expensive of the shader's two noise samples.
	match quality_level:
		0: # Low
			material.set_shader_parameter("sparkle_intensity", 0.0)
		1: # Medium
			material.set_shader_parameter("sparkle_intensity", _base_sparkle_intensity * 0.5)
		2: # High
			material.set_shader_parameter("sparkle_intensity", _base_sparkle_intensity)
