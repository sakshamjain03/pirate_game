extends GutTest

## M27 Task 2 — EconomyPricingData (Requirements 2.5, 3.1-3.3). AGENTS.md: "Every
## timer must also be reducible by playing" — every job kind has a speed source
## and playing (a higher level) strictly shortens it.

const PRICING_PATH := "res://resources/balance/EconomyPricing.tres"
const EconomyPricingScript := preload("res://scripts/world/EconomyPricingData.gd")

var _pricing: EconomyPricingScript


func before_all() -> void:
	_pricing = load(PRICING_PATH) as EconomyPricingScript


func _tres_in(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	assert_not_null(dir, "%s exists" % dir_path)
	if not dir:
		return result
	for file in dir.get_files():
		if file.ends_with(".tres"):
			result.append(load(dir_path.path_join(file)))
	return result


## Speed-source levels each kind can actually reach, lowest first.
func _levels_for(kind: String) -> Array:
	if kind in ["build", "upgrade"]:
		return range(1, _pricing.build_speed_by_island_tier.size() + 1)   # island tier 1..5
	return range(0, _pricing.speed_multipliers_for(kind).size())          # 0 = no building


func test_authored_pricing_loads() -> void:
	assert_not_null(_pricing)
	assert_gt(_pricing.seconds_per_eight, 0.0)
	assert_false(_pricing.shortfall_rates.has("eights"), "Eights is never a shortfall resource")


func test_every_timed_job_kind_has_a_speed_source() -> void:
	for kind in ScheduleManager.KINDS:
		assert_gt(_pricing.speed_multipliers_for(kind).size(), 1, "'%s' has a speed source with more than one level" % kind)


func test_effective_duration_strictly_decreases_with_level_for_every_kind() -> void:
	for kind in ScheduleManager.KINDS:
		var previous := INF
		for level in _levels_for(kind):
			var d := _pricing.effective_duration(kind, 600.0, level)
			assert_lt(d, previous, "'%s' at level %d is faster than the level below" % [kind, level])
			assert_gt(d, 0.0, "a speed source never makes a timed job instant")
			previous = d


func test_zero_base_is_instant_at_every_level() -> void:
	for kind in ScheduleManager.KINDS:
		for level in _levels_for(kind):
			assert_eq(_pricing.effective_duration(kind, 0.0, level), 0.0)


func test_levels_past_the_table_clamp() -> void:
	var top := _pricing.effective_duration("research", 600.0, _pricing.research_speed_by_academy_level.size() - 1)
	assert_eq(_pricing.effective_duration("research", 600.0, 99), top)
	assert_eq(_pricing.effective_duration("build", 600.0, 0), _pricing.effective_duration("build", 600.0, 1))


func test_finish_cost_is_at_least_one_while_time_remains() -> void:
	assert_eq(_pricing.finish_cost(0.0), 0)
	assert_eq(_pricing.finish_cost(0.5), 1)
	assert_eq(_pricing.finish_cost(_pricing.seconds_per_eight), 1)
	assert_eq(_pricing.finish_cost(_pricing.seconds_per_eight + 1.0), 2)


func test_existing_content_loads_with_its_duration_field() -> void:
	# A duration export the .tres doesn't set must read as a number, never fail
	# silently to null (docs/05 D3/D14's class of bug).
	for b in _tres_in("res://resources/buildings"):
		assert_true(b is BuildingData and b.build_seconds >= 0.0, "%s has build_seconds" % b.resource_path)
	for t in _tres_in("res://resources/techs"):
		assert_true(t is TechData and t.research_seconds >= 0.0, "%s has research_seconds" % t.resource_path)
	for s in _tres_in("res://resources/ships"):
		assert_true(s is ShipStats and s.build_seconds >= 0.0, "%s has build_seconds" % s.resource_path)


func test_durations_default_to_instant() -> void:
	assert_eq(BuildingData.new().build_seconds, 0.0)
	assert_eq(TechData.new().research_seconds, 0.0)
	assert_eq(ShipStats.new().build_seconds, 0.0)
