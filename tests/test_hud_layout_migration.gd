extends GutTest

const SettingsManagerClass = preload("res://scripts/managers/SettingsManager.gd")

# test_hud_layout_migration.gd
# M22 Phase 1.6 (design.md §9) — mobile_control_overrides' stored "position"
# deltas are in MobileLayoutManager.REFERENCE_LANDSCAPE units, which moved
# from a 1080-tall reference to a 780-tall one when the project base changed
# (Phase 1.5). A config file saved before this change (no "hud_layout_version"
# key, i.e. version 1) must have its stored positions rescaled on load so a
# returning player's saved HUD customization still lands in the same real
# screen location — never silently reset (CLAUDE.md fragile-area rule).

## Mirrors test_mobile_layout_manager_overrides.gd's own TestableSettingsManager
## — a real load_settings()/save_settings() would otherwise reach real
## DisplayServer/audio bus state.
class TestableSettingsManager extends SettingsManagerClass:
	func apply_display_settings() -> void:
		pass
	func apply_audio_settings() -> void:
		pass

const _TEST_PATH := "user://test_hud_layout_migration.cfg"

var _settings: TestableSettingsManager


func after_each():
	if is_instance_valid(_settings):
		_settings.queue_free()
	_settings = null
	if FileAccess.file_exists(_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_TEST_PATH))


func _write_fixture(hud_layout_version, overrides: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("mobile", "control_overrides", overrides)
	if hud_layout_version != null:
		config.set_value("mobile", "hud_layout_version", hud_layout_version)
	config.save(_TEST_PATH)


func _load() -> TestableSettingsManager:
	var settings := TestableSettingsManager.new()
	settings._settings_path = _TEST_PATH
	add_child_autofree(settings)
	settings.load_settings()
	return settings


func test_a_v1_config_with_no_version_key_has_its_positions_rescaled():
	_write_fixture(null, {"movement": {"position": Vector2(100, 200), "scale_mult": 1.0}})
	_settings = _load()

	var expected := Vector2(100, 200) * SettingsManagerClass.HUD_LAYOUT_MIGRATION_RATIO
	var got: Vector2 = _settings.mobile_control_overrides["movement"]["position"]
	assert_almost_eq(got.x, expected.x, 0.01)
	assert_almost_eq(got.y, expected.y, 0.01)
	assert_eq(_settings.hud_layout_version, SettingsManagerClass.HUD_LAYOUT_VERSION_CURRENT)


func test_a_v1_config_leaves_scale_mult_untouched():
	_write_fixture(null, {"movement": {"position": Vector2(100, 200), "scale_mult": 1.3}})
	_settings = _load()
	assert_eq(_settings.mobile_control_overrides["movement"]["scale_mult"], 1.3)


func test_an_already_current_config_is_not_rescaled_again():
	_write_fixture(SettingsManagerClass.HUD_LAYOUT_VERSION_CURRENT,
		{"movement": {"position": Vector2(100, 200), "scale_mult": 1.0}})
	_settings = _load()

	var got: Vector2 = _settings.mobile_control_overrides["movement"]["position"]
	assert_eq(got, Vector2(100, 200), "A version-2 config's positions must load unchanged")


func test_an_empty_overrides_dict_migrates_without_error():
	_write_fixture(null, {})
	_settings = _load()
	assert_eq(_settings.mobile_control_overrides, {})
	assert_eq(_settings.hud_layout_version, SettingsManagerClass.HUD_LAYOUT_VERSION_CURRENT)


func test_save_settings_always_writes_the_current_version():
	_settings = TestableSettingsManager.new()
	_settings._settings_path = _TEST_PATH
	add_child_autofree(_settings)
	_settings.save_settings()

	var config := ConfigFile.new()
	config.load(_TEST_PATH)
	assert_eq(config.get_value("mobile", "hud_layout_version", -1),
		SettingsManagerClass.HUD_LAYOUT_VERSION_CURRENT)
