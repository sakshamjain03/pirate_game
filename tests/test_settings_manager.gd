extends "res://addons/gut/test.gd"

# test_settings_manager.gd
# Property-based tests for SettingsManager.

const SettingsManagerClass = preload("res://Scripts/managers/SettingsManager.gd")

class TestableSettingsManager extends SettingsManagerClass:
	var display_applied: bool = false
	
	func apply_display_settings() -> void:
		display_applied = true

class MockAudioManager extends Node:
	var bus_calls: Array[Dictionary] = []
	
	func set_bus_volume(bus_name: String, linear: float) -> void:
		bus_calls.append({"bus": bus_name, "vol": linear})
		
	func clear_calls() -> void:
		bus_calls.clear()

var sm: TestableSettingsManager
var mock_am: MockAudioManager
var temp_cfg_path = "user://test_settings_temp.cfg"

func before_each():
	sm = TestableSettingsManager.new()
	sm._settings_path = temp_cfg_path
	mock_am = MockAudioManager.new()
	sm.audio_manager = mock_am
	add_child(sm)
	add_child(mock_am)
	
	# Ensure temp file doesn't exist
	if FileAccess.file_exists(temp_cfg_path):
		var dir = DirAccess.open("user://")
		dir.remove(temp_cfg_path.replace("user://", ""))

func after_each():
	if is_instance_valid(sm):
		sm.queue_free()
	if is_instance_valid(mock_am):
		mock_am.queue_free()
		
	if FileAccess.file_exists(temp_cfg_path):
		var dir = DirAccess.open("user://")
		dir.remove(temp_cfg_path.replace("user://", ""))

# 3.1 Property 8: settings persistence round-trip
func test_property_8_persistence_round_trip():
	var resolutions = ["1920x1080", "1280x720", "2560x1440", "3840x2160"]
	var passed = true
	var iterations = 50
	
	for i in range(iterations):
		var master = randf()
		var music = randf()
		var sfx = randf()
		var is_fullscreen = (randi() % 2) == 0
		var res = resolutions[randi() % resolutions.size()]
		var is_vsync = (randi() % 2) == 0
		
		# Set and save
		sm.master_volume = master
		sm.music_volume = music
		sm.sfx_volume = sfx
		sm.fullscreen = is_fullscreen
		sm.resolution = res
		sm.vsync = is_vsync
		sm.save_settings()
		
		# Load into a fresh manager
		var sm2 = TestableSettingsManager.new()
		sm2._settings_path = temp_cfg_path
		sm2.audio_manager = mock_am
		add_child(sm2)
		sm2.load_settings()
		
		if not is_equal_approx(sm2.master_volume, master): passed = false
		if not is_equal_approx(sm2.music_volume, music): passed = false
		if not is_equal_approx(sm2.sfx_volume, sfx): passed = false
		if sm2.fullscreen != is_fullscreen: passed = false
		if sm2.resolution != res: passed = false
		if sm2.vsync != is_vsync: passed = false
		
		sm2.queue_free()
		
		if not passed:
			break
			
	assert_true(passed, "All settings values must match exactly after save and load")

# 3.2 Property 9: settings_changed signal emitted on every save
func test_property_9_signal_emitted_on_save():
	var passed = true
	var iterations = 25
	
	for i in range(iterations):
		sm.master_volume = randf()
		watch_signals(sm)
		sm.save_settings()
		assert_signal_emitted(sm, "settings_changed")
		assert_signal_emit_count(sm, "settings_changed", 1)
		
		# GUT watch_signals keeps track, so we need to reset/unwatch for clean iteration
		# Actually we can just rely on the single watch above, but to avoid accumulation:
		# Just instantiate a new sm.
		sm.queue_free()
		sm = TestableSettingsManager.new()
		sm._settings_path = temp_cfg_path
		sm.audio_manager = mock_am
		add_child(sm)
		
	# Instead of breaking, we do the property correctly
	# Let's do it simpler inside the loop
	pass

# A better implementation for Property 9 that doesn't rely on recreating sm
func test_property_9_signal_emitted_on_save_better():
	var iterations = 25
	var total_emits = 0
	
	# Connect to a local counter
	sm.settings_changed.connect(func(): total_emits += 1)
	
	for i in range(iterations):
		sm.master_volume = randf()
		var before = total_emits
		sm.save_settings()
		if total_emits != before + 1:
			assert_true(false, "settings_changed must be emitted exactly once per save")
			return
			
	assert_true(true, "settings_changed was emitted exactly once per save")

# 3.3 Property 10: settings saved under correct ConfigFile sections
func test_property_10_saved_under_correct_sections():
	var passed = true
	var iterations = 20
	var resolutions = ["1920x1080", "1280x720", "2560x1440"]
	
	for i in range(iterations):
		sm.master_volume = randf()
		sm.music_volume = randf()
		sm.sfx_volume = randf()
		sm.fullscreen = (randi() % 2) == 0
		sm.resolution = resolutions[randi() % resolutions.size()]
		sm.vsync = (randi() % 2) == 0
		
		sm.save_settings()
		
		var cfg = ConfigFile.new()
		var err = cfg.load(temp_cfg_path)
		if err != OK:
			passed = false
			break
			
		if not cfg.has_section_key("audio", "master_volume"): passed = false
		if not cfg.has_section_key("audio", "music_volume"): passed = false
		if not cfg.has_section_key("audio", "sfx_volume"): passed = false
		
		if not cfg.has_section_key("display", "fullscreen"): passed = false
		if not cfg.has_section_key("display", "resolution"): passed = false
		if not cfg.has_section_key("display", "vsync"): passed = false
		
		if not passed:
			break
			
	assert_true(passed, "All settings must be saved under their correct ConfigFile sections")

# 3.4 Property 11: apply_audio_settings calls set_bus_volume for all three buses
func test_property_11_apply_audio_calls_set_bus_volume():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		mock_am.clear_calls()
		
		var master = randf()
		var music = randf()
		var sfx = randf()
		
		sm.master_volume = master
		sm.music_volume = music
		sm.sfx_volume = sfx
		
		sm.apply_audio_settings()
		
		if mock_am.bus_calls.size() != 3:
			passed = false
			break
			
		var master_found = false
		var music_found = false
		var sfx_found = false
		
		for call in mock_am.bus_calls:
			if call.bus == "Master" and is_equal_approx(call.vol, master): master_found = true
			if call.bus == "Music" and is_equal_approx(call.vol, music): music_found = true
			if call.bus == "SFX" and is_equal_approx(call.vol, sfx): sfx_found = true
			
		if not (master_found and music_found and sfx_found):
			passed = false
			break
			
	assert_true(passed, "apply_audio_settings must call set_bus_volume exactly three times with correct arguments")
