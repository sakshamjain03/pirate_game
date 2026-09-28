extends GutTest

## Guards M26's MaelstromCurveData — the one authored source of a Maelstrom run's
## escalation, level thresholds and Eights reward (Requirements 3.1, 5.1, 6.2).

const CURVE_PATH := "res://resources/balance/MaelstromCurve.tres"

var _curve: MaelstromCurveData


func before_all() -> void:
	_curve = load(CURVE_PATH) as MaelstromCurveData


func _band(start: float) -> MaelstromBandData:
	var b := MaelstromBandData.new()
	b.start_seconds = start
	return b


func _synthetic() -> MaelstromCurveData:
	var c := MaelstromCurveData.new()
	c.bands = [_band(0.0), _band(60.0), _band(150.0)]
	c.xp_per_level = [4, 6, 9]
	c.eights_milestones = [Vector2i(120, 2), Vector2i(300, 4), Vector2i(480, 6)]
	c.eights_cap_per_run = 10
	return c


func test_authored_curve_loads_with_bands_levels_and_milestones() -> void:
	assert_not_null(_curve, "MaelstromCurve.tres should load as MaelstromCurveData")
	assert_gt(_curve.bands.size(), 0, "curve must author bands")
	assert_gt(_curve.xp_per_level.size(), 0, "curve must author xp_per_level")
	assert_gt(_curve.eights_milestones.size(), 0, "curve must author Eights milestones")
	assert_gt(_curve.drops.size(), 0, "curve must author a drop table")
	assert_gt(_curve.upgrade_pool.size(), 0, "curve must author an upgrade pool")
	for u in _curve.upgrade_pool:
		assert_true(u is BattleUpgradeData, "every pool entry is a BattleUpgradeData")


func test_authored_bands_are_sorted_and_start_at_zero() -> void:
	assert_eq(_curve.bands[0].start_seconds, 0.0, "first band must start at 0 s")
	for i in range(_curve.bands.size() - 1):
		assert_lt(_curve.bands[i].start_seconds, _curve.bands[i + 1].start_seconds,
			"bands must be strictly increasing by start_seconds (index %d)" % i)


func test_authored_bands_escalate() -> void:
	# The design's promise: pressure only ever climbs.
	for i in range(_curve.bands.size() - 1):
		var a: MaelstromBandData = _curve.bands[i]
		var b: MaelstromBandData = _curve.bands[i + 1]
		assert_true(b.max_enemies >= a.max_enemies, "cap never drops (band %d)" % (i + 1))
		assert_true(b.spawn_interval <= a.spawn_interval, "interval never grows (band %d)" % (i + 1))
		assert_true(b.strength_multiplier >= a.strength_multiplier, "strength never drops (band %d)" % (i + 1))


func test_authored_boss_is_an_existing_scene() -> void:
	var bosses := 0
	for b in _curve.bands:
		if b.boss_scene:
			bosses += 1
			assert_true(b.boss_scene.can_instantiate(), "boss scene must instantiate")
	assert_gt(bosses, 0, "curve authors at least one boss band")


func test_band_at_boundaries() -> void:
	var c := _synthetic()
	assert_eq(c.band_at(0.0), c.bands[0])
	assert_eq(c.band_at(59.9), c.bands[0])
	assert_eq(c.band_at(60.0), c.bands[1], "a band starts exactly at its start_seconds")
	assert_eq(c.band_at(149.0), c.bands[1])
	assert_eq(c.band_at(99999.0), c.bands[2], "past the last band stays in the last band")
	assert_eq(c.band_at(-5.0), c.bands[0], "before 0 falls back to the first band")
	assert_eq(c.band_index_at(150.0), 2)


func test_xp_for_level_repeats_last_value() -> void:
	var c := _synthetic()
	assert_eq(c.xp_for_level(1), 4)
	assert_eq(c.xp_for_level(2), 6)
	assert_eq(c.xp_for_level(3), 9)
	assert_eq(c.xp_for_level(4), 9, "past the table the last value repeats")
	assert_eq(c.xp_for_level(50), 9)


func test_eights_for_sums_reached_milestones() -> void:
	var c := _synthetic()
	assert_eq(c.eights_for(0.0), 0)
	assert_eq(c.eights_for(119.9), 0)
	assert_eq(c.eights_for(120.0), 2)
	assert_eq(c.eights_for(300.0), 6)


func test_eights_for_respects_cap() -> void:
	var c := _synthetic()
	assert_eq(c.eights_for(10000.0), 10, "2+4+6=12 is clamped to the per-run cap of 10")


func test_authored_eights_never_exceed_cap() -> void:
	assert_true(_curve.eights_for(1.0e9) <= _curve.eights_cap_per_run)
