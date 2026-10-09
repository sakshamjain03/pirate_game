extends GutTest
## M30 Wave 2 (2.11): Captain Orders, Nemesis officers, and the Infirmary / Training Yard.
##   - Orders on a captain's ability change the boarding rules: Board First makes the captain a hero
##     (more boarders, harder melee blows), No Quarter closes the surrender (only an objective ends
##     the fight; winning that way earns Dread), +CP gives a bell more command points.
##   - An officer who escapes is remembered by EmpireManager and reappears PROMOTED on the next
##     ship of their faction; seizing a ship with the officers aboard ends them and pays the bounty.
##   - A Tavern is an Infirmary and a Fortress a Training Yard: the best of each at the port mends
##     more wounds / drills the company when the player docks.

class MockShip extends RigidBody3D:
	var faction: FactionData = null
	var active_captain: CaptainData = null

var _scene: Node3D
var _prev_scene: Node
var _made: Array = []
var _rules: BoardingData
var _table: CrewRankTable
var _saved_nemeses: Dictionary
var _saved_axis: float
var _saved_resources: Dictionary
var _saved_squads: Array[OwnedSquadData]
var _saved_quick: bool


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "OrdersWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_made = []
	_rules = BoardingData.new()
	_table = CrewRankTable.get_default()
	_saved_nemeses = EmpireManager.nemeses.duplicate(true)
	_saved_axis = EmpireManager.axis
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_squads = FleetManager.squads.duplicate()
	_saved_quick = SettingsManager.quick_boarding
	SettingsManager.quick_boarding = false
	EmpireManager.nemeses.clear()
	EmpireManager.axis = 0.0
	FleetManager.squads.clear()
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")


func after_each() -> void:
	get_tree().paused = false
	EmpireManager.nemeses = _saved_nemeses.duplicate(true)
	EmpireManager.axis = _saved_axis
	ResourceManager.current_resources = _saved_resources.duplicate()
	FleetManager.squads = _saved_squads.duplicate()
	SettingsManager.quick_boarding = _saved_quick
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


func _ability(captain_file: String) -> CaptainAbilityData:
	return (load("res://resources/captains/%s.tres" % captain_file) as CaptainData).active_ability


func _action(id: StringName) -> BoardingActionData:
	for a in (load("res://resources/combat/Boarding.tres") as BoardingData).actions:
		if a.id == id:
			return a
	return null


func _foe(hp: int = 20) -> DefenderData:
	var d := DefenderData.new()
	d.hp = hp
	d.attack = 1
	return d


## A deck with one defender in the landing zone and an objective far away, so nothing ends early.
func _deck(foe: DefenderData = null) -> BoardingDeck:
	var deck := BoardingDeck.new()
	deck.entry_zone = BoardingZone.Id.WAIST
	deck.hull_fraction = 0.3
	deck.defenders = [{"data": foe if foe else _foe(), "zone": BoardingZone.Id.WAIST}]
	var colours := load("res://resources/combat/boarding/objectives/Colours.tres") as BoardingObjectiveData
	deck.objectives = [colours]
	return deck


# === Orders are authored on the captains ===

func test_captain_orders_are_authored_on_the_abilities() -> void:
	assert_true(_ability("Cutlass").board_first)
	assert_true(_ability("Redbeard").no_quarter)
	assert_eq(_ability("Mary").boarding_cp_bonus, 1)
	assert_true(_ability("Cutlass").has_boarding_orders())
	assert_false(_ability("Jack").has_boarding_orders(), "most captains give no boarding order")
	assert_gt(_ability("Cutlass").hero_hp, 0)
	assert_gt(_ability("Cutlass").hero_damage_bonus, 0)


# === Board First: the captain is a hero ===

func test_board_first_adds_a_hero_with_boarders_to_the_deck() -> void:
	var profile := BoardingDeckProfile.new()
	var plain := BoardingDeckBuilder.build(profile, _rules, {"player_crew": 40.0})
	var ability := _ability("Cutlass")
	var led := BoardingDeckBuilder.build(profile, _rules, {"player_crew": 40.0, "orders": {
		"board_first": true, "hero_name": "Kane", "hero_hp": ability.hero_hp, "hero_damage": ability.hero_damage_bonus}})
	assert_eq(led.hero["name"], "Kane")
	assert_eq(led.player_hp, plain.player_hp + ability.hero_hp, "the hero's hit points join the party")
	assert_true(plain.hero.is_empty())


func test_the_heros_blows_land_harder_in_melee_but_not_at_range() -> void:
	var cutlass := _action(&"cutlass")
	var pistol := _action(&"pistol")
	var plain := BoardingBattle.new(_deck(), _rules, 1)
	plain.queue_action(cutlass, plain.defenders[0].uid)
	plain.ring_bell()
	var plain_hp: int = plain.log.filter(func(e): return e["type"] == "hit")[0]["damage"]

	var deck := _deck()
	deck.hero = {"name": "Kane", "hp": 6, "damage": 2}
	var led := BoardingBattle.new(deck, _rules, 1)
	led.queue_action(cutlass, led.defenders[0].uid)
	led.queue_action(pistol, led.defenders[0].uid)
	led.ring_bell()
	var hits := led.log.filter(func(e): return e["type"] == "hit")
	assert_eq(hits[0]["damage"], plain_hp + 2, "Kane's cutlass")
	assert_eq(hits[1]["damage"], pistol.damage, "the pistol is just a pistol")


func test_cutlass_enters_as_a_hero_through_the_boarding_system() -> void:
	var rig := _rig()
	rig["player"].active_captain = load("res://resources/captains/Cutlass.tres")
	var system: BoardingSystem = rig["system"]
	assert_true(system.begin_boarding())
	assert_false(system.deck.hero.is_empty(), "Cutlass leads the boarding")
	assert_eq(system.battle.hero["name"], (load("res://resources/captains/Cutlass.tres") as CaptainData).captain_name)
	system.cancel_boarding()
	rig["player"].active_captain = load("res://resources/captains/Jack.tres")
	system._eligible_enemy = rig["enemy"]
	system.begin_boarding()
	assert_true(system.deck.hero.is_empty(), "Jack gives no such order")


func test_the_overlay_names_the_hero_and_the_order() -> void:
	var rig := _rig()
	rig["player"].active_captain = load("res://resources/captains/Redbeard.tres")
	var overlay := (load("res://scenes/ui/BoardingOverlay.tscn") as PackedScene).instantiate() as BoardingOverlay
	_scene.add_child(overlay)
	_made.append(overlay)
	overlay.bind_boarding_system(rig["system"])
	rig["system"].begin_boarding()
	assert_string_contains(overlay._title.text, "No quarter")
	overlay.cut_loose()
	overlay.finish()


# === No Quarter: no surrender ===

func _weak_morale_deck(no_quarter: bool) -> BoardingDeck:
	var deck := _deck()
	deck.morale = _rules.strike_morale  # already at the line
	deck.no_quarter = no_quarter
	# `build` never starts a battle struck; this one does, to isolate the rule.
	return deck


func test_no_quarter_disables_surrender() -> void:
	var plain := BoardingBattle.new(_weak_morale_deck(false), _rules, 1)
	plain.ring_bell()
	assert_true(plain.is_over())
	assert_eq(plain.outcome["id"], "struck", "without the order the crew gives up at the line")

	var grim := BoardingBattle.new(_weak_morale_deck(true), _rules, 1)
	grim.ring_bell()
	assert_false(grim.is_over(), "under No Quarter nobody surrenders")
	for i in 5:
		if not grim.is_over():
			grim.ring_bell()
	assert_ne(grim.outcome.get("id", ""), "struck", "only an objective or the last bell ends it")


func test_winning_under_no_quarter_earns_dread_and_losing_does_not() -> void:
	var rig := _rig()
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	system.resolve_tactical("colours", true, {"captures_ship": true, "no_quarter": true})
	assert_eq(EmpireManager.axis, NotorietyGainsData.get_default().dread_no_quarter)
	EmpireManager.axis = 0.0
	var rig2 := _rig()
	rig2["system"].begin_boarding()
	rig2["system"].resolve_tactical("cut_loose", false, {"no_quarter": true})
	assert_eq(EmpireManager.axis, 0.0)
	var rig3 := _rig()
	rig3["system"].begin_boarding()
	rig3["system"].resolve_tactical("colours", true, {"captures_ship": true})
	assert_eq(EmpireManager.axis, 0.0, "a normal win is neither")


# === +CP ===

func test_extra_cp_applies_every_bell() -> void:
	var deck := _deck()
	deck.cp_bonus = 1
	var b := BoardingBattle.new(deck, _rules, 1)
	assert_eq(b.cp_left(), _rules.bell_cp + 1)
	b.ring_bell()
	assert_eq(b.cp_left(), _rules.bell_cp + 1, "the bonus is for every bell")
	var plain := BoardingBattle.new(_deck(), _rules, 1)
	assert_eq(plain.cp_left(), _rules.bell_cp)


func test_a_negative_cp_bonus_is_ignored() -> void:
	var built := BoardingDeckBuilder.build(BoardingDeckProfile.new(), _rules, {"orders": {"cp_bonus": -4}})
	assert_eq(built.cp_bonus, 0)


# === Nemesis officers ===

func test_every_faction_has_an_authored_officer_with_a_promotion_ladder() -> void:
	for faction in ["royal_navy", "spanish_empire", "pirate_clans", "merchant_guild"]:
		var o := EnemyCaptainData.for_faction(faction)
		assert_not_null(o, faction)
		assert_ne(o.captain_id, "")
		assert_true(o.titles.size() >= 3, "a ladder to climb")
		assert_eq(EnemyCaptainData.by_id(o.captain_id).faction_id, faction)
		assert_gt(o.hp_per_promotion, 0)
	assert_null(EnemyCaptainData.for_faction("ghost_fleet"))
	assert_null(EnemyCaptainData.for_faction(""))


func test_titles_and_the_poster_follow_the_promotion() -> void:
	var o := EnemyCaptainData.for_faction("royal_navy")
	assert_eq(o.title_for(0), "Lieutenant")
	assert_eq(o.title_for(1), "Captain")
	assert_eq(o.title_for(99), o.titles[o.titles.size() - 1], "capped at the top")
	assert_eq(o.title_for(-3), "Lieutenant")
	assert_string_contains(o.full_name(1), o.display_name)
	assert_string_contains(o.poster(1), "WANTED")
	assert_string_contains(o.poster(1), str(o.bounty(1)))
	assert_gt(o.bounty(2), o.bounty(0), "a promoted officer is worth more")


func test_an_escaped_officer_is_remembered_and_promoted_with_each_escape() -> void:
	watch_signals(EmpireManager)
	var first := EmpireManager.register_officer_escape("royal_navy")
	assert_eq(first["escapes"], 1)
	assert_eq(first["title"], "Captain", "reappears promoted")
	var second := EmpireManager.register_officer_escape("royal_navy")
	assert_eq(second["title"], "Commodore")
	var third := EmpireManager.register_officer_escape("royal_navy")
	assert_eq(third["title"], "Commodore", "the ladder ends")
	assert_eq(third["escapes"], 3)
	assert_signal_emit_count(EmpireManager, "nemesis_changed", 3)
	assert_eq(EmpireManager.register_officer_escape("ghost_fleet"), {}, "no officer authored for that faction")
	assert_eq(EmpireManager.nemesis_for_faction("royal_navy")["promotion"], 2)
	assert_true(EmpireManager.nemesis_for_faction("pirate_clans").is_empty(), "other factions are unaffected")
	assert_eq(EmpireManager.get_wanted_posters().size(), 1)
	assert_string_contains(EmpireManager.get_wanted_posters()[0], "Commodore")


func test_the_nemesis_registry_is_saved_only_while_it_has_entries() -> void:
	assert_false(EmpireManager.get_save_data().has("nemeses"), "omitted when empty")
	EmpireManager.register_officer_escape("spanish_empire")
	EmpireManager.register_officer_escape("spanish_empire")
	var saved := JSON.parse_string(JSON.stringify(EmpireManager.get_save_data()))
	EmpireManager.nemeses.clear()
	EmpireManager.load_save_data(saved)
	assert_eq(EmpireManager.nemesis_for_faction("spanish_empire")["promotion"], 2)
	EmpireManager.load_save_data({"notoriety": 0.0})
	assert_true(EmpireManager.nemeses.is_empty(), "an older save has none, and none is left over")


func test_a_returning_officer_is_promoted_on_the_next_deck() -> void:
	var profile := BoardingDeckProfile.new()
	var officer := DefenderData.new()
	officer.hp = 8
	officer.attack = 3
	officer.is_officer = true
	profile.defenders = [officer]
	var foe := EnemyCaptainData.for_faction("royal_navy")
	var base := BoardingDeckBuilder.build(profile, _rules, {})
	var back := BoardingDeckBuilder.build(profile, _rules, {"nemesis": {"captain": foe, "promotion": 2}})
	assert_eq(back.defenders[0]["hp"], base.defenders[0]["hp"] + 2 * foe.hp_per_promotion)
	assert_eq(back.defenders[0]["attack_bonus"], 2 * foe.attack_per_promotion)
	assert_eq(back.defenders[0]["label"], foe.full_name(2), "named, with the new title")
	assert_false(base.defenders[0].has("label"))
	var battle := BoardingBattle.new(back, _rules, 1)
	assert_eq(battle.defenders[0].label, foe.full_name(2))
	assert_eq(battle.defenders[0].attack_bonus, 2 * foe.attack_per_promotion)


func test_a_nemeses_attack_bonus_hits_the_party_harder() -> void:
	var slash := DefenderIntentData.new()
	slash.kind = DefenderIntentData.Kind.STRIKE
	var boss := DefenderData.new()
	boss.hp = 50
	boss.attack = 2
	boss.is_officer = true
	boss.intents = [slash]
	var deck := BoardingDeck.new()
	deck.entry_zone = BoardingZone.Id.WAIST
	deck.hull_fraction = 0.3
	deck.player_hp = 30
	deck.defenders = [{"data": boss, "zone": BoardingZone.Id.WAIST, "attack_bonus": 3}]
	deck.objectives = [load("res://resources/combat/boarding/objectives/Colours.tres")]
	var b := BoardingBattle.new(deck, _rules, 1)
	b.ring_bell()
	assert_eq(30 - b.player_hp, 2 + 3, "attack 2 plus the promotion bonus 3")


# === A boarding against a faction with a Nemesis ===

func _rig(faction_file: String = "RoyalNavy") -> Dictionary:
	var system := BoardingSystem.new()
	system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(system)
	_made.append(system)
	var player := MockShip.new()
	player.add_to_group("player_ship")
	var pstats := ShipStats.new()
	pstats.max_crew = 100.0
	var pdmg = load("res://scripts/world/ShipDamage.gd").new()
	pdmg.name = "ShipDamage"
	pdmg.ship_stats = pstats
	player.add_child(pdmg)
	pdmg.crew = 100.0
	_scene.add_child(player)
	_made.append(player)
	var enemy := MockShip.new()
	enemy.faction = load("res://resources/factions/%s.tres" % faction_file)
	enemy.add_to_group("enemy_ship")
	var estats := ShipStats.new()
	estats.max_crew = 100.0
	estats.ship_id = "sloop"
	var edmg = load("res://scripts/world/ShipDamage.gd").new()
	edmg.name = "ShipDamage"
	edmg.ship_stats = estats
	enemy.add_child(edmg)
	edmg.crew = 100.0
	_scene.add_child(enemy)
	_made.append(enemy)
	system._eligible_enemy = enemy
	return {"system": system, "player": player, "enemy": enemy}


func test_officers_who_escape_a_boarding_are_remembered() -> void:
	var rig := _rig()
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	system.resolve_tactical("cut_loose", false, {"officers_escaped": true})
	assert_eq(EmpireManager.nemesis_for_faction("royal_navy")["promotion"], 1)


func test_the_next_ship_of_that_faction_carries_the_officer_back_promoted() -> void:
	EmpireManager.register_officer_escape("royal_navy")
	var rig := _rig()
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	var officers := system.battle.defenders.filter(func(d): return d.data.is_officer)
	assert_false(officers.is_empty(), "the Default/Navy profile carries an officer")
	var foe := EnemyCaptainData.for_faction("royal_navy")
	assert_eq(officers[0].label, foe.full_name(1), "Captain Hargreave, not an anonymous officer")
	assert_eq(officers[0].attack_bonus, foe.attack_per_promotion)
	system.cancel_boarding()
	var other := _rig("PirateClans")
	other["system"].begin_boarding()
	assert_true(other["system"].battle.defenders.filter(func(d): return d.label != "").is_empty(),
		"another faction's ships carry nobody special")


func test_seizing_the_ship_with_the_officers_aboard_ends_the_nemesis_and_pays_the_bounty() -> void:
	EmpireManager.register_officer_escape("royal_navy")
	var foe := EnemyCaptainData.for_faction("royal_navy")
	ResourceManager.current_resources["gold"] = 0
	var rig := _rig()
	var system: BoardingSystem = rig["system"]
	system.begin_boarding()
	watch_signals(EmpireManager)
	system.resolve_tactical("colours", true, {"captures_ship": true, "officers_escaped": false})
	assert_true(EmpireManager.nemesis_for_faction("royal_navy").is_empty(), "finished")
	assert_true(ResourceManager.get_resource("gold") >= foe.bounty(1), "the bounty is paid (plus whatever the hold yielded)")
	var gone: Dictionary = get_signal_parameters(EmpireManager, "nemesis_changed")[0]
	assert_eq(gone["escapes"], 0, "the poster comes down")


func test_capturing_the_officers_pays_exactly_the_bounty_for_their_promotion() -> void:
	EmpireManager.register_officer_escape("spanish_empire")
	EmpireManager.register_officer_escape("spanish_empire")
	var foe := EnemyCaptainData.for_faction("spanish_empire")
	ResourceManager.current_resources["gold"] = 0
	var record := EmpireManager.capture_officers("spanish_empire")
	assert_eq(record["bounty"], foe.bounty(2))
	assert_eq(ResourceManager.get_resource("gold"), foe.bounty(2))
	assert_eq(EmpireManager.capture_officers("spanish_empire"), {}, "only once")


func test_a_win_with_no_nemesis_pays_no_bounty_and_a_hold_win_leaves_it_at_large() -> void:
	EmpireManager.register_officer_escape("royal_navy")
	var rig := _rig()
	rig["system"].begin_boarding()
	rig["system"].resolve_tactical("hold", true, {"captures_ship": false, "officers_escaped": false})
	assert_false(EmpireManager.nemesis_for_faction("royal_navy").is_empty(), "only the Colours end a Nemesis")
	var calm := _rig("PirateClans")
	var gold_before: int = ResourceManager.get_resource("gold")
	calm["system"].begin_boarding()
	assert_eq(EmpireManager.capture_officers("pirate_clans"), {})
	assert_eq(ResourceManager.get_resource("gold"), gold_before)


# === Infirmary and Training Yard ===

func _building(file: String) -> BuildingData:
	return load("res://resources/buildings/%s.tres" % file)


func test_tavern_levels_are_infirmaries_and_fortress_levels_are_training_yards() -> void:
	assert_eq(_building("Tavern_L1").infirmary_heal_bonus, 0)
	var last_heal := -1
	var last_xp := -1
	for lvl in range(1, 6):
		var heal := _building("Tavern_L%d" % lvl).infirmary_heal_bonus
		var xp := _building("Fortress_L%d" % lvl).training_xp_per_dock
		assert_true(heal >= last_heal, "Tavern L%d is no worse than the one below" % lvl)
		assert_gt(xp, last_xp, "Fortress L%d drills harder" % lvl)
		last_heal = heal
		last_xp = xp
	assert_gt(_building("Tavern_L5").infirmary_heal_bonus, 0)
	assert_eq(_building("Farm_L1").infirmary_heal_bonus, 0, "other buildings do nothing for the company")
	assert_eq(_building("Farm_L1").training_xp_per_dock, 0)


func test_the_best_infirmary_and_training_yard_at_a_port_count_and_they_do_not_stack() -> void:
	var none := FleetManager.port_services([_building("Farm_L2")])
	assert_eq(none, {"heal": 0, "xp": 0})
	var both := FleetManager.port_services([_building("Tavern_L4"), _building("Tavern_L2"), _building("Fortress_L2"), _building("Fortress_L1")])
	assert_eq(both["heal"], _building("Tavern_L4").infirmary_heal_bonus, "the best Tavern, not their sum")
	assert_eq(both["xp"], _building("Fortress_L2").training_xp_per_dock)
	assert_eq(FleetManager.port_services([]), {"heal": 0, "xp": 0})
	assert_eq(FleetManager.port_services([null, "nope"]), {"heal": 0, "xp": 0}, "junk in the list is ignored")


func _squad(role: StringName, wounds: int = 0) -> OwnedSquadData:
	var s := OwnedSquadData.new()
	s.uid = "q%d" % (FleetManager.squads.size() + 1)
	s.role = role
	s.wounds = wounds
	return s


func test_the_training_yard_drills_fit_squads_with_sailing_xp_only() -> void:
	var fit := _squad(&"gunners")
	var hurt := _squad(&"marines", _table.wound_cap)
	FleetManager.squads.append(fit)
	FleetManager.squads.append(hurt)
	FleetManager.train_squads(6)
	assert_eq(fit.xp, 6)
	assert_eq(fit.boarding_xp, 0, "drill never makes an elite")
	assert_eq(hurt.xp, 0, "a squad in the infirmary cannot drill")
	FleetManager.train_squads(0)
	FleetManager.train_squads(-2)
	assert_eq(fit.xp, 6)
	FleetManager.train_squads(100000)
	assert_lt(fit.rank(_table), _table.rank_count() - 1, "a Training Yard cannot make an elite squad")


func test_a_better_infirmary_mends_more_at_the_dock() -> void:
	var s := _squad(&"marines", 3)
	FleetManager.squads.append(s)
	var services := FleetManager.port_services([_building("Tavern_L5")])
	FleetManager.heal_squads(_table.dock_heal + int(services["heal"]))
	assert_eq(s.wounds, 3 - (_table.dock_heal + _building("Tavern_L5").infirmary_heal_bonus))
