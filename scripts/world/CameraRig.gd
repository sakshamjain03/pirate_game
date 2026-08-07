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

# The rig previously rode 20 units above the ship with no look_at to
# compensate, which put the ship ~75% down the frame at default zoom (worse
# zoomed in, since the offset is constant while zoom isn't). Following at
# ship height with a steeper pitch (-48 deg) frames the ship centrally
# without needing a compensating look_at.
const EYE_HEIGHT := 0.0
var target_yaw: float = 0.0

# How long a manual Q/E yaw nudge suppresses auto-align, in milliseconds —
# long enough to look around deliberately without the camera immediately
# snapping back and fighting the input.
const MANUAL_YAW_HOLD_MS := 2000
var _manual_yaw_until_ms: int = 0

func _ready() -> void:
	if not settings:
		settings = CameraSettings.new()
	if not is_instance_valid(target):
		# Scenes can't wire a Node3D-typed export to a sibling via a plain
		# NodePath in .tscn (it stays an unresolved NodePath, never a real
		# node) — fall back to the player ship so the rig isn't just frozen
		# at its scene-default transform forever.
		target = get_tree().get_first_node_in_group("player_ship")
	target_zoom = settings.default_distance
	if spring_arm:
		spring_arm.spring_length = target_zoom

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not pivot or not spring_arm:
		return

	# Smoothly follow target position
	var t = 1.0 - exp(-settings.damping * delta * 10.0)
	global_position = global_position.lerp(target.global_position + Vector3.UP * EYE_HEIGHT, t)
	
	# Handle rotation based on mode
	# ORBIT and LOOK are deferred — tracked for a future milestone. set_mode() still
	# accepts them (so callers don't break), but they currently run identical FOLLOW
	# behavior below rather than distinct logic.
	if current_mode == CameraMode.FOLLOW and Time.get_ticks_msec() >= _manual_yaw_until_ms:
		# Tank-style ship controls are steered relative to the hull, so the
		# camera has to face the same way the ship does — otherwise "left"
		# on the stick stops matching "left" on screen the moment the ship
		# turns. Chase the ship's heading instead of leaving target_yaw
		# frozen wherever the player last set it with Q/E.
		target_yaw = wrapf(rad_to_deg(target.global_rotation.y), -180.0, 180.0)

	# Apply smoothed rotations. Yaw goes through lerp_angle (via radians)
	# rather than a plain lerp on degrees — a plain lerp crossing the +-180
	# seam sends the camera almost all the way around the wrong way instead
	# of taking the short path.
	var current_pitch = pivot.rotation_degrees.x
	var current_yaw_rad = deg_to_rad(pivot.rotation_degrees.y)
	var target_yaw_rad = deg_to_rad(target_yaw)

	pivot.rotation_degrees.x = lerp(current_pitch, target_pitch, t)
	pivot.rotation_degrees.y = rad_to_deg(lerp_angle(current_yaw_rad, target_yaw_rad, t))

	# Apply zoom
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, t)

func add_yaw(amount: float) -> void:
	target_yaw -= amount
	# Normalize yaw
	target_yaw = wrapf(target_yaw, -180.0, 180.0)
	_manual_yaw_until_ms = Time.get_ticks_msec() + MANUAL_YAW_HOLD_MS

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
