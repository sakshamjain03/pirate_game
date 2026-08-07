extends GutTest

# test_resource_manager.gd
# Property-based tests for ResourceManager (D12 coverage: Economy).
# ResourceManager is a real autoload; every test saves/restores its mutable
# state so tests never leak values into each other or into later suites.

var _saved_resources: Dictionary
var _saved_storage: Dictionary

func before_each():
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_storage = ResourceManager.max_storage.duplicate()

func after_each():
	ResourceManager.current_resources = _saved_resources.duplicate()
	ResourceManager.max_storage = _saved_storage.duplicate()

func test_add_resource_increases_and_clamps_to_storage_cap():
	var iterations = 30
	for i in range(iterations):
		ResourceManager.current_resources["wood"] = 0
		ResourceManager.max_storage["wood"] = 200
		var amount = randi_range(1, 500)
		ResourceManager.add_resource("wood", amount)
		var expected = min(amount, 200)
		assert_eq(ResourceManager.get_resource("wood"), expected,
			"wood must be clamped to max_storage after adding %d" % amount)

func test_add_resource_ignores_non_positive_amounts():
	ResourceManager.current_resources["gold"] = 100
	ResourceManager.add_resource("gold", 0)
	assert_eq(ResourceManager.get_resource("gold"), 100, "add_resource(0) must be a no-op")
	ResourceManager.add_resource("gold", -50)
	assert_eq(ResourceManager.get_resource("gold"), 100, "add_resource(negative) must be a no-op")

func test_add_resource_is_case_insensitive():
	ResourceManager.current_resources["gold"] = 0
	ResourceManager.add_resource("GOLD", 10)
	assert_eq(ResourceManager.get_resource("gold"), 10, "resource type keys must be case-insensitive")

func test_spend_resource_success_and_failure():
	ResourceManager.current_resources["iron"] = 20
	var ok = ResourceManager.spend_resource("iron", 15)
	assert_true(ok, "spend_resource must succeed when enough is stored")
	assert_eq(ResourceManager.get_resource("iron"), 5)

	var fail = ResourceManager.spend_resource("iron", 999)
	assert_false(fail, "spend_resource must fail when not enough is stored")
	assert_eq(ResourceManager.get_resource("iron"), 5, "a failed spend must not change the balance")

func test_spend_resource_zero_or_negative_is_free_noop():
	ResourceManager.current_resources["iron"] = 20
	assert_true(ResourceManager.spend_resource("iron", 0), "spending 0 always succeeds")
	assert_true(ResourceManager.spend_resource("iron", -5), "spending a negative amount always succeeds")
	assert_eq(ResourceManager.get_resource("iron"), 20, "balance must be unchanged")

func test_can_afford_matches_get_resource():
	ResourceManager.current_resources = {"gold": 100, "wood": 10, "iron": 5, "rum": 0, "research": 0}
	assert_true(ResourceManager.can_afford({"gold": 100, "wood": 10}), "affordable at exact balance")
	assert_true(ResourceManager.can_afford({"gold": 50}), "affordable below balance")
	assert_false(ResourceManager.can_afford({"gold": 101}), "not affordable above balance")
	assert_false(ResourceManager.can_afford({"iron": 6}), "not affordable above balance for a second resource")

func test_spend_resources_is_all_or_nothing():
	ResourceManager.current_resources = {"gold": 100, "wood": 10, "iron": 5, "rum": 0, "research": 0}
	var before = ResourceManager.current_resources.duplicate()

	var ok = ResourceManager.spend_resources({"gold": 500, "wood": 5})
	assert_false(ok, "spend_resources must fail if any single resource is unaffordable")
	assert_eq(ResourceManager.get_resource("wood"), before["wood"],
		"an affordable resource in a failed multi-cost spend must not be partially deducted")
	assert_eq(ResourceManager.get_resource("gold"), before["gold"])

	var ok2 = ResourceManager.spend_resources({"gold": 50, "wood": 5})
	assert_true(ok2, "spend_resources must succeed when every resource is affordable")
	assert_eq(ResourceManager.get_resource("gold"), 50)
	assert_eq(ResourceManager.get_resource("wood"), 5)

func test_resources_changed_signal_emitted_on_add_and_spend():
	ResourceManager.current_resources["gold"] = 100
	watch_signals(ResourceManager)

	ResourceManager.add_resource("gold", 10)
	assert_signal_emitted(ResourceManager, "resources_changed")

	ResourceManager.spend_resource("gold", 10)
	assert_signal_emit_count(ResourceManager, "resources_changed", 2,
		"resources_changed must fire once per add and once per spend")

func test_save_load_round_trip():
	var iterations = 20
	for i in range(iterations):
		var data = {
			"gold": randi_range(0, 5000),
			"wood": randi_range(0, 200),
			"iron": randi_range(0, 100),
			"rum": randi_range(0, 50),
			"research": randi_range(0, 999),
		}
		ResourceManager.load_save_data(data)
		var saved = ResourceManager.get_save_data()
		for key in data.keys():
			assert_eq(saved[key], data[key],
				"resource '%s' must round-trip exactly through save/load" % key)
