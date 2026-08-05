@tool
class_name CameraSettings extends Resource

@export_group("Distance")
@export var min_distance: float = 10.0
@export var max_distance: float = 50.0
@export var default_distance: float = 30.0

@export_group("Angles")
@export_range(-90.0, 90.0) var min_pitch: float = -30.0
@export_range(-90.0, 90.0) var max_pitch: float = 60.0

@export_group("Smoothing")
@export_range(0.0, 1.0) var damping: float = 0.1
