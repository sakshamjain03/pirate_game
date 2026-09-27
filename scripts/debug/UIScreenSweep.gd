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
	# M22 6c: modals pop in and text types out now. Content shots want each
	# screen's settled state, so motion is collapsed for them; the motion
	# section below turns it back on and captures mid-animation on purpose.
	UIMotion.force_reduced_motion_for_test = true
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


## _settle()'s frame-count wait doesn't correspond to a fixed wall-clock
## duration and can't reliably outlast a *timed* animation (e.g.
## MainMenu._animate_title()'s 1.2s fade-in with up to a 0.5s delay — found
## 2026-09-25 during M22 Phase 1: 5 frames left the title/subtitle captured
## mid-fade, invisible, in BOTH the pre-M22 baseline and every later sweep,
## confirmed pre-existing and unrelated to any M22 change). Use this instead
## wherever a screen is known to run a real-time animation on open.
func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
	await _run_modals()
	await _run_kit_sheet()


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

	# M22 Phase 5 — the phone utility controls are gated on
	# OS.has_feature("pc"), not the forced-mobile flag, so a phone-profile
	# sweep on this PC used to capture the DESKTOP rail on a phone-sized
	# screen (a layout no real phone ever shows). Force the real phone branch.
	if _hud and PROFILES[_profile]["mobile"] and "force_mobile_utility_menu" in _hud:
		_hud.force_mobile_utility_menu = true
		await _hud._rebuild_utility_controls()
		_hud._apply_mobile_safe_area()
		await _settle(3)

	await _capture("00_world_hud")
	await _run_hud_states()

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
		# M22 Phase 6.3 — a fresh game has discovered nothing, so the map was
		# only ever captured empty. Discover every island IN MEMORY (restored
		# below; never saved) and select one so the dossier is filled too —
		# the same check 90fd46f's ring-label fix was made against.
		var undiscovered: Array = []
		var first_data: IslandData = null
		for isl in get_tree().get_nodes_in_group("islands"):
			if "island_data" in isl and isl.island_data:
				if not isl.island_data.discovered:
					undiscovered.append(isl.island_data)
					isl.island_data.discovered = true
				if not first_data:
					first_data = isl.island_data
		var map_screen = _hud.world_map_screen
		map_screen._selected_island = first_data
		map_screen._update_info_panel()
		map_screen.map_display.queue_redraw()
		await _settle(4)
		await _capture("02_world_map_discovered")
		for data in undiscovered:
			data.discovered = false
		map_screen.close()
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
		await _capture_owned_island_menu(island)
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

	await _run_motion_states()
	_world.queue_free()
	await _settle(3)


## M22 Phase 6c/7 — motion captured MID-animation on purpose: a modal
## ~0.12 s into its pop-in, a resource pill mid tick + shine, and the
## tutorial line mid-typewriter. Only this section runs with motion on.
func _run_motion_states() -> void:
	if not _hud:
		return
	UIMotion.force_reduced_motion_for_test = false
	if "captains_log" in _hud and _hud.captains_log:
		_hud.captains_log.open()
		await _wait_seconds(0.12)
		await _capture("30_motion_modal_pop")
		_hud.captains_log.close()
		await _settle(2)
	if _hud.has_method("_on_resources_changed"):
		var res: Dictionary = ResourceManager.current_resources.duplicate()
		var bumped := res.duplicate()
		bumped["gold"] = int(res.get("gold", 0)) + 850
		_hud._on_resources_changed(bumped)
		await _wait_seconds(UITokens.SHINE_SEC * 0.45)
		await _capture("31_motion_pill_shine_tick")
		_hud._on_resources_changed(res)  # display only — ResourceManager untouched
		await _wait_seconds(0.7)
	var tutorial: Control = _hud.get("tutorial_dialogue")
	if tutorial and tutorial.has_method("_render_current_beat") and not tutorial._queue.is_empty():
		tutorial.show()
		tutorial._queue_index = 0
		tutorial._render_current_beat()
		await _wait_seconds(0.8)
		await _capture("32_motion_typewriter")
		tutorial.hide()
	UIMotion.force_reduced_motion_for_test = true


## M22 Phase 5 verification states (tasks.md 5.2/5.4/5.5/5.6): the HUD with
## the first-run tutorial out of the way, hull under 25% (the low-hp pulse),
## cooldown sweeps mid-way, and on phone the utility drawer open plus a
## left-handed custom layout. Every change is reverted and nothing is saved.
func _run_hud_states() -> void:
	if not _hud:
		return
	var tutorial: Control = _hud.get("tutorial_dialogue")
	var tutorial_was_visible := tutorial != null and tutorial.visible
	if tutorial:
		tutorial.hide()
	await _settle(3)
	await _capture("00b_world_hud_clean")

	var mobile_controls: Node = _hud.get_node_or_null("MobileControls")
	_hud.set_health(18.0, 100.0)
	# WorldHUD._process() re-feeds the ship's REAL cooldown fractions every
	# frame (ready at spawn), which would wipe these straight back to 0.
	_hud.set_process(false)
	if mobile_controls and mobile_controls.has_method("set_cooldown_fraction"):
		mobile_controls.set_cooldown_fraction("ability", 0.35)
		mobile_controls.set_cooldown_fraction("broadside", 0.7)
	await _wait_seconds(0.35)
	await _capture("00c_world_hud_low_hull")
	_hud.set_process(true)
	_hud.announce_event("Spanish Main is now active!
The Spanish Empire is hunting you!")
	await _wait_seconds(0.6)
	await _capture("00g_announcement")
	_hud.set_health(100.0, 100.0)

	if PROFILES[_profile]["mobile"]:
		if _hud.mobile_utility_menu_button:
			_hud.mobile_utility_menu_button.emit_signal("pressed")
			await _settle(3)
			await _capture("00d_mobile_drawer")
			_hud.mobile_utility_drawer.hide()
		var was_left := bool(SettingsManager.mobile_left_handed)
		var old_overrides: Dictionary = SettingsManager.mobile_control_overrides.duplicate(true)
		SettingsManager.mobile_left_handed = true
		MobileLayoutManager.notify_layout_changed()
		await _settle(4)
		await _capture("00e_left_handed")
		# A saved HUD customisation (Settings > Customize HUD Layout) on the
		# default right-handed layout. Overrides are clamped to the viewport,
		# not to other controls — a player can drag one cluster onto another.
		SettingsManager.mobile_left_handed = false
		SettingsManager.mobile_control_overrides = {
			"actions": {"position": Vector2(-60, -30), "scale_mult": 1.15},
			"top_right_panel": {"position": Vector2(0, 10), "scale_mult": 0.9},
		}
		MobileLayoutManager.notify_layout_changed()
		await _settle(4)
		await _capture("00f_custom_layout")
		SettingsManager.mobile_left_handed = was_left
		SettingsManager.mobile_control_overrides = old_overrides
		MobileLayoutManager.notify_layout_changed()
		await _settle(2)
	# The announcement toast fades over ~3.4s and would sit over the next
	# several content shots; drop it now.
	for child in _hud.get_children():
		if child.name.begins_with("Announcement"):
			child.queue_free()
	# M22 Phase 6 — the first-run tutorial beat stays hidden for every later
	# content-screen shot (it covered IslandMenu's lower half), and is
	# captured once on its own instead (08_tutorial_dialogue, 6.4's surface).
	if tutorial and tutorial_was_visible:
		tutorial.show()
		await _settle(4)
		await _capture("08_tutorial_dialogue")
		tutorial.hide()
		await _settle(2)


## M22 Phase 6 — a fresh game owns no island, so the sweep never reached the
## Buildings/Shipyard/Tavern/Trade tabs. Present the same island as the
## player's capital with a shipyard + tavern IN MEMORY ONLY (duplicated
## IslandData, appended BuildingData), capture every tab, then restore both.
## Nothing is saved; no building models are spawned.
func _capture_owned_island_menu(island: Node3D) -> void:
	if not ("island_data" in island) or not island.island_data or not ("built_buildings" in island):
		return
	var original_data: Resource = island.island_data
	var original_buildings: Array = island.built_buildings.duplicate()
	var owned: IslandData = original_data.duplicate()
	owned.island_type = IslandData.IslandType.CAPITAL
	island.island_data = owned
	for path in ["res://resources/buildings/Shipyard_L1.tres", "res://resources/buildings/Tavern_L1.tres"]:
		var b = load(path)
		if b:
			island.built_buildings.append(b)
	_hud.island_menu.open(island)
	await _settle(4)
	await _capture("06_island_owned")
	for tab in range(_hud.island_menu.tab_container.get_tab_count()):
		if not _hud.island_menu.tab_container.is_tab_hidden(tab):
			_hud.island_menu.tab_container.current_tab = tab
			await _settle(3)
			await _capture("06_island_owned_tab%d" % tab)
	_hud.island_menu.close()
	island.built_buildings.assign(original_buildings)
	island.island_data = original_data
	await _settle(2)


func _run_standalone_menus() -> void:
	var main_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(main_menu)
	await _settle(5)
	# MainMenu._animate_title() fades the title/subtitle in over up to ~1.7s
	# real time (1.2s tween + 0.5s delay) — outlast it so the capture shows
	# the settled screen, not mid-fade (see _wait_seconds()'s own header).
	await _wait_seconds(1.8)
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


## M22 Phase 4.4/4.5 — the modals no ordinary screen path reaches: each is
## normally opened by AdManager/CrashReporter state that a sweep never
## produces, so without this they were never seen at all.
func _run_modals() -> void:
	# Crash-recovery notice: MainMenu shows it only when CrashReporter has a
	# pending report. Set the flag for the capture, then restore it exactly —
	# never dismiss_pending_report(), which would touch the real report.
	var had_pending: bool = CrashReporter.has_pending_report
	CrashReporter.has_pending_report = true
	var menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await _settle(5)
	await _wait_seconds(1.8)
	await _capture("14_crash_notice")
	menu.queue_free()
	CrashReporter.has_pending_report = had_pending
	await _settle(2)

	var dialog := ChoiceDialog.new("Cloud Save Found",
		"A newer save exists in the cloud. Which one do you want to keep?",
		PackedStringArray(["Keep Local", "Keep Cloud"]))
	add_child(dialog)
	await _settle(4)
	await _capture("15_choice_dialog")
	dialog.queue_free()
	await _settle(2)

	# AgeGate/ConsentPanel open themselves off AdManager.state; show() them
	# directly instead of driving the real ad state machine into a gate.
	for entry in [["16_age_gate", "res://scenes/ui/AgeGate.tscn"],
			["17_consent_panel", "res://scenes/ui/ConsentPanel.tscn"]]:
		var modal = load(entry[1]).instantiate()
		add_child(modal)
		await _settle(3)
		modal.show()
		await _settle(3)
		await _capture(entry[0])
		modal.queue_free()
		get_tree().paused = false
		await _settle(2)
	await _run_content_modals()


## M22 Phase 6b — the content modals the world path never opens on its own
## (store, support, rewarded offer, raid report, death, battle upgrades).
## Each is shown straight from its own render method, NOT its gameplay
## entry point: StoreScreen.open() logs analytics, RewardedBonusOffer.present()
## is gated on real AdManager caps and DeathScreen's respawn spends gold —
## a sweep must never touch any of that state.
func _run_content_modals() -> void:
	var store = load("res://scenes/ui/StoreScreen.tscn").instantiate()
	add_child(store)
	await _settle(3)
	store._refresh()
	store.show()
	await _settle(4)
	await _capture("18_store")
	store.queue_free()

	var support = load("res://scenes/ui/PurchaseSupportScreen.tscn").instantiate()
	add_child(support)
	await _settle(3)
	support._refresh()
	support.show()
	await _settle(3)
	await _capture("19_purchase_support")
	support.queue_free()

	var offer = load("res://scenes/ui/RewardedBonusOffer.tscn").instantiate()
	add_child(offer)
	await _settle(3)
	offer.offer_label.text = "Your crew found extra salvage. Watch a short ad to double it?"
	offer.show()
	await _settle(3)
	await _capture("20_rewarded_offer")
	offer.queue_free()

	for variant in [["21_raid_repelled", {"repelled": true, "faction_id": "spain"}],
			["21_raid_hit", {"repelled": false, "faction_id": "britain", "stolen": {"gold": 120, "wood": 40}}]]:
		var raid = load("res://scenes/ui/RaidReportScreen.tscn").instantiate()
		add_child(raid)
		await _settle(3)
		raid.open(variant[1])
		await _settle(3)
		await _capture(variant[0])
		raid.queue_free()
		get_tree().paused = false

	var death = load("res://scenes/ui/DeathScreen.tscn").instantiate()
	add_child(death)
	await _settle(3)
	death.open(null)
	await _settle(3)
	await _capture("22_death")
	death.queue_free()
	get_tree().paused = false

	var choice = load("res://scenes/ui/UpgradeChoiceScreen.tscn").instantiate()
	add_child(choice)
	await _settle(3)
	var ups: Array = []
	for id in ["HeavyVolley", "RapidReload", "EmergencyRepairs"]:
		ups.append(load("res://resources/combat/upgrades/%s.tres" % id))
	choice._on_offer(ups, 1, 3)
	await _settle(4)
	await _capture("23_upgrade_choice")
	choice.queue_free()
	get_tree().paused = false
	await _settle(2)


func _run_kit_sheet() -> void:
	# M22 Phase 2.6 — UIKitSheet.gd's self_capture=false so it builds its
	# grid without also self-driving its own window-resize/capture/quit
	# (both tools share the same --capture-dir= cmdline arg; without this
	# flag an embedded instance would quit the whole sweep early).
	var sheet = load("res://scenes/debug/UIKitSheet.tscn").instantiate()
	sheet.self_capture = false
	add_child(sheet)
	await _settle(3)
	sheet.size_window_to_fit()
	await _settle(3)
	await _capture("13_ui_kit_sheet")
	sheet.queue_free()
	await _settle(2)
