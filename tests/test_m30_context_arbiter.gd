extends GutTest
## M30 Wave 0 (0.20): the one context button. Phone controls are two steering
## buttons plus an ~11-button HUD, so every new M30 verb shares this slot,
## ranked Repel > Brace > Board/Take Prize > Keg > Land > Assault > Spyglass >
## Dock. Wave 0 moves WorldManager's hard-coded "board, else dock" into two
## providers; these pin that the ranking, labels and the fallthrough hold.

var _arbiter: ContextVerbArbiter
var _state := {"board": false, "dock": false, "board_succeeds": true}
var _performed: Array = []


func before_each() -> void:
	_arbiter = ContextVerbArbiter.new()
	_state = {"board": false, "dock": false, "board_succeeds": true}
	_performed = []
	_arbiter.register_provider(&"dock",
		func(): return _state["dock"],
		func(): _performed.append("dock"); return true,
		"Dock", "anchor")
	_arbiter.register_provider(&"board",
		func(): return _state["board"],
		func(): _performed.append("board"); return _state["board_succeeds"],
		"Board Enemy", "grapple")


func test_nothing_available_is_no_verb() -> void:
	assert_eq(_arbiter.get_context_verb(), &"")
	assert_eq(_arbiter.perform(), &"")


func test_board_beats_dock_when_both_are_available() -> void:
	_state["board"] = true
	_state["dock"] = true
	assert_eq(_arbiter.get_context_verb(), &"board")
	assert_eq(_arbiter.get_label(&"board"), "Board Enemy")
	assert_eq(_arbiter.get_icon(&"board"), "grapple")
	assert_eq(_arbiter.perform(), &"board")
	assert_eq(_performed, ["board"])


func test_dock_alone() -> void:
	_state["dock"] = true
	assert_eq(_arbiter.get_context_verb(), &"dock")
	assert_eq(_arbiter.perform(), &"dock")


func test_a_declined_board_falls_through_to_dock() -> void:
	# The old WorldManager rule: `if not boarded: _toggle_docking()`.
	_state["board"] = true
	_state["dock"] = true
	_state["board_succeeds"] = false
	assert_eq(_arbiter.perform(), &"dock")
	assert_eq(_performed, ["board", "dock"])


func test_priority_order_is_the_agreed_one() -> void:
	assert_eq(ContextVerbArbiter.PRIORITY, [&"repel", &"brace", &"board", &"take_prize",
		&"keg", &"land", &"assault", &"spyglass", &"dock"])
	for verb in [&"spyglass", &"repel", &"keg", &"brace"]:
		_arbiter.register_provider(verb, func(): return true, func(): return true, str(verb))
	assert_eq(_arbiter.get_context_verb(), &"repel")
	_arbiter.unregister_provider(&"repel")
	assert_eq(_arbiter.get_context_verb(), &"brace")
	_arbiter.unregister_provider(&"brace")
	assert_eq(_arbiter.get_context_verb(), &"keg")


func test_unknown_verb_is_rejected() -> void:
	# push_errors by design (never skip silently); GUT 9.4 has no error tracker.
	_arbiter.register_provider(&"teleport", func(): return true, func(): return true, "Teleport")
	assert_eq(_arbiter.get_context_verb(), &"", "an unranked verb must never win")


func test_world_manager_routes_dock_input_through_the_arbiter() -> void:
	var wm: Node = load("res://scripts/managers/WorldManager.gd").new()
	assert_true(wm.has_method("get_context_verb"), "WorldManager exposes the arbiter's verb")
	assert_true(wm.has_method("register_context_provider"), "later waves register their verbs here")
	wm.free()
