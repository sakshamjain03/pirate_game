extends GutTest

# test_touch_target_audit.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — Automated touch-target verification.
# Rather than checking every screen's layout manually to guarantee docs/18_ACCESSIBILITY.md §6
# (72x72 minimum target), this parameterised test iterates through all core UI screens.
# It simulates the mobile environment and verifies that PirateThemeBuilder's layout pass
# successfully clamped every Button's custom_minimum_size to at least 72x72.

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
		assert_true(node.custom_minimum_size.x >= 72.0 and node.custom_minimum_size.y >= 72.0,
			"Button '%s' in %s must meet the 72x72 minimum touch target (found %s)" % [node.name, scene_name, node.custom_minimum_size])
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
