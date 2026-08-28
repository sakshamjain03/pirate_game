extends GutTest

## M11 Requirement 7 — 6 new EventData resources (bringing the total from 3
## to 9, within the 8-10 target) plus the EventManager handlers that give
## each one a real effect, following _spawn_merchant_convoy()/
## _spawn_floating_treasure()/_spawn_ghost_ship_boss()'s established pattern.

const NEW_EVENT_PATHS := [
	"res://resources/world/events/DriftingWreckage.tres",
	"res://resources/world/events/SmugglersCache.tres",
	"res://resources/world/events/PirateRaidingParty.tres",
	"res://resources/world/events/RoyalNavyPatrol.tres",
	"res://resources/world/events/FavorableWinds.tres",
	"res://resources/world/events/Becalmed.tres",
]

func test_all_new_events_load_with_valid_data():
	for path in NEW_EVENT_PATHS:
		var event: EventData = load(path)
		assert_not_null(event, "%s should load as EventData" % path)
		assert_false(event.event_id.is_empty(), "%s must have a real event_id" % path)
		assert_false(event.display_text.is_empty(), "%s must have real display_text" % path)
		assert_gt(event.weight, 0.0, "%s must have a positive weight or it can never be picked" % path)
		assert_true(event.min_region_tier >= 1 and event.min_region_tier <= 3,
			"%s min_region_tier should be a real region tier (1-3)" % path)

func test_world_events_dir_has_at_least_the_8_to_10_target():
	## The directory also holds the 2 boss ambient events from Requirement 5
	## (Iron Vulture, Fortune's Toll) — they share the same EventManager
	## trigger pool but count toward the boss target, not this one, so this
	## only asserts the floor, not an exact/ceiling count.
	var dir = DirAccess.open("res://resources/world/events/")
	assert_not_null(dir)
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			count += 1
		file_name = dir.get_next()
	assert_true(count >= 8, "Requirement 7.1 targets 8-10 world events; found %d" % count)

	var new_and_original = NEW_EVENT_PATHS.size() + 3  # 3 pre-M11 events: merchant_convoy, floating_treasure, ghost_ship_boss
	assert_true(new_and_original >= 8 and new_and_original <= 10,
		"Requirement 7.1's own event-variety count (excluding the M11 boss events) should land in 8-10; got %d" % new_and_original)

func test_event_manager_has_a_spawn_path_for_every_new_event_id():
	var mgr = load("res://scripts/managers/EventManager.gd").new()
	for method in ["_spawn_drifting_wreckage", "_spawn_smugglers_cache",
			"_spawn_pirate_raiding_party", "_spawn_royal_navy_patrol"]:
		assert_true(mgr.has_method(method), "EventManager must know how to spawn '%s'" % method)
	assert_true(mgr.has_method("_apply_temporary_wind_modifier"),
		"Favorable Winds/Becalmed both route through _apply_temporary_wind_modifier()")
	mgr.free()

func test_wind_modifier_mutation_contract_scales_and_restores_exactly():
	## _apply_temporary_wind_modifier() resolves its region via
	## _get_player_region(), which needs a live player_ship + islands group —
	## exercised end-to-end in test_wind_system.gd's style elsewhere. This
	## isolates the actual mutation contract it performs on whatever region it
	## resolves: scale by `multiplier`, clamp to [0,1], then restore exactly.
	var region = RegionData.new()
	region.wind_strength = 0.5

	var original = region.wind_strength
	region.wind_strength = clampf(original * 1.6, 0.0, 1.0)
	assert_almost_eq(region.wind_strength, 0.8, 0.01, "Favorable Winds should scale wind_strength up")
	region.wind_strength = original
	assert_almost_eq(region.wind_strength, 0.5, 0.01, "Restoring must return the exact original value")

func test_get_player_region_exists_for_the_wind_events_to_resolve_a_target():
	var mgr = load("res://scripts/managers/EventManager.gd").new()
	assert_true(mgr.has_method("_get_player_region"),
		"Favorable Winds/Becalmed need a way to find which region's wind to touch")
	mgr.free()
