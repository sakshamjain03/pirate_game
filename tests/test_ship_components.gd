extends GutTest

# test_ship_components.gd — M23 Requirement 3: Clash-of-Clans-style component
# upgrades gated by ship level.

var _saved_resources: Dictionary
var _saved_ships: Array
var _saved_active: int


func before_each():
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_active = FleetManager.active_ship_index
	ResourceManager.current_resources["gold"] = 1000000
	ResourceManager.current_resources["wood"] = 1000000
	ResourceManager.current_resources["iron"] = 1000000


func after_each():
	ResourceManager.current_resources = _saved_resources
	FleetManager.owned_ships.clear()
	for o in _saved_ships:
		FleetManager.owned_ships.append(o)
	FleetManager.active_ship_index = _saved_active


func _fresh(path: String = "res://resources/ships/Sloop.tres") -> OwnedShipData:
	var o := OwnedShipData.new()
	o.ship_stats = load(path)
	return o


func _install(o: OwnedShipData) -> int:
	FleetManager.owned_ships.clear()
	FleetManager.owned_ships.append(o)
	FleetManager.active_ship_index = 0
	return 0


func test_catalog_has_the_five_parts():
	var cat := OwnedShipData.get_component_catalog()
	assert_not_null(cat)
	for id in ["hull", "bow", "stern", "sails", "cannons"]:
		assert_not_null(cat.get_component(id), "missing component '%s'" % id)


func test_new_hull_starts_every_part_at_level_one():
	var o := _fresh()
	for id in OwnedShipData.get_component_catalog().get_ids():
		assert_eq(o.get_component_level(id), 1)


func test_a_part_cannot_out_level_the_ship():
	var o := _fresh()
	assert_false(o.can_upgrade_component("hull"), "at ship Lv1 a part is already at its cap")
	var idx := _install(o)
	assert_false(FleetManager.upgrade_component(idx, "hull"))
	assert_eq(o.get_component_level("hull"), 1)


func test_ship_level_up_requires_every_part_to_catch_up():
	var o := _fresh()
	var idx := _install(o)
	assert_true(FleetManager.level_up_ship(idx), "Lv1 -> Lv2 is open: all parts are at Lv1")
	assert_eq(o.level, 2)
	assert_false(FleetManager.level_up_ship(idx), "Lv2 -> Lv3 blocked until the parts reach Lv2")
	for id in OwnedShipData.get_component_catalog().get_ids():
		assert_true(FleetManager.upgrade_component(idx, id), "upgrading '%s' to the cap" % id)
	assert_eq(o.get_components_below_level().size(), 0)
	assert_true(FleetManager.level_up_ship(idx), "all parts caught up — the ship may level")
	assert_eq(o.level, 3)


func test_component_upgrade_spends_its_authored_cost():
	var o := _fresh()
	o.level = 2
	var idx := _install(o)
	var cost := o.get_component_upgrade_cost("cannons")
	assert_gt(int(cost.get("gold", 0)), 0)
	var gold_before := int(ResourceManager.current_resources["gold"])
	assert_true(FleetManager.upgrade_component(idx, "cannons"))
	assert_eq(int(ResourceManager.current_resources["gold"]), gold_before - int(cost["gold"]))


func test_component_upgrade_refused_when_unaffordable():
	var o := _fresh()
	o.level = 2
	var idx := _install(o)
	ResourceManager.current_resources["gold"] = 0
	assert_false(FleetManager.upgrade_component(idx, "hull"))
	assert_eq(o.get_component_level("hull"), 1)


func test_components_apply_to_effective_stats_without_touching_the_template():
	var o := _fresh()
	var template := o.ship_stats
	var hp := template.max_health
	var ram := template.ram_damage_mult
	o.level = 5
	o.component_levels["hull"] = 5
	o.component_levels["bow"] = 5
	var eff := o.get_effective_stats()
	assert_eq(template.max_health, hp, "template untouched")
	assert_eq(template.ram_damage_mult, ram, "template untouched")
	assert_gt(eff.impact_resistance, 1.0)
	assert_gt(eff.ram_damage_mult, 1.0)


func test_cannons_part_adds_guns_at_its_authored_levels():
	var o := _fresh()
	o.level = 5
	var base := o.get_effective_stats().cannons_per_side
	o.component_levels["cannons"] = 3
	var at3 := o.get_effective_stats().cannons_per_side
	o.component_levels["cannons"] = 5
	var at5 := o.get_effective_stats().cannons_per_side
	assert_eq(at3, max(base, 3) + 1 if base > 0 else 4, "one extra gun per side at cannons Lv3")
	assert_eq(at5, at3 + 1, "another at Lv5")


func test_save_round_trip_keeps_component_levels():
	var o := _fresh()
	o.level = 4
	o.component_levels["sails"] = 3
	o.component_levels["hull"] = 4
	var restored := OwnedShipData.from_save_data(o.get_save_data())
	assert_eq(restored.level, 4)
	assert_eq(restored.get_component_level("sails"), 3)
	assert_eq(restored.get_component_level("hull"), 4)


func test_legacy_save_without_components_starts_parts_at_ship_level():
	var legacy := {"ship_path": "res://resources/ships/Sloop.tres", "level": 3, "modules": []}
	var restored := OwnedShipData.from_save_data(legacy)
	for id in OwnedShipData.get_component_catalog().get_ids():
		assert_eq(restored.get_component_level(id), 3, "'%s' must migrate to the saved ship level" % id)
	assert_true(restored.can_level_up_ship(), "a migrated ship isn't stuck behind catch-up upgrades")


func test_saved_component_levels_are_clamped_to_the_ship_level():
	var data := {"ship_path": "res://resources/ships/Sloop.tres", "level": 2, "modules": [],
		"components": {"hull": 9}}
	var restored := OwnedShipData.from_save_data(data)
	assert_eq(restored.get_component_level("hull"), 2)


func test_max_level_is_ten():
	assert_eq(OwnedShipData.MAX_LEVEL, 10)
