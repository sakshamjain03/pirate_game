class_name EnemyHealthBar extends Label3D

## Purpose: Displays a floating health bar above enemy ships using text.

var combat_node: ShipCombat

func _ready() -> void:
	# Hide initially until first update
	visible = false
	var parent = get_parent()
	if parent:
		var combat = parent.get_node_or_null("ShipCombat")
		if combat:
			setup(combat)

func setup(combat: ShipCombat) -> void:
	combat_node = combat
	if combat_node:
		combat_node.health_changed.connect(_on_health_changed)
		combat_node.died.connect(_on_died)
		_update_display(combat_node.current_health, combat_node.ship_stats.max_health)

func _on_health_changed(current: float, maximum: float) -> void:
	_update_display(current, maximum)
	visible = true

func _on_died() -> void:
	visible = false

func _update_display(current: float, maximum: float) -> void:
	var pct = clamp(current / maximum, 0.0, 1.0)
	var total_bars = 10
	var filled = int(round(pct * total_bars))
	
	var bar_str = "["
	for i in range(total_bars):
		if i < filled:
			bar_str += "|"
		else:
			bar_str += "."
	bar_str += "]"
	
	text = bar_str
