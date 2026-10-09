extends GutTest
## M30 Wave 2 (2.10): the Ship's Company. The crew is a set of named squads (role, rank, xp,
## wounds, trait) layered over ShipDamage.crew, which stays the total. Squads work sea stations
## through ONE persistent CombatModifiers layer under a stacking cap, and the boarding roles'
## stations are empty while a boarding is open. The Tavern sells Green squads only: an elite squad
## exists solely because a boarding outcome (the Brig) freed one, and the top rank only comes from
## boarding xp. An old save derives template squads from its ship's crew.

class MockShip extends RigidBody3D:
	pass

const IslandMenuScene = preload("res://scenes/ui/IslandMenu.tscn")

var _scene: Node3D
var _prev_scene: Node
var _made: Array = []
var _table: CrewRankTable
var _saved_squads: Array[OwnedSquadData]
var _saved_ships: Array[OwnedShipData]
var _saved_captains: Array[CaptainData]
var _saved_active: int
var _saved_resources: Dictionary
var _saved_xp: int
var _saved_level: int


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "CompanyWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_made = []
	_table = CrewRankTable.get_default()
	_saved_squads = FleetManager.squads.duplicate()
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_captains = FleetManager.owned_captains.duplicate()
	_saved_active = FleetManager.active_ship_index
	_saved_resources = ResourceManager.current_resources.duplicate()
	var jack: CaptainData = load("res://resources/captains/Jack.tres")
	_saved_xp = jack.current_xp
	_saved_level = jack.level
	FleetManager.squads.clear()
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")


func after_each() -> void:
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	FleetManager.squads = _saved_squads.duplicate()
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.owned_captains = _saved_captains.duplicate()
	FleetManager.active_ship_index = _saved_active
	ResourceManager.current_resources = _saved_resources.duplicate()
	var jack: CaptainData = load("res://resources/captains/Jack.tres")
	jack.current_xp = _saved_xp
	jack.level = _saved_level
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
	get_tree().paused = false
	_scene = null


func _squad(role: StringName, xp: int = 0, boarding_xp: int = 0, wounds: int = 0, trait_id: StringName = &"") -> OwnedSquadData:
	var s := OwnedSquadData.new()
	s.uid = "t%d" % (FleetManager.squads.size() + 1)
	s.squad_name = "Squad %s" % s.uid
	s.role = role
	s.xp = xp
	s.boarding_xp = boarding_xp
	s.wounds = wounds
	s.trait_id = trait_id
	return s


func _give_gold(n: int) -> void:
	ResourceManager.current_resources["gold"] = n


# === The rulebook ===

func test_the_authored_rank_table_is_coherent() -> void:
	var t: CrewRankTable = load(CrewRankTable.DEFAULT_PATH)
	assert_not_null(t)
	assert_eq(t.rank_ids.size(), t.rank_names.size())
	assert_eq(t.rank_ids.size(), t.xp_thresholds.size())
	assert_eq(t.rank_ids.size(), t.station_mults.size())
	assert_eq(t.rank_ids.size(), t.boarding_hp_per_rank.size())
	assert_eq(t.xp_thresholds[0], 0)
	for i in range(1, t.xp_thresholds.size()):
		assert_gt(t.xp_thresholds[i], t.xp_thresholds[i - 1], "ranks climb")
		assert_gt(t.station_mults[i], t.station_mults[i - 1])
	assert_lt(t.boarding_only_from_rank, t.rank_ids.size(), "the top rank is boarding-only")
	for r in t.boarding_roles:
		assert_true(r in t.roles)
	for r in t.template_roles:
		assert_true(r in t.roles)
	var valid_keys := ["fire_rate", "speed", "damage_taken", "regen"]
	for role in t.role_effects.keys():
		assert_true(StringName(role) in t.roles, "effects for an unknown role %s" % role)
		for key in t.role_effects[role].keys():
			assert_true(key in valid_keys, "%s: unknown modifier key %s" % [role, key])
			assert_true(t.stack_caps.has(key), "%s needs a stacking cap" % key)
	var seen := {}
	for tr_ in t.traits:
		assert_not_null(tr_)
		assert_false(seen.has(tr_.trait_id), "duplicate trait %s" % tr_.trait_id)
		seen[tr_.trait_id] = true
		for role in tr_.roles:
			assert_true(role in t.roles)
	assert_gte_traits(t)


func assert_gte_traits(t: CrewRankTable) -> void:
	assert_true(t.traits.size() >= 3, "a handful of traits to deal")
	for role in t.roles:
		assert_false(t.traits_for_role(role).is_empty(), "%s can be dealt a trait" % role)


func test_rank_follows_xp_but_the_top_rank_needs_boarding_xp() -> void:
	assert_eq(_table.rank_for(0, 0), 0)
	assert_eq(_table.rank_for(_table.xp_thresholds[1], 0), 1)
	assert_eq(_table.rank_for(_table.xp_thresholds[2], 0), 2)
	assert_eq(_table.rank_for(999999, 0), _table.boarding_only_from_rank - 1, "sailing alone never makes an elite")
	var top := _table.xp_thresholds[_table.xp_thresholds.size() - 1]
	assert_eq(_table.rank_for(top, top), _table.rank_count() - 1, "boarding xp does")
	assert_eq(_table.rank_for(top, top - 1), _table.boarding_only_from_rank - 1, "one short of it is not enough")


# === A squad ===

func test_a_squads_station_multiplier_is_its_ranks_plus_its_traits() -> void:
	var green := _squad(&"gunners")
	assert_eq(green.station_mult(_table), _table.station_mult(0))
	var steady := _squad(&"gunners", 0, 0, 0, &"steady")
	assert_almost_eq(steady.station_mult(_table), _table.station_mult(0) + _table.trait_by_id(&"steady").station_mult_bonus, 0.0001)
	var vet := _squad(&"gunners", _table.xp_thresholds[2])
	assert_eq(vet.rank(_table), 2)
	assert_eq(vet.station_mult(_table), _table.station_mult(2))


func test_wounds_put_a_squad_out_of_action_and_a_tough_trait_raises_the_bar() -> void:
	var s := _squad(&"marines", 0, 0, _table.wound_cap - 1)
	assert_true(s.is_fit(_table))
	s.wounds = _table.wound_cap
	assert_false(s.is_fit(_table))
	assert_eq(s.boarding_hp(_table), 0, "an out-of-action squad brings nothing aboard")
	s.trait_id = &"tough"
	assert_true(s.is_fit(_table), "Tough as Teak adds a wound before it drops")
	assert_eq(s.wound_cap(_table), _table.wound_cap + _table.trait_by_id(&"tough").wound_cap_bonus)


func test_boarding_hp_rises_with_rank_and_the_bloodied_trait() -> void:
	var green := _squad(&"marines")
	var vet := _squad(&"marines", _table.xp_thresholds[2])
	assert_gt(vet.boarding_hp(_table), green.boarding_hp(_table))
	var bloodied := _squad(&"marines", 0, 0, 0, &"bloodied")
	assert_eq(bloodied.boarding_hp(_table), green.boarding_hp(_table) + _table.trait_by_id(&"bloodied").boarding_hp_bonus)


func test_a_squad_round_trips_through_json_and_omits_an_empty_trait() -> void:
	var s := _squad(&"riggers", 120, 40, 2, &"steady")
	var back := OwnedSquadData.from_save_data(JSON.parse_string(JSON.stringify(s.get_save_data())))
	assert_eq(back.uid, s.uid)
	assert_eq(back.squad_name, s.squad_name)
	assert_eq(back.role, &"riggers")
	assert_eq(back.xp, 120)
	assert_eq(back.boarding_xp, 40)
	assert_eq(back.wounds, 2)
	assert_eq(back.trait_id, &"steady")
	assert_false(_squad(&"gunners").get_save_data().has("trait"), "an optional key is omitted at its default")
	var odd := OwnedSquadData.from_save_data({"uid": "x", "xp": 10, "boarding_xp": 99})
	assert_eq(odd.boarding_xp, 10, "boarding xp can never exceed total xp")


# === The company ===

func _fleet_with_crew(max_crew: float) -> void:
	var stats := ShipStats.new()
	stats.max_crew = max_crew
	var owned := OwnedShipData.new()
	owned.ship_stats = stats
	FleetManager.owned_ships.clear()
	FleetManager.owned_ships.append(owned)
	FleetManager.active_ship_index = 0


func test_a_company_is_derived_from_the_ships_crew_when_there_is_none() -> void:
	_fleet_with_crew(40.0)
	watch_signals(FleetManager)
	FleetManager.ensure_squads()
	assert_eq(FleetManager.squads.size(), _table.template_roles.size())
	var roles: Array = FleetManager.squads.map(func(s): return s.role)
	assert_eq(roles, _table.template_roles)
	for s in FleetManager.squads:
		assert_eq(s.headcount, 40 / _table.template_roles.size(), "the crew shared out")
		assert_eq(s.xp, 0)
		assert_ne(s.uid, "")
		assert_ne(s.squad_name, "")
	assert_signal_emitted(FleetManager, "squads_changed")
	var names := {}
	for s in FleetManager.squads:
		names[s.squad_name] = true
	assert_eq(names.size(), FleetManager.squads.size(), "named squads, no two alike")
	FleetManager.ensure_squads()
	assert_eq(FleetManager.squads.size(), _table.template_roles.size(), "idempotent")


func test_an_old_save_with_no_squads_loads_with_template_squads() -> void:
	var old := {
		"owned_ships": [{"ship_path": "res://resources/ships/Sloop.tres", "level": 2, "modules": [], "components": {}}],
		"owned_captains": [], "active_ship_index": 0, "active_captain_index": 0, "active_missions": {},
		"defend_home_ship_indices": [],
	}
	FleetManager.load_save_data(old)
	assert_eq(FleetManager.squads.size(), _table.template_roles.size())
	var sloop: ShipStats = load("res://resources/ships/Sloop.tres")
	var total := 0
	for s in FleetManager.squads:
		total += s.headcount
	assert_true(total <= int(sloop.max_crew), "the squads share out the Sloop crew, never more")
	assert_gt(total, 0)


func test_the_company_round_trips_through_save_and_load() -> void:
	_fleet_with_crew(40.0)
	FleetManager.squads.append(_squad(&"gunners", 120, 0, 1, &"keen"))
	FleetManager.squads.append(_squad(&"marines", 260, 260, 2, &"bloodied"))
	var saved := JSON.parse_string(JSON.stringify(FleetManager.get_save_data()))
	FleetManager.squads.clear()
	FleetManager.load_save_data(saved)
	assert_eq(FleetManager.squads.size(), 2, "a saved company is kept as it was, not re-derived")
	assert_eq(FleetManager.squads[0].trait_id, &"keen")
	assert_eq(FleetManager.squads[1].wounds, 2)
	assert_eq(FleetManager.squads[1].rank(_table), _table.rank_count() - 1)


# === The Tavern ===

func test_the_tavern_sells_green_squads_for_gold() -> void:
	_fleet_with_crew(40.0)
	FleetManager.ensure_squads()
	_give_gold(1000)
	var before := FleetManager.squads.size()
	var s := FleetManager.hire_squad(&"gunners")
	assert_not_null(s)
	assert_eq(FleetManager.squads.size(), before + 1)
	assert_eq(s.rank(_table), 0, "always Green")
	assert_eq(s.xp, 0)
	assert_eq(s.headcount, _table.squad_headcount)
	assert_eq(ResourceManager.get_resource("gold"), 1000 - _table.hire_cost_gold)
	assert_eq(s.trait_id, &"")


func test_the_tavern_refuses_what_it_cannot_sell() -> void:
	_fleet_with_crew(40.0)
	FleetManager.ensure_squads()
	_give_gold(10)
	assert_null(FleetManager.hire_squad(&"gunners"), "no gold")
	_give_gold(100000)
	assert_null(FleetManager.hire_squad(&"pirates"), "no such role")
	while FleetManager.squads.size() < _table.max_squads:
		FleetManager.hire_squad(&"riggers")
	var gold := ResourceManager.get_resource("gold")
	assert_null(FleetManager.hire_squad(&"riggers"), "the company is full")
	assert_eq(ResourceManager.get_resource("gold"), gold, "and a refusal costs nothing")


func test_nothing_the_tavern_or_the_voyage_can_do_makes_an_elite_squad() -> void:
	_fleet_with_crew(40.0)
	_give_gold(100000)
	var s := FleetManager.hire_squad(&"marines")
	FleetManager.award_squad_xp(s, 100000, false)
	assert_eq(s.rank(_table), _table.boarding_only_from_rank - 1, "a lifetime at sea tops out at Veteran")
	assert_lt(s.rank(_table), _table.rank_count() - 1)
	for sq in FleetManager.squads:
		assert_lt(sq.rank(_table), _table.rank_count() - 1, "no elite squad in the company")


# === Promotion and traits ===

func test_a_new_rank_deals_a_trait_that_suits_the_role_and_always_the_same_one() -> void:
	var a := _squad(&"gunners")
	var b := _squad(&"gunners")
	b.uid = a.uid
	FleetManager.squads.append(a)
	FleetManager.award_squad_xp(a, _table.xp_thresholds[1])
	assert_ne(a.trait_id, &"", "promotion earns a trait")
	var t := _table.trait_by_id(a.trait_id)
	assert_true(t.roles.is_empty() or &"gunners" in t.roles, "a trait that suits gunners")
	FleetManager.squads.append(b)
	FleetManager.award_squad_xp(b, _table.xp_thresholds[1])
	assert_eq(b.trait_id, a.trait_id, "deterministic per squad")
	var held := a.trait_id
	FleetManager.award_squad_xp(a, _table.xp_thresholds[2])
	assert_eq(a.trait_id, held, "a squad keeps the trait it was dealt")


func test_xp_below_a_threshold_changes_no_rank_and_deals_nothing() -> void:
	var s := _squad(&"riggers")
	FleetManager.squads.append(s)
	FleetManager.award_squad_xp(s, _table.xp_thresholds[1] - 1)
	assert_eq(s.rank(_table), 0)
	assert_eq(s.trait_id, &"")
	FleetManager.award_squad_xp(s, 0)
	FleetManager.award_squad_xp(s, -5)
	assert_eq(s.xp, _table.xp_thresholds[1] - 1)


func test_dock_healing_mends_wounds_down_to_zero() -> void:
	var s := _squad(&"marines", 0, 0, 2)
	FleetManager.squads.append(s)
	FleetManager.heal_squads(1)
	assert_eq(s.wounds, 1)
	FleetManager.heal_squads(5)
	assert_eq(s.wounds, 0)


# === Boarding changes the company ===

func test_a_boarding_wounds_and_trains_the_boarding_squads_only() -> void:
	var marines := _squad(&"marines")
	var gunners := _squad(&"gunners")
	FleetManager.squads.append(marines)
	FleetManager.squads.append(gunners)
	FleetManager.apply_boarding_result({"success": true, "casualty_ratio": 0.5})
	assert_eq(marines.wounds, int(ceil(0.5 * _table.boarding_wounds_max)))
	assert_eq(marines.xp, _table.boarding_xp_win)
	assert_eq(marines.boarding_xp, _table.boarding_xp_win, "boarding xp, which is what reaches the top rank")
	assert_eq(gunners.wounds, 0, "the gunners stayed at their guns")
	assert_eq(gunners.xp, 0)


func test_losing_trains_less_and_an_unscathed_win_wounds_nobody() -> void:
	var m := _squad(&"marines")
	FleetManager.squads.append(m)
	FleetManager.apply_boarding_result({"success": false, "casualty_ratio": 1.0})
	assert_eq(m.xp, _table.boarding_xp_loss)
	assert_eq(m.wounds, _table.boarding_wounds_max)
	var m2 := _squad(&"marines")
	FleetManager.squads.append(m2)
	FleetManager.apply_boarding_result({"success": true, "casualty_ratio": 0.0})
	assert_eq(m2.wounds, 0)


func test_a_squad_that_is_out_of_action_does_not_board() -> void:
	var hurt := _squad(&"marines", 0, 0, _table.wound_cap)
	FleetManager.squads.append(hurt)
	FleetManager.apply_boarding_result({"success": true, "casualty_ratio": 1.0})
	assert_eq(hurt.xp, 0)
	assert_eq(hurt.wounds, _table.wound_cap)


func test_the_brig_frees_an_elite_squad_and_only_on_a_win() -> void:
	_fleet_with_crew(40.0)
	FleetManager.apply_boarding_result({"success": false, "grants_elite_squad": true})
	assert_eq(FleetManager.squads.size(), 0, "a lost boarding frees no one")
	FleetManager.apply_boarding_result({"success": true, "grants_elite_squad": true})
	assert_eq(FleetManager.squads.size(), 1)
	var elite := FleetManager.squads[0]
	assert_eq(elite.rank(_table), _table.rank_count() - 1, "the only way an elite squad is made")
	assert_eq(elite.role, &"marines")
	assert_ne(elite.trait_id, &"")
	assert_eq(elite.squad_name, "Freed Prisoners")


func test_a_full_company_cannot_take_the_freed_prisoners() -> void:
	_fleet_with_crew(40.0)
	while FleetManager.squads.size() < _table.max_squads:
		FleetManager.squads.append(_squad(&"gunners"))
	FleetManager.apply_boarding_result({"success": true, "grants_elite_squad": true})
	assert_eq(FleetManager.squads.size(), _table.max_squads)


func test_the_cabin_pays_the_captain_on_a_win() -> void:
	var jack: CaptainData = load("res://resources/captains/Jack.tres")
	FleetManager.owned_captains.clear()
	FleetManager.owned_captains.append(jack)
	FleetManager.active_captain_index = 0
	var xp_before := jack.current_xp
	var level_before := jack.level
	FleetManager.apply_boarding_result({"success": false, "captain_xp": 25})
	assert_eq(jack.current_xp, xp_before, "no papers from a lost boarding")
	FleetManager.apply_boarding_result({"success": true, "captain_xp": 25})
	assert_true(jack.current_xp != xp_before or jack.level != level_before, "the officers' papers were worth something")


func test_the_boarding_party_grows_with_its_fit_marines() -> void:
	FleetManager.squads.append(_squad(&"marines", _table.xp_thresholds[2]))
	FleetManager.squads.append(_squad(&"marines", 0, 0, _table.wound_cap))  # out of action
	FleetManager.squads.append(_squad(&"gunners", _table.xp_thresholds[2]))  # not a boarding role
	assert_eq(FleetManager.boarding_hp_bonus(), _table.boarding_hp_per_rank[2])
	var rules := BoardingData.new()
	var profile := BoardingDeckProfile.new()
	var base := BoardingDeckBuilder.build(profile, rules, {"player_crew": 40.0})
	var boosted := BoardingDeckBuilder.build(profile, rules, {"player_crew": 40.0, "squad_hp": 4})
	assert_eq(boosted.player_hp, base.player_hp + 4)


# === Brig and Cabin ===

func _objective(name: String) -> BoardingObjectiveData:
	return load("res://resources/combat/boarding/objectives/%s.tres" % name)


func test_brig_and_cabin_are_authored_with_their_rewards() -> void:
	var brig := _objective("Brig")
	var cabin := _objective("Cabin")
	assert_eq(brig.outcome_id, &"brig")
	assert_true(brig.grants_elite_squad)
	assert_eq(brig.zone, BoardingZone.Id.HOLD)
	assert_false(brig.captures_ship)
	assert_eq(cabin.outcome_id, &"cabin")
	assert_gt(cabin.captain_xp, 0)
	assert_false(cabin.grants_elite_squad)
	var navy: BoardingDeckProfile = load("res://resources/combat/boarding/profiles/RoyalNavySmall.tres")
	var spanish: BoardingDeckProfile = load("res://resources/combat/boarding/profiles/SpanishEmpire.tres")
	assert_true(navy.objectives.any(func(o): return o.outcome_id == &"brig"), "Navy ships keep a brig")
	assert_true(spanish.objectives.any(func(o): return o.outcome_id == &"cabin"), "a Spanish great cabin")


func _seize(objective_name: String, zone: int) -> Dictionary:
	var deck := BoardingDeck.new()
	deck.entry_zone = zone
	deck.objectives = [_objective(objective_name)]
	var battle := BoardingBattle.new(deck, BoardingData.new(), 1)
	battle.ring_bell()
	return battle.outcome


func test_seizing_the_brig_or_the_cabin_ends_the_battle_with_its_reward() -> void:
	var brig := _seize("Brig", BoardingZone.Id.HOLD)
	assert_eq(brig["id"], "brig")
	assert_true(brig["success"])
	assert_true(brig["grants_elite_squad"])
	var cabin := _seize("Cabin", BoardingZone.Id.FORECASTLE)
	assert_eq(cabin["id"], "cabin")
	assert_eq(cabin["captain_xp"], 25)
	assert_false(_seize("Colours", BoardingZone.Id.QUARTERDECK)["grants_elite_squad"])


# === Sea stations ===

func test_gunners_riggers_marines_and_surgeons_each_move_their_own_stat() -> void:
	for pair in [[&"gunners", "fire_rate"], [&"riggers", "speed"], [&"marines", "damage_taken"], [&"surgeons", "regen"]]:
		var layer := CrewStationApplier.compute_effects([_squad(pair[0])], _table, false)
		assert_eq(layer.keys(), [pair[1]], "%s move only %s" % [pair[0], pair[1]])
	assert_lt(CrewStationApplier.compute_effects([_squad(&"marines")], _table, false)["damage_taken"], 1.0,
		"marines at their post cut damage taken")
	assert_gt(CrewStationApplier.compute_effects([_squad(&"gunners")], _table, false)["fire_rate"], 1.0)
	assert_gt(CrewStationApplier.compute_effects([_squad(&"surgeons")], _table, false)["regen"], 0.0)
	assert_true(CrewStationApplier.compute_effects([], _table, false).is_empty())


func test_rank_and_trait_scale_the_station_bonus() -> void:
	var green: float = CrewStationApplier.compute_effects([_squad(&"gunners")], _table, false)["fire_rate"] - 1.0
	var vet: float = CrewStationApplier.compute_effects([_squad(&"gunners", _table.xp_thresholds[2])], _table, false)["fire_rate"] - 1.0
	assert_almost_eq(vet / green, _table.station_mult(2) / _table.station_mult(0), 0.0001)
	var keen: float = CrewStationApplier.compute_effects([_squad(&"gunners", 0, 0, 0, &"keen")], _table, false)["fire_rate"] - 1.0
	assert_gt(keen, green)


func test_the_stacking_cap_holds() -> void:
	var many: Array = []
	for i in 12:
		many.append(_squad(&"gunners", _table.xp_thresholds[2]))
		many.append(_squad(&"marines", _table.xp_thresholds[2]))
		many.append(_squad(&"surgeons", _table.xp_thresholds[2]))
		many.append(_squad(&"riggers", _table.xp_thresholds[2]))
	var layer := CrewStationApplier.compute_effects(many, _table, false)
	assert_almost_eq(layer["fire_rate"], 1.0 + float(_table.stack_caps["fire_rate"]), 0.0001)
	assert_almost_eq(layer["speed"], 1.0 + float(_table.stack_caps["speed"]), 0.0001)
	assert_almost_eq(layer["damage_taken"], 1.0 + float(_table.stack_caps["damage_taken"]), 0.0001, "the cap on a reduction")
	assert_almost_eq(layer["regen"], float(_table.stack_caps["regen"]), 0.0001)
	# One more squad changes nothing once capped.
	many.append(_squad(&"gunners", _table.xp_thresholds[2]))
	assert_eq(CrewStationApplier.compute_effects(many, _table, false)["fire_rate"], layer["fire_rate"])


func test_wounded_out_of_action_squads_work_no_station() -> void:
	var hurt := _squad(&"gunners", 0, 0, _table.wound_cap)
	assert_true(CrewStationApplier.compute_effects([hurt], _table, false).is_empty())


func test_the_boarding_roles_leave_their_stations_while_boarding() -> void:
	var squads := [_squad(&"marines"), _squad(&"gunners")]
	var at_sea := CrewStationApplier.compute_effects(squads, _table, false)
	var boarding := CrewStationApplier.compute_effects(squads, _table, true)
	assert_true(at_sea.has("damage_taken"))
	assert_false(boarding.has("damage_taken"), "the marines are over the side")
	assert_true(boarding.has("fire_rate"), "the gunners stayed at their guns")


# === The applier on a ship ===

func _player_rig() -> Dictionary:
	var system := BoardingSystem.new()
	system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(system)
	_made.append(system)
	var ship := MockShip.new()
	ship.add_to_group("player_ship")
	var mods := CombatModifiers.new()
	mods.name = "CombatModifiers"
	ship.add_child(mods)
	_scene.add_child(ship)
	_made.append(ship)
	var applier := CrewStationApplier.new()
	applier.name = "CrewStationApplier"
	ship.add_child(applier)
	return {"system": system, "ship": ship, "mods": mods, "applier": applier}


func test_the_applier_keeps_one_persistent_layer_in_step_with_the_company() -> void:
	var rig := _player_rig()
	var mods: CombatModifiers = rig["mods"]
	assert_false(mods.has_persistent_layer(CrewStationApplier.LAYER) and mods.fire_rate_mult > 1.0, "an empty company adds nothing")
	FleetManager.squads.append(_squad(&"gunners", _table.xp_thresholds[2]))
	FleetManager.squads_changed.emit()
	assert_true(mods.has_persistent_layer(CrewStationApplier.LAYER))
	assert_gt(mods.fire_rate_mult, 1.0, "the gunners are at their guns")
	FleetManager.squads.clear()
	FleetManager.squads_changed.emit()
	assert_eq(mods.fire_rate_mult, 1.0)


func test_a_maelstrom_run_is_closed_to_the_company() -> void:
	var rig := _player_rig()
	var mods: CombatModifiers = rig["mods"]
	FleetManager.squads.append(_squad(&"gunners", _table.xp_thresholds[2]))
	FleetManager.squads_changed.emit()
	assert_gt(mods.fire_rate_mult, 1.0, "precondition: the campaign company works")
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	FleetManager.squads_changed.emit()
	assert_eq(mods.fire_rate_mult, 1.0, "nothing from the campaign carries into a Maelstrom run")
	assert_false(mods.has_persistent_layer(CrewStationApplier.LAYER))
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	FleetManager.squads_changed.emit()
	assert_gt(mods.fire_rate_mult, 1.0)


func test_the_layer_survives_an_encounter_reset() -> void:
	var rig := _player_rig()
	var mods: CombatModifiers = rig["mods"]
	FleetManager.squads.append(_squad(&"gunners", _table.xp_thresholds[2]))
	FleetManager.squads_changed.emit()
	var with_crew := mods.fire_rate_mult
	mods.reset()
	assert_eq(mods.fire_rate_mult, with_crew, "a persistent layer outlives a battle")


func test_stations_are_suspended_while_a_boarding_is_open_and_restored_after() -> void:
	var rig := _player_rig()
	var mods: CombatModifiers = rig["mods"]
	var system: BoardingSystem = rig["system"]
	var applier: CrewStationApplier = rig["applier"]
	FleetManager.squads.append(_squad(&"marines", _table.xp_thresholds[2]))
	FleetManager.squads.append(_squad(&"gunners"))
	FleetManager.squads_changed.emit()
	assert_lt(mods.damage_taken_mult, 1.0, "marines at their post")
	var fire_rate := mods.fire_rate_mult

	var enemy := MockShip.new()
	_scene.add_child(enemy)
	_made.append(enemy)
	system._locked_enemy = enemy  # a tactical boarding is open
	applier._process(0.0)
	assert_eq(mods.damage_taken_mult, 1.0, "the marines are over the side")
	assert_eq(mods.fire_rate_mult, fire_rate, "the gunners are not")

	system._locked_enemy = null
	applier._process(0.0)
	assert_lt(mods.damage_taken_mult, 1.0, "back at their post when it is over")


func test_the_player_ship_gets_an_applier_and_an_enemy_does_not() -> void:
	var player := preload("res://scenes/world/EnemyShip.tscn").instantiate()
	player.remove_from_group("enemy_ship")
	player.add_to_group("player_ship")
	_scene.add_child(player)
	_made.append(player)
	assert_not_null(player.get_node_or_null("CrewStationApplier"))
	var enemy := preload("res://scenes/world/EnemyShip.tscn").instantiate()
	_scene.add_child(enemy)
	_made.append(enemy)
	assert_null(enemy.get_node_or_null("CrewStationApplier"))


# === The whole thing: a boarding changes the company ===

func test_a_brig_boarding_frees_an_elite_squad_through_the_applier() -> void:
	_fleet_with_crew(40.0)
	var rig := _player_rig()
	var system: BoardingSystem = rig["system"]
	var ship_stats := ShipStats.new()
	ship_stats.max_crew = 100.0
	var pdmg = load("res://scripts/world/ShipDamage.gd").new()
	pdmg.name = "ShipDamage"
	pdmg.ship_stats = ship_stats
	rig["ship"].add_child(pdmg)
	pdmg.crew = 100.0
	var enemy := MockShip.new()
	enemy.add_to_group("enemy_ship")
	var estats := ShipStats.new()
	estats.max_crew = 100.0
	var edmg = load("res://scripts/world/ShipDamage.gd").new()
	edmg.name = "ShipDamage"
	edmg.ship_stats = estats
	enemy.add_child(edmg)
	edmg.crew = 100.0
	_scene.add_child(enemy)
	_made.append(enemy)
	FleetManager.squads.append(_squad(&"marines"))
	var before := FleetManager.squads.size()
	system._eligible_enemy = enemy
	system.begin_boarding()
	system.resolve_tactical("brig", true, {"captures_ship": false, "grants_elite_squad": true, "casualty_ratio": 0.25})
	assert_eq(FleetManager.squads.size(), before + 1, "a freed squad joined")
	assert_eq(FleetManager.squads.back().rank(_table), _table.rank_count() - 1)
	assert_gt(FleetManager.squads[0].boarding_xp, 0, "the marines who fought earned boarding xp")


# === Tavern UI ===

func test_the_tavern_lists_the_company_and_offers_green_squads() -> void:
	_fleet_with_crew(40.0)
	FleetManager.ensure_squads()
	_give_gold(5000)
	var menu := IslandMenuScene.instantiate()
	_scene.add_child(menu)
	_made.append(menu)
	await wait_process_frames(2)
	menu._refresh_captains()
	var labels: Array = menu.captains_container.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_true(labels.any(func(t): return t.contains("Ship's Company")), "the company is listed")
	assert_true(labels.any(func(t): return t.contains("Marlow")), "its named squads are shown")
	var buttons: Array = menu.captains_container.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("Hire "))
	assert_eq(buttons.size(), _table.roles.size(), "one hire button per role")
	buttons[0].emit_signal("pressed")
	assert_eq(FleetManager.squads.size(), _table.template_roles.size() + 1, "a click hires one")
