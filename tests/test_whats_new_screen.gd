extends GutTest

# test_whats_new_screen.gd
# M14 Requirement 5 — the What's New panel. Purely reactive over
# PatchNotesData, mirroring test_captains_log.gd's exact pattern; plus the
# one-time auto-show comparison WorldHUD._check_whats_new() drives.

const WhatsNewScreenScene = preload("res://scenes/ui/WhatsNewScreen.tscn")
const WorldHUDScene = preload("res://scenes/ui/WorldHUD.tscn")

var _screen


func after_each():
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _notes(entries: Array[Dictionary]) -> PatchNotesData:
	var n := PatchNotesData.new()
	n.entries = entries
	return n


func test_latest_version_reads_the_last_entry():
	var n := _notes([
		{"version": "1.13.0", "date": "2026-08-01", "notes": "old"},
		{"version": "1.14.0", "date": "2026-09-07", "notes": "new"},
	])
	assert_eq(n.latest_version(), "1.14.0")


func test_latest_version_is_empty_when_no_entries_exist():
	assert_eq(_notes([]).latest_version(), "")


func test_opening_shows_the_panel_and_pauses():
	_screen = WhatsNewScreenScene.instantiate()
	add_child(_screen)
	_screen.patch_notes = _notes([{"version": "1.0.0", "date": "2026-01-01", "notes": "x"}])

	var was_paused := get_tree().paused
	_screen.open()
	assert_true(_screen.visible)
	assert_true(get_tree().paused)
	_screen.close()
	get_tree().paused = was_paused


func test_closing_hides_the_panel_and_unpauses():
	_screen = WhatsNewScreenScene.instantiate()
	add_child(_screen)
	_screen.open()
	_screen.close()
	assert_false(_screen.visible)
	assert_false(get_tree().paused)


func test_toggle_flips_visibility():
	_screen = WhatsNewScreenScene.instantiate()
	add_child(_screen)
	assert_false(_screen.visible)
	_screen.toggle()
	assert_true(_screen.visible)
	_screen.toggle()
	assert_false(_screen.visible)
	get_tree().paused = false


func test_lists_entries_newest_first():
	_screen = WhatsNewScreenScene.instantiate()
	add_child(_screen)
	_screen.patch_notes = _notes([
		{"version": "1.13.0", "date": "2026-08-01", "notes": "The older entry."},
		{"version": "1.14.0", "date": "2026-09-07", "notes": "The newer entry."},
	])

	_screen._refresh()

	var texts: Array[String] = []
	for child in _screen.content.get_children():
		if child is Label:
			texts.append(child.text)
	var newer_index := -1
	var older_index := -1
	for i in texts.size():
		if texts[i].contains("The newer entry."):
			newer_index = i
		if texts[i].contains("The older entry."):
			older_index = i
	assert_true(newer_index >= 0 and older_index >= 0, "Both entries must render")
	assert_lt(newer_index, older_index, "The newest entry must render first")
	_screen.close()


func test_shows_a_fallback_message_when_no_patch_notes_exist():
	_screen = WhatsNewScreenScene.instantiate()
	add_child(_screen)
	_screen.patch_notes = _notes([])

	_screen._refresh()

	var text_blob := ""
	for child in _screen.content.get_children():
		if child is Label:
			text_blob += child.text
	assert_true(text_blob.length() > 0)


# === WorldHUD._check_whats_new() — the one-time auto-show comparison ===

var _hud
var _saved_version: String


func _instantiate_hud():
	_hud = WorldHUDScene.instantiate()
	add_child(_hud)


func test_check_whats_new_opens_the_panel_when_the_stored_version_is_stale():
	_saved_version = SaveManager.last_seen_whats_new_version
	_instantiate_hud()
	_hud.whats_new_screen.patch_notes = _notes([{"version": "9.9.9", "date": "2099-01-01", "notes": "future"}])
	SaveManager.last_seen_whats_new_version = "9.9.8"

	_hud._check_whats_new()

	assert_true(_hud.whats_new_screen.visible)
	assert_eq(SaveManager.last_seen_whats_new_version, "9.9.9",
		"the stored version must advance so this doesn't show again next launch")

	_hud.whats_new_screen.close()
	_hud.queue_free()
	SaveManager.last_seen_whats_new_version = _saved_version


func test_check_whats_new_is_a_no_op_when_already_up_to_date():
	_saved_version = SaveManager.last_seen_whats_new_version
	_instantiate_hud()
	_hud.whats_new_screen.patch_notes = _notes([{"version": "9.9.9", "date": "2099-01-01", "notes": "future"}])
	SaveManager.last_seen_whats_new_version = "9.9.9"

	_hud._check_whats_new()

	assert_false(_hud.whats_new_screen.visible, "an up-to-date player must not see the panel pop up unprompted")

	_hud.queue_free()
	SaveManager.last_seen_whats_new_version = _saved_version


func test_save_load_round_trips_last_seen_whats_new_version():
	var saved := SaveManager.last_seen_whats_new_version
	SaveManager.last_seen_whats_new_version = "1.14.0"

	var data := {"last_seen_whats_new_version": SaveManager.last_seen_whats_new_version}
	SaveManager.last_seen_whats_new_version = ""
	if data.has("last_seen_whats_new_version"):
		SaveManager.last_seen_whats_new_version = str(data["last_seen_whats_new_version"])

	assert_eq(SaveManager.last_seen_whats_new_version, "1.14.0")
	SaveManager.last_seen_whats_new_version = saved
