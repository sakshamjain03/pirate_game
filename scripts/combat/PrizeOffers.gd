class_name PrizeOffers extends RefCounted

## Purpose: what the Prize Ledger offers for a ship taken by its colours, and what each choice
##   does (M30 2.8). Keep (send it home with a prize crew), Ransom the officers, or Break it
##   for salvage.
## Responsibilities: a pure `build()` that says which choices are open and what they pay, and an
##   `apply()` that performs one through the autoloads (FleetManager, FactionManager,
##   ResourceManager, EmpireManager). No UI: `PrizeLedger` shows it, tests drive it directly.
##
## A record is what the ledger knows about the taken ship (see `record_from_outcome`):
##   {ship_id, ship_class, faction_id, officers_present, is_boss, condition}

enum Choice { KEEP, RANSOM, BREAK }

const SHIPS_DIR := "res://resources/ships"
const ENEMIES_DIR := "res://resources/enemies"


## The ledger record for a `BoardingSystem.boarding_outcome` payload. `{}` when this outcome takes
## no ship (not a Colours outcome, not a success, a boss, or nothing was captured).
static func record_from_outcome(outcome_id: String, details: Dictionary,
		config: PrizeConfigData = null) -> Dictionary:
	if config == null:
		config = PrizeConfigData.get_default()
	if not outcome_id in BoardingSystem.COLOURS_OUTCOMES:
		return {}
	if not bool(details.get("success", false)) or not bool(details.get("captured", false)):
		return {}
	if bool(details.get("is_boss", false)):
		return {}
	return {
		"ship_id": str(details.get("target_ship_id", "")),
		"ship_class": int(details.get("ship_class", 1)),
		"faction_id": str(details.get("target_faction_id", "")),
		"officers_present": not bool(details.get("officers_escaped", false)),
		"is_boss": false,
		# A badly hurt hull is kept at the configured condition; a ship that struck at full hull
		# is in better shape than that.
		"condition": clampf(maxf(float(details.get("hull_fraction", 0.0)), config.keep_condition), 0.0, 1.0),
	}


## The hull a ship_id names, from the player-ship catalogue; push_error on an unknown id (a
## resolver never skips silently). Enemy-only hulls (resources/enemies) are NOT an error: they
## are simply not offered, so this returns null for them quietly.
static func resolve_hull(ship_id: String) -> ShipStats:
	if ship_id.is_empty():
		push_error("PrizeOffers: a prize has no ship_id")
		return null
	var hull := ResourceLookup.find_by_id(SHIPS_DIR, "ship_id", ship_id) as ShipStats
	if hull != null:
		return hull
	if is_enemy_only(ship_id):
		return null
	push_error("PrizeOffers: no hull with ship_id '%s' under %s" % [ship_id, SHIPS_DIR])
	return null


## True for a hull that only enemies sail (authored under resources/enemies). Never offered as a prize.
static func is_enemy_only(ship_id: String) -> bool:
	return ResourceLookup.find_by_id(ENEMIES_DIR, "ship_id", ship_id) != null


## Which choices are open for `record`, and what each pays. Each entry:
## {choice, available: bool, reason: String, gold, reputation, wood, iron, chance, crew_fraction}.
## An empty array means there is nothing to offer (no record, or a boss).
static func build(record: Dictionary, config: PrizeConfigData = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if record.is_empty() or bool(record.get("is_boss", false)):
		return out
	if config == null:
		config = PrizeConfigData.get_default()
	var klass := maxi(int(record.get("ship_class", 1)), 1)

	var keep := {"choice": Choice.KEEP, "available": true, "reason": "", "gold": 0, "reputation": 0,
			"wood": 0, "iron": 0, "chance": 0.0, "crew_fraction": config.prize_crew_fraction}
	var ship_id := str(record.get("ship_id", ""))
	if is_enemy_only(ship_id):
		keep["available"] = false
		keep["reason"] = "No yard can refit this hull."
	elif ResourceLookup.find_by_id(SHIPS_DIR, "ship_id", ship_id) == null:
		keep["available"] = false
		keep["reason"] = "Unknown hull."
		push_error("PrizeOffers: no hull with ship_id '%s' under %s" % [ship_id, SHIPS_DIR])
	else:
		keep["chance"] = FleetManager.recapture_chance_now() if FleetManager else config.recapture_chance
	out.append(keep)

	var ransom := {"choice": Choice.RANSOM, "available": true, "reason": "", "gold": 0, "reputation": 0,
			"wood": 0, "iron": 0, "chance": 0.0, "crew_fraction": 0.0}
	var faction_id := str(record.get("faction_id", ""))
	if not bool(record.get("officers_present", false)):
		ransom["available"] = false
		ransom["reason"] = "The officers got away."
	elif faction_id.is_empty() or faction_id == "player":
		ransom["available"] = false
		ransom["reason"] = "No one would pay for them."
	else:
		ransom["gold"] = config.ransom_gold_per_class * klass
		ransom["reputation"] = config.ransom_reputation
	out.append(ransom)

	out.append({"choice": Choice.BREAK, "available": true, "reason": "", "gold": 0, "reputation": 0,
			"wood": config.break_wood_per_class * klass, "iron": config.break_iron_per_class * klass,
			"chance": 0.0, "crew_fraction": 0.0})
	return out


## Performs `choice` for `record`. Refuses (returns {"ok": false}) a choice that `build()` marks
## unavailable. `player` is the player's ship node (for the prize crew). Returns what happened.
static func apply(choice: int, record: Dictionary, player: Node = null,
		config: PrizeConfigData = null) -> Dictionary:
	if config == null:
		config = PrizeConfigData.get_default()
	var offer := {}
	for o in build(record, config):
		if int(o["choice"]) == choice:
			offer = o
	if offer.is_empty() or not bool(offer["available"]):
		return {"ok": false, "choice": choice}
	var klass := maxi(int(record.get("ship_class", 1)), 1)
	match choice:
		Choice.KEEP:
			_take_prize_crew(player, config.prize_crew_fraction)
			var faction_id := str(record.get("faction_id", ""))
			FleetManager.send_prize_home({
				"ship_id": str(record.get("ship_id", "")),
				"ship_class": klass,
				"faction_id": faction_id,
				"provenance_trait": "prize_%s" % faction_id if not faction_id.is_empty() else "prize",
				"condition": float(record.get("condition", config.keep_condition)),
			})
			return {"ok": true, "choice": choice}
		Choice.RANSOM:
			var paid := FactionManager.ransom_officers(str(record.get("faction_id", "")), klass)
			return {"ok": true, "choice": choice, "gold": paid["gold"], "reputation": paid["reputation"]}
		Choice.BREAK:
			ResourceManager.add_resource("wood", int(offer["wood"]))
			ResourceManager.add_resource("iron", int(offer["iron"]))
			EmpireManager.shift_axis(NotorietyGainsData.get_default().dread_break_prize)
			return {"ok": true, "choice": choice, "wood": offer["wood"], "iron": offer["iron"]}
	return {"ok": false, "choice": choice}


## A prize crew sails the prize home, so the player's own crew shrinks (never below one).
static func _take_prize_crew(player: Node, fraction: float) -> void:
	if player == null:
		return
	var dmg = player.get_node_or_null("ShipDamage")
	if dmg == null or dmg.ship_stats == null:
		return
	dmg.crew = maxf(1.0, dmg.crew - dmg.ship_stats.max_crew * fraction)
