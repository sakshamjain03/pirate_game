class_name OceanController extends Node3D

## Purpose: Controls the ocean visual and simulation systems.
## Responsibilities: Applies OceanSettings to the water shader and wave generator.
## Dependencies: OceanSettings resource, WaveGenerator child, WaterMesh child

@export var ocean_settings: OceanSettings
@export var quality_level: int = 1 # 0: Low, 1: Medium, 2: High

@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var wave_generator: WaveGenerator = $WaveGenerator
var material: ShaderMaterial

func _ready() -> void:
	# Use defaults if no settings resource assigned — never crash
	if not ocean_settings:
		push_warning("OceanController: No OceanSettings resource — using defaults.")
		ocean_settings = OceanSettings.new()

	_setup_material()
	_apply_settings()
	_apply_quality()

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

	if wave_generator:
		wave_generator.ocean_settings = ocean_settings

func _apply_quality() -> void:
	if not material or not ocean_settings:
		return

	match quality_level:
		0: # Low
			material.set_shader_parameter("reflectivity", 0.0)
		1: # Medium
			material.set_shader_parameter("reflectivity", ocean_settings.reflectivity * 0.5)
		2: # High
			material.set_shader_parameter("reflectivity", ocean_settings.reflectivity)
