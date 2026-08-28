class_name OceanController extends Node3D

## Purpose: Controls the ocean visual and simulation systems.
## Responsibilities: Applies OceanSettings to the water shader and wave generator.
## Dependencies: OceanSettings resource, WaveGenerator child, WaterMeshNear/WaterMeshFar children

@export var ocean_settings: OceanSettings
@export var quality_level: int = 1 # 0: Low, 1: Medium, 2: High

## M10 Requirement 1 — the ocean used to be one uniformly-dense PlaneMesh
## (14,641 verts) recentered under the camera every frame. That paid full
## mesh density even at the horizon, where individual wave facets are
## invisible anyway. Split into two rings sharing the same material and
## recentering together (both are children of this node, moved as one by
## _follow_camera()): a small high-density ring for water close enough to
## show real wave shape, and a large low-density ring covering the horizon.
## WaveGenerator's CPU sampling (what BuoyancySimulator floats ships on) is
## untouched by any of this — it's pure math over world position, not mesh
## geometry, so LOD here only affects what's drawn, never what ships float on.
@onready var water_mesh_near: MeshInstance3D = $WaterMeshNear
@onready var water_mesh_far: MeshInstance3D = $WaterMeshFar
@onready var wave_generator: WaveGenerator = $WaveGenerator
var material: ShaderMaterial
var _base_sparkle_intensity: float = 0.35

## Half-extent of the near ring (300x300) — the radius within which the
## camera sees full wave-mesh density.
const LOD_NEAR_RADIUS := 150.0

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
	## Both water rings are large but still finite (the far ring is
	## 1200x1200) — at a ship's cruising speed the player would sail off its
	## edge in well under a minute, and the edge is visible on the horizon
	## from anywhere near it. Re-centering under the camera (not the ship, so
	## it stays centered even while the camera leads/lags during a turn)
	## keeps the edge permanently out of view. Snapping to a grid aligned
	## with wave_length keeps the Gerstner pattern — which is a function of
	## world position, independent of this node's transform — from visibly
	## popping as the rings re-center.
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var grid: float = max(ocean_settings.wave_length, 1.0) if ocean_settings else 20.0
	var cam_pos := cam.global_position
	global_position.x = round(cam_pos.x / grid) * grid
	global_position.z = round(cam_pos.z / grid) * grid

func _setup_material() -> void:
	if not water_mesh_near or not water_mesh_near.mesh:
		push_error("OceanController: WaterMeshNear or its mesh is missing!")
		return

	# Check if a ShaderMaterial is already on the near mesh's surface
	var existing = water_mesh_near.get_surface_override_material(0)
	if existing is ShaderMaterial:
		material = existing
	else:
		# Also check the mesh's own material
		var mesh_mat = water_mesh_near.mesh.surface_get_material(0)
		if mesh_mat is ShaderMaterial:
			material = mesh_mat as ShaderMaterial
		else:
			# Create a new ShaderMaterial with the water shader
			var water_shader = load("res://resources/shaders/water.gdshader")
			if water_shader:
				material = ShaderMaterial.new()
				material.shader = water_shader
			else:
				push_error("OceanController: Could not load water.gdshader!")
				return

	# Both rings render the exact same ShaderMaterial resource so a single
	# set_shader_parameter() call (below, and in _apply_quality()) updates
	# both at once — required for the two rings to read as one continuous
	# ocean rather than two visibly different water surfaces.
	water_mesh_near.set_surface_override_material(0, material)
	if water_mesh_far:
		water_mesh_far.set_surface_override_material(0, material)

func get_lod_level(distance: float) -> int:
	## 0 = within the near ring's full-density radius, 1 = beyond it (far
	## ring only). Distance bands, per Requirement 1.1.
	return 0 if distance < LOD_NEAR_RADIUS else 1

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
