@tool
class_name CameraSettings extends Resource

@export_group("Distance")
@export var min_distance: float = 10.0
@export var max_distance: float = 50.0
@export var default_distance: float = 30.0
## The phone camera frames the player ship more closely than a mouse-and-
## keyboard desktop view, where the player sits farther from the display.
@export var mobile_min_distance: float = 10.0
@export var mobile_max_distance: float = 50.0
@export var mobile_default_distance: float = 24.0

@export_group("Angles")
@export_range(-90.0, 90.0) var min_pitch: float = -30.0
@export_range(-90.0, 90.0) var max_pitch: float = 60.0
## Direct world dragging changes camera orbit and pitch. These are authored
## camera feel values, not player-facing settings, so phone and PC stay
## consistent without an extra options-menu control.
@export_range(0.01, 1.0, 0.01) var drag_yaw_degrees_per_pixel: float = 0.18
@export_range(0.01, 1.0, 0.01) var drag_pitch_degrees_per_pixel: float = 0.12

@export_group("Smoothing")
@export_range(0.0, 1.0) var damping: float = 0.1
