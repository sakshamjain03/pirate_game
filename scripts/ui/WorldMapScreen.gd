class_name WorldMapScreen extends Control

## Purpose: M10 Requirement 3's world chart, rebuilt in M22 Phase 6d to v0.3
## screen 01 — a sunset-sea chart the player reads at a glance and acts on:
## island medallions in their terrain colours with a faction glow and a
## name plaque ("Port Royal · You", "Skull Cove · T3"), the player's ship
## bobbing where it really is, a dashed route that scrolls toward the picked
## target inside a slowly turning gold ring, a faction legend, and a torn-
## parchment dossier (status, region, distance, danger, codex) whose one
## coral action sets the HUD's course marker to that island.
## Responsibilities: presentation + selection only. Distance/danger come from
## IslandData/RegionData; "Set Course" hands the target to WorldHUD.set_course
## (a HUD waypoint — no gameplay system changes). Undiscovered islands stay
## hidden (true fog of war, docs/00_VISION.md's Explore pillar).
## Dependencies: RegionData, IslandData, FactionData, EmpireManager, WorldHUD
## ("hud" group), UIMotion, PirateThemeBuilder.

signal course_requested(island: IslandData)

@onready var map_display: Control = %MapDisplay
@onready var close_button: Button = %CloseButton
@onready var view_log_button: Button = %ViewLogButton
@onready var set_course_button: Button = %SetCourseButton
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var info_panel: RichTextLabel = %InfoPanel
@onready var dossier_title: Label = %DossierTitle
@onready var faction_row: HBoxContainer = %FactionRow
@onready var faction_chip: Panel = %FactionChip
@onready var faction_label: Label = %FactionLabel
@onready var rows: GridContainer = %Rows
@onready var legend_grid: GridContainer = %LegendGrid
@onready var sea: TextureRect = %Sea
@onready var sea_lines: Control = %SeaLines

## Margin so the outermost island doesn't touch MapDisplay's edge.
const _DISPLAY_MARGIN := 16.0
## Extra reach beyond a medallion's own radius that still counts as a tap.
const _TAP_HIT_RADIUS := 16.0
## Dossier column width (scene) — the mobile sizing reserves it.
const _DOSSIER_WIDTH := 460.0
const _PLAQUE_FONT_SIZE := 22
## Room kept free around the fitted archipelago: medallion + plaque at the
## sides/top, and the legend card along the bottom.
const _FIT_MARGIN_X := 90.0
const _RADIAL_EXPONENT := 0.7
const _FIT_MARGIN_TOP := 70.0
const _FIT_MARGIN_BOTTOM := 60.0
## v0.3 sky-to-sea chart background (screen 01's own gradient stops).
const _SEA_STOPS := [[0.0, "#2B2440"], [0.09, "#6B3D4A"], [0.16, "#D98A55"], [0.20, "#F4C96E"],
	[0.22, "#E8B56A"], [0.27, "#3A9A97"], [0.50, "#1F6F76"], [0.76, "#124952"], [1.0, "#0A2C33"]]
## Medallion light / mid / shadow per IslandData.TerrainTheme.
const _TERRAIN := {
	IslandData.TerrainTheme.TROPICAL: ["#EFD89A", "#6F9A4A", "#2F4A2A"],
	IslandData.TerrainTheme.VOLCANIC: ["#E8A878", "#8A4A2A", "#3A1A10"],
	IslandData.TerrainTheme.FROZEN: ["#F2F8FB", "#9CC4D6", "#3A5A6A"],
	IslandData.TerrainTheme.DROWNED_RUIN: ["#B8B39A", "#5B6A58", "#27332F"],
	IslandData.TerrainTheme.FORTIFIED: ["#C9C0A0", "#6D7F58", "#2E3F33"],
	IslandData.TerrainTheme.CALDERA: ["#E3CF94", "#7A8A4A", "#39402A"],
}
## v0.3 "Your Fleet" chip (#3a7ae0 over #3a3d42) and a neutral sand chip.
const _YOU_COLORS := ["#3A7AE0", "#3A3D42"]
const _NEUTRAL_COLORS := ["#EFE2C0", "#6B4428"]
const _DANGER := ["Calm", "Choppy", "Spicy", "Deadly", "Legendary"]
const _RING_SPIN_SEC := 14.0     ## v0.3 "target ring spin 14s"
const _DASH_SCROLL_SEC := 1.0    ## v0.3 "trail dash-scroll 1s loop"
const _SHIP_BOB_SEC := 2.6       ## v0.3 bob keyframe

var _regions: Array[RegionData] = []
var _world_radius: float = 1.0
var _player_pos: Vector2 = Vector2.ZERO
var _player_heading_deg: float = 0.0
var _has_player: bool = false
var _selected_island: IslandData = null
var _t := 0.0
var _placed_label_rects: Array[Rect2] = []


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.dress_modal_dim($ColorRect)
	sea.texture = _make_sea_texture()
	PirateThemeBuilder.mark_primary(set_course_button)
	PirateThemeBuilder.apply_button_juice(self)
	close_button.pressed.connect(close)
	view_log_button.pressed.connect(_on_view_log_pressed)
	set_course_button.pressed.connect(_on_set_course_pressed)
	map_display.draw.connect(_on_map_display_draw)
	map_display.gui_input.connect(_on_map_display_gui_input)
	map_display.resized.connect(map_display.queue_redraw)
	sea_lines.draw.connect(_on_sea_lines_draw)
	info_panel.add_theme_font_size_override("normal_font_size", UITokens.FONT_CHIP + 4)
	info_panel.add_theme_font_size_override("italics_font_size", UITokens.FONT_CHIP + 4)
	set_process(false)
	_load_regions()
	if PirateThemeBuilder.is_mobile():
		_apply_mobile_sizing()


func _apply_mobile_sizing() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Phone: fit inside the Margin's 20/24 insets with room to spare, and
	# shrink the dossier's floors so its content can't push past the screen.
	panel.custom_minimum_size = Vector2(maxf(320.0, vp.x - 96.0), maxf(320.0, vp.y - 64.0))
	info_panel.custom_minimum_size.y = 48.0
	set_course_button.custom_minimum_size.y = 96.0  # the 48dp touch floor
	map_display.custom_minimum_size = Vector2(
		maxf(320.0, panel.custom_minimum_size.x - _DOSSIER_WIDTH - 28.0),
		maxf(320.0, panel.custom_minimum_size.y - 120.0))
	for btn in [view_log_button, close_button]:
		btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(140, 48))


func _make_sea_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(_SEA_STOPS.map(func(s): return s[0]))
	g.colors = PackedColorArray(_SEA_STOPS.map(func(s): return Color(s[1])))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	return tex


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
	_build_legend()
	show()
	UIMotion.modal_enter(panel, $ColorRect)
	get_tree().paused = true
	set_process(true)
	map_display.queue_redraw()


func close() -> void:
	hide()
	set_process(false)
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _process(delta: float) -> void:
	# The chart is alive (v0.3): the target ring turns, the route dashes
	# scroll, the ship bobs, the swell drifts. Reduced motion freezes it.
	if UIMotion.reduced_motion():
		return
	_t += delta
	map_display.queue_redraw()
	sea_lines.queue_redraw()


func _on_view_log_pressed() -> void:
	# WorldMapScreen is instanced as a sibling of %CaptainsLog inside
	# WorldHUD.tscn — Godot 4's scene-unique-name lookup resolves "%Name"
	# tree-wide within that shared scene owner, so this reaches the same
	# node WorldHUD.gd itself refers to, no new wiring needed.
	var log := get_node_or_null("%CaptainsLog")
	if log and log.has_method("open"):
		log.open()


func _on_set_course_pressed() -> void:
	if not _selected_island:
		return
	course_requested.emit(_selected_island)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_course"):
		hud.set_course(_selected_island)
	close()


func _refresh_player_state() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")
	_has_player = ship != null and is_instance_valid(ship)
	if _has_player:
		_player_pos = Vector2(ship.global_position.x, ship.global_position.z)
		_player_heading_deg = fmod(ship.global_rotation_degrees.y, 360.0)


func _display_radius() -> float:
	return max(0.0, min(map_display.size.x, map_display.size.y) * 0.5 - _DISPLAY_MARGIN)


## World XZ -> MapDisplay local. 6d: fitted to the whole archipelago's
## bounding box (every island, discovered or not, so the chart never jumps as
## islands are found) instead of the outermost ring, which left the real
## islands in a clump mid-chart and clipped the northernmost off the top.
## `display_radius` is kept for the callers/tests that pass it.
func _world_to_local(world_xz: Vector2, _display_radius: float) -> Vector2:
	var fit := _fit()
	return fit.origin + (_compress(world_xz) - fit.world_centre) * fit.scale


## Radial compression about home (distance^_RADIAL_EXPONENT). The real
## archipelago is a tight home cluster plus far outliers, which a linear fit
## stacked on top of each other; this spreads the cluster while keeping the
## order of distances — "further out = more dangerous" still reads true
## (docs/11_WORLD_MAP.md's ring bands).
func _compress(world_xz: Vector2) -> Vector2:
	var d := world_xz.length()
	if d < 0.001:
		return Vector2.ZERO
	return world_xz / d * pow(d, _RADIAL_EXPONENT)


func _fit() -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for island in get_tree().get_nodes_in_group("islands"):
		if "island_data" in island and island.island_data:
			var p: Vector2 = _compress(island.island_data.world_position)
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF:
		lo = Vector2(-_world_radius, -_world_radius)
		hi = -lo
	var span := (hi - lo).max(Vector2(200.0, 200.0))
	var avail := map_display.size - Vector2(_FIT_MARGIN_X * 2.0, _FIT_MARGIN_TOP + _FIT_MARGIN_BOTTOM)
	var k := minf(avail.x / span.x, avail.y / span.y)
	var world_centre := (lo + hi) * 0.5
	var origin := Vector2(map_display.size.x * 0.5,
		_FIT_MARGIN_TOP + avail.y * 0.5)
	return {"scale": k, "world_centre": world_centre, "origin": origin}


func _region_of(data: IslandData) -> RegionData:
	return EmpireManager.get_region_for_island(data.island_id) if EmpireManager else null


func _tier_of(data: IslandData) -> int:
	var region := _region_of(data)
	return region.tier if region else 1


## Medallion radius: home/capital biggest, then by region tier.
func _medallion_radius(data: IslandData) -> float:
	var k := clampf(_display_radius() / 320.0, 0.6, 1.4)
	var base := 52.0 * k if data.island_type == IslandData.IslandType.CAPITAL else (26.0 + _tier_of(data) * 5.0) * k
	# Never wider than 42% of the gap to the nearest island on screen, so
	# neighbouring medallions can't overlap however tight the cluster.
	var me := _world_to_local(data.world_position, 0.0)
	var nearest := INF
	for island in get_tree().get_nodes_in_group("islands"):
		if "island_data" in island and island.island_data and island.island_data != data:
			nearest = minf(nearest, me.distance_to(_world_to_local(island.island_data.world_position, 0.0)))
	return minf(base, maxf(14.0, nearest * 0.42))


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


func _faction_colors(data: IslandData) -> Array:
	if data.is_owned_by_player():
		return [Color(_YOU_COLORS[0]), Color(_YOU_COLORS[1])]
	var f := data.owner_faction as FactionData
	if f:
		return [f.sail_color, f.hull_color]
	return [Color(_NEUTRAL_COLORS[0]), Color(_NEUTRAL_COLORS[1])]


func _faction_name(data: IslandData) -> String:
	if data.is_owned_by_player():
		return tr("Your Empire")
	var f := data.owner_faction as FactionData
	return f.faction_name if f else tr("Unclaimed")


# ---------------------------------------------------------------- drawing

func _on_sea_lines_draw() -> void:
	# v0.3 swell: faint light crests and dark troughs, drifting down slowly.
	var h := sea_lines.size.y
	var w := sea_lines.size.x
	var drift := fmod(_t * 8.0, 66.0)
	var y := h * 0.26 + drift
	while y < h:
		sea_lines.draw_line(Vector2(0, y), Vector2(w, y - 6), Color(210.0 / 255, 245.0 / 255, 235.0 / 255, 0.07), 4.0)
		sea_lines.draw_line(Vector2(0, y + 30), Vector2(w, y + 24), Color(0, 20.0 / 255, 25.0 / 255, 0.12), 6.0)
		y += 66.0


func _on_map_display_draw() -> void:
	var display_radius := _display_radius()
	var center := map_display.size * 0.5
	var pal := UITokens.palette()
	_placed_label_rects.clear()
	var legend: Control = %Legend
	if legend and legend.visible:
		_placed_label_rects.append(Rect2(legend.position, legend.size).grow(6.0))
	# Faint tier rings: distance still reads as danger (docs/11_WORLD_MAP.md),
	# but they are sea currents now, not the chart itself.
	for region in _regions:
		if region.display_ring_radius <= 0.0:
			continue
		var fit := _fit()
		var radius: float = pow(region.display_ring_radius, _RADIAL_EXPONENT) * float(fit.scale)
		map_display.draw_arc(_world_to_local(Vector2.ZERO, display_radius), radius, 0.0, TAU, 96, Color(pal.brass_light.r, pal.brass_light.g, pal.brass_light.b, 0.14), 3.0, true)

	var markers := _get_visible_island_markers(display_radius)
	var selected_pos := Vector2.INF
	for marker in markers:
		if marker.data == _selected_island:
			selected_pos = marker.pos
	if _has_player and selected_pos != Vector2.INF:
		_draw_route(_world_to_local(_player_pos, display_radius), selected_pos, _medallion_radius(_selected_island))
	for marker in markers:
		_draw_medallion(marker.data, marker.pos)
		# Plaques must step around every medallion too, not just each other.
		var mr := _medallion_radius(marker.data)
		_placed_label_rects.append(Rect2(marker.pos - Vector2(mr, mr), Vector2(mr, mr) * 2.0))
	if selected_pos != Vector2.INF:
		# Spinning dashed gold target ring (v0.3: 2.5px dashed #f2c66d, 14s),
		# over every medallion so a neighbour can't hide it.
		var ring_r := _medallion_radius(_selected_island) + 16.0
		var spin := fmod(_t / _RING_SPIN_SEC, 1.0) * TAU
		for i in 24:
			var a0 := spin + TAU * i / 24.0
			map_display.draw_arc(selected_pos, ring_r, a0, a0 + TAU / 48.0, 6, Color("#F2C66D"), 5.0, true)
	for marker in markers:
		_draw_plaque(marker.data, marker.pos)
	if _has_player:
		_draw_ship(_world_to_local(_player_pos, display_radius))


func _draw_route(from: Vector2, to: Vector2, target_r: float) -> void:
	# v0.3: a dark under-stroke plus a dashed cream line scrolling toward the
	# target (stroke-dasharray 2 10, dash 1s loop).
	var dir := (to - from)
	if dir.length() < target_r + 8.0:
		return
	var end := to - dir.normalized() * (target_r + 10.0)
	var normal := Vector2(-dir.y, dir.x).normalized() * dir.length() * 0.18
	var c1 := from + dir * 0.33 + normal
	var c2 := from + dir * 0.66 - normal * 0.4
	var pts := PackedVector2Array()
	for i in 41:
		var t := i / 40.0
		pts.append(from.bezier_interpolate(c1, c2, end, t))
	map_display.draw_polyline(pts, Color(10.0 / 255, 40.0 / 255, 45.0 / 255, 0.45), 14.0, true)
	var step := 24.0
	var offset := fmod(_t / _DASH_SCROLL_SEC, 1.0) * step
	var acc := step - offset
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		var seg_len := seg.length()
		while acc <= seg_len:
			map_display.draw_circle(pts[i - 1] + seg.normalized() * acc, 4.0, Color("#FFF1C8"))
			acc += step
		acc -= seg_len


func _medallion_points(pos: Vector2, r: float, phase: float) -> PackedVector2Array:
	# v0.3 medallions are not perfect circles (border-radius 50% 48% 46% 54%).
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var k := 1.0 + 0.035 * sin(3.0 * a + phase) + 0.02 * sin(5.0 * a + phase * 1.7)
		pts.append(pos + Vector2(cos(a), sin(a)) * r * k)
	return pts


func _draw_medallion(data: IslandData, pos: Vector2) -> void:
	var r := _medallion_radius(data)
	var cols: Array = _faction_colors(data)
	var glow: Color = cols[0]
	# Faction glow halo (v0.3: radial faction colour -> 0 at 68%).
	for i in 8:
		var gr := r * (1.55 - i * 0.07)
		map_display.draw_circle(pos, gr, Color(glow.r, glow.g, glow.b, 0.06))
	var terrain: Array = _TERRAIN.get(data.terrain_theme, _TERRAIN[IslandData.TerrainTheme.TROPICAL])
	var phase := float(data.island_id.hash() % 100) * 0.1
	var shadow := _medallion_points(pos + Vector2(0, 5), r, phase)
	map_display.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	map_display.draw_colored_polygon(_medallion_points(pos, r, phase), Color(terrain[2]))
	map_display.draw_colored_polygon(_medallion_points(pos - Vector2(r, r) * 0.1, r * 0.8, phase), Color(terrain[1]))
	map_display.draw_colored_polygon(_medallion_points(pos - Vector2(r, r) * 0.28, r * 0.38, phase), Color(terrain[0]).lerp(Color(terrain[1]), 0.35))
	map_display.draw_circle(pos - Vector2(r, r) * 0.36, r * 0.16, Color(terrain[0]))
	var rim := _medallion_points(pos, r, phase)
	rim.append(rim[0])
	map_display.draw_polyline(rim, Color(1.0, 240.0 / 255, 210.0 / 255, 0.6), 3.0, true)


func _plaque_text(data: IslandData) -> String:
	if data.island_type == IslandData.IslandType.CAPITAL:
		return "%s · %s" % [data.island_name, tr("You")]
	return "%s · T%d" % [data.island_name, _tier_of(data)]


func _draw_plaque(data: IslandData, pos: Vector2) -> void:
	var font: Font = get_theme_font("font", "ChipLabel")
	var text := _plaque_text(data)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _PLAQUE_FONT_SIZE).x
	var chip := 16.0
	var w := tw + chip + 30.0
	var h := 40.0
	var r := _medallion_radius(data)
	var candidates := [pos + Vector2(-w * 0.5, r + 10.0), pos + Vector2(-w * 0.5, -r - h - 10.0),
		pos + Vector2(r + 10.0, -h * 0.5), pos + Vector2(-r - w - 10.0, -h * 0.5),
		pos + Vector2(r * 0.6, r * 0.6), pos + Vector2(-w - r * 0.6, r * 0.6),
		pos + Vector2(r * 0.6, -h - r * 0.6), pos + Vector2(-w - r * 0.6, -h - r * 0.6)]
	var box := Rect2(candidates[0], Vector2(w, h))
	for c in candidates:
		var trial := Rect2(c, Vector2(w, h))
		var clear := Rect2(Vector2.ZERO, map_display.size).encloses(trial)
		for placed in _placed_label_rects:
			if placed.intersects(trial):
				clear = false
				break
		if clear:
			box = trial
			break
	_placed_label_rects.append(box)
	var selected := data == _selected_island
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3 if selected else 2)
	sb.anti_aliasing = true
	if selected:
		sb.bg_color = Color("#E4BC6E")
		sb.border_color = Color("#4A300F")
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
	else:
		sb.bg_color = Color("#2A1A0E")
		sb.border_color = Color("#8A6A3A")
	map_display.draw_style_box(sb, box)
	var cols: Array = _faction_colors(data)
	var chip_rect := Rect2(box.position + Vector2(12.0, (h - chip) * 0.5), Vector2(chip, chip))
	map_display.draw_rect(Rect2(chip_rect.position, Vector2(chip, chip * 0.55)), cols[0])
	map_display.draw_rect(Rect2(chip_rect.position + Vector2(0, chip * 0.55), Vector2(chip, chip * 0.45)), cols[1])
	map_display.draw_rect(chip_rect, Color("#0C0806"), false, 2.0)
	var text_col := Color("#3A2410") if selected else Color("#E6D4B0")
	map_display.draw_string(font, box.position + Vector2(chip + 20.0, h * 0.5 + _PLAQUE_FONT_SIZE * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _PLAQUE_FONT_SIZE, text_col)


func _draw_ship(pos: Vector2) -> void:
	# The player's ship, bobbing (v0.3 bob 2.6s) with a faint heading wake.
	var bob := sin(_t * TAU / _SHIP_BOB_SEC)
	var p := pos + Vector2(0, bob * 5.0)
	var heading := deg_to_rad(_player_heading_deg)
	var fwd := Vector2(sin(heading), -cos(heading))
	map_display.draw_line(pos - fwd * 10.0, pos - fwd * 34.0, Color(1, 1, 1, 0.25), 5.0, true)
	var tilt := deg_to_rad(2.0 * bob)
	var xf := Transform2D(tilt, p)
	var hull := PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(15, 12), Vector2(-15, 12)])
	var sail := PackedVector2Array([Vector2(-2, -30), Vector2(-2, -2), Vector2(-18, -4)])
	var sail2 := PackedVector2Array([Vector2(2, -26), Vector2(2, -2), Vector2(16, -4)])
	map_display.draw_colored_polygon(xf * hull, Color("#6D452A"))
	map_display.draw_polyline(xf * PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(15, 12), Vector2(-15, 12), Vector2(-22, 0)]),
		Color("#2E1A0C"), 2.5, true)
	map_display.draw_colored_polygon(xf * sail, Color("#F2E8D0"))
	map_display.draw_colored_polygon(xf * sail2, Color("#E9DCC0"))
	map_display.draw_line(xf * Vector2(0, -32), xf * Vector2(0, 0), Color("#2E1A0C"), 2.5)


# ---------------------------------------------------------------- input

func _on_map_display_gui_input(event: InputEvent) -> void:
	var press_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		press_pos = event.position
	if press_pos == Vector2.INF:
		return

	var nearest: IslandData = null
	var nearest_dist := INF
	for marker in _get_visible_island_markers(_display_radius()):
		var d: float = press_pos.distance_to(marker.pos)
		if d <= _medallion_radius(marker.data) + _TAP_HIT_RADIUS and d < nearest_dist:
			nearest_dist = d
			nearest = marker.data

	_selected_island = nearest
	_update_info_panel()
	map_display.queue_redraw()


# ---------------------------------------------------------------- dossier

func _add_row(label_text: String, value_text: String) -> void:
	var l := Label.new()
	l.text = label_text
	l.theme_type_variation = &"InkSubLabel"
	l.add_theme_font_size_override("font_size", UITokens.FONT_BODY)
	rows.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.theme_type_variation = &"InkBodyLabel"
	v.add_theme_font_override("font", get_theme_font("font", "ChipLabel"))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(v)


func _set_faction_chip(cols: Array) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cols[0]
	sb.border_color = cols[1]
	sb.set_border_width_all(0)
	sb.border_width_bottom = 9
	sb.set_corner_radius_all(4)
	faction_chip.add_theme_stylebox_override("panel", sb)


## Fills the torn-parchment dossier for the tapped island: faction + tier,
## status, region, distance (from the ship, else from home — the same
## "distance = danger" read docs/11_WORLD_MAP.md's bands are built on),
## danger band, then the codex summary and its real-world echo.
func _update_info_panel() -> void:
	if not is_instance_valid(info_panel):
		return
	for child in rows.get_children():
		child.queue_free()
	if not _selected_island:
		dossier_title.text = tr("Your Waters")
		faction_row.visible = false
		set_course_button.visible = false
		var charted := _get_visible_island_markers(_display_radius()).size()
		var total := get_tree().get_nodes_in_group("islands").size()
		_add_row(tr("Charted"), "%d / %d" % [charted, total])
		if EmpireManager:
			_add_row(tr("Notoriety"), "%d" % roundi(EmpireManager.notoriety))
		info_panel.text = tr("Tap an island for its dossier.")
		return

	var data := _selected_island
	dossier_title.text = data.island_name
	faction_row.visible = true
	_set_faction_chip(_faction_colors(data))
	var tier := _tier_of(data)
	faction_label.text = "%s · %s" % [_faction_name(data), tr("Tier %d") % tier]
	var region := _region_of(data)
	var status := tr("Yours")
	if not data.is_owned_by_player():
		status = tr("Hostile") if data.island_type == IslandData.IslandType.ENEMY else tr("Open to colonize")
	_add_row(tr("Status"), status)
	if region:
		_add_row(tr("Waters"), region.display_name)
	var from := _player_pos if _has_player else Vector2.ZERO
	_add_row(tr("Distance"), tr("~%d u") % int(round(data.world_position.distance_to(from))))
	_add_row(tr("Risk"), tr(_DANGER[clampi(tier - 1, 0, _DANGER.size() - 1)]))

	# The title above already names the island big; the codex line keeps the
	# name inline (plain, body size) so the summary still reads as a sentence.
	var bbcode := data.island_name
	if not data.codex_summary.is_empty():
		bbcode += " — " + data.codex_summary
	if not data.real_world_echo.is_empty():
		bbcode += "\n[i]%s[/i]" % data.real_world_echo
	info_panel.text = bbcode
	set_course_button.visible = _has_player and data.world_position.distance_to(_player_pos) > 60.0


func _build_legend() -> void:
	for child in legend_grid.get_children():
		child.queue_free()
	var seen := {}
	var entries: Array = []
	for marker in _get_visible_island_markers(_display_radius()):
		var data: IslandData = marker.data
		var fname := _faction_name(data)
		if data.is_owned_by_player() or seen.has(fname):
			continue
		seen[fname] = true
		entries.append([fname, _faction_colors(data)])
	entries.append([tr("Your Fleet"), [Color(_YOU_COLORS[0]), Color(_YOU_COLORS[1])]])
	for e in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(20, 20)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = e[1][0]
		sb.border_color = e[1][1]
		sb.border_width_bottom = 8
		sb.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("panel", sb)
		row.add_child(chip)
		var l := Label.new()
		l.text = e[0]
		l.theme_type_variation = &"ChipLabel"
		row.add_child(l)
		legend_grid.add_child(row)
