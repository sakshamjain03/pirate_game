extends Node

## DEBUG HARNESS — not part of the game, but permanent (M22).
##
## Walks the game's UI screens and screenshots each, at one device profile per
## run. Promoted from the 2026-09-24 FontOverflowAudit (which was meant to be
## deleted after the Cinzel swap) because it is the only tool that actually
## *sees* every screen — M15.5 closed with only MainMenu/PauseMenu viewed live,
## since GUT cannot catch layout/overflow defects. M22 runs it at every phase
## checkpoint (see .kiro/specs/milestone-m22-ui-overhaul/design.md §8).
##
## Must run headful (the headless dummy renderer produces blank images):
##   godot --path <project> scenes/debug/UIScreenSweep.tscn \
##       --capture-dir=<abs path> [--profile=phone|tablet|desktop]
##
## Profiles set the window to the device's aspect ratio (not its native pixel
## count, which may not fit the dev monitor — canvas_items stretch makes layout
## depend on aspect, not resolution) and force the matching scaling path.
## When a phase restyles a screen this sweep can't reach yet, add it here.

const PROFILES := {
	"phone":   {"size": Vector2i(1560, 720),  "mobile": true,  "tablet": false},  # 19.5:9
	"tablet":  {"size": Vector2i(1024, 768),  "mobile": true,  "tablet": true},   # 4:3
	"desktop": {"size": Vector2i(1600, 900),  "mobile": false, "tablet": false},  # 16:9
}

var _dir := ""
var _profile := "phone"
var _world: Node3D
var _hud: Node


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--capture-dir="):
			_dir = a.trim_prefix("--capture-dir=")
		elif a.begins_with("--profile="):
			_profile = a.trim_prefix("--profile=")
	if _dir.is_empty():
		set_process(false)
		return
	if not PROFILES.has(_profile):
		push_error("UIScreenSweep: unknown --profile=%s (expected phone|tablet|desktop)" % _profile)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_apply_profile(PROFILES[_profile])
	print("[sweep] profile=%s writing to %s" % [_profile, _dir])
	await _run()
	print("[sweep] done")
	get_tree().quit(0)


func _apply_profile(p: Dictionary) -> void:
	PirateThemeBuilder.force_mobile_scaling_for_test = p["mobile"]
	MobileLayoutManager.force_tablet_for_test = p["tablet"]
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = p["size"]
	win.move_to_center()


func _settle(frames: int = 3) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if not vp:
		return
	var img := vp.get_texture().get_image()
	if not img:
		return
	var path := _dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("[sweep] %s -> err=%d" % [shot_name, err])


func _run() -> void:
	await _run_world_screens()
	await _run_standalone_menus()


func _run_world_screens() -> void:
	_world = preload("res://scenes/world/World.tscn").instantiate()
	add_child(_world)
	await _settle(8)
	_hud = _world.get_node_or_null("WorldUI")
	if not _hud:
		_hud = get_tree().get_first_node_in_group("hud")

	var island: Node3D = null
	for candidate in get_tree().get_nodes_in_group("islands"):
		if candidate is Node3D and candidate.has_method("is_owned_by_player") and candidate.is_owned_by_player():
			island = candidate
			break
	if not island:
		var any_islands := get_tree().get_nodes_in_group("islands")
		if not any_islands.is_empty():
			island = any_islands[0]

	await _capture("00_world_hud")

	if _hud and "captains_log" in _hud and _hud.captains_log:
		_hud.captains_log.open()
		await _settle(4)
		await _capture("01_captains_log")
		_hud.captains_log.close()
		await _settle(2)

	if _hud and "world_map_screen" in _hud and _hud.world_map_screen:
		_hud.world_map_screen.open()
		await _settle(4)
		await _capture("02_world_map")
		_hud.world_map_screen.close()
		await _settle(2)

	if _hud and "codex_screen" in _hud and _hud.codex_screen:
		_hud.codex_screen.toggle()
		await _settle(4)
		await _capture("03_codex")
		_hud.codex_screen.close()
		await _settle(2)

	if _hud and "wardrobe_screen" in _hud and _hud.wardrobe_screen:
		_hud.wardrobe_screen.open()
		await _settle(4)
		await _capture("04_wardrobe")
		_hud.wardrobe_screen.close()
		await _settle(2)

	if _hud and "whats_new_screen" in _hud and _hud.whats_new_screen:
		_hud.whats_new_screen.open()
		await _settle(4)
		await _capture("05_whats_new")
		_hud.whats_new_screen.close()
		await _settle(2)

	if island and _hud and "island_menu" in _hud and _hud.island_menu:
		_hud.island_menu.open(island)
		await _settle(4)
		await _capture("06_island_menu")
		for tab in range(_hud.island_menu.tab_container.get_tab_count()):
			if not _hud.island_menu.tab_container.is_tab_hidden(tab):
				_hud.island_menu.tab_container.current_tab = tab
				await _settle(3)
				await _capture("06_island_menu_tab%d" % tab)
		_hud.island_menu.close()
		await _settle(2)

	var pause = _hud.get_node_or_null("PauseMenu") if _hud else null
	if pause:
		if pause.has_method("open"):
			pause.open()
		else:
			pause.visible = true
		await _settle(4)
		await _capture("07_pause_menu")
		if pause.has_method("close"):
			pause.close()
		else:
			pause.visible = false
		await _settle(2)

	_world.queue_free()
	await _settle(3)


func _run_standalone_menus() -> void:
	var main_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(main_menu)
	await _settle(5)
	await _capture("10_main_menu")
	main_menu.queue_free()
	await _settle(2)

	var settings = load("res://scenes/ui/SettingsMenu.tscn").instantiate()
	add_child(settings)
	await _settle(5)
	for tab in range(settings.tab_container.get_tab_count()):
		settings.tab_container.current_tab = tab
		await _settle(3)
		await _capture("11_settings_tab%d" % tab)
	settings.queue_free()
	await _settle(2)

	var credits = load("res://scenes/ui/CreditsScreen.tscn").instantiate()
	add_child(credits)
	await _settle(5)
	await _capture("12_credits")
	credits.queue_free()
	await _settle(2)
