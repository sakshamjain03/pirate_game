extends GutTest

## Test encounter validation

var _test_scene: Node = null

func setup() -> void:
	_test_scene = Node.new()
	get_tree().root.add_child(_test_scene)

func teardown() -> void:
	if is_instance_valid(_test_scene):
		_test_scene.queue_free()

func test_validate_missing_enemy_scene() -> void:
	var manager = EncounterManager.new()

	var data = EncounterData.new()
	data.encounter_id = "test_missing_scene"
	data.enemy_scene = null

	var error = manager._validate(data)
	assert_true(error != "", "Should reject encounter with missing enemy_scene")

func test_validate_protect_target_missing_escort() -> void:
	var manager = EncounterManager.new()

	var data = EncounterData.new()
	data.encounter_id = "test_no_escort"
	data.objective = EncounterData.Objective.PROTECT_TARGET
	data.escort_scene = null
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject PROTECT_TARGET without escort")

func test_validate_survive_time_zero_limit() -> void:
	var manager = EncounterManager.new()

	var data = EncounterData.new()
	data.encounter_id = "test_zero_time"
	data.objective = EncounterData.Objective.SURVIVE_TIME
	data.time_limit = 0.0
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject SURVIVE_TIME with time_limit <= 0")

func test_validate_destroy_count_zero_target() -> void:
	var manager = EncounterManager.new()

	var data = EncounterData.new()
	data.encounter_id = "test_zero_count"
	data.objective = EncounterData.Objective.DESTROY_COUNT
	data.objective_count = 0
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error != "", "Should reject DESTROY_COUNT with target <= 0")

func test_validate_valid_encounter() -> void:
	var manager = EncounterManager.new()

	var data = EncounterData.new()
	data.encounter_id = "test_valid"
	data.objective = EncounterData.Objective.DESTROY_ALL
	data.enemy_scene = load("res://scenes/world/EnemyShip.tscn")

	var error = manager._validate(data)
	assert_true(error == "", "Should accept valid encounter")

func test_encounter_failed_signal_emitted() -> void:
	var manager = EncounterManager.new()
	_test_scene.add_child(manager)

	var signal_emitted = false
	var signal_encounter_id = ""
	var signal_reason = ""

	manager.encounter_failed.connect(func(id, reason):
		signal_emitted = true
		signal_encounter_id = id
		signal_reason = reason
	)

	# Create an invalid encounter
	var data = EncounterData.new()
	data.encounter_id = "test_signal"
	data.objective = EncounterData.Objective.SURVIVE_TIME
	data.time_limit = 0.0
	data.enemy_scene = null

	manager.start_encounter(data)

	# Signal should have been emitted
	assert_true(signal_emitted, "encounter_failed signal should be emitted on validation failure")
	assert_true(signal_encounter_id == data.encounter_id, "Signal should carry encounter_id")
