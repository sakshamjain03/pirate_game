extends GutTest
## M30 Wave 2 (2.9): prize courts, captives and the campaign "capture" objectives.
##   - A port's court is chosen by its owner faction. A Navy court refuses merchant prizes (with a
##     reputation cost); a pirate haven pays 0.7x; captives are PRESSED into your crew or handed
##     back LOYAL to their flag.
##   - CAPTURE_SHIPS and SELL_PRIZE are appended to ObjectiveData.Condition (existing ints keep
##     their values) and CampaignManager tracks them while their chapter is current.
## test_campaign_golden_path.gd must keep passing unmodified.

class MockShip extends RigidBody3D:
	var faction: FactionData = null

const SLOOP := "res://resources/ships/Sloop.tres"

var _scene: Node3D
var _prev_scene: Node
var _made: Array = []
var _saved_ships: Array[OwnedShipData]
var _saved_active: int
var _saved_captains: Array[CaptainData]
var _saved_missions: Dictionary
var _saved_defend: Array
var _saved_resources: Dictionary
var _saved_reps: Dictionary
var _saved_chapters: Array
var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _navy: PrizeCourtData
var _haven: PrizeCourtData
var _port: PrizeCourtData


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "CourtWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_made = []
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_active = FleetManager.active_ship_index
	_saved_captains = FleetManager.owned_captains.duplicate()
	_saved_missions = FleetManager.active_missions.duplicate(true)
	_saved_defend = FleetManager.defend_home_ship_uids.duplicate()
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_reps = FactionManager.reputation_scores.duplicate()
	_saved_chapters = CampaignManager.chapters.duplicate()
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	FleetManager.owned_ships.clear()
	FleetManager.active_missions.clear()
	FleetManager.defend_home_ship_uids.clear()
	FleetManager.active_ship_index = 0
	_navy = PrizeCourtData.court_for("royal_navy")
	_haven = PrizeCourtData.court_for("pirate_clans")
	_port = PrizeCourtData.court_for("player")
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")


func after_each() -> void:
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.active_ship_index = _saved_active
	FleetManager.owned_captains = _saved_captains.duplicate()
	FleetManager.active_missions = _saved_missions.duplicate(true)
	FleetManager.defend_home_ship_uids = _saved_defend.duplicate()
	ResourceManager.current_resources = _saved_resources.duplicate()
	FactionManager.reputation_scores = _saved_reps.duplicate()
	CampaignManager.chapters = _saved_chapters.duplicate()
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	for n in _made:
		if is_instance_valid(n):
			n.free()
	for g in [&"player_ship", &"enemy_ship"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		get_tree().root.remove_child(_scene)
		_scene.free()
	_scene = null


## A fleet of an active (bought) hull plus one prize; returns the prize.
func _fleet_with_prize(provenance: StringName, condition: float = 1.0, captives: int = 0) -> OwnedShipData:
	var active := OwnedShipData.new()
	active.ship_stats = load("res://resources/ships/Dinghy.tres")
	FleetManager.owned_ships.append(active)
	FleetManager.uid_of(0)
	return FleetManager.add_prize(load(SLOOP), condition, provenance, captives)


func _player(crew: float, max_crew: float = 100.0) -> Node:
	var p := MockShip.new()
	p.add_to_group("player_ship")
	var stats := ShipStats.new()
	stats.max_crew = max_crew
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	p.add_child(dmg)
	dmg.crew = crew
	_scene.add_child(p)
	_made.append(p)
	return p


# === The courts ===

func test_each_authored_court_is_found_by_the_faction_that_owns_its_ports() -> void:
	assert_not_null(_navy)
	assert_not_null(_haven)
	assert_not_null(_port)
	assert_eq(_navy.faction_id, "royal_navy")
	assert_eq(_haven.faction_id, "pirate_clans")
	assert_not_null(PrizeCourtData.court_for("spanish_empire"))
	assert_null(PrizeCourtData.court_for("merchant_guild"), "the guild keeps no court")
	assert_null(PrizeCourtData.court_for(""))
	assert_null(PrizeCourtData.court_for("no_such_faction"))


func test_court_factions_are_real_factions_and_refusals_name_real_ones() -> void:
	var real := {}
	for f in ["GhostFaction", "MerchantGuild", "PirateClans", "PlayerFaction", "RoyalNavy", "SpanishEmpire"]:
		real[(load("res://resources/factions/%s.tres" % f) as FactionData).faction_id] = true
	for path in ResourceLookup.list_resource_paths(PrizeCourtData.COURTS_DIR):
		var c: PrizeCourtData = load(path)
		assert_true(real.has(c.faction_id), "%s: faction '%s'" % [path, c.faction_id])
		for refused in c.refuses_prizes_from:
			assert_true(real.has(refused), "%s refuses unknown faction '%s'" % [path, refused])
		assert_ne(c.court_id, "")
		assert_gt(c.payout_mult, 0.0)


func test_a_navy_court_refuses_merchant_prizes_and_nobody_elses() -> void:
	assert_true(_navy.refuses("merchant_guild"))
	assert_false(_navy.refuses("pirate_clans"))
	assert_false(_navy.refuses("royal_navy"))
	assert_false(_navy.refuses(""), "an unknown origin is not refused")
	assert_false(_haven.refuses("merchant_guild"), "a haven asks no questions")


func test_a_pirate_haven_pays_seventy_percent() -> void:
	assert_eq(_haven.payout_mult, 0.7)
	assert_eq(_haven.quote(2, 1.0), int(floor(_haven.gold_per_class * 2 * 0.7)))
	assert_lt(_haven.quote(2, 1.0), _navy.quote(2, 1.0) if _navy.gold_per_class >= _haven.gold_per_class else _haven.gold_per_class * 2)
	assert_eq(_navy.payout_mult, 1.0)


func test_a_quote_scales_with_class_and_condition_and_never_goes_negative() -> void:
	assert_eq(_navy.quote(4, 1.0), 4 * _navy.quote(1, 1.0))
	assert_eq(_navy.quote(1, 0.5), int(floor(_navy.gold_per_class * 0.5)))
	assert_eq(_navy.quote(1, -3.0), 0)
	assert_eq(_navy.quote(1, 9.0), _navy.quote(1, 1.0), "condition is clamped to 1")
	assert_eq(_navy.quote(0, 1.0), _navy.quote(1, 1.0), "class is at least 1")


# === Selling ===

func test_selling_a_prize_pays_removes_the_hull_and_tells_the_world() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans", 0.8)
	var gold_before: int = ResourceManager.get_resource("gold")
	watch_signals(FleetManager)
	var res := FleetManager.sell_prize(prize.uid, _haven)
	assert_true(res["ok"])
	assert_eq(res["gold"], _haven.quote(1, 0.8))
	assert_eq(ResourceManager.get_resource("gold"), gold_before + res["gold"])
	assert_eq(FleetManager.owned_ships.size(), 1, "the prize is gone")
	assert_eq(res["ship_id"], "sloop")
	assert_eq(res["court_id"], _haven.court_id)
	assert_signal_emit_count(FleetManager, "prize_sold", 1)


func test_a_navy_court_refuses_a_merchant_prize_with_a_reputation_cost() -> void:
	var prize := _fleet_with_prize(&"prize_merchant_guild")
	var gold_before: int = ResourceManager.get_resource("gold")
	var rep_before := FactionManager.get_reputation("royal_navy")
	watch_signals(FleetManager)
	var res := FleetManager.sell_prize(prize.uid, _navy)
	assert_false(res["ok"])
	assert_true(res["refused"])
	assert_eq(res["rep_cost"], _navy.refusal_reputation_cost)
	assert_eq(FactionManager.get_reputation("royal_navy"), rep_before - _navy.refusal_reputation_cost)
	assert_eq(ResourceManager.get_resource("gold"), gold_before, "nothing is paid")
	assert_eq(FleetManager.owned_ships.size(), 2, "she is still yours")
	assert_signal_emit_count(FleetManager, "prize_refused", 1)
	assert_signal_not_emitted(FleetManager, "prize_sold")


func test_the_same_merchant_prize_sells_at_a_haven() -> void:
	var prize := _fleet_with_prize(&"prize_merchant_guild")
	assert_true(FleetManager.sell_prize(prize.uid, _haven)["ok"])


func test_a_navy_court_buys_a_pirate_prize() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans")
	assert_true(FleetManager.sell_prize(prize.uid, _navy)["ok"])


func test_only_a_non_active_prize_can_be_sold() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans")
	var bought := FleetManager.owned_ships[0]
	assert_false(FleetManager.sell_prize(bought.uid, _haven)["ok"], "a bought hull is not a prize")
	FleetManager.active_ship_index = 1  # the prize is the active hull
	assert_false(FleetManager.sell_prize(prize.uid, _haven)["ok"], "never the ship you are sailing")
	assert_false(FleetManager.sell_prize("nope", _haven)["ok"])
	assert_false(FleetManager.sell_prize(prize.uid, null)["ok"], "no court, no sale")
	assert_eq(FleetManager.owned_ships.size(), 2)


func test_selling_keeps_the_active_hull_and_drops_the_prizes_duties() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans")
	var second := FleetManager.add_prize(load(SLOOP), 1.0, &"prize_pirate_clans")
	FleetManager.owned_captains.clear()
	FleetManager.owned_captains.append(load("res://resources/captains/Jack.tres"))
	FleetManager.assign_mission(1, 0, "patrol")
	FleetManager.set_defend_home(1, true)
	FleetManager.active_ship_index = 2  # sailing the second prize
	assert_true(FleetManager.sell_prize(prize.uid, _haven)["ok"])
	assert_eq(FleetManager.owned_ships[FleetManager.active_ship_index].uid, second.uid,
		"the active index followed its hull down one slot")
	assert_true(FleetManager.active_missions.is_empty(), "the sold hull's mission is gone")
	assert_true(FleetManager.defend_home_ship_uids.is_empty())


# === Captives ===

func test_captives_are_pressed_into_the_crew_up_to_the_ships_capacity() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans", 1.0, 20)
	var player := _player(90.0)
	var res := FleetManager.sell_prize(prize.uid, _haven, player)
	var want := mini(int(floor(20.0 * _haven.pressed_fraction)), 10)  # only 10 berths free
	assert_eq(res["pressed"], want)
	assert_eq(player.get_node("ShipDamage").crew, 90.0 + want)
	assert_eq(res["repatriated"], 0)


func test_pressed_captives_never_overfill_the_ship() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans", 1.0, 40)
	var player := _player(99.0)
	FleetManager.sell_prize(prize.uid, _haven, player)
	assert_eq(player.get_node("ShipDamage").crew, 100.0)


func test_a_navy_court_hands_captives_back_loyal_for_goodwill() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans", 1.0, 12)
	# A pirate-clans prize at a Navy court is accepted; the Navy keeps the men for their own flag.
	var player := _player(50.0)
	var rep_before := FactionManager.get_reputation("pirate_clans")
	var res := FleetManager.sell_prize(prize.uid, _navy, player)
	assert_true(res["ok"])
	assert_eq(res["pressed"], 0, "loyal captives do not sign on")
	assert_eq(res["repatriated"], 12)
	assert_eq(player.get_node("ShipDamage").crew, 50.0)
	assert_eq(FactionManager.get_reputation("pirate_clans"), rep_before + _navy.loyal_reputation)


func test_a_prize_with_no_captives_resolves_none() -> void:
	var prize := _fleet_with_prize(&"prize_pirate_clans")
	var res := FleetManager.sell_prize(prize.uid, _haven, _player(50.0))
	assert_eq(res["pressed"], 0)
	assert_eq(res["repatriated"], 0)


func test_captives_and_the_prize_faction_survive_save_and_load() -> void:
	var prize := _fleet_with_prize(&"prize_royal_navy", 0.7, 9)
	assert_eq(prize.provenance_faction(), "royal_navy")
	var saved := JSON.parse_string(JSON.stringify(prize.get_save_data()))
	assert_eq(saved["captives"], 9)
	var back := OwnedShipData.from_save_data(saved)
	assert_eq(back.captives, 9)
	assert_eq(back.provenance_faction(), "royal_navy")
	var plain := OwnedShipData.new()
	assert_false(plain.get_save_data().has("captives"))
	plain.provenance_trait = &"something_else"
	assert_eq(plain.provenance_faction(), "")


func test_captives_travel_with_a_kept_prize_to_the_dock() -> void:
	var details := {"success": true, "captured": true, "is_boss": false, "target_ship_id": "sloop",
			"target_faction_id": "royal_navy", "ship_class": 1, "hull_fraction": 0.2, "captives": 14}
	var record := PrizeOffers.record_from_outcome("colours", details)
	assert_eq(record["captives"], 14)
	PrizeOffers.apply(PrizeOffers.Choice.KEEP, record)
	assert_eq(FleetManager.prizes_in_transit[0]["captives"], 14)
	FleetManager.owned_ships.clear()
	var calm := 0.0
	for s in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if rng.randf() >= FleetManager.recapture_chance_now():
			calm = s
			break
	FleetManager.prizes_in_transit[0]["seed"] = int(calm)
	FleetManager.resolve_prizes_on_dock()
	assert_eq(FleetManager.owned_ships[0].captives, 14)
	FleetManager.prizes_in_transit.clear()


func test_boarding_reports_the_defenders_still_standing_as_captives() -> void:
	var system := BoardingSystem.new()
	system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(system)
	_made.append(system)
	_player(100.0)
	var enemy := MockShip.new()
	enemy.add_to_group("enemy_ship")
	var stats := ShipStats.new()
	stats.max_crew = 100.0
	stats.ship_id = "sloop"
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	enemy.add_child(dmg)
	dmg.crew = 60.0  # near enough the player's 100 x 1.2 that this is a tactical boarding, not an overwhelm
	_scene.add_child(enemy)
	_made.append(enemy)
	system._eligible_enemy = enemy
	system.begin_boarding()
	watch_signals(system)
	system.resolve_tactical("colours", true, {"captures_ship": true})
	assert_eq(get_signal_parameters(system, "boarding_outcome")[1]["captives"], 60)


# === The objective conditions ===

func test_the_capture_conditions_are_appended_and_the_old_ints_are_unchanged() -> void:
	assert_eq(ObjectiveData.Condition.REPAIR_SHIP, 21)
	assert_eq(ObjectiveData.Condition.CAPTURE_SHIPS, 22)
	assert_eq(ObjectiveData.Condition.SELL_PRIZE, 23)
	assert_eq(ObjectiveData.Condition.BOARD_SHIPS, 4, "BOARD_SHIPS is untouched")


func _objective(id: String, condition: int, target := "", count := 1) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.condition = condition
	o.target_id = target
	o.target_count = count
	return o


func _start(objective: ObjectiveData) -> void:
	var anchor := _objective("anchor", ObjectiveData.Condition.DOCK_AT_ISLAND, "nowhere")
	var ch1 := ChapterData.new()
	ch1.chapter_id = "ch1"
	ch1.chapter_number = 1
	var list1: Array[ObjectiveData] = [objective, anchor]
	ch1.objectives = list1
	var ch2 := ChapterData.new()
	ch2.chapter_id = "ch2"
	ch2.chapter_number = 2
	ch2.required_previous_chapter = "ch1"
	var twin := objective.duplicate() as ObjectiveData
	twin.objective_id = "later." + objective.objective_id
	var list2: Array[ObjectiveData] = [twin]
	ch2.objectives = list2
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager._catch_up()


func _done(id: String) -> bool:
	return CampaignManager._completed_objective_ids.has(id)


func _progress(id: String) -> int:
	return int(CampaignManager._objective_progress.get(id, 0))


func _captured_details(faction: String = "royal_navy", ship_id: String = "sloop") -> Dictionary:
	return {"success": true, "captured": true, "target_faction_id": faction, "target_ship_id": ship_id}


func test_capturing_a_ship_advances_capture_ships_for_a_matching_faction_or_hull() -> void:
	_start(_objective("cap.any", ObjectiveData.Condition.CAPTURE_SHIPS, "", 2))
	CampaignManager._on_boarding_outcome("colours", _captured_details())
	assert_eq(_progress("cap.any"), 1)
	CampaignManager._on_boarding_outcome("struck", _captured_details("pirate_clans"))
	assert_true(_done("cap.any"), "two captures, either Colours outcome")
	assert_eq(_progress("later.cap.any"), 0, "a later chapter's objective never advances early")


func test_capture_ships_honours_a_faction_or_hull_target() -> void:
	_start(_objective("cap.navy", ObjectiveData.Condition.CAPTURE_SHIPS, "royal_navy"))
	CampaignManager._on_boarding_outcome("colours", _captured_details("pirate_clans"))
	assert_eq(_progress("cap.navy"), 0)
	CampaignManager._on_boarding_outcome("colours", _captured_details("royal_navy"))
	assert_true(_done("cap.navy"))
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	_start(_objective("cap.hull", ObjectiveData.Condition.CAPTURE_SHIPS, "frigate"))
	CampaignManager._on_boarding_outcome("colours", _captured_details("royal_navy", "sloop"))
	assert_eq(_progress("cap.hull"), 0)
	CampaignManager._on_boarding_outcome("colours", _captured_details("royal_navy", "frigate"))
	assert_true(_done("cap.hull"))


func test_only_a_real_capture_counts() -> void:
	_start(_objective("cap.real", ObjectiveData.Condition.CAPTURE_SHIPS, "", 5))
	CampaignManager._on_boarding_outcome("hold", _captured_details())
	CampaignManager._on_boarding_outcome("magazine", _captured_details())
	CampaignManager._on_boarding_outcome("auto_win", _captured_details())
	CampaignManager._on_boarding_outcome("colours", {"success": false, "captured": true})
	var not_captured := _captured_details()
	not_captured["captured"] = false
	CampaignManager._on_boarding_outcome("colours", not_captured)
	assert_eq(_progress("cap.real"), 0, "the Hold, the Magazine, the instant plunder, a loss and a boss do not capture")


func test_selling_a_prize_advances_sell_prize_for_a_matching_court() -> void:
	_start(_objective("sell.any", ObjectiveData.Condition.SELL_PRIZE, "", 2))
	CampaignManager._on_prize_sold({"court_id": "pirate_haven"})
	CampaignManager._on_prize_sold({"court_id": "royal_navy_court"})
	assert_true(_done("sell.any"))
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	_start(_objective("sell.haven", ObjectiveData.Condition.SELL_PRIZE, "pirate_haven"))
	CampaignManager._on_prize_sold({"court_id": "royal_navy_court"})
	assert_eq(_progress("sell.haven"), 0)
	CampaignManager._on_prize_sold({"court_id": "pirate_haven"})
	assert_true(_done("sell.haven"))


func test_a_real_sale_reaches_the_campaign_through_the_fleet_signal() -> void:
	_start(_objective("sell.real", ObjectiveData.Condition.SELL_PRIZE, "pirate_haven"))
	var prize := _fleet_with_prize(&"prize_pirate_clans")
	FleetManager.sell_prize(prize.uid, _haven)
	assert_true(_done("sell.real"), "CampaignManager listens to FleetManager.prize_sold")
