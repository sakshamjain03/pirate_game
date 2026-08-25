extends GutTest

# test_input_rebinding.gd
# D57: SettingsMenu resolved InputManager via get_tree().root.get_node_or_null(
# "InputManager") — i.e. as an autoload — but it was a scene-local node under
# World/Systems. Both lookups always returned null, were null-guarded, and
# rebinding silently did nothing. Fixed by promoting InputManager to a real
# autoload (M7 Task 5); this test pins that a rebind actually reaches InputMap.

const SettingsMenuScene = preload("res://scenes/ui/SettingsMenu.tscn")

var menu

var _original_events: Array


func before_each():
	_original_events = InputMap.action_get_events("ship_forward")
	menu = SettingsMenuScene.instantiate()
	add_child_autoqfree(menu)


func after_each():
	# Restore whatever the action carried before this test rebound it.
	for e in InputMap.action_get_events("ship_forward"):
		InputMap.action_erase_event("ship_forward", e)
	for e in _original_events:
		InputMap.action_add_event("ship_forward", e)


func test_input_manager_is_reachable_without_a_world_scene():
	## SettingsMenu is opened via a full scene change from MainMenu
	## (SceneManager.change_scene_with_fade), so no World scene — and so no
	## scene-local node — exists when this menu is up. The old
	## get_tree().root.get_node_or_null("InputManager") lookup always returned
	## null here; the autoload must be reachable regardless of what scene (if
	## any) is currently loaded.
	assert_true(InputManager is Node, "InputManager must be reachable as an autoload")
	assert_true(InputManager.has_method("rebind_action"))


func test_rebinding_a_key_actually_changes_the_input_map():
	var new_event := InputEventKey.new()
	new_event.keycode = KEY_J
	new_event.pressed = true

	menu._on_rebind_pressed("ship_forward", Button.new())
	menu._input(new_event)

	var events := InputMap.action_get_events("ship_forward")
	var found := false
	for e in events:
		if e is InputEventKey and e.keycode == KEY_J:
			found = true
	assert_true(found, "Rebinding must actually reach InputMap.action_add_event()")


func test_reset_to_defaults_reaches_the_input_map():
	for e in InputMap.action_get_events("ship_forward"):
		InputMap.action_erase_event("ship_forward", e)
	assert_eq(InputMap.action_get_events("ship_forward").size(), 0, "Precondition: unbound")

	InputManager.reset_to_defaults()

	assert_gt(InputMap.action_get_events("ship_forward").size(), 0,
		"Reset to defaults must reload real bindings from project settings, not leave the action unbound")
