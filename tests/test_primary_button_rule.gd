extends GutTest

# test_primary_button_rule.gd
# M22 Phase 4.7 (design.md §7, requirements 6.3) — "one Primary CTA per
# screen": coral is reserved for the single most important action, so a
# screen with two coral buttons has no primary action at all. Each Phase-4
# screen is instantiated for real and every Button it builds (scene or
# runtime) is counted. Extended to every modal screen in Phase 6.10;
# IslandMenu's docked-action rule lives in test_island_menu_board.gd and the
# HUD's Set Sail in test_mobile_controls_layout.gd (both need a live world).

const SCREENS_WITH_ONE_PRIMARY := [
	"res://scenes/ui/MainMenu.tscn",       # Continue or New Game, never both
	"res://scenes/ui/PauseMenu.tscn",      # Resume
	"res://scenes/ui/WardrobeScreen.tscn", # Equip (its nested Store has none)
]
const SCREENS_WITH_NO_PRIMARY := [
	"res://scenes/ui/SettingsMenu.tscn",
	"res://scenes/ui/CreditsScreen.tscn",
	"res://scenes/ui/AgeGate.tscn",
	"res://scenes/ui/ConsentPanel.tscn",
	"res://scenes/ui/CaptainsLog.tscn",
	"res://scenes/ui/CodexScreen.tscn",
	"res://scenes/ui/WhatsNewScreen.tscn",
	"res://scenes/ui/WorldMapScreen.tscn",
	"res://scenes/ui/TutorialDialogue.tscn",
	"res://scenes/ui/PurchaseSupportScreen.tscn",
	"res://scenes/ui/RaidReportScreen.tscn",
	"res://scenes/ui/UpgradeChoiceScreen.tscn",
]
## Screens where coral is not just "at most one" but NONE, by design
## (M22 6b): a glowing coral Buy is purchase pressure and a coral Watch Ad is
## ad pressure (AGENTS.md never-list); a pulsing "go!" on defeat reads as
## celebration (design.md §10: somber).
const SCREENS_THAT_MUST_NOT_HAVE_A_PRIMARY := [
	"res://scenes/ui/StoreScreen.tscn",
	"res://scenes/ui/RewardedBonusOffer.tscn",
	"res://scenes/ui/DeathScreen.tscn",
]


func _primary_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for node in root.find_children("*", "Button", true, false):
		var btn := node as Button
		# `visible` (own flag), not is_visible_in_tree(): PauseMenu is built
		# hidden until opened, which would otherwise count nothing at all.
		if btn.visible and btn.theme_type_variation == &"PrimaryButton":
			out.append(btn)
	return out


func _names(buttons: Array[Button]) -> String:
	return ", ".join(buttons.map(func(b: Button) -> String: return String(b.name)))


func test_menus_have_exactly_one_primary():
	for path in SCREENS_WITH_ONE_PRIMARY:
		var screen: Node = load(path).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame
		var primaries := _primary_buttons(screen)
		assert_eq(primaries.size(), 1,
			"%s must have exactly one visible PrimaryButton, found [%s]" % [path, _names(primaries)])


func test_secondary_screens_have_no_more_than_one_primary():
	for path in SCREENS_WITH_NO_PRIMARY:
		var screen: Node = load(path).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame
		var primaries := _primary_buttons(screen)
		assert_lte(primaries.size(), 1,
			"%s must have at most one visible PrimaryButton, found [%s]" % [path, _names(primaries)])


func test_store_ads_and_defeat_have_no_primary_at_all():
	for path in SCREENS_THAT_MUST_NOT_HAVE_A_PRIMARY:
		var screen: Node = load(path).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame
		if screen.has_method("_refresh"):
			screen._refresh()  # Store builds its Buy buttons on refresh
			await get_tree().process_frame
		var primaries := _primary_buttons(screen)
		assert_eq(primaries.size(), 0,
			"%s must never show a coral PrimaryButton, found [%s]" % [path, _names(primaries)])
	get_tree().paused = false


# ChoiceDialog is a modal ask(), not a scene — a destructive choice (Delete
# Account) must never be dressed as the coral "go" action.
func test_choice_dialog_has_no_primary():
	var dialog := ChoiceDialog.new("Title", "Body", PackedStringArray(["Cancel", "Delete Account"]))
	add_child_autofree(dialog)
	await get_tree().process_frame
	assert_eq(_primary_buttons(dialog).size(), 0,
		"ChoiceDialog buttons are all brass — none is a Primary CTA")
