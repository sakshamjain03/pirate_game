extends GutTest

const SettingsManagerClass = preload("res://scripts/managers/SettingsManager.gd")

## Mirrors test_settings_manager.gd's own TestableSettingsManager — a fresh
## SettingsManager instance's save_settings()/load_settings() would otherwise
## reach real DisplayServer/audio bus state, which this test has no business
## touching just to verify one Dictionary field round-trips through ConfigFile.
class TestableSettingsManager extends SettingsManagerClass:
	func apply_display_settings() -> void:
		pass
	func apply_audio_settings() -> void:
		pass

# test_mobile_layout_manager_overrides.gd
# 2026-09-20 — Settings > Customize HUD Layout persists per-control drag/
# resize adjustments through SettingsManager.mobile_control_overrides,
# applied on top of each control's already-computed default position/scale
# by MobileLayoutManager.apply_control_override(). GUT can fully exercise
# this data/plumbing half (the override lookup, delta math, and viewport
# clamping) headlessly; it cannot exercise real touch-drag interaction
# itself (HudCustomizeOverlay's _gui_input handlers), which needs a manual
# device pass instead — matching this project's existing documented
# limitations for touch/gamepad feel.

var _viewport: SubViewport
var _overrides_before: Dictionary

func before_each():
	_overrides_before = SettingsManager.mobile_control_overrides.duplicate(true)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2340, 1080)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

func after_each():
	SettingsManager.mobile_control_overrides = _overrides_before
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null


func test_no_override_returns_the_base_position_and_scale_unchanged():
	SettingsManager.mobile_control_overrides = {}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 0.8, _viewport, Vector2(200, 100))
	assert_eq(result.position, Vector2(10, 20))
	assert_eq(result.scale, 0.8)


func test_empty_dict_is_the_reset_state_even_after_a_prior_override():
	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2(50, 50), "scale_mult": 1.3}}
	SettingsManager.mobile_control_overrides = {}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 0.8, _viewport, Vector2(200, 100))
	assert_eq(result.position, Vector2(10, 20),
		"Clearing the overrides dict must fully reset a previously-customized control")


func test_position_delta_is_applied_in_reference_scale_units():
	# mobile_scale() at REFERENCE_LANDSCAPE against REFERENCE_LANDSCAPE itself
	# is exactly 1.0, so a stored delta of (100, 40) reference-units should
	# add through unscaled. M22 (2026-09-25): REFERENCE_LANDSCAPE moved from
	# 2340x1080 (physical) to 1688x780 (canvas px — design.md §3), so this
	# test's own viewport must match it, not a hardcoded 2340x1080.
	_viewport.size = Vector2i(MobileLayoutManager.REFERENCE_LANDSCAPE)
	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2(100, 40), "scale_mult": 1.0}}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 0.8, _viewport, Vector2(200, 100))
	assert_eq(result.position, Vector2(110, 60))
	assert_eq(result.scale, 0.8)


func test_scale_mult_multiplies_the_base_scale_and_is_clamped():
	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2.ZERO, "scale_mult": 1.2}}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 1.0, _viewport, Vector2(200, 100))
	assert_eq(result.scale, 1.2)

	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2.ZERO, "scale_mult": 9.0}}
	result = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 1.0, _viewport, Vector2(200, 100))
	assert_eq(result.scale, 1.5, "scale_mult must clamp to the documented [0.75, 1.5] range")

	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2.ZERO, "scale_mult": 0.01}}
	result = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 1.0, _viewport, Vector2(200, 100))
	assert_eq(result.scale, 0.75, "scale_mult must clamp to the documented [0.75, 1.5] range")


func test_resulting_position_is_clamped_onto_the_viewport():
	# A saved customization from a much larger device must never place a
	# control fully off-screen on a smaller one.
	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2(5000, 5000), "scale_mult": 1.0}}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 1.0, _viewport, Vector2(200, 100))
	var full := _viewport.get_visible_rect()
	assert_true(result.position.x <= full.end.x - 200.0 + 0.5)
	assert_true(result.position.y <= full.end.y - 100.0 + 0.5)

	SettingsManager.mobile_control_overrides = {"movement": {"position": Vector2(-5000, -5000), "scale_mult": 1.0}}
	result = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 1.0, _viewport, Vector2(200, 100))
	assert_true(result.position.x >= full.position.x - 0.5)
	assert_true(result.position.y >= full.position.y - 0.5)


func test_malformed_override_entry_falls_back_to_the_base_position_and_scale():
	SettingsManager.mobile_control_overrides = {"movement": "not a dictionary"}
	var result: Dictionary = MobileLayoutManager.apply_control_override(
		"movement", Vector2(10, 20), 0.8, _viewport, Vector2(200, 100))
	assert_eq(result.position, Vector2(10, 20))
	assert_eq(result.scale, 0.8)


func test_settings_manager_persists_overrides_through_save_and_load():
	var settings := TestableSettingsManager.new()
	settings._settings_path = "user://test_hud_overrides.cfg"
	add_child_autofree(settings)
	settings.mobile_control_overrides = {"movement": {"position": Vector2(12, -8), "scale_mult": 1.1}}
	settings.save_settings()

	var reloaded := TestableSettingsManager.new()
	reloaded._settings_path = "user://test_hud_overrides.cfg"
	add_child_autofree(reloaded)
	reloaded.load_settings()
	assert_eq(reloaded.mobile_control_overrides, {"movement": {"position": Vector2(12, -8), "scale_mult": 1.1}})

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hud_overrides.cfg"))
