extends GutTest
## M30 Wave 2 (2.4): the authored boarding content in resources/combat/boarding/**
## and the wiring in resources/combat/Boarding.tres. A .tres property the script does not
## export fails silently (docs/05 D3/D14), so beyond test_lint_resource_exports this checks
## that what was authored is actually referenced, valid and playable.

const BOARDING := "res://resources/combat/Boarding.tres"
const OUTCOMES := ["colours", "hold", "magazine", "struck", "repulsed", "cut_loose"]

var _rules: BoardingData


func before_each() -> void:
	_rules = load(BOARDING)


func _profiles() -> Array:
	var all: Array = _rules.deck_profiles.duplicate()
	all.append(_rules.default_profile)
	return all


func test_boarding_data_loads_with_content_wired_in() -> void:
	assert_not_null(_rules)
	assert_not_null(_rules.default_profile, "the fallback profile")
	assert_eq(_rules.deck_profiles.size(), 5)
	assert_eq(_rules.actions.size(), 6, "Cutlass, Pistol, Shove, Parry, Brace, Point-Blank")


func test_actions_are_valid_and_unique() -> void:
	var ids := {}
	for a in _rules.actions:
		assert_not_null(a)
		assert_ne(a.id, &"")
		assert_false(ids.has(a.id), "duplicate action %s" % a.id)
		ids[a.id] = true
		assert_between(a.cp_cost, 1, 3)
	for want in [&"cutlass", &"pistol", &"shove", &"parry", &"brace", &"point_blank"]:
		assert_true(ids.has(want), "missing %s" % want)


func test_each_action_does_the_one_thing_it_exists_for() -> void:
	var by_id := {}
	for a in _rules.actions:
		by_id[a.id] = a
	assert_gt(by_id[&"cutlass"].damage, by_id[&"pistol"].damage, "the cutlass hits harder than the pistol")
	assert_eq(by_id[&"pistol"].target_rule, BoardingActionData.TargetRule.DEFENDER_RANGED)
	assert_gt(by_id[&"shove"].push, 0)
	assert_true(by_id[&"parry"].cancels_intent)
	assert_eq(by_id[&"brace"].target_rule, BoardingActionData.TargetRule.NONE)
	assert_gt(by_id[&"brace"].outside_guard, 0)
	assert_eq(by_id[&"point_blank"].target_rule, BoardingActionData.TargetRule.OUTSIDE_THREAT)


func test_every_profile_references_valid_defenders_zones_and_objectives() -> void:
	for p in _profiles():
		var label := "profile %s [%d-%d]" % [p.faction_id, p.ship_class_min, p.ship_class_max]
		assert_gt(p.defenders.size(), 0, label)
		assert_eq(p.defender_zones.size(), p.defenders.size(), label + ": one zone per defender")
		assert_true(p.ship_class_min <= p.ship_class_max, label)
		for i in p.defenders.size():
			var d: DefenderData = p.defenders[i]
			assert_not_null(d, label + ": null defender")
			assert_between(p.defender_zones[i], 0, BoardingZone.COUNT - 1, label + ": zone")
			assert_gt(d.hp, 0, d.id)
			assert_gt(d.intents.size(), 0, "%s needs an intent rotation" % d.id)
			for intent in d.intents:
				assert_not_null(intent, "%s: null intent" % d.id)
		assert_gt(p.objectives.size(), 0, label)
		var seen_zone := {}
		for o in p.objectives:
			assert_true(str(o.outcome_id) in OUTCOMES, "%s: outcome %s" % [label, o.outcome_id])
			assert_false(seen_zone.has(o.zone), label + ": two objectives in one zone")
			seen_zone[o.zone] = true
		assert_true(p.objectives.any(func(o): return o.outcome_id == &"colours"), label + ": can take the colours")
		assert_gt(p.morale, _rules.strike_morale, label + ": must not start struck")
		assert_true(p.defenders.size() >= p.min_defenders, label)
		assert_true(p.defenders.any(func(d): return d.is_officer), label + ": has an officer to fall or flee")
		for te in p.timed_events:
			assert_true(str(te["kind"]) in ["jettison", "officers_escape"], label + ": timed event kind")


func test_profile_factions_exist_and_cover_every_class_for_every_faction() -> void:
	for p in _rules.deck_profiles:
		var path := ""
		for f in ["GhostFaction", "MerchantGuild", "PirateClans", "RoyalNavy", "SpanishEmpire"]:
			var fd: FactionData = load("res://resources/factions/%s.tres" % f)
			if fd.faction_id == p.faction_id:
				path = f
		assert_ne(path, "", "profile faction '%s' is not a real faction id" % p.faction_id)
	for faction in ["royal_navy", "pirate_clans", "merchant_guild", "spanish_empire", "ghost_fleet"]:
		for cls in range(1, 6):
			var picked := BoardingDeckBuilder.pick_profile(_rules.deck_profiles, faction, cls, _rules.default_profile)
			assert_not_null(picked, "%s class %d" % [faction, cls])


func test_removal_tags_name_real_ammo() -> void:
	var ammo_ids := {}
	for f in ["RoundShot", "ChainShot", "GrapeShot"]:
		ammo_ids["ammo:" + (load("res://resources/combat/ammo/%s.tres" % f) as AmmoData).ammo_id] = true
	var tags_used := 0
	for p in _profiles():
		for d in p.defenders:
			for t in d.removed_by_tags:
				tags_used += 1
				assert_true(ammo_ids.has(str(t)), "%s: removed_by_tags '%s' matches no ammo" % [d.id, t])
	assert_gt(tags_used, 0, "precondition: gunnery actually shapes the deck")
	# The deckhand is the grape victim and the rigger the chain victim.
	var deckhand: DefenderData = load("res://resources/combat/boarding/defenders/Deckhand.tres")
	var rigger: DefenderData = load("res://resources/combat/boarding/defenders/Rigger.tres")
	var officer: DefenderData = load("res://resources/combat/boarding/defenders/Officer.tres")
	assert_true(&"ammo:grape" in deckhand.removed_by_tags)
	assert_true(&"ammo:chain" in rigger.removed_by_tags)
	assert_true(&"facing:stern" in officer.wounded_by_tags)
	assert_true(officer.is_officer)


func test_the_three_objectives_are_the_three_zones_that_matter() -> void:
	var by_outcome := {}
	for o in _rules.default_profile.objectives:
		by_outcome[str(o.outcome_id)] = o
	assert_eq(by_outcome["colours"].zone, BoardingZone.Id.QUARTERDECK)
	assert_eq(by_outcome["hold"].zone, BoardingZone.Id.HOLD)
	assert_eq(by_outcome["magazine"].zone, BoardingZone.Id.FORECASTLE)
	assert_true(by_outcome["colours"].captures_ship)
	assert_false(by_outcome["magazine"].captures_ship, "the magazine wrecks the prize")
	assert_gt(by_outcome["hold"].loot_mult, by_outcome["colours"].loot_mult, "the hold is the cargo run")


# === Playable ===

## A plain policy: cutlass what is in front (counting the damage already queued, so no
## CP is wasted on a man who is already as good as dead), advance when the zone will be clear.
func _bot_play(battle: BoardingBattle) -> void:
	var cutlass: BoardingActionData
	var point_blank: BoardingActionData
	for a in _rules.actions:
		if a.id == &"cutlass": cutlass = a
		if a.id == &"point_blank": point_blank = a
	var guard := 0
	while not battle.is_over() and guard < 10:
		guard += 1
		var planned := {}
		if not battle.outside_threats.is_empty() and battle.cp_left() >= point_blank.cp_cost:
			for i in battle.outside_threats.size():
				battle.queue_action(point_blank, i)
		while battle.cp_left() > 0:
			var target: BoardingBattle.DefenderState = null
			for d in battle.defenders_in(battle.projected_zone()):
				if d.hp - int(planned.get(d.uid, 0)) > 0:
					target = d
					break
			if target != null:
				if not battle.queue_action(cutlass, target.uid):
					break
				planned[target.uid] = int(planned.get(target.uid, 0)) + cutlass.damage
			else:
				var next := BoardingZone.step_toward(battle.projected_zone(), BoardingZone.Id.QUARTERDECK)
				if next < 0 or not battle.queue_advance(next):
					break
		battle.ring_bell()


func test_every_profile_plays_to_a_known_ending() -> void:
	for p in _profiles():
		for facing in [&"bow", &"beam", &"stern"]:
			var deck := BoardingDeckBuilder.build(p, _rules, {"facing": facing, "hull_fraction": 0.2,
					"crew_fraction": 1.0, "player_crew": 40.0})
			var battle := BoardingBattle.new(deck, _rules, 3)
			_bot_play(battle)
			assert_true(battle.is_over(), "%s/%s must end within its bells" % [p.faction_id, facing])
			assert_true(str(battle.outcome["id"]) in OUTCOMES, "%s/%s: outcome %s" % [p.faction_id, facing, battle.outcome["id"]])


func test_a_merchant_is_takeable_and_the_navys_largest_is_a_real_fight() -> void:
	var merchant := BoardingDeckBuilder.pick_profile(_rules.deck_profiles, "merchant_guild", 2)
	var navy := BoardingDeckBuilder.pick_profile(_rules.deck_profiles, "royal_navy", 5)
	var mdeck := BoardingDeckBuilder.build(merchant, _rules, {"facing": &"beam", "hull_fraction": 0.2,
			"crew_fraction": 1.0, "player_crew": 60.0})
	var ndeck := BoardingDeckBuilder.build(navy, _rules, {"facing": &"beam", "hull_fraction": 0.2,
			"crew_fraction": 1.0, "player_crew": 60.0})
	assert_gt(ndeck.defenders.size(), mdeck.defenders.size(), "a ship of the line has more men than a merchant")
	assert_gt(ndeck.morale, mdeck.morale, "and steadier ones")
	var battle := BoardingBattle.new(mdeck, _rules, 3)
	_bot_play(battle)
	assert_true(battle.outcome["success"], "a plain player with a decent crew takes a merchant")
