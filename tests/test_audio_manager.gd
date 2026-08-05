extends GutTest

# test_audio_manager.gd
# Property-based tests for AudioManager
#
# Responsibilities:
# - Test volume round-trip consistency (Property 5)
# - Test volume_changed signal emission (Property 6)
# - Test volume clamping behavior (Property 7)
#
# Dependencies:
# - GUT testing framework
# - AudioManager autoload

var audio_manager
var original_master_volume: float
var original_music_volume: float
var original_sfx_volume: float

func before_each():
	# Store original volumes to restore after tests
	original_master_volume = AudioManager.get_bus_volume("Master")
	original_music_volume = AudioManager.get_bus_volume("Music")
	original_sfx_volume = AudioManager.get_bus_volume("SFX")
	
	# Get reference to AudioManager
	audio_manager = AudioManager
	assert_not_null(audio_manager, "AudioManager should be loaded as autoload")

func after_each():
	# Restore original volumes
	if audio_manager:
		audio_manager.set_bus_volume("Master", original_master_volume)
		audio_manager.set_bus_volume("Music", original_music_volume)
		audio_manager.set_bus_volume("SFX", original_sfx_volume)

func test_property_5_volume_round_trip():
	# Property 5: For any valid bus and linear volume in [0.0, 1.0],
	# get_bus_volume after set_bus_volume must equal the original value within tolerance.
	
	var buses = ["Master", "Music", "SFX"]
	var test_values = [0.0, 0.25, 0.5, 0.75, 1.0]
	var tolerance = 0.00001
	
	for bus in buses:
		for value in test_values:
			# Set volume
			audio_manager.set_bus_volume(bus, value)
			
			# Get volume back
			var result = audio_manager.get_bus_volume(bus)
			
			# Verify within tolerance
			var diff = abs(result - value)
			assert_true(diff < tolerance, 
				"Volume round-trip for %s at %.4f: got %.6f" % [bus, value, result])

func test_property_6_volume_changed_signal():
	# Property 6: For any valid bus and linear volume, set_bus_volume
	# must emit volume_changed exactly once with correct arguments.
	
	var buses = ["Master", "Music", "SFX"]
	var test_values = [0.0, 0.5, 1.0]
	
	for bus in buses:
		for value in test_values:
			# Connect signal spy
			var state = {
				"emitted": false,
				"bus": "",
				"value": 0.0
			}
			
			var my_func = func(b: String, v: float):
				state.emitted = true
				state.bus = b
				state.value = v
			
			audio_manager.volume_changed.connect(my_func)
			
			# Call set_bus_volume
			audio_manager.set_bus_volume(bus, value)
			
			# Verify signal was emitted
			assert_true(state.emitted, 
				"volume_changed signal should be emitted for %s at %.4f" % [bus, value])
			
			# Verify arguments
			assert_eq(state.bus, bus, "Bus name should match")
			assert_eq(state.value, value, "Volume value should match")
			
			# Disconnect
			audio_manager.volume_changed.disconnect(my_func)

func test_property_7_volume_clamping():
	# Property 7: For any float value (including outside [0.0, 1.0]),
	# get_bus_volume after set_bus_volume must return a value in [0.0, 1.0].
	
	var buses = ["Master", "Music", "SFX"]
	
	# Test values outside valid range
	var out_of_range_values = [-10.0, -1.0, -0.5, -0.001, 1.001, 2.0, 5.0, 10.0]
	var boundary_values = [0.0, 1.0]
	var all_test_values = out_of_range_values + boundary_values
	
	for bus in buses:
		for value in all_test_values:
			# Set volume with potentially out-of-range value
			audio_manager.set_bus_volume(bus, value)
			
			# Get volume back
			var result = audio_manager.get_bus_volume(bus)
			
			# Verify result is clamped to [0.0, 1.0]
			assert_true(result >= 0.0 and result <= 1.0,
				"Volume for %s with input %.4f should be clamped to [0.0, 1.0], got %.6f" 
				% [bus, value, result])

func _test_invalid_bus_name():
	# Additional test: invalid bus names should log error and return 0.0
	
	var invalid_buses = ["Invalid", "", "music", "MASTER", "Audio"]
	
	for bus in invalid_buses:
		# get_bus_volume should return 0.0 for invalid bus
		var result = audio_manager.get_bus_volume(bus)
		assert_eq(result, 0.0, "get_bus_volume should return 0.0 for invalid bus: %s" % bus)
		
		# set_bus_volume should return early (no crash)
		audio_manager.set_bus_volume(bus, 0.5)
