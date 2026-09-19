class_name EnemyHealthBar extends Label3D

## Purpose: Displays a compact, billboarded combat health readout above enemy ships.
## Responsibilities: Shows an opponent name, segmented health bar, and remaining
##                   percentage only after that opponent has taken damage.
## Dependencies: ShipCombat.health_changed / died signals.
## Limitations: Uses Label3D so it remains readable without a per-enemy UI viewport.

var combat_node: ShipCombat
const BAR_SEGMENTS := 12
const FILLED_SEGMENT := "■"
const EMPTY_SEGMENT := "□"

func _ready() -> void:
	# Do not add permanent labels to a peaceful ocean. The bar appears when the
	# player has actually damaged an opponent and disappears with it.
	visible = false
	if PirateThemeBuilder.is_mobile():
		font_size = PirateThemeBuilder.scaled_font_size(font_size)
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
	# ShipCombat._ready() fires an initial health_changed at full health
	# purely to sync listeners — without this check every enemy showed a
	# full health bar from the moment it spawned, before taking any damage.
	visible = current < maximum

func _on_died() -> void:
	visible = false

func _update_display(current: float, maximum: float) -> void:
	var pct := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	var filled := int(round(pct * BAR_SEGMENTS))
	var bar := ""
	for segment in range(BAR_SEGMENTS):
		bar += FILLED_SEGMENT if segment < filled else EMPTY_SEGMENT
	var ship_name := tr("Enemy")
	var ship := get_parent()
	var stats = ship.get("ship_stats") if ship else null
	if stats and not str(stats.get("display_name")).is_empty():
		ship_name = str(stats.get("display_name"))
	text = "%s\n%s  %d%%" % [ship_name, bar, roundi(pct * 100.0)]
	# The same simple traffic-light palette works at a distance and avoids
	# colour-only communication because the percentage is always visible.
	if pct > 0.6:
		modulate = Color(0.35, 1.0, 0.45, 1.0)
	elif pct > 0.3:
		modulate = Color(1.0, 0.78, 0.2, 1.0)
	else:
		modulate = Color(1.0, 0.3, 0.25, 1.0)
