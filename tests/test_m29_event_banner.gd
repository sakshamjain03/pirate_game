extends GutTest

## M29 D.1 / J.1 / J.2 — world events, failed encounters and the campaign's end
## reach the player through WorldHUD's existing announcer, one at a time; the
## dock prompt says who holds the island.

const WorldHUDScene = preload("res://scenes/ui/WorldHUD.tscn")

var _viewport: SubViewport
var _hud: Node


func before_each():
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.disable_3d = true
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_viewport.add_child(_hud)
	await wait_frames(3)


func after_each():
	if is_instance_valid(_viewport):
		_viewport.queue_free()


func _announcements() -> Array:
	return _hud.find_children("Announcement", "PanelContainer", true, false)


func test_every_trigger_event_in_event_manager_has_an_entry() -> void:
	var table := load("res://resources/events/EventAnnouncements.tres") as EventAnnouncementData
	assert_not_null(table)
	var src := FileAccess.get_file_as_string("res://scripts/managers/EventManager.gd")
	var re := RegEx.new()
	re.compile('trigger_event[(]"([a-z_]+)"')
	var names := {}
	for m in re.search_all(src):
		names[m.get_string(1)] = true
	assert_gt(names.size(), 5, "found EventManager's trigger_event literals")
	for n in names:
		var title = table.get_title(n)
		assert_not_null(title, "EventAnnouncements has an entry for '%s'" % n)
		if title != null and not String(title).is_empty():
			assert_false(String(title).begins_with("event_"), "'%s' title is player text, not an id" % n)


func test_world_events_queue_one_at_a_time_in_order() -> void:
	EventManager.world_event_triggered.emit("merchant_convoy_spotted", {})
	EventManager.world_event_triggered.emit("ghost_ship_spotted", {})
	EventManager.world_event_triggered.emit("iron_vulture_spotted", {})
	await wait_frames(1)
	var shown := _announcements()
	assert_eq(shown.size(), 1, "one announcement on screen at a time")
	assert_string_contains(shown[0].get_child(0).text, "convoy", "first in, first shown")
	assert_eq(_hud._announce_queue.size(), 2, "the other two wait their turn")
	shown[0].queue_free()
	await wait_frames(2)
	assert_string_contains(_announcements()[0].get_child(0).text, "ghost ship", "then the next")


func test_silent_and_unknown_events_show_nothing() -> void:
	EventManager.world_event_triggered.emit("ship_docked", {})
	EventManager.world_event_triggered.emit("no_such_event", {})
	await wait_frames(1)
	assert_eq(_announcements().size(), 0)


func test_campaign_end_and_failed_encounter_are_announced() -> void:
	CampaignManager.campaign_completed_signal.emit()
	_hud._on_encounter_failed("x", "bad data")
	await wait_frames(1)
	assert_string_contains(_announcements()[0].get_child(0).text, "Campaign complete")
	assert_eq(_hud._announce_queue.size(), 1, "the encounter notice queues behind it")


func test_dock_owner_line_names_the_owner_in_its_colour() -> void:
	var spain := load("res://resources/factions/SpanishEmpire.tres") as FactionData
	var isle := IslandData.new()
	isle.island_name = "Cartagena"
	isle.island_type = IslandData.IslandType.ENEMY
	isle.owner_faction = spain
	var line: Dictionary = _hud.island_owner_line(isle)
	assert_string_contains(line["text"], "Cartagena")
	assert_string_contains(line["text"], spain.faction_name)
	assert_eq(line["color"], spain.sail_color)
	assert_eq(_hud.island_owner_line(null)["text"], "", "unknown island: no line, no crash")
	assert_not_null(_hud._dock_owner_label, "the owner line sits in the dock prompt's column")
	assert_eq(_hud._dock_owner_label.get_parent().name, "DockColumn")
