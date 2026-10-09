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

## M25 — display thresholds for the "this one is crippled" markers. Exported
## rather than const so they are tunable without a code change, and deliberately
## NOT balance values: they describe when to TELL the player something, not when
## it becomes true.
@export_range(0.0, 1.0) var sails_crippled_fraction: float = 0.3
@export_range(0.0, 1.0) var crew_broken_fraction: float = 0.35

var _pulse_active := false
var _pulse_tween: Tween

## M25 — the hull/sails/crew triangle, made visible.
##
## All three pools have always existed with real, distinct consequences: chain
## shot wrecks sails so a target cannot flee, grape kills crew so boarding
## succeeds, round kills hull so you get loot instead of a prize. Until now the
## widget showed hull ONLY, so the player had no way to see any of it and no
## reason to ever change ammo. Showing the pools is what turns three authored
## AmmoData resources into an actual decision.
var _sails_bar: ProgressBar
var _crew_bar: ProgressBar
var _status_label: Label
## M30 W2 (2.5): one line under the pools — what boarding this ship would face. Hidden
## unless WorldHUD feeds it a summary from BoardingSystem.deck_preview_changed.
var _preview_label: Label
var _damage: Node = null
var _pool_max: Dictionary = {"sails": 1.0, "crew": 1.0}
var _pool_now: Dictionary = {"sails": 1.0, "crew": 1.0}


func _ready() -> void:
	# The name floats over open sea, not a panel — an ink outline keeps it
	# legible on bright water and foam (M22 6.9).
	_name_label.add_theme_color_override("font_outline_color", UITokens.palette().ink)
	_name_label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE * 2)


func bind(ship: Node3D) -> void:
	var combat := ship.get_node_or_null("ShipCombat")
	if not combat:
		return
	_bind_pools(ship)
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


# ------------------------------------------------- Sails & crew (M25)

func _bind_pools(ship: Node3D) -> void:
	_damage = ship.get_node_or_null("ShipDamage")
	if not _damage:
		return
	_build_pool_bars()
	if _damage.has_signal("pool_changed") \
			and not _damage.pool_changed.is_connected(_on_pool_changed):
		_damage.pool_changed.connect(_on_pool_changed)
	# Seed from current state — pool_changed only fires on a change, so a ship
	# that spawns already damaged (a siege garrison, a captured prize) would
	# otherwise show full bars until it took its first hit.
	for pool in ["sails", "crew"]:
		var maximum: float = 1.0
		if _damage.has_method("get_pool_maximum"):
			maximum = _damage.get_pool_maximum(pool)
		_on_pool_changed(pool, float(_damage.get(pool)), maximum)


## Built in code and added to the EXISTING VBoxContainer rather than positioned
## against the hull bar by hand. Two independently placed pixel offsets have
## drifted apart in this project before with no code change in between, so a
## sibling's position belongs to the container (CLAUDE.md fragile-area rule).
func _build_pool_bars() -> void:
	if _sails_bar:
		return
	# bind() can be called before the widget enters the tree (WorldHUD builds and
	# binds in one step), and @onready vars are still null then. Retry once the
	# node is ready rather than erroring or silently skipping the pool bars.
	if _bar == null:
		if not is_node_ready():
			ready.connect(_build_pool_bars, CONNECT_ONE_SHOT)
		return
	var vbox := _bar.get_parent() as BoxContainer
	if not vbox:
		return

	var row := HBoxContainer.new()
	row.name = "PoolRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	vbox.add_child(row)

	_sails_bar = _make_pool_bar(row, tr("RIG"))
	_crew_bar = _make_pool_bar(row, tr("CREW"))

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	_status_label.add_theme_color_override("font_outline_color", UITokens.palette().ink)
	_status_label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE * 2)
	vbox.add_child(_status_label)

	_preview_label = Label.new()
	_preview_label.name = "BoardingPreview"
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.theme_type_variation = &"ChipLabel"
	_preview_label.visible = false
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label with no minimum width collapses to 1px in a VBox; match the bar.
	_preview_label.custom_minimum_size = Vector2(custom_minimum_size.x, 0)
	_preview_label.add_theme_color_override("font_outline_color", UITokens.palette().ink)
	_preview_label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE * 2)
	vbox.add_child(_preview_label)


## Each pool carries a text tag as well as its bar. docs/18_ACCESSIBILITY.md —
## the three pools must be tellable apart without relying on colour.
func _make_pool_bar(row: HBoxContainer, tag: String) -> ProgressBar:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 3)
	row.add_child(cell)

	var label := Label.new()
	label.text = tag
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"ChipLabel"
	cell.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 1.0
	cell.add_child(bar)
	return bar


func _on_pool_changed(pool: String, current: float, maximum: float) -> void:
	if pool != "sails" and pool != "crew":
		return   # hull already has its own bar, fed by ShipCombat.health_changed
	_pool_now[pool] = current
	_pool_max[pool] = maxf(maximum, 1.0)
	var bar: ProgressBar = _sails_bar if pool == "sails" else _crew_bar
	if bar:
		bar.max_value = _pool_max[pool]
		bar.value = current
	_refresh_status()


## The payoff line: tells the player what their ammo choice actually bought them.
func _refresh_status() -> void:
	if not _status_label:
		return
	var sails_frac: float = _pool_now["sails"] / _pool_max["sails"]
	var crew_frac: float = _pool_now["crew"] / _pool_max["crew"]
	var parts: Array[String] = []
	if sails_frac <= sails_crippled_fraction:
		parts.append(tr("RIGGING DOWN"))   # chain shot worked — it cannot run
	if crew_frac <= crew_broken_fraction:
		parts.append(tr("CREW BROKEN"))    # grape worked — boarding will go your way
	_status_label.text = " · ".join(parts)
	_status_label.visible = not parts.is_empty()


func get_pool_fraction(pool: String) -> float:
	if not _pool_max.has(pool):
		return 1.0
	return _pool_now[pool] / _pool_max[pool]


# ------------------------------------------------- Boarding preview (M30 W2)

## `summary` is BoardingDeckBuilder.summarize(); an empty one hides the strip.
func set_boarding_preview(summary: Dictionary) -> void:
	_build_pool_bars()
	if _preview_label == null:
		return
	if summary.is_empty():
		_preview_label.visible = false
		_preview_label.text = ""
		return
	_preview_label.text = boarding_preview_text(summary)
	_preview_label.visible = true


func boarding_preview_text(summary: Dictionary) -> String:
	var entry: int = int(summary.get("entry", BoardingZone.Id.WAIST))
	var text := "%s · %s · %s" % [
		tr_n_defenders(int(summary.get("defenders", 0))),
		"%s %d" % [tr("Bells"), int(summary.get("bells", 0))],
		"%s %s" % [tr("Enter"), tr(BoardingZone.NAMES[clampi(entry, 0, BoardingZone.COUNT - 1)])]]
	if int(summary.get("officers", 0)) > 0:
		text += " · " + tr("Officer aboard")
	if int(summary.get("threats", 0)) > 0:
		text += " · " + tr("Escorts firing")
	return text


func tr_n_defenders(count: int) -> String:
	return "%d %s" % [count, tr("defenders") if count != 1 else tr("defender")]


func get_boarding_preview_label() -> Label:
	return _preview_label
