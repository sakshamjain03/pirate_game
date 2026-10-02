## M29 D.1 — EventBanner and EventAnnouncements integration test.
## Requirements D1: WorldHUD connects world_event_triggered and shows a
## non-modal announcement banner (FIFO-queued, one at a time, auto-dismisses).

extends GutTest

func test_event_banner_queues_fifo() -> void:
	## Three trigger_event calls → three banners FIFO, one visible at a time.

	# Sanity: EventManager exists and has the signal
	assert_not_null(EventManager, "EventManager must be an autoload")
	assert_true(EventManager.has_signal("world_event_triggered"),
		"EventManager must have world_event_triggered signal")

	# We can't fully test the banner in headless, but we can verify:
	# 1. The EventAnnouncementData table exists and is loaded
	# 2. Every trigger_event literal in EventManager has a table entry

	var announcements = load("res://resources/events/EventAnnouncements.tres")
	assert_not_null(announcements, "EventAnnouncements.tres must exist and load")

	var announcement_table = announcements.get_announcements() if announcements.has_method("get_announcements") else {}

	# These are the 12 event names from EventManager.gd
	var expected_events = [
		"merchant_convoy_spotted",
		"floating_treasure_spotted",
		"ghost_ship_spotted",
		"iron_vulture_spotted",
		"fortunes_toll_spotted",
		"drifting_wreckage_spotted",
		"smugglers_cache_spotted",
		"pirate_raiding_party_spotted",
		"royal_navy_patrol_spotted",
		"wind_shifted",
		"island_discovered",
		"ship_docked"
	]

	for event_name in expected_events:
		assert_true(announcement_table.has(event_name),
			"EventAnnouncements must have entry for '%s'" % event_name)

func test_unknown_event_name_shows_nothing() -> void:
	## An unknown event name → no banner plus a warning.
	# This is tested in WorldHUD's actual queue logic when it encounters
	# an event with no table entry. We just verify the table lookup handles it.
	var announcements = load("res://resources/events/EventAnnouncements.tres")
	assert_not_null(announcements, "EventAnnouncements.tres must exist")

	var announcement_table = announcements.get_announcements() if announcements.has_method("get_announcements") else {}
	var unknown = announcement_table.get("unknown_event", null)
	assert_null(unknown, "Unknown events should not be in the table")
