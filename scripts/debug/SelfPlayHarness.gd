extends Node

## TEMPORARY DEBUG HARNESS — not part of the game.
##
## Self-play bug-hunting driver. Unlike scripts/tests/ScreenshotHarness.gd
## (which starts already inside World.tscn), this one boots through the real
## Boot.tscn -> MainMenu flow, so it exercises the exact menu/save/pause/
## quit-to-menu loop a real player hits, using REAL simulated input rather
## than direct method calls:
##   - Menu buttons: a real InputEventMouseButton down+up dispatched via
##     Input.parse_input_event() at the button's actual get_global_rect()
##     center, so hidden/mis-hit-tested buttons are caught too, not just
##     "the signal handler works when called directly."
##   - Event-driven actions (pause): a real InputEventAction dispatched via
##     Input.parse_input_event(), since Input.action_press() alone only
##     updates polling state and does NOT reach _unhandled_input callbacks.
##   - Polling-driven actions (ship movement, firing, docking): plain
##     Input.action_press()/action_release(), matching ScreenshotHarness.gd's
##     already-proven pattern (these are read via Input.is_action_pressed()/
##     is_action_just_pressed() in _physics_process, not via input callbacks).
##
## Usage: `<godot-binary> --path . -s res://scripts/debug/SelfPlayHarness.gd`
## Headless is fine for this pass — Control layout and input-action dispatch
## don't depend on the real renderer; only pixel screenshots would need
## headful. Redirect stdout/stderr to a file and grep it for "HARNESS:"
## progress markers plus genuine runtime-error signatures (Invalid get index,
## Nonexistent function, on a null instance, Attempt to call function, Node
## not found, or an assertion "at:" stack trace) — NOT the parser unused-
## variable/signal/parameter warnings that print at every boot regardless of
## this harness and are not real bugs.
##
## Delete this file once the bugs it's meant to find are closed out.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("HARNESS: === self-play run starting ===")

	await _wait_for_main_menu()
	if not (get_tree().current_scene is MainMenu):
		print("HARNESS: aborting run, never reached MainMenu")
		get_tree().quit()
		return

	await _drive_main_menu_new_game()

	var world_ok := await _wait_for_world_loaded()
	if world_ok:
		await _dismiss_tutorial_if_present()
		await _drive_ship_and_combat()
		await _drive_docking()
		await _drive_world_hud_panels()
		await _drive_pause_and_quit_to_menu()
		await _drive_continue_from_menu()
	else:
		print("HARNESS: world never loaded, skipping in-world checks")

	print("HARNESS: === self-play run complete ===")
	get_tree().quit()


# ---------------------------------------------------------------------------
# Low-level input helpers
# ---------------------------------------------------------------------------

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Activates a button via grab_focus() + a simulated "ui_accept" action,
## going through BaseButton's keyboard-activation path.
##
## An earlier version of this harness used real InputEventMouseButton events
## via get_viewport().push_input(pos, true) to also exercise Viewport GUI
## hit-testing. Empirically that was unreliable in this headful-automation
## environment: it worked once (a button with nothing overlapping it) and
## failed repeatedly afterward (e.g. the same button's second click, once a
## panel it had just opened was likely now overlapping it at that same fixed
## screen coordinate) — while grab_focus()+ui_accept succeeded 100% of the
## time across every button tried. Since this harness's goal is exercising
## game flow/logic (not proving out raw screen-coordinate hit-testing),
## keyboard activation is the more reliable choice here. This does mean it
## can no longer catch a button that is visible but unreachable by an actual
## mouse click (hidden under another panel, wrong z-order) — a real but
## smaller gap than a harness that silently can't get past the first menu.
func _click_button(button: Button, label: String) -> bool:
	if not button or not is_instance_valid(button):
		print("HARNESS: click FAILED (button null/freed) for '%s'" % label)
		return false
	if not button.visible:
		print("HARNESS: click SKIPPED, '%s' is not visible" % label)
		return false
	if button.disabled:
		print("HARNESS: click SKIPPED, '%s' is disabled" % label)
		return false

	print("HARNESS: activating '%s' via grab_focus()+ui_accept" % label)
	button.grab_focus()
	await _wait_frames(2)

	var accept_down := InputEventAction.new()
	accept_down.action = "ui_accept"
	accept_down.pressed = true
	Input.parse_input_event(accept_down)
	await _wait_frames(2)

	var accept_up := InputEventAction.new()
	accept_up.action = "ui_accept"
	accept_up.pressed = false
	Input.parse_input_event(accept_up)
	await _wait_frames(6)
	return true

## Real event-driven action press/release (reaches _unhandled_input), for
## actions like "pause" that are read via is_action_pressed(event) in an
## input callback rather than polled every frame.
func _send_action_event(action_name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)
	await _wait_frames(2)

## Waits until get_tree().current_scene differs from old_scene AND is a real
## node (change_scene_to_file briefly leaves current_scene null while freeing
## the old scene and loading the new one — catching that transient null and
## treating it as "the change happened" would just move the false-negative
## from "nothing happened" to "looks like it crashed").
func _wait_for_scene_change(old_scene: Node, timeout: float) -> bool:
	var waited := 0.0
	var scene := get_tree().current_scene
	while (scene == old_scene or scene == null) and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
		scene = get_tree().current_scene
	return scene != old_scene and scene != null

func _find_button_by_text(root: Node, text: String) -> Button:
	if root is Button and root.text == text:
		return root
	for child in root.get_children():
		var found := _find_button_by_text(child, text)
		if found:
			return found
	return null


# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

func _wait_for_main_menu() -> void:
	var waited := 0.0
	while not (get_tree().current_scene and get_tree().current_scene is MainMenu) and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	if get_tree().current_scene is MainMenu:
		print("HARNESS: MainMenu reached after %.2fs" % waited)
	else:
		print("HARNESS ERROR: MainMenu never reached after %.2fs, current_scene=%s" % [waited, get_tree().current_scene])


func _drive_main_menu_new_game() -> void:
	var menu := get_tree().current_scene
	var continue_btn: Button = menu.get_node_or_null("Control/ButtonPanel/VBoxContainer/ContinueButton")
	var new_game_btn: Button = menu.get_node_or_null("Control/ButtonPanel/VBoxContainer/NewGameButton")

	print("HARNESS: pre-existing save detected=%s (ContinueButton present+visible)" % \
		(continue_btn != null and continue_btn.visible))

	if not new_game_btn:
		print("HARNESS ERROR: NewGameButton not found at expected path")
		return

	# GDScript lambdas capture outer locals BY VALUE, so a plain `var fired :=
	# false` reassigned inside the lambda would silently not propagate — use a
	# single-element array as a mutable box instead (arrays are references).
	var fired := [false]
	var on_pressed := func(): fired[0] = true
	new_game_btn.pressed.connect(on_pressed)
	await _click_button(new_game_btn, "NewGameButton")
	await _wait_frames(4)
	print("HARNESS: NewGameButton.pressed signal fired=%s" % fired[0])
	if new_game_btn.pressed.is_connected(on_pressed):
		new_game_btn.pressed.disconnect(on_pressed)

	if new_game_btn.pressed.is_connected(on_pressed):
		new_game_btn.pressed.disconnect(on_pressed)


func _wait_for_world_loaded() -> bool:
	var waited := 0.0
	var wm: Node = null
	var last_logged_scene := ""
	while waited < 15.0:
		var scene := get_tree().current_scene
		var scene_desc := "null"
		if scene:
			scene_desc = "%s (script=%s)" % [scene.name, (scene.get_script().resource_path if scene.get_script() else "none")]
			wm = scene.get_node_or_null("Systems/WorldManager")
			if wm and wm.is_world_loaded:
				break
		if scene_desc != last_logged_scene:
			print("HARNESS: current_scene changed to %s (has Systems/WorldManager=%s)" % [scene_desc, wm != null])
			last_logged_scene = scene_desc
		await get_tree().process_frame
		waited += get_process_delta_time()

	var loaded: bool = wm != null and wm.is_world_loaded
	print("HARNESS: world_loaded=%s waited=%.2fs final_scene=%s" % [loaded, waited, get_tree().current_scene])
	return loaded


func _dismiss_tutorial_if_present() -> void:
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("WorldUI") if scene else null
	var tutorial := hud.get_node_or_null("TutorialDialogue") if hud else null

	if not tutorial:
		print("HARNESS: no TutorialDialogue node found")
		return
	if not tutorial.visible:
		print("HARNESS: TutorialDialogue not active, nothing to dismiss")
		return

	print("HARNESS: TutorialDialogue active, clicking Skip to unblock scripted play")
	var skip_btn: Button = tutorial.get("skip_button")
	await _click_button(skip_btn, "TutorialDialogue.SkipButton")
	await _wait_frames(4)
	print("HARNESS: TutorialDialogue visible after skip=%s" % tutorial.visible)


func _drive_ship_and_combat() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")

	await _settle(2.0)
	if ship:
		print("HARNESS: at_rest pos=%s vel=%s" % [ship.global_position, ship.linear_velocity])
	else:
		print("HARNESS ERROR: no node in group 'player_ship' found")

	# Full sail replaces the old held-throttle simulation — sail level is a
	# discrete ship state now, not a continuous input, so it's set directly
	# rather than via Input.action_press("ship_forward").
	if ship and ship.has_method("adjust_sail_level"):
		ship.adjust_sail_level(ship.ship_stats.sail_levels)
	await _settle(4.0)
	if ship:
		print("HARNESS: moving pos=%s vel=%s speed=%.2f" % \
			[ship.global_position, ship.linear_velocity, ship.linear_velocity.length()])

	Input.action_press("ship_right")
	await _settle(2.0)
	Input.action_release("ship_right")
	if ship:
		print("HARNESS: turning pos=%s rot=%s" % [ship.global_position, ship.global_rotation])

	Input.action_press("fire_port")
	await get_tree().process_frame
	Input.action_release("fire_port")
	await _settle(0.3)
	print("HARNESS: fired fire_port")


func _drive_docking() -> void:
	var scene := get_tree().current_scene
	var docking: Node = scene.get_node_or_null("Systems/DockingSystem") if scene else null
	var ship := get_tree().get_first_node_in_group("player_ship")

	if not docking:
		print("HARNESS ERROR: no Systems/DockingSystem node found, skipping dock sequence")
		if ship and ship.has_method("adjust_sail_level"):
			ship.adjust_sail_level(-ship.ship_stats.sail_levels)
		return

	# Same lambda-by-value-capture caveat as _drive_main_menu_new_game() above.
	var got_signal := [false]
	var on_dock_completed := func(_id): got_signal[0] = true
	docking.dock_completed.connect(on_dock_completed)

	# Keep sailing forward (already pressed from combat step), watching for
	# proximity (state -> APPROACHING), up to a time budget. A ship still
	# nowhere near an island after this budget is a real, reportable outcome,
	# not something to force.
	var waited := 0.0
	while docking.current_state == docking.DockState.FREE and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	if docking.current_state != docking.DockState.APPROACHING:
		print("HARNESS: dock APPROACHING never reached within %.1fs (state=%s) — spawn may just be far from any dock area" % \
			[waited, docking.current_state])
		if ship and ship.has_method("adjust_sail_level"):
			ship.adjust_sail_level(-ship.ship_stats.sail_levels)
		docking.dock_completed.disconnect(on_dock_completed)
		return

	print("HARNESS: reached APPROACHING after %.2fs, attempting dock" % waited)
	if ship and ship.has_method("adjust_sail_level"):
		ship.adjust_sail_level(-ship.ship_stats.sail_levels)
	await _settle(1.0)  # let speed bleed off below max_docking_speed

	Input.action_press("dock")
	await get_tree().process_frame
	Input.action_release("dock")

	waited = 0.0
	while not got_signal[0] and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	print("HARNESS: dock_completed received=%s after %.2fs (final state=%s)" % \
		[got_signal[0], waited, docking.current_state])
	docking.dock_completed.disconnect(on_dock_completed)

	if got_signal[0]:
		var hud := scene.get_node_or_null("WorldUI")
		var island_menu = hud.get("island_menu") if hud else null
		if island_menu and island_menu.visible:
			print("HARNESS: IslandMenu opened correctly on dock")
			island_menu.close()
			await _wait_frames(4)
			print("HARNESS: IslandMenu closed, visible=%s" % island_menu.visible)
		else:
			print("HARNESS ERROR: docked but IslandMenu did not open (island_menu=%s visible=%s)" % \
				[island_menu, island_menu.visible if island_menu else "n/a"])

		# Undock so the ship is free again for the remaining checks.
		docking.attempt_undock()
		await _wait_frames(4)


func _drive_world_hud_panels() -> void:
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("WorldUI") if scene else null
	if not hud:
		print("HARNESS ERROR: WorldUI (WorldHUD) node not found")
		return

	var panels := [
		["captains_log_button", "captains_log", "Log"],
		["world_map_button", "world_map_screen", "Map"],
	]

	for entry in panels:
		var button_prop: String = entry[0]
		var panel_prop: String = entry[1]
		var label: String = entry[2]
		var button: Button = hud.get(button_prop)
		var panel = hud.get(panel_prop)

		if not button:
			print("HARNESS ERROR: '%s' button not found on WorldHUD" % label)
			continue

		await _click_button(button, label + " button (open)")
		var opened: bool = panel != null and panel.visible
		print("HARNESS: %s panel visible after open click=%s" % [label, opened])

		if opened:
			await _click_button(button, label + " button (close)")
			print("HARNESS: %s panel visible after close click=%s" % [label, panel.visible])

	# Codex button is created locally in WorldHUD.gd without a class member,
	# so find it by its label text instead of a property name.
	var top_right = hud.get("top_right_panel")
	if top_right:
		var codex_btn := _find_button_by_text(top_right, "Codex")
		var codex_screen = hud.get("codex_screen")
		if codex_btn:
			await _click_button(codex_btn, "Codex button (open)")
			print("HARNESS: Codex panel visible after open click=%s" % (codex_screen.visible if codex_screen else "n/a"))
			await _click_button(codex_btn, "Codex button (close)")
		else:
			print("HARNESS ERROR: Codex button not found under top_right_panel")
	else:
		print("HARNESS ERROR: top_right_panel not found on WorldHUD")


func _drive_pause_and_quit_to_menu() -> void:
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("WorldUI") if scene else null
	var pause_menu := hud.get_node_or_null("PauseMenu") if hud else null

	if not pause_menu:
		print("HARNESS ERROR: PauseMenu node not found under WorldUI")
		return

	await _send_action_event("pause", true)
	await _send_action_event("pause", false)
	await _wait_frames(4)
	print("HARNESS: PauseMenu visible after pause press=%s" % pause_menu.visible)

	if not pause_menu.visible:
		print("HARNESS ERROR: pause action did not open PauseMenu")
		return

	var pre_settings_scene := get_tree().current_scene
	var settings_btn: Button = pause_menu.get("settings_button")
	await _click_button(settings_btn, "PauseMenu.SettingsButton")
	# change_scene_with_fade() only swaps scenes after its fade-out tween
	# finishes — checking current_scene right after the click (before that
	# fade completes) would wrongly look like the click did nothing.
	await _wait_for_scene_change(pre_settings_scene, 3.0)
	print("HARNESS: current_scene after Settings click=%s" % get_tree().current_scene)

	# SettingsMenu pushes World onto SceneManager's history; its own Back
	# button should return here. Find it by text rather than guessing a path,
	# since we only care whether the return trip works, not its exact layout.
	var settings_scene := get_tree().current_scene
	if settings_scene and not (settings_scene is MainMenu):
		var back_btn := _find_button_by_text(settings_scene, "Back")
		if back_btn:
			await _click_button(back_btn, "SettingsMenu Back button")
			await _wait_for_scene_change(settings_scene, 3.0)
		else:
			print("HARNESS ERROR: no 'Back' button found on SettingsMenu, cannot return")

	# Re-fetch: World may have been reloaded as current_scene by SceneManager.
	scene = get_tree().current_scene
	hud = scene.get_node_or_null("WorldUI") if scene else null
	pause_menu = hud.get_node_or_null("PauseMenu") if hud else null
	if not pause_menu or not pause_menu.visible:
		print("HARNESS ERROR: PauseMenu not visible after returning from Settings (pause_menu=%s)" % pause_menu)
		return

	var pre_quit_scene := get_tree().current_scene
	var quit_btn: Button = pause_menu.get("quit_button")
	await _click_button(quit_btn, "PauseMenu.QuitButton (Quit to Menu)")
	await _wait_for_scene_change(pre_quit_scene, 3.0)


func _drive_continue_from_menu() -> void:
	var waited := 0.0
	while not (get_tree().current_scene and get_tree().current_scene is MainMenu) and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	if not (get_tree().current_scene is MainMenu):
		print("HARNESS ERROR: did not land back on MainMenu after Quit to Menu (current_scene=%s)" % get_tree().current_scene)
		return

	print("HARNESS: back on MainMenu after Quit to Menu")

	var menu := get_tree().current_scene
	var continue_btn: Button = menu.get_node_or_null("Control/ButtonPanel/VBoxContainer/ContinueButton")

	if not continue_btn or not continue_btn.visible:
		print("HARNESS ERROR: ContinueButton missing/not visible after quitting to menu — save may not have persisted (continue_btn=%s)" % continue_btn)
		return

	await _click_button(continue_btn, "ContinueButton")

	var world_ok := await _wait_for_world_loaded()
	print("HARNESS: Continue -> world_loaded=%s (this is the direct regression check for the reported 'stuck' bug)" % world_ok)
