class_name CameraRig extends Node3D

signal camera_mode_changed(mode: String)
signal camera_target_changed(target: Node3D)

@export var settings: CameraSettings
@export var target: Node3D

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/MainCamera

enum CameraMode {
	FOLLOW,
	ORBIT,
	LOOK
}

var current_mode: CameraMode = CameraMode.FOLLOW
var target_zoom: float = 35.0
var target_pitch: float = -48.0
var target_yaw: float = 0.0

func _ready() -> void:
	if not settings:
		settings = CameraSettings.new()
	target_zoom = settings.default_distance
	if spring_arm:
		spring_arm.spring_length = target_zoom

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not pivot or not spring_arm:
		return
	
	# Smoothly follow target position
	var t = 1.0 - exp(-settings.damping * delta * 10.0)
	global_position = global_position.lerp(target.global_position, t)
	
	# Handle rotation based on mode
	if current_mode == CameraMode.FOLLOW:
		# In follow mode, optionally align yaw with ship over time, or just let player control it
		pass
	
	# Apply smoothed rotations
	var current_pitch = pivot.rotation_degrees.x
	var current_yaw = pivot.rotation_degrees.y
	
	pivot.rotation_degrees.x = lerp(current_pitch, target_pitch, t)
	pivot.rotation_degrees.y = lerp(current_yaw, target_yaw, t)
	
	# Apply zoom
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, t)

func add_yaw(amount: float) -> void:
	target_yaw -= amount
	# Normalize yaw
	target_yaw = wrapf(target_yaw, -180.0, 180.0)

func add_pitch(amount: float) -> void:
	target_pitch -= amount
	target_pitch = clamp(target_pitch, settings.min_pitch, settings.max_pitch)

func add_zoom(amount: float) -> void:
	target_zoom -= amount
	target_zoom = clamp(target_zoom, settings.min_distance, settings.max_distance)

func set_mode(mode: CameraMode) -> void:
	if current_mode != mode:
		current_mode = mode
		var mode_str = "follow"
		match mode:
			CameraMode.FOLLOW: mode_str = "follow"
			CameraMode.ORBIT: mode_str = "orbit"
			CameraMode.LOOK: mode_str = "look"
		camera_mode_changed.emit(mode_str)

func set_target(new_target: Node3D) -> void:
	target = new_target
	camera_target_changed.emit(target)
