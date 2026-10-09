extends GutTest
## M30 Wave 2 (2.8): the Prize Fleet. A ship taken by its colours is CAPTURED (no explosion,
## loot drop or notoriety; a boss keeps the destroyed path), then the Prize Ledger offers Keep
## (a prize crew sails her to the next dock, where a seeded roll may retake her), Ransom the
## officers (gold + reputation) or Break her up (salvage + Dread). Kept prizes join the fleet with
## a uid, is_prize, condition and provenance_trait, duplicates allowed. Prizes in transit persist.

class MockShip extends RigidBody3D:
	var faction: FactionData = null

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const SLOOP := "res://resources/ships/Sloop.tres"

var _scene: Node3D
var _prev_scene: Node
var _made: Array = []
var _saved_ships: Array[OwnedShipData]
var _saved_transit: Array[Dictionary]
var _saved_missions: Dictionary
var _saved_resources: Dictionary
var _saved_axis: float
var _saved_notoriety: float
var _saved_reps: Dictionary
var _saved_quick: bool


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "PrizeWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_made = []
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_transit = FleetManager.prizes_in_transit.duplicate(true)
	_saved_missions = FleetManager.active_missions.duplicate(true)
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_axis = EmpireManager.axis
	_saved_notoriety = EmpireManager.notoriety
	_saved_reps = FactionManager.reputation_scores.duplicate()
	_saved_quick = SettingsManager.quick_boarding
	SettingsManager.quick_boarding = false
	EmpireManager.axis = 0.0
	EmpireManager.notoriety = 0.0
	FleetManager.prizes_in_transit.clear()
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")


func after_each() -> void:
	get_tree().paused = false
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.prizes_in_transit = _saved_transit.duplicate(true)
	FleetManager.active_missions = _saved_missions.duplicate(true)
	ResourceManager.current_resources = _saved_resources.duplicate()
	EmpireManager.axis = _saved_axis
	EmpireManager.notoriety = _saved_notoriety
	FactionManager.reputation_scores = _saved_reps.duplicate()
	SettingsManager.quick_boarding = _saved_quick
	for n in _made:
		if is_instance_valid(n):
			n.free()
	for g in [&"player_ship", &"enemy_ship", &"struck_ship", &"boss_ship"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		get_tree().root.remove_child(_scene)
		_scene.free()
	_scene = null


func _record(overrides: Dictionary = {}) -> Dictionary:
	var r := {"ship_id": "sloop", "ship_class": 1, "faction_id": "royal_navy",
			"officers_present": true, "is_boss": false, "condition": 0.6}
	r.merge(overrides, true)
	return r


func _details(overrides: Dictionary = {}) -> Dictionary:
	var d := {"success": true, "captured": true, "is_boss": false, "target_ship_id": "sloop",
			"target_faction_id": "royal_navy", "ship_class": 1, "officers_escaped": false,
			"hull_fraction": 0.2}
	d.merge(overrides, true)
	return d


func _find_seed(want_recaptured: bool, chance: float) -> int:
	for s in range(1, 2000):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if (rng.randf() < chance) == want_recaptured:
			return s
	return -1


# === Config ===

func test_the_authored_prize_config_loads() -> void:
	var cfg: PrizeConfigData = load(PrizeConfigData.DEFAULT_PATH)
	assert_not_null(cfg)
	assert_between(cfg.keep_condition, 0.0, 1.0)
	assert_gt(cfg.ransom_gold_per_class, 0)
	assert_gt(cfg.recapture_chance, 0.0, "the voyage home is a risk")
	assert_lt(cfg.recapture_chance, 1.0, "but not a certainty")


# === Which outcomes take a ship ===

func test_only_a_captured_colours_outcome_yields_a_ledger_record() -> void:
	assert_false(PrizeOffers.record_from_outcome("colours", _details()).is_empty())
	assert_false(PrizeOffers.record_from_outcome("struck", _details()).is_empty(), "a crew that struck is taken too")
	for id in ["hold", "magazine", "auto_win", "auto_loss", "cut_loose", "repulsed"]:
		assert_true(PrizeOffers.record_from_outcome(id, _details()).is_empty(), "%s takes no ship" % id)
	assert_true(PrizeOffers.record_from_outcome("colours", _details({"success": false})).is_empty())
	assert_true(PrizeOffers.record_from_outcome("colours", _details({"captured": false})).is_empty())
	assert_true(PrizeOffers.record_from_outcome("colours", _details({"is_boss": true})).is_empty(), "a boss is destroyed")


func test_the_record_reads_the_outcome() -> void:
	var r := PrizeOffers.record_from_outcome("colours", _details({"ship_class": 3, "officers_escaped": true}))
	assert_eq(r["ship_id"], "sloop")
	assert_eq(r["ship_class"], 3)
	assert_eq(r["faction_id"], "royal_navy")
	assert_false(r["officers_present"], "they escaped")


func test_a_hurt_hull_is_kept_at_the_configured_condition_and_an_untouched_one_in_better_shape() -> void:
	var cfg := PrizeConfigData.get_default()
	var hurt := PrizeOffers.record_from_outcome("colours", _details({"hull_fraction": 0.1}))
	assert_eq(hurt["condition"], cfg.keep_condition)
	var fine := PrizeOffers.record_from_outcome("struck", _details({"hull_fraction": 0.95}))
	assert_almost_eq(float(fine["condition"]), 0.95, 0.0001)


# === Resolving a hull by id ===

func test_hulls_resolve_by_their_own_ship_id_not_a_guessed_file_name() -> void:
	assert_eq(PrizeOffers.resolve_hull("sloop").resource_path, SLOOP)
	assert_eq(PrizeOffers.resolve_hull("man_o_war").display_name, "Man O'War", "man_o_war is ManOWar.tres")


func test_an_enemy_only_hull_is_never_offered_and_an_unknown_id_is_an_error() -> void:
	assert_true(PrizeOffers.is_enemy_only("enemy_raider"))
	assert_false(PrizeOffers.is_enemy_only("sloop"))
	assert_null(PrizeOffers.resolve_hull("enemy_raider"))
	assert_null(PrizeOffers.resolve_hull(""))
	assert_null(PrizeOffers.resolve_hull("no_such_hull"))


# === What the ledger offers ===

func _offer(offers: Array[Dictionary], choice: int) -> Dictionary:
	for o in offers:
		if int(o["choice"]) == choice:
			return o
	return {}


func test_a_normal_prize_offers_all_three_choices() -> void:
	var offers := PrizeOffers.build(_record())
	assert_eq(offers.size(), 3)
	assert_true(_offer(offers, PrizeOffers.Choice.KEEP)["available"])
	assert_true(_offer(offers, PrizeOffers.Choice.RANSOM)["available"])
	assert_true(_offer(offers, PrizeOffers.Choice.BREAK)["available"])
	var cfg := PrizeConfigData.get_default()
	assert_eq(_offer(offers, PrizeOffers.Choice.RANSOM)["gold"], cfg.ransom_gold_per_class)
	assert_eq(_offer(offers, PrizeOffers.Choice.BREAK)["wood"], cfg.break_wood_per_class)
	assert_eq(_offer(offers, PrizeOffers.Choice.KEEP)["crew_fraction"], cfg.prize_crew_fraction)
	assert_gt(_offer(offers, PrizeOffers.Choice.KEEP)["chance"], 0.0)


func test_offers_scale_with_the_ships_class() -> void:
	var small := PrizeOffers.build(_record({"ship_class": 1}))
	var big := PrizeOffers.build(_record({"ship_class": 4}))
	assert_eq(_offer(big, PrizeOffers.Choice.RANSOM)["gold"], 4 * _offer(small, PrizeOffers.Choice.RANSOM)["gold"])
	assert_eq(_offer(big, PrizeOffers.Choice.BREAK)["iron"], 4 * _offer(small, PrizeOffers.Choice.BREAK)["iron"])


func test_an_enemy_only_hull_cannot_be_kept_but_can_be_ransomed_or_broken() -> void:
	var offers := PrizeOffers.build(_record({"ship_id": "enemy_raider"}))
	assert_false(_offer(offers, PrizeOffers.Choice.KEEP)["available"])
	assert_ne(_offer(offers, PrizeOffers.Choice.KEEP)["reason"], "")
	assert_true(_offer(offers, PrizeOffers.Choice.RANSOM)["available"])
	assert_true(_offer(offers, PrizeOffers.Choice.BREAK)["available"])


func test_escaped_officers_or_a_flagless_ship_cannot_be_ransomed() -> void:
	assert_false(_offer(PrizeOffers.build(_record({"officers_present": false})), PrizeOffers.Choice.RANSOM)["available"])
	assert_false(_offer(PrizeOffers.build(_record({"faction_id": ""})), PrizeOffers.Choice.RANSOM)["available"])
	assert_false(_offer(PrizeOffers.build(_record({"faction_id": "player"})), PrizeOffers.Choice.RANSOM)["available"])


func test_a_boss_or_an_empty_record_offers_nothing() -> void:
	assert_true(PrizeOffers.build(_record({"is_boss": true})).is_empty())
	assert_true(PrizeOffers.build({}).is_empty())


# === What each choice does ===

func test_keep_sends_the_prize_home_costs_crew_and_adds_nothing_yet() -> void:
	var player := _player(100.0)
	var fleet_before := FleetManager.owned_ships.size()
	var res := PrizeOffers.apply(PrizeOffers.Choice.KEEP, _record(), player)
	assert_true(res["ok"])
	assert_eq(FleetManager.owned_ships.size(), fleet_before, "she is still at sea")
	assert_eq(FleetManager.prizes_in_transit.size(), 1)
	var t: Dictionary = FleetManager.prizes_in_transit[0]
	assert_eq(t["ship_id"], "sloop")
	assert_eq(t["provenance_trait"], "prize_royal_navy")
	assert_eq(t["condition"], 0.6)
	assert_true(t.has("seed"), "the recapture roll is seeded now, so a reload cannot reroll it")
	var cfg := PrizeConfigData.get_default()
	assert_eq(player.get_node("ShipDamage").crew, 100.0 - 100.0 * cfg.prize_crew_fraction, "the prize crew")


func test_the_prize_crew_never_takes_the_last_hand() -> void:
	var player := _player(100.0)
	player.get_node("ShipDamage").crew = 5.0
	PrizeOffers.apply(PrizeOffers.Choice.KEEP, _record(), player)
	assert_eq(player.get_node("ShipDamage").crew, 1.0)


func test_ransom_pays_gold_and_reputation() -> void:
	var gold_before: int = ResourceManager.get_resource("gold")
	var rep_before := FactionManager.get_reputation("royal_navy")
	var res := PrizeOffers.apply(PrizeOffers.Choice.RANSOM, _record({"ship_class": 2}))
	var cfg := PrizeConfigData.get_default()
	assert_true(res["ok"])
	assert_eq(ResourceManager.get_resource("gold"), gold_before + 2 * cfg.ransom_gold_per_class)
	assert_eq(FactionManager.get_reputation("royal_navy"), rep_before + cfg.ransom_reputation)


func test_break_pays_salvage_and_earns_dread() -> void:
	var wood_before: int = ResourceManager.get_resource("wood")
	var iron_before: int = ResourceManager.get_resource("iron")
	var res := PrizeOffers.apply(PrizeOffers.Choice.BREAK, _record({"ship_class": 3}))
	var cfg := PrizeConfigData.get_default()
	assert_true(res["ok"])
	assert_eq(ResourceManager.get_resource("wood"), wood_before + 3 * cfg.break_wood_per_class)
	assert_eq(ResourceManager.get_resource("iron"), iron_before + 3 * cfg.break_iron_per_class)
	assert_eq(EmpireManager.axis, NotorietyGainsData.get_default().dread_break_prize, "breaking the surrendered is Dread")


func test_an_unavailable_choice_is_refused_and_changes_nothing() -> void:
	var gold_before: int = ResourceManager.get_resource("gold")
	var res := PrizeOffers.apply(PrizeOffers.Choice.RANSOM, _record({"officers_present": false}))
	assert_false(res["ok"])
	assert_eq(ResourceManager.get_resource("gold"), gold_before)
	assert_false(PrizeOffers.apply(PrizeOffers.Choice.KEEP, _record({"ship_id": "enemy_raider"}))["ok"])
	assert_true(FleetManager.prizes_in_transit.is_empty())


func test_ransoming_an_unknown_faction_pays_nothing_and_errors() -> void:
	var gold_before: int = ResourceManager.get_resource("gold")
	var paid := FactionManager.ransom_officers("no_such_faction", 2)
	assert_eq(paid["gold"], 0)
	assert_eq(ResourceManager.get_resource("gold"), gold_before)


# === The fleet ===

func test_add_prize_allows_duplicate_hulls_and_never_blocks_a_purchase() -> void:
	var sloop: ShipStats = load(SLOOP)
	FleetManager.owned_ships.clear()
	var a := FleetManager.add_prize(sloop, 0.6, &"prize_royal_navy")
	var b := FleetManager.add_prize(sloop, 0.9, &"prize_pirate_clans")
	assert_eq(FleetManager.owned_ships.size(), 2, "three captured Sloops are three ships")
	assert_ne(a.uid, b.uid)
	assert_true(a.is_prize)
	assert_eq(a.condition, 0.6)
	assert_eq(a.provenance_trait, &"prize_royal_navy")
	assert_false(FleetManager.owns_ship_stats(sloop), "prizes do not count as having bought one")
	FleetManager.add_ship(sloop)
	FleetManager.add_ship(sloop)
	assert_eq(FleetManager.owned_ships.size(), 3, "purchases stay idempotent: one bought Sloop")
	assert_true(FleetManager.owns_ship_stats(sloop))


func test_condition_scales_a_prizes_effective_hull() -> void:
	var sloop: ShipStats = load(SLOOP)
	var owned := OwnedShipData.new()
	owned.ship_stats = sloop
	var base := owned.get_effective_stats().max_health
	owned.is_prize = true
	owned.condition = 0.0
	var floor_mult := PrizeConfigData.get_default().condition_health_floor
	assert_almost_eq(owned.get_effective_stats().max_health, base * floor_mult, 0.001)
	owned.condition = 1.0
	assert_almost_eq(owned.get_effective_stats().max_health, base, 0.001)
	owned.condition = 0.5
	assert_almost_eq(owned.get_effective_stats().max_health, base * lerpf(floor_mult, 1.0, 0.5), 0.001)
	owned.is_prize = false
	owned.condition = 0.0
	assert_almost_eq(owned.get_effective_stats().max_health, base, 0.001, "a bought hull has no condition penalty")


func test_prize_fields_save_only_for_prizes_and_round_trip() -> void:
	var plain := OwnedShipData.new()
	plain.ship_stats = load(SLOOP)
	var saved_plain := plain.get_save_data()
	assert_false(saved_plain.has("is_prize"), "a purchased hull saves exactly as before")
	assert_false(saved_plain.has("condition"))

	var prize := FleetManager.add_prize(load(SLOOP), 0.7, &"prize_royal_navy")
	var data := prize.get_save_data()
	assert_true(data["is_prize"])
	var back := OwnedShipData.from_save_data(JSON.parse_string(JSON.stringify(data)))
	assert_true(back.is_prize)
	assert_almost_eq(back.condition, 0.7, 0.0001)
	assert_eq(back.provenance_trait, &"prize_royal_navy")
	assert_eq(back.uid, prize.uid)


# === Transit and the recapture roll ===

func test_a_prize_in_transit_arrives_at_the_next_dock() -> void:
	var seed := _find_seed(false, FleetManager.recapture_chance_now())
	FleetManager.owned_ships.clear()
	FleetManager.send_prize_home({"ship_id": "sloop", "ship_class": 1, "faction_id": "royal_navy",
			"provenance_trait": "prize_royal_navy", "condition": 0.6, "seed": seed})
	watch_signals(FleetManager)
	var results := FleetManager.resolve_prizes_on_dock()
	assert_eq(results.size(), 1)
	assert_eq(results[0]["result"], "arrived")
	assert_eq(FleetManager.owned_ships.size(), 1)
	var owned := FleetManager.owned_ships[0]
	assert_true(owned.is_prize)
	assert_eq(owned.condition, 0.6)
	assert_eq(owned.provenance_trait, &"prize_royal_navy")
	assert_ne(owned.uid, "")
	assert_eq(owned.ship_stats.ship_id, "sloop", "resolved by id")
	assert_true(FleetManager.prizes_in_transit.is_empty())
	assert_signal_emit_count(FleetManager, "prize_arrived", 1)
	assert_signal_not_emitted(FleetManager, "prize_recaptured")


func test_a_prize_may_be_retaken_on_the_way_by_its_seeded_roll() -> void:
	var seed := _find_seed(true, FleetManager.recapture_chance_now())
	FleetManager.owned_ships.clear()
	FleetManager.send_prize_home({"ship_id": "sloop", "ship_class": 1, "faction_id": "royal_navy",
			"provenance_trait": "prize_royal_navy", "condition": 0.6, "seed": seed})
	watch_signals(FleetManager)
	var results := FleetManager.resolve_prizes_on_dock()
	assert_eq(results[0]["result"], "recaptured")
	assert_true(FleetManager.owned_ships.is_empty(), "she never made port")
	assert_true(FleetManager.prizes_in_transit.is_empty())
	assert_signal_emit_count(FleetManager, "prize_recaptured", 1)


func test_the_same_seed_always_gives_the_same_fate() -> void:
	var chance := FleetManager.recapture_chance_now()
	for want in [true, false]:
		var seed := _find_seed(want, chance)
		var outcomes: Array = []
		for _i in 3:
			FleetManager.owned_ships.clear()
			FleetManager.prizes_in_transit.clear()
			FleetManager.send_prize_home({"ship_id": "sloop", "provenance_trait": "p", "condition": 1.0, "seed": seed})
			outcomes.append(FleetManager.resolve_prizes_on_dock()[0]["result"])
		assert_eq(outcomes[0], outcomes[1])
		assert_eq(outcomes[1], outcomes[2])


func test_notoriety_makes_a_voyage_more_dangerous() -> void:
	var calm := FleetManager.recapture_chance_now()
	EmpireManager.notoriety = 200.0
	assert_gt(FleetManager.recapture_chance_now(), calm)
	EmpireManager.notoriety = 1.0e9
	assert_lte(FleetManager.recapture_chance_now(), 1.0, "a probability never exceeds 1")


func test_a_prize_whose_hull_cannot_be_resolved_stays_in_transit() -> void:
	var seed := _find_seed(false, FleetManager.recapture_chance_now())
	FleetManager.send_prize_home({"ship_id": "no_such_hull", "provenance_trait": "p", "condition": 1.0, "seed": seed})
	FleetManager.resolve_prizes_on_dock()
	assert_eq(FleetManager.prizes_in_transit.size(), 1, "never silently destroyed")


func test_transit_round_trips_through_the_save_and_is_omitted_when_empty() -> void:
	assert_false(FleetManager.get_save_data().has("prizes_in_transit"), "an empty optional section is omitted")
	FleetManager.send_prize_home({"ship_id": "sloop", "ship_class": 1, "faction_id": "royal_navy",
			"provenance_trait": "prize_royal_navy", "condition": 0.6, "seed": 1234})
	var saved := JSON.parse_string(JSON.stringify(FleetManager.get_save_data()))
	FleetManager.prizes_in_transit.clear()
	FleetManager.load_save_data(saved)
	assert_eq(FleetManager.prizes_in_transit.size(), 1)
	assert_eq(FleetManager.prizes_in_transit[0]["ship_id"], "sloop")
	assert_eq(int(FleetManager.prizes_in_transit[0]["seed"]), 1234, "the seed survives, so the fate is the same after a reload")
	FleetManager.load_save_data({"owned_ships": []})
	assert_true(FleetManager.prizes_in_transit.is_empty(), "a save with none clears none stale")


# === Captured, not sunk ===

func _enemy(boss: bool = false) -> Node:
	var e := ENEMY_SHIP.instantiate()
	if boss:
		e.add_to_group("boss_ship")
	_scene.add_child(e)
	_made.append(e)
	return e


func test_a_captured_hull_skips_the_explosion_and_the_destroyed_path() -> void:
	var e := _enemy()
	e.set_meta("captured", true)
	e.set_meta("loot_claimed", true)
	var children_before := _scene.get_child_count()
	watch_signals(e)
	e._on_died()
	assert_eq(_scene.get_child_count(), children_before, "no explosion was spawned")
	assert_signal_emitted(e, "ship_destroyed", "listeners still learn she is gone")
	assert_eq(EmpireManager.notoriety, 0.0)
	assert_eq(EmpireManager.axis, 0.0, "a captured ship is not 'sunk after surrendering' either")


func test_a_sunk_hull_still_explodes_and_a_boss_ignores_the_captured_flag() -> void:
	var sunk := _enemy()
	var before := _scene.get_child_count()
	sunk._on_died()
	assert_gt(_scene.get_child_count(), before, "the ordinary destroyed path explodes")

	var boss := _enemy(true)
	boss.set_meta("captured", true)
	var before_boss := _scene.get_child_count()
	boss._on_died()
	assert_gt(_scene.get_child_count(), before_boss, "a boss keeps the destroyed path")


# === BoardingSystem marks the capture ===

func _boarding(struck: bool = false, boss: bool = false) -> Dictionary:
	var system := BoardingSystem.new()
	system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(system)
	_made.append(system)
	var player := _player(100.0)
	var enemy := _mock_enemy(boss)
	if struck:
		enemy.set_meta(&"struck", true)
	system._eligible_enemy = enemy
	return {"system": system, "player": player, "enemy": enemy}


func _player(crew: float) -> Node:
	var p := MockShip.new()
	p.add_to_group("player_ship")
	var stats := ShipStats.new()
	stats.max_crew = 100.0
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	p.add_child(dmg)
	dmg.crew = crew
	_scene.add_child(p)
	_made.append(p)
	return p


func _mock_enemy(boss: bool) -> Node:
	var e := MockShip.new()
	e.faction = load("res://resources/factions/RoyalNavy.tres")
	e.add_to_group("enemy_ship")
	if boss:
		e.add_to_group("boss_ship")
	var stats := ShipStats.new()
	stats.max_crew = 100.0
	stats.ship_id = "sloop"
	stats.ship_class = 2
	stats.display_name = "Mock"
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	e.add_child(dmg)
	dmg.crew = 100.0
	_scene.add_child(e)
	_made.append(e)
	return e


func test_a_colours_outcome_marks_the_hull_captured_and_reports_what_the_ledger_needs() -> void:
	var rig := _boarding()
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	watch_signals(system)
	system.resolve_tactical("colours", true, {"captures_ship": true, "officers_escaped": true})
	assert_true(rig["enemy"].get_meta("captured", false))
	var details: Dictionary = get_signal_parameters(system, "boarding_outcome")[1]
	assert_true(details["captured"])
	assert_true(details["officers_escaped"])
	assert_eq(details["ship_class"], 2)
	assert_eq(details["target_ship_id"], "sloop")
	assert_false(details["is_boss"])
	assert_between(details["hull_fraction"], 0.0, 1.0)


func test_the_hold_and_the_magazine_and_the_instant_path_never_capture() -> void:
	for id in ["hold", "magazine"]:
		var rig := _boarding()
		var system: BoardingSystem = rig["system"]
		system.begin_boarding()
		system.resolve_tactical(id, true, {"captures_ship": id == "hold"})
		assert_false(rig["enemy"].get_meta("captured", false), "%s is not a capture" % id)
		assert_true(rig["enemy"].get_node("ShipDamage").is_destroyed())
	var rig2 := _boarding()
	var s2: BoardingSystem = rig2["system"]
	s2.attempt_boarding()
	assert_false(rig2["enemy"].get_meta("captured", false), "the legacy instant plunder is unchanged")


func test_a_boss_is_destroyed_not_captured() -> void:
	var rig := _boarding(false, true)
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	system.resolve_tactical("colours", true, {"captures_ship": true})
	assert_false(rig["enemy"].get_meta("captured", false))
	assert_true(rig["enemy"].get_node("ShipDamage").is_destroyed())


# === The Prize Ledger UI ===

func _ledger() -> PrizeLedger:
	var l := PrizeLedger.new()
	_scene.add_child(l)
	_made.append(l)
	return l


func test_the_ledger_opens_on_a_captured_colours_outcome_and_pauses() -> void:
	var rig := _boarding()
	var system: BoardingSystem = rig["system"]
	var ledger := _ledger()
	ledger.bind_boarding_system(system)
	system.begin_boarding()
	system.resolve_tactical("colours", true, {"captures_ship": true})
	assert_true(ledger.is_open)
	assert_true(ledger.visible)
	assert_true(get_tree().paused, "a modal")
	assert_eq(ledger.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(ledger._cards_row.get_child_count(), 3)
	assert_string_contains(ledger.card_body(ledger.offer_for(PrizeOffers.Choice.RANSOM)), "gold")


func test_the_ledger_stays_shut_for_every_other_outcome_and_for_a_boss() -> void:
	var rig := _boarding()
	var system: BoardingSystem = rig["system"]
	var ledger := _ledger()
	ledger.bind_boarding_system(system)
	system.begin_boarding()
	system.resolve_tactical("hold", true, {"captures_ship": false})
	assert_false(ledger.is_open)
	assert_false(get_tree().paused)

	var boss := _boarding(false, true)
	var l2 := _ledger()
	l2.bind_boarding_system(boss["system"])
	boss["system"].begin_boarding()
	boss["system"].resolve_tactical("colours", true, {"captures_ship": true})
	assert_false(l2.is_open, "a boss has nothing to offer")


func test_choosing_applies_the_pick_closes_and_unpauses() -> void:
	var ledger := _ledger()
	ledger.open(_record({"ship_class": 2}), _player(100.0))
	assert_true(get_tree().paused)
	var gold_before: int = ResourceManager.get_resource("gold")
	watch_signals(ledger)
	ledger.choose(PrizeOffers.Choice.RANSOM)
	assert_gt(ResourceManager.get_resource("gold"), gold_before)
	assert_false(ledger.is_open)
	assert_false(ledger.visible)
	assert_false(get_tree().paused)
	assert_signal_emit_count(ledger, "choice_made", 1)


func test_an_unavailable_card_is_disabled_and_choosing_it_keeps_the_modal_open() -> void:
	var ledger := _ledger()
	ledger.open(_record({"officers_present": false}), _player(100.0))
	var ransom: Button = ledger._cards_row.get_node("Card_Ransom")
	assert_true(ransom.disabled)
	assert_string_contains(ledger.card_body(ledger.offer_for(PrizeOffers.Choice.RANSOM)), "officers")
	ledger.choose(PrizeOffers.Choice.RANSOM)
	assert_true(ledger.is_open, "no way to dismiss without a real choice")
	assert_true(get_tree().paused)
	ledger.choose(PrizeOffers.Choice.BREAK)
	assert_false(ledger.is_open)


func test_keeping_through_the_ledger_queues_the_prize_for_the_next_dock() -> void:
	var ledger := _ledger()
	ledger.open(_record(), _player(100.0))
	ledger.choose(PrizeOffers.Choice.KEEP)
	assert_eq(FleetManager.prizes_in_transit.size(), 1)


func test_freeing_an_open_ledger_releases_the_pause() -> void:
	var ledger := _ledger()
	ledger.open(_record(), _player(100.0))
	_scene.remove_child(ledger)
	ledger.free()
	assert_false(get_tree().paused)


# === The whole voyage ===

func test_colours_then_keep_then_dock_puts_a_prize_in_the_fleet() -> void:
	var rig := _boarding()
	var system: BoardingSystem = rig["system"]
	var ledger := _ledger()
	ledger.bind_boarding_system(system)
	FleetManager.owned_ships.clear()
	system.begin_boarding()
	system.resolve_tactical("colours", true, {"captures_ship": true})
	ledger.choose(PrizeOffers.Choice.KEEP)
	assert_true(FleetManager.owned_ships.is_empty(), "still at sea")
	# Make this voyage a safe one, then reach port.
	FleetManager.prizes_in_transit[0]["seed"] = _find_seed(false, FleetManager.recapture_chance_now())
	FleetManager.resolve_prizes_on_dock()
	assert_eq(FleetManager.owned_ships.size(), 1)
	assert_true(FleetManager.owned_ships[0].is_prize)
	assert_eq(FleetManager.owned_ships[0].ship_stats.ship_id, "sloop")
