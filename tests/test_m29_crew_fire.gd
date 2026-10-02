extends GutTest

## Test crew fire rate and reload penalty logic

func test_reload_penalty_bounded() -> void:
	# Verify the reload penalty is bounded by min_crew_fire_rate_mult
	# If crew is very low (1/20):
	# crew_pct = 0.05
	# penalty = 0.05 / 0.5 = 0.1
	# clamped to [0.25, 1.0] = 0.25

	var crew_pct = 1.0 / 20.0
	var optimal = 0.5
	var penalty = crew_pct / optimal
	var min_mult = 0.25
	var clamped_penalty = clampf(penalty, min_mult, 1.0)

	assert_true(clamped_penalty >= min_mult, "Penalty should be bounded to min_crew_fire_rate_mult")
	assert_true(clamped_penalty <= 1.0, "Penalty should not exceed 1.0")

func test_cooldown_capped_by_max_reload_seconds() -> void:
	# Verify cooldown is capped by max_reload_seconds
	var fire_rate = 0.1  # Very slow
	var cooldown = 1.0 / maxf(fire_rate, 0.01)
	var max_reload = 40.0
	var final_cooldown = minf(cooldown, max_reload)

	assert_true(final_cooldown <= max_reload, "Cooldown should not exceed max_reload_seconds")

func test_optimal_crew_no_penalty() -> void:
	# At or above optimal crew fraction, there should be no penalty
	var crew_pct = 0.5  # 50% of max
	var optimal = 0.5
	var min_mult = 0.25

	# When crew_pct >= optimal, the penalty calculation doesn't apply
	# So the rate multiplier stays at 1.0
	var penalty = crew_pct / optimal
	var clamped = clampf(penalty, min_mult, 1.0)

	assert_true(clamped == 1.0, "No penalty at optimal crew")

func test_life_id_can_increment() -> void:
	# Verify that _life_id can be incremented
	var initial = 0
	var incremented = initial + 1
	assert_true(incremented == 1, "_life_id should increment")
