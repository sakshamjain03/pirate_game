extends Control

## DEBUG HARNESS — not part of the game (M22 Phase 2, tasks.md 2.6).
##
## Lays out every generated kit texture (assets/ui/kit/*.svg,
## assets/ui/icons/{research,cannonball}.svg) in a labelled grid so it can be
## screenshotted and reviewed against the v0.3 design doc's own component
## sheet — the visual test bed for Phases 3+ (design.md §6).
##
## Usage (headful only — the dummy renderer produces blank images):
##   godot --path <project> scenes/debug/UIKitSheet.tscn --capture-dir=<abs path>
## Also reachable via scenes/debug/UIScreenSweep.tscn once wired there.

const KIT_DIR := "res://assets/ui/kit"
const ICONS_DIR := "res://assets/ui/icons"
const CELL_SIZE := Vector2(180, 180)
const COLUMNS := 8
## M22 Phase 3.1/3.4 — extra vertical space reserved below the swatch grid
## for the live-controls section (real Button/Panel/HSlider/etc. instances
## with PirateThemeBuilder.build()'s theme applied — the only way to catch a
## texture_margin/content_margin mistake, since a raw swatch always looks
## fine in isolation and only reveals a bad 9-slice margin once something
## actually stretches it). Generous on purpose: a tall blank margin at the
## bottom is harmless for a debug capture, a clipped row is not.
const LIVE_CONTROLS_EXTRA_HEIGHT := 1000

## When true (the default — standalone `godot --path ... UIKitSheet.tscn`
## launch), this node drives its own window-resize/capture/quit from
## _ready(). UIScreenSweep sets this to false BEFORE add_child()-ing an
## instance of this scene, so it can drive the capture itself instead —
## both tools read the same shared `--capture-dir=` cmdline arg, so without
## this flag an embedded instance would see that arg too and quit the whole
## sweep early.
@export var self_capture := true

var _dir := ""
var _entry_count := 0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--capture-dir="):
			_dir = a.trim_prefix("--capture-dir=")
	_build_sheet()
	if not self_capture or _dir.is_empty():
		return
	size_window_to_fit()
	DirAccess.make_dir_recursive_absolute(_dir)
	await _capture()
	get_tree().quit(0)


## Sizes THIS node's window to fit every row without scrolling — a
## screenshot can only ever capture what's on-screen, and the item count
## grows with the kit, so a fixed guessed window size would silently start
## clipping rows again the next time a piece is added. Public so
## UIScreenSweep (self_capture = false) can call this itself instead of
## duplicating the math.
func size_window_to_fit() -> void:
	var rows := ceili(float(_entry_count) / COLUMNS)
	var needed := Vector2i(
		int(COLUMNS * (CELL_SIZE.x + 12) + 40),
		int(rows * (CELL_SIZE.y + 12) + 80 + LIVE_CONTROLS_EXTRA_HEIGHT))
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = needed


func _build_sheet() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(outer_vbox)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	outer_vbox.add_child(grid)

	var entries := _collect_entries()
	entries.sort()
	_entry_count = entries.size()
	for entry in entries:
		grid.add_child(_build_cell(entry))

	outer_vbox.add_child(_build_live_controls_section())
	# Applied AFTER parenting (not inside the builder) — apply_button_juice()
	# reads each Button's get_minimum_size() to add its text-clip-bug buffer
	# (PirateThemeBuilder's own header), which only resolves this theme's
	# real fonts/margins once the subtree is actually part of this
	# Control's live ancestor chain; done any earlier, it measures against
	# Godot's stock default theme instead and the buffer lands on the wrong
	# (much smaller) baseline.
	PirateThemeBuilder.apply_button_juice(outer_vbox)


func _collect_entries() -> Array:
	var entries := []
	for dir_path in [KIT_DIR, ICONS_DIR]:
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if fname.ends_with(".svg"):
				entries.append(dir_path.path_join(fname))
			fname = da.get_next()
		da.list_dir_end()
	return entries


func _build_cell(path: String) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.alignment = BoxContainer.ALIGNMENT_CENTER

	# A plain Control hosting two full-rect layers: the checker backdrop
	# (so transparency/near-white/near-black art all stay readable), then
	# the actual swatch on top, centred and aspect-kept.
	var swatch_area := Control.new()
	swatch_area.custom_minimum_size = Vector2(CELL_SIZE.x - 16, CELL_SIZE.y - 40)

	var checker := _make_checker_backdrop()
	checker.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch_area.add_child(checker)

	var tex_rect := TextureRect.new()
	tex_rect.texture = load(path)
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Without this, a TextureRect's reported *minimum size* defaults to the
	# texture's own native pixel size regardless of stretch_mode, forcing
	# the parent (and this cell) to grow to fit the biggest source texture
	# (parchment_panel at 320x320) — found by actually looking at the
	# capture, where it visibly overflowed into neighbouring cells.
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swatch_area.add_child(tex_rect)

	cell.add_child(swatch_area)

	var label := Label.new()
	label.text = path.get_file().get_basename()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_child(label)
	return cell


## A light/dark checkerboard behind each swatch so transparency and
## near-white/near-black art are both readable regardless of the debug
## scene's own background colour.
static var _checker_tex: ImageTexture = null

func _make_checker_backdrop() -> Control:
	var rect := TextureRect.new()
	rect.texture = _get_checker_texture()
	rect.stretch_mode = TextureRect.STRETCH_TILE
	return rect


func _get_checker_texture() -> ImageTexture:
	if _checker_tex:
		return _checker_tex
	var sq := 10
	var img := Image.create(sq * 2, sq * 2, false, Image.FORMAT_RGB8)
	var light := Color(0.62, 0.62, 0.62)
	var dark := Color(0.42, 0.42, 0.42)
	img.fill_rect(Rect2i(0, 0, sq, sq), light)
	img.fill_rect(Rect2i(sq, 0, sq, sq), dark)
	img.fill_rect(Rect2i(0, sq, sq, sq), dark)
	img.fill_rect(Rect2i(sq, sq, sq, sq), light)
	_checker_tex = ImageTexture.create_from_image(img)
	return _checker_tex


func _capture() -> void:
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var path := _dir.path_join("ui_kit_sheet.png")
	var err := img.save_png(path)
	print("[kit-sheet] %s -> err=%d" % [path, err])


## M22 Phase 3.1/3.4 — real instantiated Controls with
## PirateThemeBuilder.build()'s theme applied, below the raw swatch grid.
## The swatch grid shows the art; this shows the art *as a Godot 9-slice
## StyleBox actually stretched by a real Control* — the only way a bad
## texture_margin/content_margin choice becomes visible (a swatch always
## looks fine in isolation).
func _build_live_controls_section() -> Control:
	theme = PirateThemeBuilder.build()

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 16)

	var heading := Label.new()
	heading.text = "Live Controls (Phase 3 theme)"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	section.add_child(heading)

	section.add_child(_labeled_row("Labels", _build_label_row()))
	section.add_child(_labeled_row("Buttons", _build_button_row()))
	section.add_child(_labeled_row("Panels", _build_panel_row()))
	section.add_child(_labeled_row("Toggles / Checks", _build_toggle_row()))
	section.add_child(_labeled_row("Slider / Progress / Scroll", _build_slider_row()))
	section.add_child(_labeled_row("Dropdown / Tabs / LineEdit", _build_misc_control_row()))

	return section


func _labeled_row(caption: String, row: Control) -> Control:
	var wrap := VBoxContainer.new()
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 16)
	cap.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	wrap.add_child(cap)
	wrap.add_child(row)
	return wrap


func _build_label_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 24)
	for variation in ["DisplayLabel", "TitleLabel", "HudNumLabel", "BodyLabel", "ChipLabel"]:
		var l := Label.new()
		l.text = variation
		l.theme_type_variation = variation
		row.add_child(l)
	return row


func _build_button_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)

	var primary := Button.new()
	primary.text = "Set Sail"
	PirateThemeBuilder.mark_primary(primary)
	row.add_child(primary)

	var brass := Button.new()
	brass.text = "Settings"
	row.add_child(brass)

	var brass_disabled := Button.new()
	brass_disabled.text = "Locked"
	brass_disabled.disabled = true
	row.add_child(brass_disabled)

	var wood_round := Button.new()
	wood_round.text = "GO"
	wood_round.theme_type_variation = "WoodRoundButton"
	wood_round.custom_minimum_size = Vector2(96, 96)
	row.add_child(wood_round)

	return row


func _build_panel_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	for variation in ["ParchmentPanel", "WoodFramePanel", "PlaquePanel"]:
		var panel := PanelContainer.new()
		panel.theme_type_variation = variation
		panel.custom_minimum_size = Vector2(200, 100)
		var label := Label.new()
		label.text = variation
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		row.add_child(panel)
	return row


func _build_toggle_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 24)

	var on := CheckButton.new()
	on.text = "On"
	on.button_pressed = true
	row.add_child(on)

	var off := CheckButton.new()
	off.text = "Off"
	off.button_pressed = false
	row.add_child(off)

	var chk_on := CheckBox.new()
	chk_on.text = "Agree"
	chk_on.button_pressed = true
	row.add_child(chk_on)

	var chk_off := CheckBox.new()
	chk_off.text = "Disagree"
	chk_off.button_pressed = false
	row.add_child(chk_off)

	return row


func _build_slider_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 24)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 32)
	slider.value = 60
	row.add_child(slider)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(200, 32)
	progress.value = 70
	row.add_child(progress)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(120, 90)
	var inner := VBoxContainer.new()
	for i in range(10):
		var l := Label.new()
		l.text = "Row %d" % i
		inner.add_child(l)
	scroll.add_child(inner)
	row.add_child(scroll)

	return row


func _build_misc_control_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 24)

	var option := OptionButton.new()
	option.add_item("Common")
	option.add_item("Rare")
	option.add_item("Legendary")
	row.add_child(option)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(260, 120)
	var tab_a := Control.new()
	tab_a.name = "General"
	tabs.add_child(tab_a)
	var tab_b := Control.new()
	tab_b.name = "Controls"
	tabs.add_child(tab_b)
	row.add_child(tabs)

	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Captain name..."
	line_edit.custom_minimum_size = Vector2(240, 0)
	row.add_child(line_edit)

	return row
