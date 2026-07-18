extends Node

# AudioManager.gd
# Manages audio bus volumes for Master, Music, and SFX channels.
#
# Responsibilities:
# - Set and get linear volume levels for audio buses
# - Convert between linear and dB scale using Godot AudioServer
# - Validate bus names and clamp volume values
# - Emit volume_changed signal when volumes change
#
# Dependencies:
# - Godot Engine (AudioServer)
#
# Limitations:
# - Only supports three predefined buses: Master, Music, SFX
# - Volume values are clamped to [0.0, 1.0] range
#
# TODOs:
# - Add support for custom bus names via configuration
# - Implement volume smoothing/ramping for transitions
# - Add mute functionality per bus

signal volume_changed(bus_name: String, linear: float)

const VALID_BUSES: Array[String] = ["Master", "Music", "SFX"]

func set_bus_volume(bus_name: String, linear: float) -> void:
        if not bus_name in VALID_BUSES:
                push_error("AudioManager: Unknown bus name: %s" % bus_name)
                return
        
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index == -1:
                push_error("AudioManager: Bus %s not found in AudioServer" % bus_name)
                return
        
        var clamped_volume: float = clamp(linear, 0.0, 1.0)
        var db_value: float = linear_to_db(clamped_volume)
        
        AudioServer.set_bus_volume_db(bus_index, db_value)
        emit_signal("volume_changed", bus_name, clamped_volume)

func get_bus_volume(bus_name: String) -> float:
        if not bus_name in VALID_BUSES:
                push_error("AudioManager: Unknown bus name: %s" % bus_name)
                return 0.0
        
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index == -1:
                push_error("AudioManager: Bus %s not found in AudioServer" % bus_name)
                return 0.0
        
        var db_value: float = AudioServer.get_bus_volume_db(bus_index)
        return db_to_linear(db_value)

