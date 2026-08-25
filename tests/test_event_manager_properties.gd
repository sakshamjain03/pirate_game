extends GutTest

# test_event_manager_properties.gd
# M2 Task 9.3 — property tests for EventManager, against design.md's
# Properties 16-18.

var _saved_active_events: Array
var _saved_discovered_islands: Array


func before_each():
	_saved_active_events = EventManager.active_events.duplicate()
	_saved_discovered_islands = EventManager.discovered_islands.duplicate()
	EventManager.active_events.clear()
	EventManager.discovered_islands.clear()


func after_each():
	EventManager.active_events = _saved_active_events.duplicate()
	EventManager.discovered_islands = _saved_discovered_islands.duplicate()


# Property 16: Event Condition Satisfaction — for any world event with
# defined trigger conditions, when all conditions are satisfied, the event
# shall trigger exactly once.
func test_property_16_trigger_event_fires_exactly_once():
	watch_signals(EventManager)

	EventManager.trigger_event("test_event", {"foo": "bar"}, EventManager.EventPriority.MEDIUM)

	assert_signal_emit_count(EventManager, "world_event_triggered", 1)
	assert_signal_emitted_with_parameters(EventManager, "world_event_triggered", ["test_event", {"foo": "bar"}])


func test_property_16_repeated_triggers_each_fire_exactly_once():
	watch_signals(EventManager)

	for i in range(5):
		EventManager.trigger_event("event_%d" % i, {}, EventManager.EventPriority.LOW)

	assert_signal_emit_count(EventManager, "world_event_triggered", 5)


# Property 17: Event Priority Resolution — for any game state where multiple
# events have satisfied trigger conditions, the event with the highest
# priority shall trigger first.
func test_property_17_higher_priority_events_process_first():
	# trigger_event() drains the queue immediately, so priority ordering only
	# matters when multiple events are queued before any processing happens —
	# exercise _sort_events()/_process_next_event() directly, as EventManager
	# itself does internally between a burst of queued events.
	EventManager.active_events = [
		{"name": "low_event", "data": {}, "priority": EventManager.EventPriority.LOW},
		{"name": "critical_event", "data": {}, "priority": EventManager.EventPriority.CRITICAL},
		{"name": "medium_event", "data": {}, "priority": EventManager.EventPriority.MEDIUM},
		{"name": "high_event", "data": {}, "priority": EventManager.EventPriority.HIGH},
	]
	EventManager._sort_events()

	watch_signals(EventManager)
	while not EventManager.active_events.is_empty():
		EventManager._process_next_event()

	assert_signal_emit_count(EventManager, "world_event_triggered", 4)
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 0)[0], "critical_event")
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 1)[0], "high_event")
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 2)[0], "medium_event")
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 3)[0], "low_event")


func test_property_17_equal_priority_events_preserve_queue_order():
	EventManager.active_events = [
		{"name": "first", "data": {}, "priority": EventManager.EventPriority.HIGH},
		{"name": "second", "data": {}, "priority": EventManager.EventPriority.HIGH},
	]
	EventManager._sort_events()

	watch_signals(EventManager)
	EventManager._process_next_event()
	EventManager._process_next_event()

	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 0)[0], "first")
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 1)[0], "second")


# Property 18: Docking Event Triggering — for any successful docking
# completion, the system shall trigger appropriate docking events
# (discovery, interaction) exactly once.
func test_property_18_first_dock_triggers_discovery_and_interaction():
	watch_signals(EventManager)

	EventManager.handle_docking_event("port_royal")

	assert_signal_emit_count(EventManager, "world_event_triggered", 2)
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 0)[0], "island_discovered")
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 1)[0], "ship_docked")
	assert_true(EventManager.discovered_islands.has("port_royal"))


func test_property_18_repeat_dock_does_not_rediscover():
	EventManager.handle_docking_event("port_royal")

	watch_signals(EventManager)
	EventManager.handle_docking_event("port_royal")

	# Only the interaction event fires again — discovery is a one-time event.
	assert_signal_emit_count(EventManager, "world_event_triggered", 1)
	assert_eq(get_signal_parameters(EventManager, "world_event_triggered", 0)[0], "ship_docked")


func test_property_18_docking_different_islands_each_discover_exactly_once():
	watch_signals(EventManager)

	EventManager.handle_docking_event("port_royal")
	EventManager.handle_docking_event("tortuga")
	EventManager.handle_docking_event("port_royal")

	var discovery_count := 0
	for i in range(get_signal_emit_count(EventManager, "world_event_triggered")):
		if get_signal_parameters(EventManager, "world_event_triggered", i)[0] == "island_discovered":
			discovery_count += 1

	assert_eq(discovery_count, 2, "Each island must be discovered exactly once, regardless of repeat docking")
