class_name LootDrop extends RigidBody3D

## Purpose: A floating loot crate that the player can pick up by sailing near it.
## Responsibilities: Bobs on the water surface, detects player proximity, grants rewards.
## Dependencies: Player ship (collision detection)
##
## Limitations:
##   - No loot table integration yet (fixed rewards)
##   - No inventory system to deposit into (prints to console)
##
## TODO:
##   - M5: Connect to ResourceManager for actual resource grants
##   - M5: Add LootTableData resource for randomized drops

signal collected(loot_data: Dictionary)

@export var loot_data: Dictionary = {
	"gold": 50,
	"wood": 10,
}
@export var pickup_range: float = 6.0
@export var lifetime: float = 60.0  # despawn after 60 seconds
@export var bob_height: float = 0.3
@export var bob_speed: float = 2.0

var _time: float = 0.0
var _base_y: float = 0.0
var _collected: bool = false
var _player_ship: Node3D = null

func _ready() -> void:
	# Float on the water
	gravity_scale = 0.0
	freeze = true
	_base_y = global_position.y

	# Auto-despawn
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)

	# Add to loot group for easy discovery
	add_to_group("loot_drops")

	# Cache the player reference once instead of doing a group lookup every
	# single frame in _process() (perf: avoid repeated node lookups in hot loops).
	var found = get_tree().get_first_node_in_group("player_ship")
	if found and found is Node3D:
		_player_ship = found


func _process(delta: float) -> void:
	if _collected:
		return

	# Bobbing animation
	_time += delta
	var bob_offset = sin(_time * bob_speed) * bob_height
	global_position.y = _base_y + bob_offset

	# Slow rotation for visual appeal
	rotation_degrees.y += 30.0 * delta

	# Check for nearby player ship (cached reference — re-resolve lazily only
	# if it wasn't available yet, e.g. loot spawned before the ship existed)
	if not is_instance_valid(_player_ship):
		var found = get_tree().get_first_node_in_group("player_ship")
		if found and found is Node3D:
			_player_ship = found
		else:
			return

	var dist = global_position.distance_to(_player_ship.global_position)
	if dist < pickup_range:
		_collect()


func _collect() -> void:
	if _collected:
		return
	_collected = true

	if AudioManager: AudioManager.play_sound("resource_collect")
	collected.emit(loot_data)

	# Grant resources via ResourceManager
	for res_type in loot_data.keys():
		var amount = loot_data[res_type]
		if ResourceManager.has_method("add_resource"):
			ResourceManager.add_resource(res_type, amount)

	# Quick scale-down animation then remove
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_lifetime_expired() -> void:
	if _collected:
		return
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
