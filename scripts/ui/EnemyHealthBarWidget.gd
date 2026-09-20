class_name EnemyHealthBarWidget extends Control

## Purpose: Screen-space health readout for one enemy ship, positioned each
## frame by WorldHUD from that ship's 3D position.
## Responsibilities: Mirrors ShipCombat.health_changed/died into a themed
## ProgressBar + labels, styled identically to the player's own HUD hull bar
## (WorldHUD.tscn's HealthBarContainer) rather than the old Label3D
## ASCII-block readout it replaces.
## Dependencies: ShipCombat.health_changed/died signals.
## Limitations: Purely presentational — WorldHUD owns visibility/positioning
## (camera facing, range, occlusion); this node only reflects health state.

@onready var _bar: ProgressBar = %Bar
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

var _pulse_active := false
var _pulse_tween: Tween


func bind(ship: Node3D) -> void:
	var combat := ship.get_node_or_null("ShipCombat")
	if not combat:
		return
	if combat.has_signal("health_changed") and not combat.is_connected("health_changed", Callable(self, "_on_health_changed")):
		combat.health_changed.connect(_on_health_changed)
	if combat.has_signal("died") and not combat.is_connected("died", Callable(self, "_on_died")):
		combat.died.connect(_on_died)

	var ship_name := tr("Enemy")
	var stats = ship.get("ship_stats") if "ship_stats" in ship else null
	if stats and not str(stats.get("display_name")).is_empty():
		ship_name = str(stats.get("display_name"))
	_name_label.text = ship_name

	var maximum: float = combat.ship_stats.max_health if combat.ship_stats else 1.0
	var dmg := ship.get_node_or_null("ShipDamage")
	if dmg and dmg.has_method("get_effective_max_health"):
		maximum = dmg.get_effective_max_health()
	_update_display(combat.current_health, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
	_update_display(current, maximum)


func _on_died() -> void:
	visible = false


func _update_display(current: float, maximum: float) -> void:
	_bar.max_value = maxf(maximum, 1.0)
	var tween := create_tween()
	tween.tween_property(_bar, "value", current, 0.15)
	_value_label.text = "%d / %d" % [int(current), int(maximum)]
	_set_pulse(maximum > 0.0 and current / maximum < 0.25)


func _set_pulse(active: bool) -> void:
	## Mirrors WorldHUD.set_health()'s own low-health pulse so the enemy bar
	## reads with the same urgency language as the player's.
	if active == _pulse_active:
		return
	_pulse_active = active
	if active:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_bar, "modulate", Color(1.3, 0.5, 0.5), 0.4)
		_pulse_tween.tween_property(_bar, "modulate", Color(1, 1, 1), 0.4)
	elif _pulse_tween:
		_pulse_tween.kill()
		_bar.modulate = Color(1, 1, 1)
