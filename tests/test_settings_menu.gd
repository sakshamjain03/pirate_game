extends GutTest

# test_settings_menu.gd
# Property-based tests for SettingsMenu UI interactions.

const SettingsMenu = preload("res://scenes/ui/SettingsMenu.tscn")

class MockSettingsManager extends Node:
	var master_volume: float = 1.0
	var music_volume: float = 1.0
	var sfx_volume: float = 1.0
	var fullscreen: bool = false
	var resolution: String = "1920x1080"
	var vsync: bool = false
	var input_sensitivity: float = 1.0
	var input_dead_zone: float = 0.2
	var graphics_quality: int = 1

	var calls: Array[String] = []
	
	func save_settings() -> void:
		calls.append("save_settings")
		
	func apply_display_settings() -> void:
		calls.append("apply_display_settings")
		
	func clear_calls() -> void:
		calls.clear()

class MockAudioManager extends Node:
	var bus_calls: Array[Dictionary] = []
	
	func set_bus_volume(bus_name: String, linear: float) -> void:
		bus_calls.append({"bus": bus_name, "vol": linear})
		
	func clear_calls() -> void:
		bus_calls.clear()

var menu
var mock_sm: MockSettingsManager
var mock_am: MockAudioManager

func before_each():
	mock_sm = MockSettingsManager.new()
	mock_am = MockAudioManager.new()
	add_child(mock_sm)
	add_child(mock_am)
	
func after_each():
	if is_instance_valid(menu):
		if menu.get_parent():
			menu.get_parent().remove_child(menu)
		menu.free()
	if is_instance_valid(mock_sm):
		mock_sm.free()
	if is_instance_valid(mock_am):
		mock_am.free()

func _instantiate_menu():
	menu = SettingsMenu.instantiate()
	menu.settings_manager = mock_sm
	menu.audio_manager = mock_am
	add_child(menu)

# 6.1 Property 12: SettingsMenu controls reflect current settings state
func test_property_12_controls_reflect_state():
	var resolutions = ["1920x1080", "1280x720", "2560x1440", "3840x2160"]
	var passed = true
	var iterations = 25
	
	for i in range(iterations):
		mock_sm.master_volume = snapped(randf(), 0.01)
		mock_sm.music_volume = snapped(randf(), 0.01)
		mock_sm.sfx_volume = snapped(randf(), 0.01)
		mock_sm.fullscreen = (randi() % 2) == 0
		mock_sm.vsync = (randi() % 2) == 0
		mock_sm.resolution = resolutions[randi() % resolutions.size()]
		
		menu = SettingsMenu.instantiate()
		menu.settings_manager = mock_sm
		menu.audio_manager = mock_am
		add_child(menu)
		
		assert_true(is_equal_approx(menu.master_slider.value, mock_sm.master_volume), "master slider")
		assert_true(is_equal_approx(menu.music_slider.value, mock_sm.music_volume), "music slider")
		assert_true(is_equal_approx(menu.sfx_slider.value, mock_sm.sfx_volume), "sfx slider")
		assert_eq(menu.fullscreen_check.button_pressed, mock_sm.fullscreen, "fullscreen check")
		assert_eq(menu.vsync_check.button_pressed, mock_sm.vsync, "vsync check")
		assert_eq(menu.resolution_option.get_item_text(menu.resolution_option.selected), mock_sm.resolution, "resolution option")
		
		remove_child(menu)
		menu.free()
		menu = null

# 6.2 Property 13: volume slider changes propagate to AudioManager and SettingsManager
func test_property_13_volume_slider_changes():
	_instantiate_menu()
	var passed = true
	var iterations = 35
	
	for i in range(iterations):
		var test_vol = randf()
		var bus = ["Master", "Music", "SFX"][randi() % 3]
		
		mock_sm.clear_calls()
		mock_am.clear_calls()
		
		if bus == "Master":
			menu.master_slider.value_changed.emit(test_vol)
		elif bus == "Music":
			menu.music_slider.value_changed.emit(test_vol)
		else:
			menu.sfx_slider.value_changed.emit(test_vol)
			
		if mock_sm.calls.size() != 1 or mock_sm.calls[0] != "save_settings":
			passed = false
			
		if mock_am.bus_calls.size() != 1:
			passed = false
		else:
			var call = mock_am.bus_calls[0]
			if call.bus != bus or not is_equal_approx(call.vol, test_vol):
				passed = false
				
		if not passed:
			break
			
	assert_true(passed, "Volume slider changes should propagate to AudioManager and SettingsManager exactly once")

# 6.3 Property 14: display control changes trigger save and apply
func test_property_14_display_changes_save_and_apply():
	_instantiate_menu()
	var passed = true
	var iterations = 25
	
	for i in range(iterations):
		mock_sm.clear_calls()
		var action = randi() % 3
		
		if action == 0:
			menu.fullscreen_check.toggled.emit((randi() % 2) == 0)
		elif action == 1:
			menu.vsync_check.toggled.emit((randi() % 2) == 0)
		else:
			menu.resolution_option.item_selected.emit(randi() % 4)
			
		if mock_sm.calls.size() != 2:
			passed = false
		else:
			if mock_sm.calls[0] != "save_settings" or mock_sm.calls[1] != "apply_display_settings":
				passed = false
				
		if not passed:
			break
			
	assert_true(passed, "Display control changes must call save_settings() before apply_display_settings()")
