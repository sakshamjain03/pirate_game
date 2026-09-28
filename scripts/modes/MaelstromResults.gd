class_name MaelstromResults extends Control

## Purpose: the end-of-run panel of a Maelstrom run (M26 Requirement 6.1).
## Responsibilities: shows time survived, kills, level, best time and Eights
##   earned; offers Retry and Main Menu. Pauses the tree while open.
## Dependencies: MaelstromRun (run_ended, retry, quit_to_menu), PirateThemeBuilder.
##
## Built in code, like UpgradeChoiceScreen: a bare Control in the scene.

@export var run_path: NodePath

var _run: MaelstromRun = null
var _panel: PanelContainer
var _dim: ColorRect
var _title: Label
var _rows: VBoxContainer
var _retry: Button
var _menu: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # must work with the tree paused
	theme = PirateThemeBuilder.build()
	_build()
	hide()
	_run = get_node_or_null(run_path) as MaelstromRun
	if _run:
		_run.run_ended.connect(open)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	PirateThemeBuilder.dress_modal_dim(_dim)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WoodFramePanel"
	centre.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	_title = Label.new()
	_title.text = tr("The Maelstrom Takes You")
	_title.theme_type_variation = &"DisplayLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	var page := PanelContainer.new()
	PirateThemeBuilder.dress_parchment_page(page)
	col.add_child(page)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	page.add_child(_rows)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	col.add_child(buttons)

	_retry = Button.new()
	_retry.name = "RetryButton"
	_retry.text = tr("Sail Again")
	_retry.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(300, 92))
	_retry.pressed.connect(_on_retry)
	buttons.add_child(_retry)
	# No coral Primary: the ship just sank, and M22's rule (DeathScreen) is that
	# a pulsing "go!" on defeat reads as celebration. Two brass ways forward.

	_menu = Button.new()
	_menu.name = "MenuButton"
	_menu.text = tr("Main Menu")
	_menu.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(300, 92))
	_menu.pressed.connect(_on_menu)
	buttons.add_child(_menu)

	PirateThemeBuilder.apply_button_juice(self)


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func open(summary: Dictionary) -> void:
	for child in _rows.get_children():
		child.queue_free()
	var seconds := float(summary.get("seconds", 0.0))
	var best := float(summary.get("best_seconds", seconds))
	_add_row(tr("Time survived"), format_time(seconds))
	_add_row(tr("Ships sunk"), str(int(summary.get("kills", 0))))
	_add_row(tr("Level reached"), str(int(summary.get("level", 1))))
	var best_text := format_time(best)
	if seconds >= best and int(summary.get("runs", 1)) > 1:
		best_text += "  " + tr("(new best!)")
	_add_row(tr("Best time"), best_text)
	_add_row(tr("Pieces of Eight"), "+%d" % int(summary.get("eights", 0)))

	show()
	UIMotion.modal_enter(_panel, _dim)
	get_tree().paused = true
	_retry.grab_focus()


func _add_row(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var l := Label.new()
	l.text = label
	l.theme_type_variation = &"InkBodyLabel"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.theme_type_variation = &"InkTitleLabel"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	_rows.add_child(row)


func get_row_texts() -> Array[String]:
	## For tests: "label=value" per row.
	var out: Array[String] = []
	for row in _rows.get_children():
		if row.is_queued_for_deletion():
			continue
		out.append("%s=%s" % [row.get_child(0).text, row.get_child(1).text])
	return out


func _on_retry() -> void:
	if _run:
		_run.retry()


func _on_menu() -> void:
	if _run:
		_run.quit_to_menu()
