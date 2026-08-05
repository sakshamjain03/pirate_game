@tool
class_name OceanSettings extends Resource

@export_group("Waves")
@export_range(0.0, 10.0) var wave_height: float = 2.0
@export_range(0.0, 10.0) var wave_length: float = 20.0
@export_range(0.0, 10.0) var wave_speed: float = 1.0
@export var wind_direction: Vector2 = Vector2(1.0, 0.0)

@export_group("Visual")
@export_color_no_alpha var water_color: Color = Color("#1a5fb4")
@export_range(0.0, 1.0) var transparency: float = 0.6
@export_range(0.0, 1.0) var reflectivity: float = 0.3
