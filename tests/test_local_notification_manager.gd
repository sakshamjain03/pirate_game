extends GutTest

## M12 Tasks 10–12 — no configured platform plugin must make notification calls harmless.

func test_raid_message_uses_the_shared_outcome_data():
	assert_string_contains(LocalNotificationManager.get_raid_notification_body({"repelled": true, "faction_id": "royal_navy"}), "Royal Navy")
	assert_string_contains(LocalNotificationManager.get_raid_notification_body({"repelled": false, "faction_id": "royal_navy"}), "raided")


func test_missing_platform_plugin_is_a_safe_no_op():
	if Engine.has_singleton(LocalNotificationManager.PLUGIN_SINGLETON):
		assert_true(true, "Platform plugin is configured; device behavior is verified separately.")
		return
	assert_false(LocalNotificationManager.schedule_completion("test", "title", "body"))


func test_raid_notification_body_matches_raid_report_screens_wording():
	## Guards the exact drift RaidReportScreen and LocalNotificationManager used to
	## be exposed to: two independently-authored sentences for the same event.
	var report := {"repelled": false, "faction_id": "merchant_guild", "stolen": {"gold": 40}}
	var screen = load("res://scenes/ui/RaidReportScreen.tscn").instantiate()
	add_child_autofree(screen)
	screen.open(report)
	get_tree().paused = false
	assert_string_contains(screen.details_label.text, LocalNotificationManager.get_raid_notification_body(report))


class FakeNotificationPlugin:
	extends RefCounted
	var permission_requests := 0
	var granted := false
	func has_permission() -> bool:
		return granted
	func request_permission() -> void:
		permission_requests += 1
	func schedule(_event_id: String, _title: String, _body: String, _delay: int) -> void:
		pass


func test_permission_is_requested_at_most_once_even_if_denied():
	var previous_requested := LocalNotificationManager._permission_requested
	var previous_file_existed := FileAccess.file_exists(LocalNotificationManager.SETTINGS_PATH)

	var fake := FakeNotificationPlugin.new()
	Engine.register_singleton(LocalNotificationManager.PLUGIN_SINGLETON, fake)
	LocalNotificationManager._permission_requested = false

	LocalNotificationManager.schedule_completion("test", "title", "body")
	LocalNotificationManager.schedule_completion("test", "title", "body")
	LocalNotificationManager.schedule_completion("test", "title", "body")

	assert_eq(fake.permission_requests, 1, "denied permission must not be re-prompted on every call")

	Engine.unregister_singleton(LocalNotificationManager.PLUGIN_SINGLETON)
	LocalNotificationManager._permission_requested = previous_requested
	if not previous_file_existed:
		DirAccess.remove_absolute(LocalNotificationManager.SETTINGS_PATH)
