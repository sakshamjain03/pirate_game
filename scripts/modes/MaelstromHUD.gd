class_name MaelstromHUD extends Control

## Purpose: the in-run readout of a Maelstrom run (M26).
## Responsibilities: time survived, level + plunder bar, ships sunk and hull, plus
##   an "Abandon" button that ends the run (it still counts). Deliberately NOT
##   WorldHUD, which is wired to CampaignManager, docking and Systems/* nodes.
## Dependencies: MaelstromRun (stats_changed), the player ship's ShipDamage.
##
## Touch controls come from the MobileControls scene placed beside this node;
## it finds the player_ship group on its own.

@export var run_path: NodePath

var _run: MaelstromRun = null
var _time_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _kills_label: Label
var _hull_bar: ProgressBar
var _abandon: Button


func _ready() -> void:
	theme = PirateThemeBuilder.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_build()
	_run = get_node_or_null(run_path) as MaelstromRun
	if _run:
		_run.stats_changed.connect(_refresh)
		_run.run_ended.connect(func(_s): _abandon.disabled = true)
	_refresh()


func _build() -> void:
	# One card, top-centre, laid out by containers (never sibling pixel offsets).
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.add_theme_constant_override("margin_top", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var card := PanelContainer.new()
	card.theme_type_variation = &"HudCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	_time_label = _num_label(row)
	_level_label = _num_label(row)
	_kills_label = _num_label(row)

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.max_value = 1.0
	_xp_bar.custom_minimum_size = PirateThemeBuilder.scaled_size(Vector2(420, 14))
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_xp_bar)

	_hull_bar = ProgressBar.new()
	_hull_bar.theme_type_variation = &"HullBar"
	_hull_bar.show_percentage = false
	_hull_bar.max_value = 1.0
	_hull_bar.custom_minimum_size = PirateThemeBuilder.scaled_size(Vector2(420, 14))
	_hull_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hull_bar)

	var corner := MarginContainer.new()
	corner.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.add_theme_constant_override("margin_top", 16)
	corner.add_theme_constant_override("margin_right", 16)
	add_child(corner)
	_abandon = Button.new()
	_abandon.name = "AbandonButton"
	_abandon.text = tr("Abandon")
	_abandon.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(180, 64))
	_abandon.pressed.connect(func(): if _run: _run.end_run_early())
	corner.add_child(_abandon)
	PirateThemeBuilder.apply_button_juice(corner)


func _num_label(parent: Node) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"HudNumLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	# Time and hull move every frame; everything else refreshes on stats_changed.
	if not _run:
		return
	_time_label.text = "⏱ " + MaelstromResults.format_time(_run.elapsed)
	var ship := get_tree().get_first_node_in_group("player_ship")
	var dmg = ship.get_node_or_null("ShipDamage") if ship else null
	if dmg:
		var maximum: float = dmg.get_pool_maximum("hull")
		_hull_bar.value = dmg.hull / maximum if maximum > 0.0 else 0.0


func _refresh() -> void:
	if not _run:
		return
	_level_label.text = tr("Level %d") % _run.level
	_kills_label.text = "☠ %d" % _run.kills
	_xp_bar.value = _run.xp_fraction()
