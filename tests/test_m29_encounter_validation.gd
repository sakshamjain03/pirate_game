extends GutTest

## Test encounter validation

var _test_scene: Node = null

func before_each() -> void:
	_test_scene = Node.new()
	get_tree().root.add_child(_test_scene)

func after_each() -> void:
	if is_instance_valid(_test_scene):
		_test_scene.queue_free()

func test_validate_missing_enemy_scene() -> void:
	var manager = autofree(EncounterManager.new())

	var data = EncounterData.new()
	data.encounter_id = "test_missing_scene"
	data.enemy_scene = null

	var error = manager._validate(data)
	assert_true(error != "", "Should reject encounter with missing enemy_scene")

func test_validate_protect_target_missing_escort() -> void:
	var manager = autofree(EncounterManager.new())

	var data = EncounterData.new()
	data.encounter_id = "test_no_escort"
	data.objective = EncounterData.Objective.PROTECT_TARGET
	data.escort_scene = null
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject PROTECT_TARGET without escort")

func test_validate_survive_time_zero_limit() -> void:
	var manager = autofree(EncounterManager.new())

	var data = EncounterData.new()
	data.encounter_id = "test_zero_time"
	data.objective = EncounterData.Objective.SURVIVE_TIME
	data.time_limit = 0.0
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject SURVIVE_TIME with time_limit <= 0")

func test_validate_destroy_count_zero_target() -> void:
	var manager = autofree(EncounterManager.new())

	var data = EncounterData.new()
	data.encounter_id = "test_zero_count"
	data.objective = EncounterData.Objective.DESTROY_COUNT
	data.objective_count = 0
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject DESTROY_COUNT with target <= 0")

func test_validate_valid_encounter() -> void:
	var manager = autofree(EncounterManager.new())

	var data = EncounterData.new()
	data.encounter_id = "test_valid"
	data.objective = EncounterData.Objective.DESTROY_ALL
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error == "", "Should accept valid encounter")

func test_encounter_failed_signal_emitted() -> void:
	var manager = EncounterManager.new()
	_test_scene.add_child(manager)
	watch_signals(manager)

	var data = EncounterData.new()
	data.encounter_id = "test_signal"
	data.objective = EncounterData.Objective.SURVIVE_TIME
	data.time_limit = 0.0

	var started: bool = manager.start_encounter(data)

	assert_false(started, "Invalid encounter must not start")
	assert_false(manager.is_active(), "No encounter left active")
	assert_signal_emitted(manager, "encounter_failed")
	var params = get_signal_parameters(manager, "encounter_failed")
	assert_eq(params[0] if params else "", "test_signal", "Signal carries encounter_id")
