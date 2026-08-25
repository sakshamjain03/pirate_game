extends GutTest

# test_navigation_integration.gd
# M1 Task 10.1-10.4 / M2 Task 11.3 — integration tests for real scene
# navigation through the SceneManager autoload.
#
# test_scene_manager_history.gd proxies SceneManager entirely so it never
# touches the engine's scene tree. These tests do the opposite on purpose:
# they exercise the REAL SceneManager autoload against real, lightweight UI
# scenes (Boot/MainMenu/SettingsMenu/CreditsScreen — never World.tscn, which
# is heavy) to prove the actual navigation wiring works end-to-end. Every
# real path in this codebase uses change_scene_with_fade's default 0.4s
# tween, so by the time scene_changed fires the deferred
# get_tree().change_scene_to_file() effect has already completed.
#
# get_tree().current_scene and SceneManager._scene_history are saved and
# restored around each test so this file can't leave state behind for other
# test files (several of which check "if not get_tree().current_scene:
# create one" and would otherwise silently adopt a leftover UI scene).

const BootScene = preload("res://scenes/core/Boot.tscn")
const MainMenuScene = preload("res://scenes/ui/MainMenu.tscn")
const SettingsMenuScene = preload("res://scenes/ui/SettingsMenu.tscn")
const CreditsScreenScene = preload("res://scenes/ui/CreditsScreen.tscn")

var _saved_current_scene: Node
var _saved_history: Array


func before_each():
	_saved_current_scene = get_tree().current_scene
	_saved_history = SceneManager._scene_history.duplicate()
	SceneManager._scene_history.clear()


func after_each():
	var leftover := get_tree().current_scene
	get_tree().current_scene = _saved_current_scene
	if leftover and leftover != _saved_current_scene and is_instance_valid(leftover):
		leftover.queue_free()
	SceneManager._scene_history = _saved_history.duplicate()


func _press_ui_cancel(node: Node) -> void:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	node._unhandled_input(e)


# Task 10.1 — Boot -> MainMenu transition.
func test_boot_transitions_to_main_menu():
	var boot = BootScene.instantiate()
	add_child_autoqfree(boot)

	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_eq(SceneManager._scene_history.back(), "res://scenes/ui/MainMenu.tscn")
	assert_true(get_tree().current_scene is MainMenu,
		"Boot must hand off to the real MainMenu scene")


# Task 10.2 — MainMenu button navigation pushes into _scene_history.
func test_main_menu_settings_button_navigates_and_pushes_history():
	var menu = MainMenuScene.instantiate()
	add_child_autoqfree(menu)

	menu._on_settings_pressed()
	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_eq(SceneManager._scene_history.back(), "res://scenes/ui/SettingsMenu.tscn")
	assert_true(get_tree().current_scene is SettingsMenu)


func test_main_menu_credits_button_navigates_and_pushes_history():
	var menu = MainMenuScene.instantiate()
	add_child_autoqfree(menu)

	menu._on_credits_pressed()
	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_eq(SceneManager._scene_history.back(), "res://scenes/ui/CreditsScreen.tscn")
	assert_true(get_tree().current_scene is CreditsScreen)


# Task 10.3 — go_back() returns to MainMenu.
func test_go_back_returns_to_main_menu():
	SceneManager._scene_history = ["res://scenes/ui/MainMenu.tscn", "res://scenes/ui/SettingsMenu.tscn"]

	SceneManager.go_back()
	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_eq(SceneManager._scene_history.back(), "res://scenes/ui/MainMenu.tscn")
	assert_true(get_tree().current_scene is MainMenu)


# Task 10.4 — ui_cancel back-navigation from SettingsMenu/CreditsScreen.
func test_ui_cancel_navigates_back_from_settings_menu():
	SceneManager._scene_history = ["res://scenes/ui/MainMenu.tscn", "res://scenes/ui/SettingsMenu.tscn"]
	var settings = SettingsMenuScene.instantiate()
	add_child_autoqfree(settings)

	_press_ui_cancel(settings)
	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_true(get_tree().current_scene is MainMenu,
		"ui_cancel on SettingsMenu must call SceneManager.go_back()")


func test_ui_cancel_navigates_back_from_credits_screen():
	SceneManager._scene_history = ["res://scenes/ui/MainMenu.tscn", "res://scenes/ui/CreditsScreen.tscn"]
	var credits = CreditsScreenScene.instantiate()
	add_child_autoqfree(credits)

	_press_ui_cancel(credits)
	await wait_for_signal(SceneManager.scene_changed, 1.0)
	await wait_process_frames(1)

	assert_true(get_tree().current_scene is MainMenu,
		"ui_cancel on CreditsScreen must call SceneManager.go_back()")
