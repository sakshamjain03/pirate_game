class_name WaveGenerator extends Node

@export var ocean_settings: OceanSettings

func _ready() -> void:
	add_to_group("wave_generator")
	if not ocean_settings:
		# Use default settings if none provided
		ocean_settings = OceanSettings.new()

# Calculate water height at a specific global position and time using Gerstner Waves
func get_water_height_at(global_pos: Vector3, time: float) -> float:
	if not ocean_settings:
		return 0.0
		
	# Simple Gerstner wave approximation for physics
	var pos2d = Vector2(global_pos.x, global_pos.z)
	var dir = ocean_settings.wind_direction.normalized()
	
	# Primary wave
	var k = 2.0 * PI / max(0.1, ocean_settings.wave_length)
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") if ProjectSettings.has_setting("physics/3d/default_gravity") else 9.8
	var c = sqrt(gravity / k) * ocean_settings.wave_speed
	var f = k * (pos2d.dot(dir) - c * time)
	
	var height = ocean_settings.wave_height * sin(f)
	
	# Secondary wave (slightly off-angle)
	var dir2 = dir.rotated(0.5)
	var k2 = k * 1.5
	var gravity2 = ProjectSettings.get_setting("physics/3d/default_gravity") if ProjectSettings.has_setting("physics/3d/default_gravity") else 9.8
	var c2 = sqrt(gravity2 / k2) * ocean_settings.wave_speed
	var f2 = k2 * (pos2d.dot(dir2) - c2 * time)
	
	height += (ocean_settings.wave_height * 0.5) * sin(f2)
	
	return height
