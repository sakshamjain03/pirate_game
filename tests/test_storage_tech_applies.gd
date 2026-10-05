extends GutTest

## Storage techs scale the basic resource caps, and saved overflow above base
## caps (Warehouses, storage techs) survives a load.

var _saved_resources: Dictionary
var _saved_techs: Array

func before_each():
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_techs = TechManager.unlocked_techs.duplicate()
	TechManager.unlocked_techs.clear()
	TechManager._recalculate_modifiers()

func after_each():
	TechManager.unlocked_techs = _saved_techs.duplicate()
	TechManager._recalculate_modifiers()
	ResourceManager.current_resources = _saved_resources.duplicate()
	ResourceManager.recalculate_storage_capacity()

func test_larger_storage_raises_basic_caps_only():
	ResourceManager.recalculate_storage_capacity()
	var base: Dictionary = ResourceManager.max_storage.duplicate()
	var tech: TechData = load("res://resources/techs/LargerStorage.tres")

	TechManager.unlock_tech(tech)

	for t in ["gold", "wood", "iron", "rum"]:
		assert_eq(ResourceManager.max_storage[t], int(base[t] * tech.storage_modifier),
			"%s cap scales by the tech's storage_modifier" % t)
	assert_eq(ResourceManager.max_storage["research"], base["research"], "research cap unchanged")
	assert_eq(ResourceManager.max_storage["eights"], base["eights"], "eights cap unchanged")

func test_bulk_load_keeps_overflow_until_caps_are_restored():
	ResourceManager.recalculate_storage_capacity()  # base caps, as on a fresh launch
	var tech: TechData = load("res://resources/techs/LargerStorage.tres")
	var saved_gold := 6000  # above base 5000, within the tech's 6250

	ResourceManager.begin_bulk_load()
	ResourceManager.load_save_data({"gold": saved_gold})
	TechManager.load_save_data({"unlocked": [tech.resource_path]})
	ResourceManager.end_bulk_load()

	assert_eq(ResourceManager.get_resource("gold"), saved_gold, "saved overflow must survive the load")

func test_end_bulk_load_still_clamps_to_final_caps():
	ResourceManager.recalculate_storage_capacity()
	ResourceManager.begin_bulk_load()
	ResourceManager.load_save_data({"gold": 999999})
	ResourceManager.end_bulk_load()
	assert_eq(ResourceManager.get_resource("gold"), ResourceManager.max_storage["gold"])
