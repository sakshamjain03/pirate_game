class_name DockingSystem extends Node

signal dock_area_entered(island_id: String)
signal dock_area_exited(island_id: String)
signal dock_initiated(island_id: String)
signal dock_completed(island_id: String)
signal undock_initiated()
signal undock_completed()

enum DockState {
	FREE,
	APPROACHING,
	ALIGNING,
	DOCKED
}

var current_state: DockState = DockState.FREE
var active_dock_area: Area3D = null
var current_island_id: String = ""
var ship_controller: ShipController = null

@export var max_docking_speed: float = 5.0
@export var alignment_speed: float = 2.0
@export var position_tolerance: float = 1.0
@export var repair_rate: float = 5.0

var _repair_timer: float = 0.0

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	# Note: the "dock" input action is polled and toggled by
	# WorldManager._toggle_docking() (single place responsible for reading
	# gameplay input, consistent with how it also handles fire_port/
	# fire_starboard). This function only advances the state machine.
	if current_state == DockState.ALIGNING:
		_process_alignment(delta)
	elif current_state == DockState.DOCKED:
		_process_healing(delta)

func initialize(ship: ShipController) -> void:
	ship_controller = ship

func on_dock_area_entered(area: Area3D, island_id: String) -> void:
	if current_state == DockState.FREE:
		active_dock_area = area
		current_island_id = island_id
		current_state = DockState.APPROACHING
		dock_area_entered.emit(island_id)

func on_dock_area_exited(area: Area3D, island_id: String) -> void:
	if active_dock_area == area and current_state == DockState.APPROACHING:
		active_dock_area = null
		current_island_id = ""
		current_state = DockState.FREE
		dock_area_exited.emit(island_id)

func attempt_dock() -> bool:
	if current_state != DockState.APPROACHING or not active_dock_area:
		return false
	
	if not ship_controller:
		return false
	
	# Verify speed is low enough
	var current_speed = ship_controller.linear_velocity.length()
	if current_speed > max_docking_speed:
		# Too fast to dock
		print("Too fast to dock! Current speed: ", current_speed, " Max allowed: ", max_docking_speed)
		return false
	
	# Start alignment
	current_state = DockState.ALIGNING
	dock_initiated.emit(current_island_id)
	
	# Freeze physics to allow manual transform alignment and disable controls
	if ship_controller.has_method("dock"):
		ship_controller.dock()
	ship_controller.freeze = true
	
	return true

func attempt_undock() -> bool:
	if current_state != DockState.DOCKED:
		return false
	
	undock_initiated.emit()
	current_state = DockState.FREE
	active_dock_area = null
	
	# Re-enable ship controls and physics
	if is_instance_valid(ship_controller):
		if ship_controller.has_method("undock"):
			ship_controller.undock()
		ship_controller.freeze = false
	
	undock_completed.emit()
	return true

func _process_alignment(delta: float) -> void:
	if not is_instance_valid(ship_controller) or not is_instance_valid(active_dock_area):
		current_state = DockState.FREE
		return
		
	var target_transform = active_dock_area.global_transform
	var ship_transform = ship_controller.global_transform
	
	var pos_diff = target_transform.origin - ship_transform.origin
	var dist = pos_diff.length()
	
	if dist < position_tolerance:
		# Alignment complete
		ship_controller.global_transform.origin = target_transform.origin
		# Ideally also align rotation
		ship_controller.global_transform.basis = target_transform.basis
		
		# Zero out velocity
		ship_controller.linear_velocity = Vector3.ZERO
		ship_controller.angular_velocity = Vector3.ZERO
		
		current_state = DockState.DOCKED
		dock_completed.emit(current_island_id)
		
		# Auto-save at this milestone
		if SaveManager.has_method("save_game"):
			SaveManager.save_game()
	else:
		# Move towards dock
		var move_dir = pos_diff.normalized()
		var move_step = move_dir * alignment_speed * delta
		# Ensure we don't overshoot
		if move_step.length() > dist:
			move_step = move_dir * dist
			
		ship_controller.global_transform.origin += move_step
		
		# Slerp rotation
		var current_quat = Quaternion(ship_transform.basis)
		var target_quat = Quaternion(target_transform.basis)
		var new_quat = current_quat.slerp(target_quat, alignment_speed * delta)
		ship_controller.global_transform.basis = Basis(new_quat)

func _process_healing(delta: float) -> void:
	if not active_dock_area or not ship_controller or not ship_controller.combat:
		return
		
	var island = active_dock_area.get_parent()
	if island and island.has_method("has_shipyard") and island.has_shipyard():
		_repair_timer += delta
		if _repair_timer >= 1.0:
			_repair_timer -= 1.0
			
			var combat = ship_controller.combat
			if combat.current_health < combat.ship_stats.max_health:
				combat.current_health = min(combat.current_health + repair_rate, combat.ship_stats.max_health)
				if combat.health_changed:
					combat.health_changed.emit(combat.current_health, combat.ship_stats.max_health)
				# Optional: Spawn a tiny heal particle or just let the HUD show it
