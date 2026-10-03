extends GutTest

## M29 B.3 — capturing an island from a faction tells FactionManager exactly who
## lost it (island_captured_from), and that faction sends one hunter, then waits
## out its hunter_cooldown_seconds.


class FakeSpawner extends Node:
	var hunters: Array = []
	func spawn_hunter(faction: Resource) -> void:
		hunters.append(faction)


var _spawner: FakeSpawner
var _saved_spawner


func before_each() -> void:
	_saved_spawner = FactionManager._spawner
	_spawner = autofree(FakeSpawner.new())
	FactionManager._spawner = _spawner
	FactionManager._event_hunter_cooldown.clear()


func after_each() -> void:
	FactionManager._spawner = _saved_spawner
	FactionManager._event_hunter_cooldown.clear()


func test_capture_emits_both_signals_old_signature_unchanged() -> void:
	watch_signals(EmpireManager)
	EmpireManager.notify_island_captured("test_island_1", "spanish_empire")
	assert_signal_emitted_with_parameters(EmpireManager, "island_captured", ["test_island_1"])
	assert_signal_emitted_with_parameters(EmpireManager, "island_captured_from",
		["test_island_1", "spanish_empire"])


func test_capture_from_a_faction_sends_one_hunter_then_cools_down() -> void:
	EmpireManager.notify_island_captured("test_island_1", "spanish_empire")
	assert_eq(_spawner.hunters.size(), 1, "the losing faction sends a hunter")
	assert_eq((_spawner.hunters[0] as FactionData).faction_id, "spanish_empire")

	EmpireManager.notify_island_captured("test_island_2", "spanish_empire")
	assert_eq(_spawner.hunters.size(), 1, "second capture inside the cooldown sends none")

	var spain := load("res://resources/factions/SpanishEmpire.tres") as FactionData
	FactionManager._process(spain.hunter_cooldown_seconds + 0.1)
	EmpireManager.notify_island_captured("test_island_3", "spanish_empire")
	assert_eq(_spawner.hunters.size(), 2, "after the cooldown, a new capture sends another")


func test_capturing_an_unowned_island_sends_no_hunter() -> void:
	EmpireManager.notify_island_captured("neutral_island", "")
	assert_eq(_spawner.hunters.size(), 0)


func test_cooldowns_are_per_faction() -> void:
	EmpireManager.notify_island_captured("a", "spanish_empire")
	EmpireManager.notify_island_captured("b", "royal_navy")
	assert_eq(_spawner.hunters.size(), 2, "Spain's cooldown doesn't block Britain")
