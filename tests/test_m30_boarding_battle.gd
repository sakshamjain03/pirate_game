extends GutTest
## M30 Wave 2 (2.2): the Three Bells model. Pure data in, events out — every resource
## here is built by hand so this file does not depend on the authored .tres (2.4).

const WAIST := BoardingZone.Id.WAIST
const FORE := BoardingZone.Id.FORECASTLE
const QUARTER := BoardingZone.Id.QUARTERDECK
const HOLD := BoardingZone.Id.HOLD

var _rules: BoardingData
var _cutlass: BoardingActionData


func before_each() -> void:
	_rules = BoardingData.new()
	_cutlass = _action(&"cutlass", BoardingActionData.TargetRule.DEFENDER_MELEE, 3)


# --- builders ---

func _intent(kind: int, power: int = 0, id: StringName = &"i") -> DefenderIntentData:
	var i := DefenderIntentData.new()
	i.id = id
	i.kind = kind as DefenderIntentData.Kind
	i.power = power
	return i


func _defender(hp: int = 3, attack: int = 1, morale_value: int = 4, intents: Array = [],
		officer: bool = false) -> DefenderData:
	var d := DefenderData.new()
	d.id = &"d"
	d.hp = hp
	d.attack = attack
	d.morale_value = morale_value
	d.is_officer = officer
	for i in intents:
		d.intents.append(i)
	return d


func _action(id: StringName, rule: int, damage: int = 0, cost: int = 1, push: int = 0,
		cancels: bool = false, guard: int = 0) -> BoardingActionData:
	var a := BoardingActionData.new()
	a.id = id
	a.target_rule = rule as BoardingActionData.TargetRule
	a.damage = damage
	a.cp_cost = cost
	a.push = push
	a.cancels_intent = cancels
	a.outside_guard = guard
	return a


func _objective(zone: int, outcome: StringName, mult: float = 1.0, captures: bool = true) -> BoardingObjectiveData:
	var o := BoardingObjectiveData.new()
	o.id = outcome
	o.zone = zone as BoardingZone.Id
	o.outcome_id = outcome
	o.loot_mult = mult
	o.captures_ship = captures
	return o


func _deck(entry: int = WAIST, defenders: Array = [], hull: float = 0.2) -> BoardingDeck:
	var deck := BoardingDeck.new()
	deck.entry_zone = entry
	deck.hull_fraction = hull
	deck.defenders = defenders
	deck.objectives = [_objective(QUARTER, &"colours"), _objective(HOLD, &"hold", 2.0),
			_objective(FORE, &"magazine", 0.5, false)]
	return deck


func _at(data: DefenderData, zone: int) -> Dictionary:
	return {"data": data, "zone": zone}




# === Determinism ===

func _play(seed_value: int) -> Array:
	var rotation := [_intent(DefenderIntentData.Kind.STRIKE, 0, &"slash"),
			_intent(DefenderIntentData.Kind.GUARD, 0, &"guard"),
			_intent(DefenderIntentData.Kind.RALLY, 5, &"rally")]
	var foe := _defender(4, 1, 3, rotation)
	var b := BoardingBattle.new(_deck(WAIST, [_at(foe, WAIST), _at(foe, WAIST), _at(foe, WAIST)]), _rules, seed_value)
	for _bell in 3:
		for d in b.defenders_in(b.zone).slice(0, 2):
			b.queue_action(_cutlass, d.uid)
		b.ring_bell()
		if b.is_over():
			break
	return b.log


func test_the_same_seed_and_actions_give_identical_events() -> void:
	assert_eq(_play(11), _play(11))
	assert_gt(_play(11).size(), 3, "precondition: the battle actually produced events")


func test_a_different_seed_changes_where_the_rotations_start() -> void:
	var differs := false
	for s in range(1, 20):
		if _play(s) != _play(11):
			differs = true
			break
	assert_true(differs)


# === Bells and CP ===

func test_bell_count_is_two_plus_round_hull_fraction_times_five_capped_at_four() -> void:
	assert_eq(BoardingBattle.bell_count(0.0, _rules), 2)
	assert_eq(BoardingBattle.bell_count(0.05, _rules), 2, "0.25 rounds down")
	assert_eq(BoardingBattle.bell_count(0.1, _rules), 3, "0.5 rounds up")
	assert_eq(BoardingBattle.bell_count(0.2, _rules), 3)
	assert_eq(BoardingBattle.bell_count(0.3, _rules), 4)
	assert_eq(BoardingBattle.bell_count(1.0, _rules), 4, "capped")
	assert_eq(BoardingBattle.new(_deck(WAIST, [], 0.3), _rules).bells_total, 4)


func test_each_bell_gives_three_cp_and_spending_is_checked() -> void:
	var foe := _defender(30)
	var b := BoardingBattle.new(_deck(WAIST, [_at(foe, WAIST)]), _rules)
	var uid: int = b.defenders[0].uid
	assert_eq(b.cp_left(), 3)
	assert_true(b.queue_action(_cutlass, uid))
	assert_true(b.queue_action(_cutlass, uid))
	assert_true(b.queue_action(_cutlass, uid))
	assert_eq(b.cp_left(), 0)
	assert_false(b.queue_action(_cutlass, uid), "no CP left")
	b.unqueue_last()
	assert_eq(b.cp_left(), 1, "an unqueued order refunds its CP")
	b.ring_bell()
	assert_eq(b.cp_left(), 3, "a new bell, a new three CP")


func test_an_action_needs_a_valid_target() -> void:
	var near := _defender(5)
	var far := _defender(5)
	var b := BoardingBattle.new(_deck(WAIST, [_at(near, WAIST), _at(far, QUARTER)]), _rules)
	var ranged := _action(&"pistol", BoardingActionData.TargetRule.DEFENDER_RANGED, 2)
	assert_false(b.queue_action(_cutlass, 999), "no such defender")
	assert_false(b.queue_action(_cutlass, b.defenders[1].uid), "melee reaches only the party's own zone")
	assert_true(b.queue_action(ranged, b.defenders[1].uid), "a pistol reaches an adjacent zone")
	assert_false(b.queue_action(_action(&"pp", BoardingActionData.TargetRule.OUTSIDE_THREAT, 2), 0),
			"no outside threats on this deck")


func test_a_role_the_party_lacks_refuses_the_action() -> void:
	var foe := _defender(5)
	var deck := _deck(WAIST, [_at(foe, WAIST)])
	var gunnery := _action(&"volley", BoardingActionData.TargetRule.DEFENDER_MELEE, 2)
	gunnery.required_role = &"gunner"
	deck.roles = [&"boarder"]
	var b := BoardingBattle.new(deck, _rules)
	assert_false(b.queue_action(gunnery, b.defenders[0].uid))
	deck.roles = [&"boarder", &"gunner"]
	assert_true(BoardingBattle.new(deck, _rules).queue_action(gunnery, 1))


# === Resolution order ===

func test_player_actions_resolve_before_defender_intents() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 0, &"slash")
	var weak := _defender(2, 5, 1, [slash])
	var deck := _deck(WAIST, [_at(weak, WAIST)])
	var b := BoardingBattle.new(deck, _rules)
	b.queue_action(_cutlass, b.defenders[0].uid)  # 3 dmg kills it before it can strike
	b.ring_bell()
	assert_eq(b.player_hp, deck.player_hp, "the defender died before its blow landed")


func test_defender_intents_resolve_in_uid_order_after_the_player() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 0, &"slash")
	var a := _defender(9, 2, 1, [slash])
	var c := _defender(9, 3, 1, [slash])
	var b := BoardingBattle.new(_deck(WAIST, [_at(a, WAIST), _at(c, WAIST)]), _rules)
	var events := b.ring_bell()
	var hits := events.filter(func(e): return e["type"] == "party_hit")
	assert_eq(hits.size(), 2)
	assert_eq(hits[0]["damage"], 2, "uid 1 first")
	assert_eq(hits[1]["damage"], 3)


func test_cancelling_an_intent_blanks_that_blow() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 0, &"slash")
	var foe := _defender(9, 4, 1, [slash])
	var deck := _deck(WAIST, [_at(foe, WAIST)])
	var b := BoardingBattle.new(deck, _rules)
	b.queue_action(_action(&"parry", BoardingActionData.TargetRule.DEFENDER_MELEE, 0, 1, 0, true), b.defenders[0].uid)
	var events := b.ring_bell()
	assert_eq(b.player_hp, deck.player_hp)
	assert_true(events.any(func(e): return e["type"] == "intent_fizzled"))
	var next := b.ring_bell()
	assert_true(next.any(func(e): return e["type"] == "party_hit"), "only that one bell was blanked")


func test_a_strike_only_lands_in_the_parties_zone_but_a_shot_lands_anywhere() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 0, &"slash")
	var shoot := _intent(DefenderIntentData.Kind.SHOOT, 1, &"shoot")
	var deck := _deck(WAIST, [_at(_defender(9, 1, 1, [slash]), QUARTER),
			_at(_defender(9, 1, 1, [shoot]), QUARTER)])
	var b := BoardingBattle.new(deck, _rules)
	var events := b.ring_bell()
	assert_true(events.any(func(e): return e["type"] == "whiff"))
	assert_eq(deck.player_hp - b.player_hp, 2, "only the shot (attack 1 + power 1) landed")


func test_guarding_soaks_damage_for_one_player_phase() -> void:
	var guard := _intent(DefenderIntentData.Kind.GUARD, 0, &"guard")
	var foe := _defender(20, 1, 1, [guard])
	var b := BoardingBattle.new(_deck(WAIST, [_at(foe, WAIST)]), _rules)
	b.ring_bell()  # intents phase: it raises its guard
	assert_true(b.defenders[0].guarding)
	b.queue_action(_cutlass, b.defenders[0].uid)
	b.ring_bell()
	assert_eq(b.defenders[0].hp, 20 - maxi(1, 3 - _rules.guard_reduction), "guard cut the cutlass")


func test_shove_pushes_a_defender_away_and_it_cannot_strike_from_there() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 0, &"slash")
	var foe := _defender(9, 4, 1, [slash])
	var deck := _deck(WAIST, [_at(foe, WAIST)])
	var b := BoardingBattle.new(deck, _rules)
	b.queue_action(_action(&"shove", BoardingActionData.TargetRule.DEFENDER_MELEE, 1, 1, 1), b.defenders[0].uid)
	var events := b.ring_bell()
	assert_true(events.any(func(e): return e["type"] == "pushed"))
	assert_ne(b.defenders[0].zone, WAIST)
	assert_eq(b.player_hp, deck.player_hp, "shoved out of reach, so the blow whiffed")


func test_charge_closes_a_zone_toward_the_party() -> void:
	var charge := _intent(DefenderIntentData.Kind.CHARGE, 0, &"charge")
	var foe := _defender(9, 1, 1, [charge])
	var b := BoardingBattle.new(_deck(WAIST, [_at(foe, QUARTER)]), _rules)
	b.ring_bell()
	assert_eq(b.defenders[0].zone, WAIST)


func test_rally_restores_enemy_morale() -> void:
	var rally := _intent(DefenderIntentData.Kind.RALLY, 8, &"rally")
	var foe := _defender(9, 1, 1, [rally])
	var deck := _deck(WAIST, [_at(foe, WAIST)])
	deck.morale = 50
	var b := BoardingBattle.new(deck, _rules)
	b.ring_bell()
	assert_eq(b.morale, 58)


# === Outside threats ===

func _with_threat(damage: int = 2, hp: int = 3) -> BoardingBattle:
	var deck := _deck(WAIST, [_at(_defender(30), FORE)])
	deck.outside_threats = [{"id": &"sloop", "name": "Escort Sloop", "hp": hp, "damage": damage}]
	return BoardingBattle.new(deck, _rules)


func test_an_outside_threat_hurts_the_party_each_bell() -> void:
	var b := _with_threat(2)
	var start := b.player_hp
	b.ring_bell()
	assert_eq(b.player_hp, start - 2)


func test_brace_blunts_and_point_blank_silences_an_outside_threat() -> void:
	var b := _with_threat(2)
	var start := b.player_hp
	b.queue_action(_action(&"brace", BoardingActionData.TargetRule.NONE, 0, 1, 0, false, 2))
	b.ring_bell()
	assert_eq(b.player_hp, start, "a Brace of 2 swallowed the 2-damage broadside")

	var c := _with_threat(2, 3)
	c.queue_action(_action(&"point_blank", BoardingActionData.TargetRule.OUTSIDE_THREAT, 3), 0)
	var events := c.ring_bell()
	assert_true(events.any(func(e): return e["type"] == "outside_hit" and e["sunk"]))
	assert_eq(c.player_hp, c.player_hp_start, "a silenced threat fires no more")


# === End conditions ===

func test_each_objective_zone_ends_the_battle_with_its_outcome() -> void:
	for case in [[QUARTER, "colours", true], [HOLD, "hold", true], [FORE, "magazine", true]]:
		var b := BoardingBattle.new(_deck(case[0], []), _rules)
		b.ring_bell()
		assert_true(b.is_over(), "an empty objective zone is seized")
		assert_eq(b.outcome["id"], case[1])
		assert_eq(b.outcome["success"], case[2])
	var hold := BoardingBattle.new(_deck(HOLD, []), _rules)
	hold.ring_bell()
	assert_eq(hold.outcome["loot_mult"], 2.0, "the hold pays double")
	var mag := BoardingBattle.new(_deck(FORE, []), _rules)
	mag.ring_bell()
	assert_false(mag.outcome["captures_ship"], "the magazine wrecks rather than takes")


func test_a_zone_is_only_seized_once_its_defenders_are_gone() -> void:
	var foe := _defender(3)
	var b := BoardingBattle.new(_deck(QUARTER, [_at(foe, QUARTER)]), _rules)
	b.ring_bell()
	assert_false(b.is_over(), "a defender still holds the quarterdeck")
	b.queue_action(_cutlass, b.defenders[0].uid)
	b.ring_bell()
	assert_true(b.is_over())
	assert_eq(b.outcome["id"], "colours")


func test_advance_needs_a_clear_zone_and_walks_the_deck_graph() -> void:
	var foe := _defender(3)
	var b := BoardingBattle.new(_deck(WAIST, [_at(foe, WAIST)]), _rules)
	assert_false(b.can_advance(99), "no such zone")
	assert_false(b.can_advance(BoardingZone.Id.WAIST), "not adjacent to itself")
	b.queue_advance(QUARTER)
	var blocked := b.ring_bell()
	assert_true(blocked.any(func(e): return e["type"] == "advance_blocked"), "the waist is still held")
	assert_eq(b.zone, WAIST)

	var c := BoardingBattle.new(_deck(WAIST, [_at(foe, WAIST)]), _rules)
	c.queue_action(_cutlass, c.defenders[0].uid)  # kills it (3 hp)
	assert_true(c.queue_advance(QUARTER))
	c.ring_bell()
	assert_true(c.is_over(), "killed the blocker, advanced, seized the quarterdeck in one bell")
	assert_eq(c.outcome["id"], "colours")


func test_morale_at_or_below_the_line_strikes_the_colours() -> void:
	var foe := _defender(1, 1, 20)
	var other := _defender(30)
	var deck := _deck(WAIST, [_at(foe, WAIST), _at(other, FORE)])
	deck.morale = 45
	var b := BoardingBattle.new(deck, _rules)
	b.queue_action(_cutlass, b.defenders[0].uid)  # 45 - 20 = 25 <= 30
	b.ring_bell()
	assert_true(b.is_over())
	assert_eq(b.outcome["id"], "struck")
	assert_true(b.outcome["success"])
	assert_true(b.outcome["captures_ship"])


func test_the_officer_falling_costs_extra_morale() -> void:
	var boss := _defender(1, 1, 5, [], true)
	var other := _defender(30)
	var deck := _deck(WAIST, [_at(boss, WAIST), _at(other, FORE)])
	deck.morale = 80
	var b := BoardingBattle.new(deck, _rules)
	b.queue_action(_cutlass, b.defenders[0].uid)
	b.ring_bell()
	assert_eq(b.morale, 80 - 5 - _rules.officer_down_morale)


func test_the_last_bell_cuts_the_party_loose() -> void:
	var b := BoardingBattle.new(_deck(WAIST, [_at(_defender(99), FORE)], 0.0), _rules)
	assert_eq(b.bells_total, 2)
	b.ring_bell()
	assert_false(b.is_over())
	b.ring_bell()
	assert_true(b.is_over())
	assert_eq(b.outcome["id"], "cut_loose")
	assert_false(b.outcome["success"])


func test_a_wiped_party_is_repulsed() -> void:
	var slash := _intent(DefenderIntentData.Kind.STRIKE, 20, &"slash")
	var deck := _deck(WAIST, [_at(_defender(9, 1, 1, [slash]), WAIST)])
	var b := BoardingBattle.new(deck, _rules)
	b.ring_bell()
	assert_eq(b.outcome["id"], "repulsed")
	assert_false(b.outcome["success"])


func test_a_finished_battle_ignores_further_orders() -> void:
	var b := BoardingBattle.new(_deck(QUARTER, []), _rules)
	b.ring_bell()
	assert_true(b.is_over())
	assert_false(b.queue_action(_cutlass, 1))
	assert_eq(b.ring_bell().size(), 0)


# === Timed events ===

func test_the_jettison_halves_the_hold_and_the_officers_flee_at_the_last_bell() -> void:
	var boss := _defender(9, 1, 5, [], true)
	var deck := _deck(WAIST, [_at(boss, QUARTER), _at(_defender(99), FORE)], 0.3)  # 4 bells
	deck.timed_events = [{"bell": 2, "kind": "jettison"}, {"bell": -1, "kind": "officers_escape"}]
	var b := BoardingBattle.new(deck, _rules)
	b.ring_bell()
	assert_false(b.hold_jettisoned)
	b.ring_bell()
	assert_true(b.hold_jettisoned, "bell 2")
	b.ring_bell()
	assert_false(b.officers_escaped)
	b.ring_bell()  # the last bell
	assert_true(b.officers_escaped)
	assert_eq(b.defenders.filter(func(d): return d.data.is_officer).size(), 0)
	assert_eq(b.outcome["id"], "cut_loose")
	assert_true(b.outcome["officers_escaped"])
	assert_false(b.outcome["hold_intact"])


func test_a_jettisoned_hold_pays_half() -> void:
	var deck := _deck(WAIST, [_at(_defender(99), FORE)], 0.3)
	deck.timed_events = [{"bell": 1, "kind": "jettison"}]
	var b := BoardingBattle.new(deck, _rules)
	b.ring_bell()
	b.zone = HOLD
	b.defenders.clear()
	b.ring_bell()
	assert_eq(b.outcome["id"], "hold")
	assert_eq(b.outcome["loot_mult"], 1.0, "2.0 halved")


# === Wounded and downed defenders ===

func test_a_wounded_defender_starts_with_less_hp_and_a_zero_hp_one_is_not_on_deck() -> void:
	var foe := _defender(5)
	var b := BoardingBattle.new(_deck(WAIST, [{"data": foe, "zone": WAIST, "hp": 2},
			{"data": foe, "zone": WAIST, "hp": 0}]), _rules)
	assert_eq(b.defenders.size(), 1)
	assert_eq(b.defenders[0].hp, 2)
