extends GutTest

# test_m30_upgrade_roller.gd
# Task 0.15: Shared UpgradeRoller produces same distribution for both callers

func _make_upgrade(id: String, weight: float = 1.0) -> BattleUpgradeData:
	var u = BattleUpgradeData.new()
	u.upgrade_id = id
	u.display_name = id
	u.weight = weight
	u.effect = BattleUpgradeData.Effect.DAMAGE
	u.magnitude = 1.1
	u.max_stacks = 1
	return u


func test_upgrade_roller_returns_count():
	var pool = [
		_make_upgrade("u1"),
		_make_upgrade("u2"),
		_make_upgrade("u3"),
	]

	var result = UpgradeRoller.roll(pool, 2)
	assert_eq(result.size(), 2, "Should return exactly count upgrades")

	# No duplicates
	assert_ne(result[0].upgrade_id, result[1].upgrade_id, "Should not duplicate")


func test_upgrade_roller_respects_pool_size():
	var pool = [_make_upgrade("u1")]

	var result = UpgradeRoller.roll(pool, 3)
	assert_eq(result.size(), 1, "Should return at most pool size")


func test_upgrade_roller_weighted_distribution():
	# With heavy weight imbalance, verify weighting works
	var pool = [
		_make_upgrade("common", 10.0),
		_make_upgrade("rare", 1.0),
	]

	var seeded_rng = RandomNumberGenerator.new()
	seeded_rng.seed = 12345

	# Sample multiple times and count occurrences
	var counts = {"common": 0, "rare": 0}
	for i in range(100):
		seed(12345 + i)  # Different seed each iteration
		var result = UpgradeRoller.roll(pool, 1)
		if result.size() > 0:
			counts[result[0].upgrade_id] += 1

	# Common should appear much more often (roughly 10:1 ratio)
	assert_gt(counts["common"], counts["rare"],
		"Higher weight should appear more often")


func test_upgrade_roller_filters():
	var pool = [
		_make_upgrade("u1"),
		_make_upgrade("u2"),
		_make_upgrade("u3"),
	]

	# Filter to only include upgrades with ID containing "2"
	var filters = [func(u): return "2" in u.upgrade_id]

	var result = UpgradeRoller.roll(pool, 2, {}, filters)
	assert_eq(result.size(), 1, "Should only return matching upgrades")
	assert_eq(result[0].upgrade_id, "u2")
