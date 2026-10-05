extends GutTest
## M30 Wave 0 (0.11): StoreBackendStub "buys" anything instantly. Before M30 a
## non-Android RELEASE build (the desktop build) used it, so every product
## was free. Release builds off Android now get StoreBackendUnavailable,
## which reports unavailable and fails every purchase without granting.


func test_unavailable_backend_never_grants() -> void:
	var backend := StoreBackendUnavailable.new()
	assert_false(backend.is_available())
	watch_signals(backend)
	backend.begin_purchase(&"eights_small")
	await wait_process_frames(2)
	assert_signal_emitted(backend, "purchase_failed", "a purchase must fail, not complete")
	assert_signal_not_emitted(backend, "purchase_completed")


func test_owned_query_returns_nothing() -> void:
	var backend := StoreBackendUnavailable.new()
	watch_signals(backend)
	backend.query_owned()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(backend, "owned_items_ready", [[]])


func test_release_builds_never_pick_the_stub() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/managers/StoreManager.gd")
	var i := src.find("func _create_backend()")
	var body := src.substr(i, src.find("\nfunc ", i + 10) - i)
	assert_string_contains(body, "OS.is_debug_build()", "the stub must be debug-only")
	assert_true(body.find("StoreBackendUnavailable") < body.find("StoreBackendStub.new()"),
		"the release guard must come before the stub")
