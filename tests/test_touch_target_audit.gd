extends GutTest

# test_touch_target_audit.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — Automated touch-target verification.
# Rather than checking every screen's layout manually to guarantee docs/18_ACCESSIBILITY.md §6
# (48dp minimum target), this parameterised test iterates through all core UI screens.
# It simulates the mobile environment and verifies that PirateThemeBuilder's layout pass
# successfully clamped every Button's custom_minimum_size to at least
# PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET.
#
# M22 (2026-09-25) — the floor moved from 72x72 to 96x96 canvas px (still
# 48dp, but the base resolution changed — design.md §3); reads the real
# constant now instead of a second hardcoded copy of the number, so this test
# can never itself drift out of sync with PirateThemeBuilder again. This
# raised floor is EXPECTED to still fail for MainMenu/SettingsMenu at the end
# of Phase 1 — see tasks.md Notes and design.md §9: MainMenu.gd's
# _apply_button_sizing() unconditionally overwrites custom_minimum_size with
# its own MOBILE_BUTTON_MIN_SIZE=(320,64) AFTER apply_button_juice()'s clamp
# already ran, undoing it; the real per-screen fix is Phase 4's, not this
# constant-reference update.

const SCENES_TO_TEST = [
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/SettingsMenu.tscn",
	"res://scenes/ui/IslandMenu.tscn",
	"res://scenes/ui/CaptainsLog.tscn",
	"res://scenes/ui/WorldMapScreen.tscn",
	"res://scenes/ui/CodexScreen.tscn",
	"res://scenes/ui/TutorialDialogue.tscn",
	"res://scenes/ui/WardrobeScreen.tscn",
	"res://scenes/ui/PauseMenu.tscn",
	"res://scenes/ui/DeathScreen.tscn",
	"res://scenes/ui/RaidReportScreen.tscn",
	"res://scenes/ui/RewardedBonusOffer.tscn",
	"res://scenes/ui/WhatsNewScreen.tscn",
	"res://scenes/ui/PurchaseSupportScreen.tscn"
]

var _viewport: SubViewport
var _screen: Node

func before_all():
	PirateThemeBuilder.force_mobile_scaling_for_test = true

func after_all():
	PirateThemeBuilder.force_mobile_scaling_for_test = false

func after_each():
	get_tree().paused = false
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_screen = null

func _check_buttons_recursively(node: Node, scene_name: String) -> void:
	if node is Button:
		# Some buttons are naturally large without custom_minimum_size, but PirateThemeBuilder
		# enforces it universally on mobile. We verify that this enforcement occurred.
		var floor_size := PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET
		assert_true(node.custom_minimum_size.x >= floor_size.x and node.custom_minimum_size.y >= floor_size.y,
			"Button '%s' in %s must meet the %sx%s minimum touch target (found %s)" %
				[node.name, scene_name, floor_size.x, floor_size.y, node.custom_minimum_size])
	for child in node.get_children():
		_check_buttons_recursively(child, scene_name)

func test_property_all_screens_meet_touch_target_minimums():
	for scene_path in SCENES_TO_TEST:
		var packed = load(scene_path)
		if not packed:
			push_error("Could not load " + scene_path)
			continue
		
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(750, 1334)
		_viewport.disable_3d = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		
		_screen = packed.instantiate()
		_viewport.add_child(_screen)
		
		# Give it time to run _ready() and apply_button_juice()
		await wait_frames(2)
		
		var scene_name = scene_path.get_file()
		_check_buttons_recursively(_screen, scene_name)
		
		_viewport.queue_free()
		_viewport = null
		_screen = null
