extends Node

## TEMPORARY DEBUG HARNESS — not part of the game.
##
## Walks the game's major UI screens, in both PC and forced-mobile scaling,
## and screenshots each — built to verify the 2026-09-21/24 global Cinzel
## font swap didn't overflow/clip text anywhere PirataOne's narrower glyphs
## used to fit. Delete this file and its scene once that's confirmed.
##
## Usage: godot --path <project> scenes/debug/FontOverflowAudit.tscn --capture-dir=<abs path>

var _dir := ""
var _world: Node3D
var _hud: Node


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--capture-dir="):
			_dir = a.trim_prefix("--capture-dir=")
	if _dir.is_empty():
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	print("[audit] writing to ", _dir)
	await _run()
	print("[audit] done")
	get_tree().quit(0)


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
	print("[audit] %s -> err=%d" % [shot_name, err])


func _run() -> void:
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

	for mode in ["pc", "mobile"]:
		PirateThemeBuilder.force_mobile_scaling_for_test = (mode == "mobile")
		await _settle(3)
		await _capture("%s_00_world_hud" % mode)

		if _hud and "captains_log" in _hud and _hud.captains_log:
			_hud.captains_log.open()
			await _settle(4)
			await _capture("%s_01_captains_log" % mode)
			_hud.captains_log.close()
			await _settle(2)

		if _hud and "world_map_screen" in _hud and _hud.world_map_screen:
			_hud.world_map_screen.open()
			await _settle(4)
			await _capture("%s_02_world_map" % mode)
			_hud.world_map_screen.close()
			await _settle(2)

		if _hud and "codex_screen" in _hud and _hud.codex_screen:
			_hud.codex_screen.toggle()
			await _settle(4)
			await _capture("%s_03_codex" % mode)
			_hud.codex_screen.close()
			await _settle(2)

		if _hud and "wardrobe_screen" in _hud and _hud.wardrobe_screen:
			_hud.wardrobe_screen.open()
			await _settle(4)
			await _capture("%s_04_wardrobe" % mode)
			_hud.wardrobe_screen.close()
			await _settle(2)

		if _hud and "whats_new_screen" in _hud and _hud.whats_new_screen:
			_hud.whats_new_screen.open()
			await _settle(4)
			await _capture("%s_05_whats_new" % mode)
			_hud.whats_new_screen.close()
			await _settle(2)

		if island and _hud and "island_menu" in _hud and _hud.island_menu:
			_hud.island_menu.open(island)
			await _settle(4)
			await _capture("%s_06_island_menu" % mode)
			for tab in range(_hud.island_menu.tab_container.get_tab_count()):
				if not _hud.island_menu.tab_container.is_tab_hidden(tab):
					_hud.island_menu.tab_container.current_tab = tab
					await _settle(3)
					await _capture("%s_06_island_menu_tab%d" % [mode, tab])
			_hud.island_menu.close()
			await _settle(2)

		var pause = _hud.get_node_or_null("PauseMenu") if _hud else null
		if pause:
			if pause.has_method("open"):
				pause.open()
			else:
				pause.visible = true
			await _settle(4)
			await _capture("%s_07_pause_menu" % mode)
			if pause.has_method("close"):
				pause.close()
			else:
				pause.visible = false
			await _settle(2)

	_world.queue_free()
	await _settle(3)

	# --- Standalone menus ---
	for mode in ["pc", "mobile"]:
		PirateThemeBuilder.force_mobile_scaling_for_test = (mode == "mobile")

		var main_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
		add_child(main_menu)
		await _settle(5)
		await _capture("%s_10_main_menu" % mode)
		main_menu.queue_free()
		await _settle(2)

		var settings = load("res://scenes/ui/SettingsMenu.tscn").instantiate()
		add_child(settings)
		await _settle(5)
		for tab in range(3):
			settings.tab_container.current_tab = tab
			await _settle(3)
			await _capture("%s_11_settings_tab%d" % [mode, tab])
		settings.queue_free()
		await _settle(2)
