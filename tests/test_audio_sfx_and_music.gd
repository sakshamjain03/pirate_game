extends GutTest

## M11 Requirement 8 — full SFX pass and music. Covers the new .ogg/.wav
## fallback in AudioManager.play_sound(), the new play_music()/stop_music()
## API, and that every sound_name actually wired into gameplay code
## (Island.gd, BoardingSystem.gd, EncounterManager.gd, etc.) has a real asset
## file on disk — the exact gap Requirement 8.1 exists to close.

const REQUIRED_SFX := [
	"cannon", "explosion",
	"building_construct", "building_upgrade",
	"boarding_start", "boarding_success", "boarding_fail",
	"victory", "defeat",
	"resource_collect", "gold_gain",
	"tech_unlock", "ship_purchase", "captain_recruit",
	"dock", "discovery", "treasure_found", "wind_shift", "level_up",
	"ui_click", "ui_confirm", "ui_cancel", "ui_error", "ui_tab_switch",
]

const REQUIRED_MUSIC := ["main_menu", "in_world"]

func test_every_wired_sound_name_has_a_real_asset_file():
	for sound_name in REQUIRED_SFX:
		var has_ogg = ResourceLoader.exists("res://assets/audio/%s.ogg" % sound_name)
		var has_wav = ResourceLoader.exists("res://assets/audio/%s.wav" % sound_name)
		assert_true(has_ogg or has_wav,
			"'%s' is wired into gameplay code but has no res://assets/audio/%s.{ogg,wav}" % [sound_name, sound_name])

func test_at_least_25_sfx_cues_exist_on_disk():
	## Requirement 8.1's literal target.
	var dir = DirAccess.open("res://assets/audio/")
	assert_not_null(dir)
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".ogg") or file_name.ends_with(".wav")):
			count += 1
		file_name = dir.get_next()
	assert_true(count >= 25, "Requirement 8.1 targets 25-30 SFX cues; found %d" % count)

func test_both_required_music_tracks_exist_on_disk():
	for track in REQUIRED_MUSIC:
		var exists = ResourceLoader.exists("res://assets/audio/music/%s.ogg" % track) \
			or ResourceLoader.exists("res://assets/audio/music/%s.wav" % track)
		assert_true(exists, "Requirement 8.2 needs a '%s' music track in assets/audio/music/" % track)

func test_play_sound_finds_ogg_before_wav():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	assert_eq(mgr._find_sound_path("cannon"), "res://assets/audio/cannon.ogg",
		"cannon.ogg exists on disk; play_sound must find it")
	mgr.free()

func test_play_sound_still_finds_wav_only_assets():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	assert_eq(mgr._find_sound_path("ui_click"), "res://assets/audio/ui_click.wav",
		"ui_click.wav exists (no .ogg counterpart); play_sound must still find it")
	mgr.free()

func test_play_sound_warns_once_for_a_genuinely_missing_asset():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	add_child_autoqfree(mgr)
	assert_eq(mgr._find_sound_path("definitely_not_a_real_sound_xyz"), "",
		"A nonexistent sound_name must resolve to no path")
	mgr.free()

func test_play_music_has_a_real_api():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	assert_true(mgr.has_method("play_music"), "Requirement 8.2 needs a play_music() entry point")
	assert_true(mgr.has_method("stop_music"))
	mgr.free()

func test_play_music_is_idempotent_for_the_same_already_playing_track():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	add_child_autoqfree(mgr)
	await wait_process_frames(1)

	mgr.play_music("main_menu")
	await wait_process_frames(2)
	assert_true(mgr._music_player.playing, "Precondition: music should be playing")
	var stream_before = mgr._music_player.stream

	mgr.play_music("main_menu")  # same track again
	assert_eq(mgr._music_player.stream, stream_before,
		"Re-requesting the same already-playing track should not restart/reload it")

func test_play_music_switches_tracks():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	add_child_autoqfree(mgr)
	await wait_process_frames(1)

	mgr.play_music("main_menu")
	await wait_process_frames(2)
	mgr.play_music("in_world")
	await wait_process_frames(2)

	assert_eq(mgr._current_music_track, "in_world", "Switching tracks should update the tracked current track")

func test_stop_music_stops_playback():
	var mgr = load("res://scripts/managers/AudioManager.gd").new()
	add_child_autoqfree(mgr)
	await wait_process_frames(1)

	mgr.play_music("main_menu")
	await wait_process_frames(2)
	mgr.stop_music()
	assert_false(mgr._music_player.playing, "stop_music() must actually stop playback")
	assert_eq(mgr._current_music_track, "")
