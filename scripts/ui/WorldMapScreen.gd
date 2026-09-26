class_name WorldMapScreen extends Control

## Purpose: M10 Requirement 3 — shows the player where they are, what
## they've found, and where they haven't been. Same pause-and-show modal
## pattern as CaptainsLog: opens paused, closes back to gameplay.
## Responsibilities: draws the three region rings and discovered island
## markers from IslandData.world_position, the player's position/heading
## reusing the same ship-controller data source WorldHUD's compass already
## reads, and a "View Log" button opening the existing CaptainsLog rather
## than duplicating its objective list.
## Dependencies: RegionData (resources/world/regions/), IslandData, CaptainsLog.

@onready var map_display: Control = %MapDisplay
@onready var close_button: Button = %CloseButton
@onready var view_log_button: Button = %ViewLogButton
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var info_panel: RichTextLabel = %InfoPanel

## Margin so the outermost ring doesn't touch MapDisplay's edge.
const _DISPLAY_MARGIN := 16.0
## Small fixed compass rose tucked in MapDisplay's corner — screen-space only,
## independent of the world-to-local ring/island scale (docs/11_WORLD_MAP.md
## §2: +X = East, +Z = South, so screen-down already reads as south and no
## rotation is needed for "up = north").
const _COMPASS_MARGIN := 10.0
const _COMPASS_RADIUS := 22.0
## How close a tap/click needs to land to an island marker to select it.
const _TAP_HIT_RADIUS := 16.0
## Dossier column width (scene) — the mobile sizing reserves it.
const _DOSSIER_WIDTH := 460.0
## Map text: the theme's Baloo at chip size with an ink outline so ring and
## island names stay legible where they cross a ring line (was the engine
## fallback font at 12-13px, unreadable on a phone).
const _MAP_FONT_SIZE := 24
const _MAP_OUTLINE := 6

var _regions: Array[RegionData] = []
var _world_radius: float = 1.0
var _player_pos: Vector2 = Vector2.ZERO
var _player_heading_deg: float = 0.0
var _has_player: bool = false
var _selected_island: IslandData = null


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.apply_button_juice(self)
	close_button.pressed.connect(close)
	view_log_button.pressed.connect(_on_view_log_pressed)
	map_display.draw.connect(_on_map_display_draw)
	map_display.gui_input.connect(_on_map_display_gui_input)
	_load_regions()
	if PirateThemeBuilder.is_mobile():
		_apply_mobile_sizing()


func _apply_mobile_sizing() -> void:
	panel.custom_minimum_size = MobileLayoutManager.mobile_dialog_size(panel.custom_minimum_size, get_viewport())
	# The map itself is the whole point of this screen — let it grow with the
	# panel (which is now a generous fraction of the real viewport, not a
	# flat multiple of a small PC box) rather than capping it at its own
	# separately-scaled minimum, which previously left a large blank
	# region inside a still-too-small panel.
	# M22 Phase 6.3: map left, parchment dossier right (v0.3 screen 01), so
	# the map gets the panel's height minus the title and the width left of
	# the dossier column.
	map_display.custom_minimum_size = Vector2(
		maxf(320.0, panel.custom_minimum_size.x - _DOSSIER_WIDTH - 120.0),
		maxf(320.0, panel.custom_minimum_size.y - 160.0))
	for btn in [view_log_button, close_button]:
		btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(140, 48))


func _load_regions() -> void:
	# Same DirAccess-scan pattern EmpireManager/CampaignManager already use
	# for region/chapter resources — reused here rather than adding a public
	# getter to EmpireManager's own (intentionally private) region list.
	_regions.clear()
	var dir := DirAccess.open("res://resources/world/regions/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var region := load("res://resources/world/regions/" + file_name) as RegionData
				if region:
					_regions.append(region)
			file_name = dir.get_next()
	for region in _regions:
		_world_radius = max(_world_radius, region.display_ring_radius)


func open() -> void:
	_refresh_player_state()
	_selected_island = null
	_update_info_panel()
	show()
	get_tree().paused = true
	map_display.queue_redraw()


func close() -> void:
	hide()
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_view_log_pressed() -> void:
	# WorldMapScreen is instanced as a sibling of %CaptainsLog inside
	# WorldHUD.tscn — Godot 4's scene-unique-name lookup resolves "%Name"
	# tree-wide within that shared scene owner, so this reaches the same
	# node WorldHUD.gd itself refers to, no new wiring needed.
	var log := get_node_or_null("%CaptainsLog")
	if log and log.has_method("open"):
		log.open()


func _refresh_player_state() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")
	_has_player = ship != null and is_instance_valid(ship)
	if _has_player:
		_player_pos = Vector2(ship.global_position.x, ship.global_position.z)
		_player_heading_deg = fmod(ship.global_rotation_degrees.y, 360.0)


func _world_to_local(world_xz: Vector2, display_radius: float) -> Vector2:
	var center := map_display.size * 0.5
	var scale := display_radius / _world_radius
	return center + Vector2(world_xz.x, world_xz.y) * scale


## Discovered islands only, with their current on-screen marker position —
## the single source both the draw pass and the tap-hit-test read from, so
## "what's visible" and "what's tappable" can never drift apart.
func _get_visible_island_markers(display_radius: float) -> Array:
	var out := []
	for island in get_tree().get_nodes_in_group("islands"):
		if not island.island_data or not island.island_data.discovered:
			continue
		out.append({
			"data": island.island_data,
			"pos": _world_to_local(island.island_data.world_position, display_radius),
		})
	return out


func _on_map_display_draw() -> void:
	var display_radius: float = max(0.0, min(map_display.size.x, map_display.size.y) * 0.5 - _DISPLAY_MARGIN)
	var center := map_display.size * 0.5
	var pal := UITokens.palette()
	_placed_label_rects.clear()
	# The sea: a teal disc under the rings (v0.3 screen 01's chart), shallow at
	# the centre (home waters) darkening outward.
	map_display.draw_circle(center, display_radius, pal.ocean_deep)
	map_display.draw_circle(center, display_radius * 0.72, pal.ocean_deep.lerp(pal.sunset_teal, 0.5))
	map_display.draw_circle(center, display_radius * 0.42, pal.sunset_teal)

	# Concentric region rings, outermost first so inner rings draw on top.
	# Each gets a name label at a tier-staggered bearing so a 3-5 region
	# world doesn't pile every label at the same spot on the ring.
	var sorted_regions := _regions.duplicate()
	sorted_regions.sort_custom(func(a, b): return a.display_ring_radius > b.display_ring_radius)
	for region in sorted_regions:
		var r: RegionData = region
		if r.display_ring_radius <= 0.0:
			continue
		var radius: float = (r.display_ring_radius / _world_radius) * display_radius
		map_display.draw_arc(center, radius, 0.0, TAU, 64, UITokens.palette().brass, 2.0, true)
		# Bearing offset by 200 deg (not a bare tier*72) and pushed 10% past the
		# ring line — a plain tier-indexed stagger put "Beginner Waters" and
		# "Contested Waters" right on top of Skull Cove/Tortuga's own markers,
		# since this world's actual geography clusters north/north-east
		# (docs/11_WORLD_MAP.md §4c); this offset was chosen by checking against
		# that real layout, not a blind formula.
		var bearing_rad: float = deg_to_rad(fmod(float(r.tier - 1) * 72.0 + 200.0, 360.0))
		var label_pos := center + Vector2(sin(bearing_rad), -cos(bearing_rad)) * radius * 1.08
		_draw_map_text(label_pos, r.display_name, HORIZONTAL_ALIGNMENT_CENTER, pal.horizon_gold)
		_placed_label_rects.append(_text_rect(label_pos, r.display_name, true))

	# Island markers. Undiscovered islands are omitted entirely rather than
	# shown as a "?" — the milestone's own framing (docs/00_VISION.md's
	# Explore pillar) is real mystery, not just withheld names, so this
	# leans toward true fog of war over a spoiler-y placeholder pin.
	var markers := _get_visible_island_markers(display_radius)
	for marker in markers:
		var data: IslandData = marker.data
		var pos: Vector2 = marker.pos
		if data == _selected_island:
			map_display.draw_arc(pos, 10.0, 0.0, TAU, 24, UITokens.palette().text_on_dark, 2.0, true)
		map_display.draw_circle(pos, 6.0, UITokens.palette().brass_light)
		var at := _free_label_position(pos, data.island_name)
		_draw_map_text(at, data.island_name, HORIZONTAL_ALIGNMENT_LEFT, pal.text_on_dark)
		_placed_label_rects.append(_text_rect(at, data.island_name, false))

	# Player position/heading marker — a small triangle pointing along yaw,
	# reusing the same ship global_position/global_rotation_degrees.y data
	# source WorldHUD's compass needle already reads (WorldHUD.gd's
	# _process(), not re-derived independently here).
	if _has_player:
		var ppos := _world_to_local(_player_pos, display_radius)
		var heading_rad := deg_to_rad(_player_heading_deg)
		var tip := ppos + Vector2(sin(heading_rad), -cos(heading_rad)) * 10.0
		var left := ppos + Vector2(sin(heading_rad + 2.5), -cos(heading_rad + 2.5)) * 6.0
		var right := ppos + Vector2(sin(heading_rad - 2.5), -cos(heading_rad - 2.5)) * 6.0
		map_display.draw_colored_polygon(PackedVector2Array([tip, left, right]),
			UITokens.palette().hp_good)

	_draw_compass_rose()


## Small fixed N/E/S/W rose in the corner — this is a static top-down world
## projection (not player-relative, see class doc), so "up" is always north
## and the rose never needs to rotate.
func _draw_compass_rose() -> void:
	var origin := Vector2(map_display.size.x - _COMPASS_MARGIN - _COMPASS_RADIUS,
		_COMPASS_MARGIN + _COMPASS_RADIUS)
	map_display.draw_circle(origin, _COMPASS_RADIUS, Color(0.05, 0.07, 0.14, 0.55))
	map_display.draw_arc(origin, _COMPASS_RADIUS, 0.0, TAU, 32, UITokens.palette().brass, 1.5, true)
	var dirs := {"N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0}
	for label in dirs:
		var rad: float = deg_to_rad(dirs[label])
		var dir := Vector2(sin(rad), -cos(rad))
		map_display.draw_line(origin, origin + dir * (_COMPASS_RADIUS - 4.0),
			UITokens.palette().brass, 1.5)
		var text_pos := origin + dir * (_COMPASS_RADIUS + 11.0)
		_draw_map_text(text_pos + Vector2(-_MAP_FONT_SIZE * 0.5, _MAP_FONT_SIZE * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, UITokens.palette().text_on_dark, _MAP_FONT_SIZE)


## Labels already drawn this pass (ring names first, then islands), so an
## island label can step aside instead of printing over its neighbour —
## at the legible chip size, close islands (Blackwater Shoal / Frostbite Reef)
## overprinted each other.
var _placed_label_rects: Array[Rect2] = []

func _text_rect(baseline_pos: Vector2, text: String, centred: bool) -> Rect2:
	var font: Font = get_theme_font("font", "Label")
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _MAP_FONT_SIZE)
	var x := baseline_pos.x - (sz.x * 0.5 if centred else 0.0)
	return Rect2(x, baseline_pos.y - sz.y * 0.8, sz.x, sz.y).grow(2.0)


## Right of the marker if free, else left, above, below (first that clears
## every label placed so far); right if none does.
func _free_label_position(marker: Vector2, text: String) -> Vector2:
	var font: Font = get_theme_font("font", "Label")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _MAP_FONT_SIZE).x
	var candidates := [marker + Vector2(12, 8), marker + Vector2(-12 - w, 8),
		marker + Vector2(-w * 0.5, -14), marker + Vector2(-w * 0.5, 32)]
	for c in candidates:
		var r := _text_rect(c, text, false)
		var clear := true
		for placed in _placed_label_rects:
			if placed.intersects(r):
				clear = false
				break
		if clear:
			return c
	return candidates[0]


func _draw_map_text(pos: Vector2, text: String, align: HorizontalAlignment, color: Color,
		width: float = -1) -> void:
	var font: Font = get_theme_font("font", "Label")
	var w := width
	if align == HORIZONTAL_ALIGNMENT_CENTER and w < 0:
		# draw_string centres within `width`; give it the text's own width and
		# shift left by half so the text centres ON pos, like before.
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _MAP_FONT_SIZE).x
		pos.x -= w * 0.5
	map_display.draw_string_outline(font, pos, text, align, w, _MAP_FONT_SIZE, _MAP_OUTLINE,
		UITokens.palette().ink)
	map_display.draw_string(font, pos, text, align, w, _MAP_FONT_SIZE, color)


func _on_map_display_gui_input(event: InputEvent) -> void:
	var press_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		press_pos = event.position
	if press_pos == Vector2.INF:
		return

	var display_radius: float = max(0.0, min(map_display.size.x, map_display.size.y) * 0.5 - _DISPLAY_MARGIN)
	var nearest: IslandData = null
	var nearest_dist := _TAP_HIT_RADIUS
	for marker in _get_visible_island_markers(display_radius):
		var d: float = press_pos.distance_to(marker.pos)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = marker.data

	_selected_island = nearest
	_update_info_panel()
	map_display.queue_redraw()


## Fills InfoPanel with the tapped island's dossier — name, region/tier,
## distance from home (the same "distance = danger" metric
## docs/11_WORLD_MAP.md's ring bands are built on, not the player's live
## position), the one-line codex summary, and its real-world echo if any.
func _update_info_panel() -> void:
	if not is_instance_valid(info_panel):
		return
	if not _selected_island:
		info_panel.text = tr("Tap an island for its dossier.")
		return

	var region: RegionData = EmpireManager.get_region_for_island(_selected_island.island_id) \
		if EmpireManager else null
	var region_bit := ""
	if region:
		# Own line under the name: " — Region" after a title-size bold name
		# wrapped, leaving a dangling "Port Royal —" heading.
		region_bit = "
%s (tier %d)" % [region.display_name, region.tier]
	var distance := _selected_island.world_position.length()

	var bbcode := "[b]%s[/b]%s\n%s" % [
		_selected_island.island_name, region_bit,
		tr("~%d u from home") % int(round(distance)),
	]
	if not _selected_island.codex_summary.is_empty():
		bbcode += "\n" + _selected_island.codex_summary
	if not _selected_island.real_world_echo.is_empty():
		bbcode += "\n[i]%s[/i]" % _selected_island.real_world_echo
	info_panel.text = bbcode
