extends GutTest

## M29 D.2 / requirement D3 — closed as STALE, and this test pins why.
## The audit feared save/load could re-fire an ocean event. It can't: the
## schedule lives in the EventManager autoload, which keeps it across scene
## changes, and a fresh app start reschedules from zero with an interval of at
## least min_event_interval. A restart can only DELAY the next event, never
## duplicate one — so no save section is needed (D3.2). If EventManager ever
## gains persistence, this test should be replaced by a round-trip test.

var _saved_timer: float
var _saved_next: float


func before_each() -> void:
	_saved_timer = EventManager._timer
	_saved_next = EventManager._next_event_time


func after_each() -> void:
	EventManager._timer = _saved_timer
	EventManager._next_event_time = _saved_next


func test_a_restart_reschedules_no_sooner_than_the_minimum_interval() -> void:
	for i in 20:
		EventManager._timer = 999.0  # as if an event were long overdue before the restart
		EventManager._schedule_next_event()
		assert_eq(EventManager._timer, 0.0, "the clock restarts")
		assert_true(EventManager._next_event_time >= EventManager.min_event_interval,
			"next event is at least min_event_interval away, so nothing fires on load")


func test_event_manager_still_has_no_save_section() -> void:
	assert_false(EventManager.has_method("get_save_data"),
		"EventManager gained persistence — replace this stale-pin with a real round-trip test and add it to _NEW_GAME_RESET_MANAGERS")
