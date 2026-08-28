extends GutTest

## M12 Task 1 — verifies the local telemetry boundary stays non-identifying and
## produces a signal usable by a future consented backend adapter.

func test_analytics_filters_non_primitive_params():
	var clean := AnalyticsManager._sanitize_params({
		"chapter_number": 2,
		"repelled": true,
		"unsupported": {"nested": "data"},
	})
	assert_eq(clean, {"chapter_number": 2, "repelled": true})


func test_log_event_emits_sanitized_params():
	watch_signals(AnalyticsManager)
	AnalyticsManager.log_event("test_event", {"value": 4, "ignored": []})
	assert_signal_emitted_with_parameters(AnalyticsManager, "event_logged", ["test_event", {"value": 4}])


func test_blank_event_name_is_rejected():
	watch_signals(AnalyticsManager)
	AnalyticsManager.log_event("")
	assert_signal_not_emitted(AnalyticsManager, "event_logged")
