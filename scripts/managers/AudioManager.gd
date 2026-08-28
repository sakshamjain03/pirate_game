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

var _warned_missing_sounds: Dictionary = {}
## M11 Requirement 8.2 — a single persistent player for ambient music/shanties,
## distinct from play_sound()'s fire-and-forget SFX players. Reused across
## calls so switching tracks (e.g. menu -> in-world) doesn't stack players.
var _music_player: AudioStreamPlayer = null
var _current_music_track: String = ""

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

## M11 — checks .ogg before .wav. Sourced SFX (Kenney's CC0 packs, this
## project's established asset-sourcing precedent) ship as .ogg, Godot's own
## preferred compressed format; .wav stays supported for any hand-authored/
## Bfxr-exported asset (docs/02_TECH_STACK.md's other named audio tool).
const SOUND_EXTENSIONS := [".ogg", ".wav"]

func _find_sound_path(sound_name: String) -> String:
	for ext in SOUND_EXTENSIONS:
		var path = "res://assets/audio/" + sound_name + ext
		if ResourceLoader.exists(path):
			return path
	return ""

func play_sound(sound_name: String) -> void:
	# Check if we have this sound (mock implementation to prevent crashes while missing assets)
	var path = _find_sound_path(sound_name)
	if not path.is_empty():
		var stream = load(path)
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX"
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	elif not _warned_missing_sounds.has(sound_name):
		# Warn once per sound name rather than on every call — this fires on
		# every cannon shot, and assets/audio/ has no files in it at all yet.
		_warned_missing_sounds[sound_name] = true
		push_warning("AudioManager: No audio asset for '%s' — assets/audio/ is empty, so this and any repeat plays are silent." % sound_name)

## M11 Requirement 8.2 — ambient music/shanties. Loops by default; calling
## again with the same track_name while it's already playing is a no-op so
## e.g. re-entering the same world state doesn't restart the track from zero.
func play_music(track_name: String, loop: bool = true) -> void:
	if _current_music_track == track_name and _music_player and _music_player.playing:
		return

	var path = "res://assets/audio/music/" + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/" + track_name + ".wav"

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: No music asset for '%s' — assets/audio/music/ is missing it." % track_name)
		return

	if not _music_player:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Music"
		add_child(_music_player)

	var stream = load(path)
	# AudioStreamOggVorbis exposes a plain bool `loop`; AudioStreamWAV instead
	# uses an enum `loop_mode` (0 = disabled, 1 = forward) — different
	# properties per format, not interchangeable.
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_music_player.stream = stream
	_music_player.play()
	_current_music_track = track_name

func stop_music() -> void:
	if _music_player:
		_music_player.stop()
	_current_music_track = ""
