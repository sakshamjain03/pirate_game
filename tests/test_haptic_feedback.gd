extends GutTest

# test_haptic_feedback.gd
#
# Haptics Handoff -- required GUT tests (see docs/ANTIGRAVITY_HAPTICS_HANDOFF.md S5).
#
# GUT runs on desktop (OS.has_feature("pc") == true), so Input.vibrate_handheld()
# is never physically called. These tests assert *contracts* -- the setting persists,
# the guard structure is correct, and the right call sites exist -- rather than
# claiming physical vibration occurred.
#
# Real-device verification is reported separately as "not tested in GUT".

# ---------------------------------------------------------------------------
# Helpers -- lightweight SettingsManager instance that uses a temp file so
# we never corrupt the real user://settings.cfg. Pattern matches
# test_settings_manager.gd exactly.
# ---------------------------------------------------------------------------

const SettingsManagerClass = preload("res://scripts/managers/SettingsManager.gd")

class TestableSettings extends SettingsManagerClass:
	func apply_display_settings() -> void: pass
	func apply_audio_settings()   -> void: pass

var _sm: TestableSettings
const _TEMP_CFG := "user://test_haptics_temp.cfg"

func before_each() -> void:
	_sm = TestableSettings.new()
	_sm._settings_path = _TEMP_CFG
	add_child(_sm)
	_clean_temp()

func after_each() -> void:
	if is_instance_valid(_sm):
		_sm.queue_free()
	_clean_temp()

func _clean_temp() -> void:
	if FileAccess.file_exists(_TEMP_CFG):
		DirAccess.open("user://").remove(_TEMP_CFG.replace("user://", ""))


# ---------------------------------------------------------------------------
# Test 1 -- Settings round-trip
# haptics_enabled saves, reloads, and defaults to true when the key is absent.
# ---------------------------------------------------------------------------

func test_haptics_enabled_round_trip_true() -> void:
	_sm.haptics_enabled = true
	_sm.save_settings()

	var sm2 := TestableSettings.new()
	sm2._settings_path = _TEMP_CFG
	add_child(sm2)
	sm2.load_settings()

	assert_true(sm2.haptics_enabled,
		"haptics_enabled should reload as true after saving true")
	sm2.queue_free()

func test_haptics_enabled_round_trip_false() -> void:
	_sm.haptics_enabled = false
	_sm.save_settings()

	var sm2 := TestableSettings.new()
	sm2._settings_path = _TEMP_CFG
	add_child(sm2)
	sm2.load_settings()

	assert_false(sm2.haptics_enabled,
		"haptics_enabled should reload as false after saving false")
	sm2.queue_free()

func test_haptics_enabled_defaults_to_true_when_key_absent() -> void:
	# Write a config that deliberately omits the [mobile] section entirely.
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", 1.0)
	cfg.save(_TEMP_CFG)

	var sm2 := TestableSettings.new()
	sm2._settings_path = _TEMP_CFG
	add_child(sm2)
	sm2.load_settings()

	assert_true(sm2.haptics_enabled,
		"haptics_enabled must default to true when [mobile] key is absent")
	sm2.queue_free()

func test_haptics_enabled_defaults_to_true_when_no_file() -> void:
	# No file at all -- load_settings falls through to _apply_defaults().
	var sm2 := TestableSettings.new()
	sm2._settings_path = "user://definitely_does_not_exist_haptics_test.cfg"
	add_child(sm2)
	sm2.load_settings()

	assert_true(sm2.haptics_enabled,
		"haptics_enabled must default to true when no settings file exists")
	sm2.queue_free()


# ---------------------------------------------------------------------------
# Test 2 -- Gateway guard
# When haptics are disabled all HapticFeedbackManager methods complete without error.
# On desktop CI, OS.has_feature("pc") is true so the pc branch fires;
# we also verify the toggle branch by checking the source-level guard.
# ---------------------------------------------------------------------------

func test_gateway_all_methods_safe_when_haptics_disabled() -> void:
	var original := SettingsManager.haptics_enabled
	SettingsManager.haptics_enabled = false

	HapticFeedbackManager.tap()
	HapticFeedbackManager.available()
	HapticFeedbackManager.ready()
	HapticFeedbackManager.damage()
	HapticFeedbackManager.reward()

	SettingsManager.haptics_enabled = original
	pass_test("All HapticFeedbackManager methods completed without error when toggle is off")

func test_gateway_guard_structure_in_source() -> void:
	var f := FileAccess.open(
		"res://scripts/managers/HapticFeedbackManager.gd", FileAccess.READ)
	assert_not_null(f, "HapticFeedbackManager.gd must be accessible from res://")
	var src := f.get_as_text()
	f.close()

	assert_true(src.contains("OS.has_feature(\"pc\")"),
		"play() must short-circuit on the pc feature flag")
	assert_true(src.contains("haptics_enabled"),
		"play() must honour the haptics_enabled toggle")


# ---------------------------------------------------------------------------
# Test 3 -- Centralization
# Input.vibrate_handheld appears in exactly one .gd file: HapticFeedbackManager.gd.
# ---------------------------------------------------------------------------

func test_vibrate_handheld_appears_only_in_haptic_manager() -> void:
	var violations: Array[String] = []
	_scan_for_vibrate("res://scripts/", violations)
	_scan_for_vibrate("res://tests/",   violations)

	assert_eq(violations.size(), 0,
		"Input.vibrate_handheld must appear ONLY in HapticFeedbackManager.gd. " +
		"Violations: " + str(violations))

func _scan_for_vibrate(root: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := root + name
		if dir.current_is_dir():
			_scan_for_vibrate(full + "/", out)
		elif name.ends_with(".gd") and not full.ends_with("HapticFeedbackManager.gd") and not full.ends_with("test_haptic_feedback.gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f:
				var src := f.get_as_text()
				f.close()
				if src.contains("vibrate_handheld"):
					out.append(full)
		name = dir.get_next()


# ---------------------------------------------------------------------------
# Test 4 -- Meaningful-event coverage
# Each completion event invokes HapticFeedbackManager.reward() on its success path.
# Verified from source text.
# ---------------------------------------------------------------------------

func _read_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("test_haptic_feedback: cannot read " + path)
		return ""
	var src := f.get_as_text()
	f.close()
	return src

func test_island_menu_build_success_calls_reward() -> void:
	var src := _read_source("res://scripts/ui/IslandMenu.gd")
	var fn_start := src.find("func _on_build_pressed(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"IslandMenu._on_build_pressed must call HapticFeedbackManager.reward() on success")

func test_island_menu_upgrade_success_calls_reward() -> void:
	var src := _read_source("res://scripts/ui/IslandMenu.gd")
	var fn_start := src.find("func _on_upgrade_pressed(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"IslandMenu._on_upgrade_pressed must call HapticFeedbackManager.reward() on success")

func test_upgrade_choice_screen_card_pressed_calls_reward() -> void:
	var src := _read_source("res://scripts/ui/UpgradeChoiceScreen.gd")
	var fn_start := src.find("func _on_card_pressed(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"UpgradeChoiceScreen._on_card_pressed must call HapticFeedbackManager.reward()")

func test_campaign_manager_complete_chapter_calls_reward() -> void:
	var src := _read_source("res://scripts/managers/CampaignManager.gd")
	var fn_start := src.find("func _complete_chapter(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"CampaignManager._complete_chapter must call HapticFeedbackManager.reward() after _grant_rewards()")
	# reward() must appear BEFORE chapter_completed.emit()
	var reward_pos := fn_body.find("HapticFeedbackManager.reward()")
	var emit_pos   := fn_body.find("chapter_completed.emit(")
	assert_true(reward_pos < emit_pos,
		"reward() must fire before chapter_completed.emit() in _complete_chapter")

func test_loot_drop_collect_calls_reward() -> void:
	var src := _read_source("res://scripts/combat/LootDrop.gd")
	var fn_start := src.find("func _collect(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"LootDrop._collect must call HapticFeedbackManager.reward() on successful pickup")

func test_raid_report_screen_open_calls_reward() -> void:
	var src := _read_source("res://scripts/ui/RaidReportScreen.gd")
	var fn_start := src.find("func open(")
	var fn_end   := src.find("\nfunc ", fn_start + 1)
	var fn_body  := src.substr(fn_start, fn_end - fn_start)
	assert_true(fn_body.contains("HapticFeedbackManager.reward()"),
		"RaidReportScreen.open must call HapticFeedbackManager.reward() when the result is presented")
	# reward() must appear at or after show() -- not before presenting the result.
	var show_pos   := fn_body.find("show()")
	var reward_pos := fn_body.find("HapticFeedbackManager.reward()")
	assert_true(reward_pos > show_pos,
		"reward() must fire at or after show() in RaidReportScreen.open")