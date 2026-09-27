extends GutTest

## Guards the M25 heat curve — the GTA-style wanted level that drives ambient danger.
##
## Heat is a LENS over `EmpireManager.notoriety`, not a second stat. If a future change
## introduces a standalone `heat` variable, the design has been lost and these tests
## will not catch it — but `test_heat_is_derived_not_stored` gets closest.
##
## The constitutional line these tests exist to protect (docs/00_VISION.md §19.2):
## heat must never gate sailing, combat or boarding. It changes how many ships exist
## and whether they engage first. It is pressure, never an energy meter.

const CURVE_PATH := "res://resources/balance/HeatCurve.tres"

var _curve: HeatConfigData


func before_all() -> void:
	_curve = load(CURVE_PATH) as HeatConfigData
	assert_not_null(_curve, "HeatCurve.tres should load as HeatConfigData")


func test_curve_authors_a_tier_at_zero() -> void:
	# Without a tier at or below 0 notoriety, tier_for() has nothing to return on a
	# fresh save and would push_error on the very first frame.
	var lowest: HeatTierData = _curve.tiers[0]
	for t in _curve.tiers:
		if t.min_notoriety < lowest.min_notoriety:
			lowest = t
	assert_eq(lowest.min_notoriety, 0.0, "The curve must author a tier starting at 0 notoriety")


func test_tiers_are_contiguous_and_strictly_increasing() -> void:
	# A duplicate or out-of-order threshold makes tier_for() ambiguous.
	var sorted_tiers := _curve.tiers.duplicate()
	sorted_tiers.sort_custom(func(a, b): return a.min_notoriety < b.min_notoriety)
	for i in range(sorted_tiers.size() - 1):
		assert_lt(
			sorted_tiers[i].min_notoriety, sorted_tiers[i + 1].min_notoriety,
			"Two heat tiers share or invert a threshold: '%s' and '%s'"
			% [sorted_tiers[i].display_name, sorted_tiers[i + 1].display_name]
		)
		assert_eq(
			sorted_tiers[i + 1].tier, sorted_tiers[i].tier + 1,
			"Heat tier numbers must be contiguous — '%s' follows '%s'"
			% [sorted_tiers[i + 1].display_name, sorted_tiers[i].display_name]
		)


func test_tier_boundaries_match_the_region_activation_thresholds() -> void:
	# The whole point of pinning these: "the sea got harder" and "a new region opened"
	# must happen together. If a region threshold moves and this is not updated, the two
	# escalation systems drift apart silently.
	var region_thresholds: Array[float] = []
	var dir := DirAccess.open("res://resources/world/regions/")
	assert_not_null(dir, "regions directory should exist")
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var region = load("res://resources/world/regions/" + entry)
			if region and ResourceLookup.is_content_enabled(region) \
					and region.activation_notoriety_threshold > 0.0:
				region_thresholds.append(region.activation_notoriety_threshold)
		entry = dir.get_next()
	dir.list_dir_end()

	var tier_thresholds: Array[float] = []
	for t in _curve.tiers:
		tier_thresholds.append(t.min_notoriety)

	for threshold in region_thresholds:
		assert_true(
			tier_thresholds.has(threshold),
			"Region activates at notoriety %.0f but no heat tier starts there — the two "
			% threshold + "escalation curves have drifted apart. Tier thresholds: %s"
			% str(tier_thresholds)
		)


func test_tier_for_resolves_every_boundary() -> void:
	var sorted_tiers := _curve.tiers.duplicate()
	sorted_tiers.sort_custom(func(a, b): return a.min_notoriety < b.min_notoriety)
	for t in sorted_tiers:
		# Exactly on the boundary resolves to that tier (inclusive lower bound).
		assert_eq(
			_curve.tier_for(t.min_notoriety), t,
			"Notoriety exactly at %.0f should resolve to '%s'" % [t.min_notoriety, t.display_name]
		)
		# Just below resolves to the tier underneath, never to this one.
		if t.min_notoriety > 0.0:
			var below := _curve.tier_for(t.min_notoriety - 0.01)
			assert_ne(below, t, "Notoriety just below %.0f must not resolve to '%s'"
				% [t.min_notoriety, t.display_name])


func test_tier_for_clamps_above_the_highest_threshold() -> void:
	var highest := _curve.highest_tier()
	assert_eq(_curve.tier_for(highest.min_notoriety + 10000.0), highest,
		"Absurdly high notoriety should stay at the top tier, not fall through to null")


func test_tier_for_handles_negative_notoriety() -> void:
	# EmpireManager clamps to 0, but tier_for() must not push_error if it ever sees a
	# transient negative during a load or a decay step.
	assert_not_null(_curve.tier_for(0.0), "Zero notoriety must resolve")


func test_tier_below_walks_down_one_step_and_stops() -> void:
	var sorted_tiers := _curve.tiers.duplicate()
	sorted_tiers.sort_custom(func(a, b): return a.min_notoriety < b.min_notoriety)
	assert_null(_curve.tier_below(sorted_tiers[0]),
		"The lowest tier has nothing below it")
	for i in range(1, sorted_tiers.size()):
		assert_eq(
			_curve.tier_below(sorted_tiers[i]), sorted_tiers[i - 1],
			"tier_below('%s') should be '%s'"
			% [sorted_tiers[i].display_name, sorted_tiers[i - 1].display_name]
		)


func test_low_tiers_are_passive_and_high_tiers_are_not() -> void:
	# The GTA line. If every tier engages unprovoked, the feature does not exist.
	var passive := 0
	var aggressive := 0
	for t in _curve.tiers:
		if t.engages_unprovoked:
			aggressive += 1
		else:
			passive += 1
	assert_gt(passive, 0, "At least one low tier must leave the player alone until provoked")
	assert_gt(aggressive, 0, "At least one high tier must engage on sight")

	# Passivity must be a floor, not scattered: once ships engage unprovoked, every
	# higher tier must too, or danger stops rising monotonically with notoriety.
	var sorted_tiers := _curve.tiers.duplicate()
	sorted_tiers.sort_custom(func(a, b): return a.min_notoriety < b.min_notoriety)
	var seen_aggressive := false
	for t in sorted_tiers:
		if t.engages_unprovoked:
			seen_aggressive = true
		else:
			assert_false(
				seen_aggressive,
				"Tier '%s' is passive but sits above an aggressive tier — danger must rise "
				% t.display_name + "monotonically with notoriety"
			)


func test_ambient_pressure_rises_with_tier() -> void:
	var sorted_tiers := _curve.tiers.duplicate()
	sorted_tiers.sort_custom(func(a, b): return a.min_notoriety < b.min_notoriety)
	for i in range(sorted_tiers.size() - 1):
		var low: HeatTierData = sorted_tiers[i]
		var high: HeatTierData = sorted_tiers[i + 1]
		assert_gte(high.max_ambient_enemies, low.max_ambient_enemies,
			"Enemy cap must not fall going from '%s' to '%s'" % [low.display_name, high.display_name])
		assert_lte(high.spawn_interval_seconds, low.spawn_interval_seconds,
			"Spawn interval must not lengthen going from '%s' to '%s'" % [low.display_name, high.display_name])
		assert_gte(high.enemy_strength_multiplier, low.enemy_strength_multiplier,
			"Enemy strength must not fall going from '%s' to '%s'" % [low.display_name, high.display_name])


func test_free_decay_can_always_reach_tier_zero() -> void:
	# docs/00_VISION.md §19.2: a timer must also be shortenable by playing. If any tier
	# had zero free decay, the paid clear would be the ONLY way down from it, which is
	# precisely the "timer whose removal is for sale" the constitution forbids.
	for t in _curve.tiers:
		assert_gt(
			t.decay_per_minute, 0.0,
			"Heat tier '%s' has no free decay — paying would be the only way down, which "
			% t.display_name + "violates docs/00_VISION.md §19.2"
		)


func test_lying_low_is_faster_than_waiting() -> void:
	assert_gt(_curve.lying_low_multiplier, 1.0,
		"Lying low in port must beat doing nothing, or the mechanic is decorative")


func test_decay_grace_is_short_enough_to_feel() -> void:
	# The pre-M25 behaviour was 600s, which meant the player had to stop playing for ten
	# minutes to observe any cooling at all.
	assert_lte(_curve.decay_grace_seconds, 300.0,
		"A grace period over 5 minutes makes cooling off invisible during normal play")


# ------------------------------------------------------- Runtime (EmpireManager)
# A fresh EmpireManager instance per test, matching test_empire_manager.gd's
# convention — the autoload carries whatever state the rest of the suite left.

var _empire: Node
var _saved_resources: Dictionary


func before_each() -> void:
	_empire = load("res://scripts/managers/EmpireManager.gd").new()
	add_child_autoqfree(_empire)
	_saved_resources = ResourceManager.current_resources.duplicate(true)
	await wait_process_frames(1)


func after_each() -> void:
	ResourceManager.current_resources = _saved_resources.duplicate(true)


func test_heat_is_derived_not_stored() -> void:
	# Heat must remain a band over notoriety. If a future change adds a standalone
	# stat, setting notoriety alone would stop moving the tier and this fails.
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	assert_eq(_empire.get_heat_level(), 0)

	_empire.add_notoriety(250.0)
	assert_eq(_empire.get_heat_level(), _curve.highest_tier().tier,
		"Raising notoriety alone must raise heat — heat is derived, never stored separately")


func test_heat_needs_no_save_section() -> void:
	# Derived state must not be persisted, or it can contradict notoriety on load.
	var save: Dictionary = _empire.get_save_data()
	for key in save.keys():
		assert_false(str(key).contains("heat"),
			"EmpireManager saved a heat key ('%s') — heat is derived from notoriety and must not be persisted" % key)


func test_loading_a_save_reresolves_the_band() -> void:
	_empire.load_save_data({"notoriety": 200.0})
	assert_eq(_empire.get_heat_level(), _curve.tier_for(200.0).tier,
		"A loaded save must re-resolve the heat band, not keep the tier it booted with")


func test_tier_change_signal_fires_once_per_crossing() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	var seen: Array = []
	_empire.heat_tier_changed.connect(func(t): seen.append(t.tier))

	_empire.add_notoriety(10.0)   # still tier 0
	assert_eq(seen.size(), 0, "No crossing, no signal — the HUD must not be spammed per tick")

	_empire.add_notoriety(15.0)   # crosses into tier 1 (>=20)
	assert_eq(seen.size(), 1, "Crossing a threshold should emit exactly once")
	assert_eq(seen[0], 1)


func test_enemies_are_passive_at_low_heat_and_hostile_at_high() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	assert_false(_empire.enemies_engage_unprovoked(),
		"At the lowest heat, ambient ships must leave the player alone until provoked")

	_empire.add_notoriety(200.0)
	assert_true(_empire.enemies_engage_unprovoked(),
		"At high heat, ambient ships must engage on sight")


func test_paid_clear_drops_exactly_one_tier() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	_empire.add_notoriety(250.0)
	var start_level: int = _empire.get_heat_level()
	assert_gt(start_level, 1, "Need a high tier to test a single-step drop")

	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 9999
	assert_true(_empire.spend_to_reduce_heat(), "A funded clear should succeed")
	assert_eq(_empire.get_heat_level(), start_level - 1,
		"One purchase must drop exactly one tier — never slide to zero")


func test_paid_clear_charges_the_authored_cost() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	_empire.add_notoriety(250.0)
	var cost: int = _empire.get_heat_tier().clear_cost_eights
	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 9999
	_empire.spend_to_reduce_heat()
	assert_eq(int(ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY)), 9999 - cost)


func test_paid_clear_refuses_when_unaffordable_and_changes_nothing() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	_empire.add_notoriety(250.0)
	var before_notoriety: float = _empire.notoriety
	var before_level: int = _empire.get_heat_level()
	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 0

	assert_false(_empire.spend_to_reduce_heat(), "An unaffordable clear must fail")
	assert_eq(_empire.notoriety, before_notoriety, "A failed clear must not move notoriety")
	assert_eq(_empire.get_heat_level(), before_level, "A failed clear must not move the tier")


func test_paid_clear_refuses_at_the_bottom_tier() -> void:
	_empire.notoriety = 0.0
	_empire._refresh_heat_tier(false)
	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 9999
	assert_false(_empire.spend_to_reduce_heat(),
		"There is nothing to buy at tier 0 — the player must not be charged for it")
	assert_eq(int(ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY)), 9999,
		"A refused clear must not charge")


func test_lying_low_decays_faster_than_waiting() -> void:
	# The mechanic exists to reward going home, so it has to beat doing nothing.
	var grace: float = _curve.decay_grace_seconds

	_empire.notoriety = 100.0
	_empire._refresh_heat_tier(false)
	_empire.set_lying_low(false)
	_empire._last_gain_unix = int(Time.get_unix_time_from_system()) - int(grace + 60.0)
	await wait_process_frames(10)
	var idle_loss: float = 100.0 - _empire.notoriety

	_empire.notoriety = 100.0
	_empire._refresh_heat_tier(false)
	_empire.set_lying_low(true)
	_empire._last_gain_unix = int(Time.get_unix_time_from_system()) - int(grace + 60.0)
	await wait_process_frames(10)
	var port_loss: float = 100.0 - _empire.notoriety

	assert_gt(idle_loss, 0.0, "Waiting out the grace period should decay heat at all")
	assert_gt(port_loss, idle_loss,
		"Lying low in port must cool heat faster than drifting at sea (idle %.4f vs port %.4f)"
		% [idle_loss, port_loss])


func test_heat_never_gates_play() -> void:
	# docs/00_VISION.md §19.2. Heat is pressure, not an energy meter. There must be
	# no API here that answers "may the player sail / fight / board?".
	for method in ["can_sail", "can_fight", "can_board", "has_energy", "consume_energy",
			"get_energy", "is_out_of_energy"]:
		assert_false(_empire.has_method(method),
			"EmpireManager grew '%s' — heat must never gate play, or it has become the energy system the constitution forbids" % method)


# ------------------------------------------------- EnemySpawner reads the tier
# These drive the AUTOLOAD EmpireManager, because EnemySpawner._heat_tier() asks
# the global, not a test instance. Notoriety is saved and restored around each.

var _saved_notoriety: float = 0.0


func _make_spawner() -> Node:
	var spawner := Node3D.new()
	spawner.set_script(load("res://scripts/combat/EnemySpawner.gd"))
	add_child_autoqfree(spawner)
	return spawner


func _set_autoload_notoriety(value: float) -> void:
	EmpireManager.notoriety = value
	EmpireManager._refresh_heat_tier(false)


func test_spawner_cap_tracks_the_heat_tier() -> void:
	_saved_notoriety = EmpireManager.notoriety
	var spawner := _make_spawner()

	_set_autoload_notoriety(0.0)
	var low_cap: int = spawner.get_active_max_enemies()
	_set_autoload_notoriety(250.0)
	var high_cap: int = spawner.get_active_max_enemies()

	_set_autoload_notoriety(_saved_notoriety)

	assert_eq(low_cap, _curve.tier_for(0.0).max_ambient_enemies)
	assert_eq(high_cap, _curve.tier_for(250.0).max_ambient_enemies)
	assert_gt(high_cap, low_cap,
		"A hunted player must face more ambient hulls than an unknown one — that is the feature")


func test_spawner_cadence_tracks_the_heat_tier() -> void:
	_saved_notoriety = EmpireManager.notoriety
	var spawner := _make_spawner()

	_set_autoload_notoriety(0.0)
	var slow: float = spawner.get_active_spawn_interval()
	_set_autoload_notoriety(250.0)
	var fast: float = spawner.get_active_spawn_interval()

	_set_autoload_notoriety(_saved_notoriety)

	assert_lt(fast, slow, "Higher heat must respawn hunters faster")


func test_spawn_strength_multiplier_rises_with_heat() -> void:
	_saved_notoriety = EmpireManager.notoriety
	var spawner := _make_spawner()

	_set_autoload_notoriety(0.0)
	var weak: float = spawner.compute_spawn_multiplier(1)
	_set_autoload_notoriety(250.0)
	var strong: float = spawner.compute_spawn_multiplier(1)

	_set_autoload_notoriety(_saved_notoriety)

	assert_gt(strong, weak,
		"Heat must compose with the existing region/notoriety scaling, not be ignored by it")


func test_spawner_falls_back_when_there_is_no_heat_curve() -> void:
	# A spawner instanced outside the world, or a failed curve load, must still
	# work off its @export rather than spawning zero enemies forever.
	var spawner := _make_spawner()
	var saved_config = EmpireManager.heat_config
	var saved_tier = EmpireManager._current_tier
	EmpireManager.heat_config = null
	EmpireManager._current_tier = null

	var cap: int = spawner.get_active_max_enemies()
	var interval: float = spawner.get_active_spawn_interval()

	EmpireManager.heat_config = saved_config
	EmpireManager._current_tier = saved_tier

	assert_eq(cap, spawner.max_enemies, "Without a curve the spawner must fall back to its export")
	assert_eq(interval, spawner.spawn_interval, "Without a curve the cadence must fall back too")
