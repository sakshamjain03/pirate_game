class_name RibbonStack extends Node

## Purpose: manages at most N visual ribbons (attack confirmations, rake feedback)
## that appear around a target ship during combat (M30 W1-2.3).
## Responsibilities: cap ribbon count, remove old ones, track lifecycle.
## Dependencies: visual Node3D children (Ribbon scenes).

@export var max_ribbons: int = 3
var _ribbons: Array = []


func add_ribbon(ribbon_name: String) -> void:
	## Add a new ribbon, removing the oldest if we're at cap.
	if _ribbons.size() >= max_ribbons:
		var old = _ribbons.pop_front()
		if old and is_instance_valid(old):
			old.queue_free()
	_ribbons.append(ribbon_name)


func clear() -> void:
	for ribbon in _ribbons:
		if ribbon and is_instance_valid(ribbon):
			ribbon.queue_free()
	_ribbons.clear()


func get_ribbon_count() -> int:
	return _ribbons.size()
