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

## Margin so the outermost ring doesn't touch MapDisplay's edge.
const _DISPLAY_MARGIN := 16.0

var _regions: Array[RegionData] = []
var _world_radius: float = 1.0
var _player_pos: Vector2 = Vector2.ZERO
var _player_heading_deg: float = 0.0
var _has_player: bool = false


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	close_button.pressed.connect(close)
	view_log_button.pressed.connect(_on_view_log_pressed)
	map_display.draw.connect(_on_map_display_draw)
	_load_regions()


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


func _on_map_display_draw() -> void:
	var display_radius: float = max(0.0, min(map_display.size.x, map_display.size.y) * 0.5 - _DISPLAY_MARGIN)
	var center := map_display.size * 0.5

	# Concentric region rings, outermost first so inner rings draw on top.
	var sorted_regions := _regions.duplicate()
	sorted_regions.sort_custom(func(a, b): return a.display_ring_radius > b.display_ring_radius)
	for region in sorted_regions:
		var r: RegionData = region
		if r.display_ring_radius <= 0.0:
			continue
		var radius: float = (r.display_ring_radius / _world_radius) * display_radius
		map_display.draw_arc(center, radius, 0.0, TAU, 64, PirateThemeBuilder.COLOR_GOLD, 2.0, true)

	# Island markers. Undiscovered islands are omitted entirely rather than
	# shown as a "?" — the milestone's own framing (docs/00_VISION.md's
	# Explore pillar) is real mystery, not just withheld names, so this
	# leans toward true fog of war over a spoiler-y placeholder pin.
	for island in get_tree().get_nodes_in_group("islands"):
		if not island.island_data or not island.island_data.discovered:
			continue
		var pos := _world_to_local(island.island_data.world_position, display_radius)
		map_display.draw_circle(pos, 6.0, PirateThemeBuilder.COLOR_GOLD_BRIGHT)
		map_display.draw_string(ThemeDB.fallback_font, pos + Vector2(8, 4),
			island.island_data.island_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			PirateThemeBuilder.COLOR_TEXT_LIGHT)

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
			PirateThemeBuilder.COLOR_GREEN_HEALTH)
