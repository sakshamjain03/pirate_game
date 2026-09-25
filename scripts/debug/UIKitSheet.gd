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
		int(rows * (CELL_SIZE.y + 12) + 80))
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

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var entries := _collect_entries()
	entries.sort()
	_entry_count = entries.size()
	for entry in entries:
		grid.add_child(_build_cell(entry))


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
