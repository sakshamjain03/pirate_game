extends GutTest
## M30 Wave 0 (0.15, B8): one shared battle-upgrade roll. EncounterManager and
## MaelstromRun each carried a private copy of the weighted no-replacement
## loop; both now call UpgradeRoller.roll(), so Wave 5's tags/keystones land
## once. Pins the contract both callers relied on.


func _upgrade(id: String, weight: float = 1.0, max_stacks: int = 1) -> BattleUpgradeData:
	var u := BattleUpgradeData.new()
	u.upgrade_id = id
	u.display_name = id
	u.weight = weight
	u.effect = BattleUpgradeData.Effect.DAMAGE
	u.magnitude = 1.1
	u.max_stacks = max_stacks
	return u


func test_returns_count_without_duplicates() -> void:
	var result := UpgradeRoller.roll([_upgrade("a"), _upgrade("b"), _upgrade("c")], 3)
	assert_eq(result.size(), 3)
	var ids := {}
	for u in result:
		ids[u.upgrade_id] = true
	assert_eq(ids.size(), 3, "an offer never repeats an upgrade")


func test_short_pool_returns_what_it_has() -> void:
	assert_eq(UpgradeRoller.roll([_upgrade("a")], 3).size(), 1)


func test_never_offers_a_maxed_upgrade() -> void:
	var mods := CombatModifiers.new()
	add_child_autofree(mods)
	var maxed := _upgrade("maxed", 100.0, 1)
	mods.apply_upgrade(maxed)
	var result := UpgradeRoller.roll([maxed, _upgrade("fresh")], 2, mods)
	assert_eq(result.size(), 1)
	assert_eq(result[0].upgrade_id, "fresh")


func test_seeded_rng_is_deterministic() -> void:
	var pool := [_upgrade("a"), _upgrade("b"), _upgrade("c"), _upgrade("d")]
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var first := UpgradeRoller.roll(pool, 2, null, r1).map(func(u): return u.upgrade_id)
	var second := UpgradeRoller.roll(pool, 2, null, r2).map(func(u): return u.upgrade_id)
	assert_eq(first, second)


func test_weight_biases_the_pick() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool := [_upgrade("common", 20.0), _upgrade("rare", 1.0)]
	var common := 0
	for i in 200:
		if UpgradeRoller.roll(pool, 1, null, rng)[0].upgrade_id == "common":
			common += 1
	assert_gt(common, 170, "a 20:1 weight should win ~95% of single picks")


func test_zero_weight_is_never_picked() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 50:
		var r := UpgradeRoller.roll([_upgrade("never", 0.0), _upgrade("always", 1.0)], 1, null, rng)
		assert_eq(r[0].upgrade_id, "always")


func test_both_callers_use_the_shared_roll() -> void:
	# Same seed, same pool: a caller with its own private loop would drift.
	var pool: Array[BattleUpgradeData] = [_upgrade("a"), _upgrade("b"), _upgrade("c")]
	var em: Node = load("res://scripts/combat/EncounterManager.gd").new()
	em.upgrade_pool = pool
	seed(99)
	var via_encounter: Array = em.roll_upgrade_choices(2).map(func(u): return u.upgrade_id)
	seed(99)
	var via_roller: Array = UpgradeRoller.roll(pool, 2).map(func(u): return u.upgrade_id)
	em.free()
	assert_eq(via_encounter, via_roller)
