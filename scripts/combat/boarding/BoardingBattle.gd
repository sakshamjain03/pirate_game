class_name BoardingBattle extends RefCounted

## Purpose: the Three Bells boarding battle as a pure, seeded model (M30 2.2).
## Responsibilities: zones, defenders with telegraphed intents, command points (CP), bells,
##   the resolution order, and the end conditions. No Node, no scene, no clock: the
##   BoardingOverlay (2.5) drives it and `BoardingSystem.resolve_tactical()` pays out its outcome.
##
## Resolution order each `ring_bell()` (requirement W2.2):
##   1. Player actions, in the order queued (Advance is one of them).
##   2. Defender intents, in uid order.
##   3. Outside-threat intents.
##   4. Timed events (the jettison at bell 2, the officers escaping at the last bell).
##   5. Morale check.
## There are no dice: damage is flat. The seed only picks where each defender's intent rotation
## starts, so one seed and one list of actions always give the same events.
##
## Ends: a seized objective zone (that objective's outcome), the enemy striking
## ("struck": morale at or below the strike line), the party wiped out ("repulsed"), or the
## last bell ringing ("cut_loose").

const MORALE_MAX := 100

class DefenderState extends RefCounted:
	var uid: int = 0
	var data: DefenderData = null
	var zone: int = BoardingZone.Id.WAIST
	var hp: int = 1
	var intent_index: int = 0
	var guarding: bool = false
	var cancelled: bool = false
	## M30 2.11 - a Nemesis officer's own name and promotion bonus (empty / 0 for everyone else).
	var label: String = ""
	var attack_bonus: int = 0

	## What this defender will do on the next bell, or null when it has nothing.
	func next_intent() -> DefenderIntentData:
		if data == null or data.intents.is_empty():
			return null
		return data.intents[intent_index % data.intents.size()]


var rules: BoardingData
var rng := RandomNumberGenerator.new()
var bell: int = 1
var bells_total: int = 2
var cp: int = 0
## The zone the boarding party currently holds.
var zone: int = BoardingZone.Id.WAIST
var player_hp: int = 0
var player_hp_start: int = 0
var morale: int = 0
var defenders: Array[DefenderState] = []
var objectives: Array[BoardingObjectiveData] = []
## Each: {"id": StringName, "name": String, "hp": int, "damage": int}.
var outside_threats: Array[Dictionary] = []
var timed_events: Array = []
var roles: Array[StringName] = []
## Empty until the battle is over; then {id, success, loot_mult, captures_ship,
## officers_escaped, hold_intact, bell, casualties}.
var outcome: Dictionary = {}
var officers_escaped: bool = false
var hold_jettisoned: bool = false
## M30 2.11 - Captain Orders (from the deck).
var hero: Dictionary = {}
var no_quarter: bool = false
var cp_bonus: int = 0
## Every event of the battle so far, oldest first.
var log: Array[Dictionary] = []

var _queue: Array[Dictionary] = []
var _next_uid: int = 1
var _outside_guard: int = 0


## `bells = 2 + round(hull_fraction * bells_per_hull)`, at most `bells_max`.
static func bell_count(hull_fraction: float, p_rules: BoardingData) -> int:
	return mini(p_rules.bells_max,
			p_rules.bells_base + int(round(hull_fraction * p_rules.bells_per_hull)))


func _init(deck: BoardingDeck, p_rules: BoardingData, seed_value: int = 0) -> void:
	rules = p_rules
	rng.seed = seed_value
	zone = deck.entry_zone
	player_hp = deck.player_hp
	player_hp_start = deck.player_hp
	morale = clampi(deck.morale, 0, MORALE_MAX)
	objectives = deck.objectives.duplicate()
	roles = deck.roles.duplicate()
	bells_total = bell_count(deck.hull_fraction, rules)
	hero = deck.hero.duplicate()
	no_quarter = deck.no_quarter
	cp_bonus = deck.cp_bonus
	cp = rules.bell_cp + cp_bonus
	for t in deck.outside_threats:
		outside_threats.append((t as Dictionary).duplicate())
	timed_events = deck.timed_events.duplicate(true)
	for entry in deck.defenders:
		var data: DefenderData = entry["data"]
		var d := DefenderState.new()
		d.uid = _next_uid
		_next_uid += 1
		d.data = data
		d.zone = int(entry.get("zone", BoardingZone.Id.WAIST))
		d.hp = int(entry.get("hp", data.hp))
		d.label = str(entry.get("label", ""))
		d.attack_bonus = int(entry.get("attack_bonus", 0))
		if d.hp <= 0:
			continue
		# The seed's one job: where each rotation starts, so the same ship does not play
		# the same battle every time but a given seed always does.
		d.intent_index = rng.randi() % data.intents.size() if not data.intents.is_empty() else 0
		defenders.append(d)


# === Reading the board ===

func is_over() -> bool:
	return not outcome.is_empty()


func defender_by_uid(uid: int) -> DefenderState:
	for d in defenders:
		if d.uid == uid:
			return d
	return null


func defenders_in(z: int) -> Array[DefenderState]:
	var out: Array[DefenderState] = []
	for d in defenders:
		if d.zone == z:
			out.append(d)
	return out


## CP still unspent this bell, after what is already queued.
func cp_left() -> int:
	var spent := 0
	for q in _queue:
		spent += int(q["cost"])
	return cp - spent


func queued_count() -> int:
	return _queue.size()


## The zone the party will be in once the queued Advances have happened.
func projected_zone() -> int:
	var z := zone
	for q in _queue:
		if q["kind"] == "advance":
			z = int(q["to"])
	return z


# === Queuing the player's CP ===

func can_queue(action: BoardingActionData, target: int = -1) -> bool:
	if is_over() or action == null or action.cp_cost > cp_left():
		return false
	if action.required_role != &"" and not roles.is_empty() and not (action.required_role in roles):
		return false
	var z := projected_zone()
	match action.target_rule:
		BoardingActionData.TargetRule.DEFENDER_MELEE:
			var d := defender_by_uid(target)
			return d != null and d.zone == z
		BoardingActionData.TargetRule.DEFENDER_RANGED:
			var d := defender_by_uid(target)
			return d != null and (d.zone == z or BoardingZone.are_adjacent(d.zone, z))
		BoardingActionData.TargetRule.OUTSIDE_THREAT:
			return target >= 0 and target < outside_threats.size() \
					and int(outside_threats[target]["hp"]) > 0
	return true


func queue_action(action: BoardingActionData, target: int = -1) -> bool:
	if not can_queue(action, target):
		return false
	_queue.append({"kind": "action", "cost": action.cp_cost, "action": action, "target": target})
	return true


func can_advance(to_zone: int) -> bool:
	return not is_over() and rules.advance_cp <= cp_left() \
			and BoardingZone.are_adjacent(projected_zone(), to_zone)


## Move the party one zone on. It only happens if the zone it leaves is clear of defenders
## when the order comes up, so queue it after the killing blows.
func queue_advance(to_zone: int) -> bool:
	if not can_advance(to_zone):
		return false
	_queue.append({"kind": "advance", "cost": rules.advance_cp, "to": to_zone})
	return true


## The orders queued for the next bell, oldest first: {"kind": "action", "action", "target", "cost"}
## or {"kind": "advance", "to", "cost"}. A copy; the UI reads it to show what is planned.
func queued() -> Array[Dictionary]:
	return _queue.duplicate()


## The player gives up: the grapples part and the battle ends as a cut-loose.
func retreat() -> void:
	if is_over():
		return
	var events: Array[Dictionary] = []
	_end("cut_loose", false, 1.0, false, events)
	_finish(events)


func unqueue_last() -> void:
	if not _queue.is_empty():
		_queue.pop_back()


# === The bell ===

## Rings the bell: resolves everything queued, then the defenders, the outside guns, the timed
## events and the morale check. Returns this bell's events (also appended to `log`).
func ring_bell() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over():
		return events
	var was_guarding: Array[DefenderState] = []
	for d in defenders:
		if d.guarding:
			was_guarding.append(d)
	_outside_guard = 0

	# 1. Player actions.
	for q in _queue:
		if q["kind"] == "advance":
			_do_advance(int(q["to"]), events)
		else:
			_do_action(q["action"], int(q["target"]), events)
		if _check_seize(events):
			return _finish(events)
	_queue.clear()
	for d in was_guarding:
		d.guarding = false
	if _check_seize(events):
		return _finish(events)

	# 2. Defender intents.
	for d in defenders.duplicate():
		_do_intent(d, events)
		if player_hp <= 0:
			_end("repulsed", false, 1.0, false, events)
			return _finish(events)
	for d in defenders:
		d.cancelled = false

	# 3. Outside threats.
	for t in outside_threats:
		if int(t["hp"]) <= 0:
			continue
		var dmg := maxi(0, int(t["damage"]) - _outside_guard)
		player_hp -= dmg
		events.append(_ev("outside_fire", {"threat": str(t["id"]), "damage": dmg,
				"braced": _outside_guard > 0}))
		if player_hp <= 0:
			_end("repulsed", false, 1.0, false, events)
			return _finish(events)

	# 4. Timed events.
	for te in timed_events:
		var due: int = bells_total if int(te["bell"]) < 0 else int(te["bell"])
		if due != bell:
			continue
		match str(te["kind"]):
			"jettison":
				hold_jettisoned = true
				events.append(_ev("jettison", {}))
			"officers_escape":
				var fled := 0
				for d in defenders.duplicate():
					if d.data.is_officer:
						defenders.erase(d)
						fled += 1
				if fled > 0:
					officers_escaped = true
					events.append(_ev("officers_escape", {"count": fled}))

	# 5. Morale check. Under No Quarter nobody surrenders: only an objective ends the fight.
	if morale <= rules.strike_morale and not no_quarter:
		_end("struck", true, 1.0, true, events)
		return _finish(events)

	if bell >= bells_total:
		_end("cut_loose", false, 1.0, false, events)
		return _finish(events)
	events.append(_ev("bell_rung", {}))
	bell += 1
	cp = rules.bell_cp + cp_bonus
	return _finish(events)


# === Internals ===

func _do_advance(to_zone: int, events: Array[Dictionary]) -> void:
	if not defenders_in(zone).is_empty() or not BoardingZone.are_adjacent(zone, to_zone):
		events.append(_ev("advance_blocked", {"to": to_zone}))
		return
	zone = to_zone
	events.append(_ev("advance", {"to": to_zone}))


func _do_action(action: BoardingActionData, target: int, events: Array[Dictionary]) -> void:
	match action.target_rule:
		BoardingActionData.TargetRule.OUTSIDE_THREAT:
			if target < 0 or target >= outside_threats.size() or int(outside_threats[target]["hp"]) <= 0:
				events.append(_ev("fizzle", {"action": str(action.id)}))
				return
			var t := outside_threats[target]
			t["hp"] = int(t["hp"]) - action.damage
			events.append(_ev("outside_hit", {"threat": str(t["id"]), "damage": action.damage,
					"sunk": int(t["hp"]) <= 0}))
		BoardingActionData.TargetRule.NONE:
			_outside_guard += action.outside_guard
			events.append(_ev("guard", {"action": str(action.id), "amount": action.outside_guard}))
		_:
			var d := defender_by_uid(target)
			var in_reach: bool = d != null and (d.zone == zone or (
					action.target_rule == BoardingActionData.TargetRule.DEFENDER_RANGED
					and BoardingZone.are_adjacent(d.zone, zone)))
			if not in_reach:
				events.append(_ev("fizzle", {"action": str(action.id)}))
				return
			if action.damage > 0:
				var dmg := action.damage
				# The hero's blows land harder (Board First): melee only.
				if action.target_rule == BoardingActionData.TargetRule.DEFENDER_MELEE and not hero.is_empty():
					dmg += int(hero.get("damage", 0))
				if d.guarding:
					dmg = maxi(1, dmg - rules.guard_reduction)
				events.append(_ev("hit", {"action": str(action.id), "defender": d.uid, "damage": dmg}))
				_damage_defender(d, dmg, events)
			if d.hp > 0:
				if action.cancels_intent:
					d.cancelled = true
					events.append(_ev("intent_cancelled", {"defender": d.uid}))
				for _i in action.push:
					_push(d, events)


func _push(d: DefenderState, events: Array[Dictionary]) -> void:
	var dest := BoardingZone.step_away(d.zone, zone)
	if dest < 0 or defenders_in(dest).size() >= rules.zone_slots:
		return
	d.zone = dest
	events.append(_ev("pushed", {"defender": d.uid, "to": dest}))


func _do_intent(d: DefenderState, events: Array[Dictionary]) -> void:
	var intent := d.next_intent()
	d.intent_index += 1
	if intent == null:
		return
	if d.cancelled:
		events.append(_ev("intent_fizzled", {"defender": d.uid, "intent": str(intent.id)}))
		return
	match intent.kind:
		DefenderIntentData.Kind.STRIKE:
			if d.zone == zone:
				_hurt_party(d.data.attack + d.attack_bonus + intent.power, d.uid, str(intent.id), events)
			else:
				events.append(_ev("whiff", {"defender": d.uid, "intent": str(intent.id)}))
		DefenderIntentData.Kind.SHOOT:
			_hurt_party(d.data.attack + d.attack_bonus + intent.power, d.uid, str(intent.id), events)
		DefenderIntentData.Kind.GUARD:
			d.guarding = true
			events.append(_ev("guarding", {"defender": d.uid}))
		DefenderIntentData.Kind.RALLY:
			morale = mini(MORALE_MAX, morale + intent.power)
			events.append(_ev("rally", {"defender": d.uid, "morale": morale}))
		DefenderIntentData.Kind.CHARGE:
			var dest := BoardingZone.step_toward(d.zone, zone)
			if dest >= 0 and defenders_in(dest).size() < rules.zone_slots:
				d.zone = dest
				events.append(_ev("charge", {"defender": d.uid, "to": dest}))


func _hurt_party(dmg: int, defender_uid: int, intent_id: String, events: Array[Dictionary]) -> void:
	player_hp -= dmg
	events.append(_ev("party_hit", {"defender": defender_uid, "intent": intent_id, "damage": dmg}))


func _damage_defender(d: DefenderState, dmg: int, events: Array[Dictionary]) -> void:
	d.hp -= dmg
	if d.hp > 0:
		return
	defenders.erase(d)
	morale = maxi(0, morale - d.data.morale_value)
	if d.data.is_officer:
		morale = maxi(0, morale - rules.officer_down_morale)
	events.append(_ev("defender_down", {"defender": d.uid, "morale": morale}))


## True (and the battle ends) when the party stands in an objective zone with no defender left in it.
func _check_seize(events: Array[Dictionary]) -> bool:
	if is_over():
		return true
	if not defenders_in(zone).is_empty():
		return false
	for obj in objectives:
		if obj.zone == zone:
			var mult := obj.loot_mult
			if hold_jettisoned and obj.outcome_id == &"hold":
				mult *= 0.5
			_end(str(obj.outcome_id), true, mult, obj.captures_ship, events,
					{"grants_elite_squad": obj.grants_elite_squad, "captain_xp": obj.captain_xp})
			return true
	return false


func _end(id: String, success: bool, loot_mult: float, captures: bool, events: Array[Dictionary],
		extras: Dictionary = {}) -> void:
	outcome = {
		"id": id, "success": success, "loot_mult": loot_mult, "captures_ship": captures,
		"officers_escaped": officers_escaped, "hold_intact": not hold_jettisoned,
		"bell": bell, "casualties": player_hp_start - maxi(player_hp, 0),
		"grants_elite_squad": bool(extras.get("grants_elite_squad", false)),
		"captain_xp": int(extras.get("captain_xp", 0)),
	}
	events.append(_ev("battle_over", {"outcome": id}))


func _finish(events: Array[Dictionary]) -> Array[Dictionary]:
	log.append_array(events)
	return events


func _ev(type: String, extra: Dictionary) -> Dictionary:
	var e := {"type": type, "bell": bell}
	e.merge(extra)
	return e
