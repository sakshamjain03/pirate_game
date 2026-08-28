extends GutTest

## M11 Requirement 6 — treaty/tribute (FactionManager.pay_tribute()) and trade
## routes as a named, region-tied FleetManager mission variant.

var fm: Node
var _saved_gold: int

func before_each():
	fm = load("res://scripts/managers/FactionManager.gd").new()
	add_child(fm)
	# ResourceManager is a real autoload shared across the whole suite —
	# save/restore gold the same way test_faction_manager.gd already does for
	# reputation_scores, so this file doesn't leak a pinned-at-cap gold value
	# into whichever test happens to run after it (e.g.
	# test_combat_loop_end_to_end.gd's own gold-increased assertion).
	_saved_gold = ResourceManager.get_resource("gold")
	ResourceManager.add_resource("gold", 10000)

func after_each():
	ResourceManager.current_resources["gold"] = _saved_gold
	if is_instance_valid(fm):
		fm.free()

# --- Diplomacy / tribute ---

func test_tribute_increases_reputation_and_spends_gold():
	fm.reputation_scores["pirate_clans"] = -50
	var gold_before = ResourceManager.get_resource("gold")

	var ok = fm.pay_tribute("pirate_clans")

	assert_true(ok, "Tribute should succeed when affordable and off cooldown")
	assert_eq(fm.get_reputation("pirate_clans"), -50 + fm.TRIBUTE_REPUTATION_GAIN,
		"Reputation should rise by exactly TRIBUTE_REPUTATION_GAIN")
	assert_eq(ResourceManager.get_resource("gold"), gold_before - fm.TRIBUTE_COST_GOLD,
		"Gold should be spent exactly once")

func test_tribute_respects_cooldown():
	fm.reputation_scores["pirate_clans"] = -50
	assert_true(fm.pay_tribute("pirate_clans"), "First tribute should succeed")

	var rep_after_first = fm.get_reputation("pirate_clans")
	var gold_after_first = ResourceManager.get_resource("gold")

	var ok_again = fm.pay_tribute("pirate_clans")

	assert_false(ok_again, "A second tribute on cooldown should be refused")
	assert_eq(fm.get_reputation("pirate_clans"), rep_after_first, "Reputation must not change on a refused tribute")
	assert_eq(ResourceManager.get_resource("gold"), gold_after_first, "Gold must not be spent on a refused tribute")

func test_tribute_cooldown_counts_down_and_expires():
	fm.reputation_scores["pirate_clans"] = -50
	fm.pay_tribute("pirate_clans")
	assert_false(fm.can_pay_tribute("pirate_clans"), "Precondition: on cooldown right after paying")

	fm._process(fm.TRIBUTE_COOLDOWN_SECONDS + 1.0)

	assert_true(fm.can_pay_tribute("pirate_clans"), "Cooldown should expire after TRIBUTE_COOLDOWN_SECONDS")

func test_tribute_fails_without_enough_gold():
	# Drain gold below the tribute cost.
	var current = ResourceManager.get_resource("gold")
	ResourceManager.spend_resources({"gold": current})
	assert_false(ResourceManager.can_afford({"gold": fm.TRIBUTE_COST_GOLD}), "Precondition: unaffordable")

	var ok = fm.pay_tribute("royal_navy")
	assert_false(ok, "Tribute should fail when the player can't afford it")

func test_tribute_cooldown_is_per_faction():
	fm.pay_tribute("pirate_clans")
	assert_false(fm.can_pay_tribute("pirate_clans"), "pirate_clans should be on cooldown")
	assert_true(fm.can_pay_tribute("royal_navy"), "royal_navy's cooldown must be independent of pirate_clans'")

func test_tribute_state_round_trips_through_save_data():
	fm.reputation_scores["pirate_clans"] = -50
	fm.pay_tribute("pirate_clans")
	var saved = fm.get_save_data()

	var restored = load("res://scripts/managers/FactionManager.gd").new()
	add_child_autoqfree(restored)
	restored.load_save_data(saved)

	assert_eq(restored.get_reputation("pirate_clans"), fm.get_reputation("pirate_clans"),
		"Reputation must round-trip")
	assert_false(restored.can_pay_tribute("pirate_clans"),
		"Tribute cooldown must round-trip too, or reloading would be a free cooldown reset")

func test_pre_m11_flat_save_format_still_loads():
	## Old saves stored the reputation dict directly, not nested under
	## "reputation_scores" — this must not silently reset reputation to 0.
	var legacy_data = {"pirate_clans": -30, "royal_navy": 10, "merchant_guild": 40}
	var restored = load("res://scripts/managers/FactionManager.gd").new()
	add_child_autoqfree(restored)
	restored.load_save_data(legacy_data)

	assert_eq(restored.get_reputation("pirate_clans"), -30)
	assert_eq(restored.get_reputation("royal_navy"), 10)
	assert_eq(restored.get_reputation("merchant_guild"), 40)

# --- Trade routes ---

func test_trade_route_ticks_gold_scaled_by_region_tier():
	var flm = load("res://scripts/managers/FleetManager.gd").new()
	add_child_autoqfree(flm)
	flm.active_ship_index = -1  # so ship index 0 isn't treated as "the active ship"
	# _ready()'s starter-captain seeding may not have run yet this same frame —
	# populate explicitly rather than depend on that timing.
	if flm.owned_captains.is_empty():
		flm.owned_captains.append(load("res://resources/captains/Jack.tres"))

	flm.assign_trade_route(0, 0, "Imperial Waters Route", 3)
	# Gold storage caps at 5000 (ResourceManager.max_storage) and before_each()
	# tops it up there — spend down first so the tick's gain isn't silently
	# clamped away by an already-full cap.
	ResourceManager.spend_resources({"gold": ResourceManager.get_resource("gold") - 100})
	var gold_before = ResourceManager.get_resource("gold")

	flm._on_economy_tick()

	var cap_level = flm.owned_captains[0].level
	var expected_gain = 10 * cap_level * 3
	assert_eq(ResourceManager.get_resource("gold"), gold_before + expected_gain,
		"Trade route gold should scale by region_tier, not be a flat rename of 'trade'")

func test_trade_route_display_text_shows_the_route_name():
	var flm = load("res://scripts/managers/FleetManager.gd").new()
	add_child_autoqfree(flm)
	flm.active_ship_index = -1

	flm.assign_trade_route(0, 0, "Contested Waters Route", 2)

	assert_eq(flm.get_mission_display_text(0), "Contested Waters Route",
		"The player should see the route's name, not an abstract 'Trade_route' label")

func test_trade_route_region_tier_is_clamped():
	var flm = load("res://scripts/managers/FleetManager.gd").new()
	add_child_autoqfree(flm)
	flm.active_ship_index = -1

	flm.assign_trade_route(0, 0, "Somewhere", 99)
	assert_eq(flm.active_missions[0]["region_tier"], 3, "region_tier should clamp to the real 1-3 region range")
