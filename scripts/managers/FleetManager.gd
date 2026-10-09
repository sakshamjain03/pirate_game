extends Node

## Purpose: Global manager for the player's fleet (M6/M8).
## Responsibilities: Tracks owned ships, owned captains, current active ship, background
##   trade/patrol missions, per-ship "Defend Home" flags (M4) — get_ships_defending_home()
##   excludes the currently active ship and any ship on a mission, for EmpireManager's defense
##   score — and per-ship level/module progression (M8, `docs/navalCombat.md` §13).
## Dependencies: ShipStats, OwnedShipData, ShipModuleData, CaptainData, ResourceManager,
##   EmpireManager (defense score consumer)

signal fleet_changed()
signal active_ship_changed(ship_stats: ShipStats, captain: CaptainData)
signal captain_recruited(captain: CaptainData)

## Each entry wraps a shared `ShipStats` template plus per-instance level/module
## state — a `ShipStats` resource is shared by every hull of its class, so two
## owned Sloops must not share one mutable record.
var owned_ships: Array[OwnedShipData] = []
var owned_captains: Array[CaptainData] = []
## M30 0.2 — save entries whose captain .tres failed to resolve; re-saved as-is.
var _unresolved_captains: Array = []
var active_ship_index: int = 0
var active_captain_index: int = 0
## M30 W2 (2.7) - ship uids (OwnedShipData.uid), not positions: a position shifts the moment a
## hull is dismantled or a prize is added, silently handing one ship's duty to another.
var defend_home_ship_uids: Array = []

## ship uid (String) -> {"captain_id": String, "captain_index": int, "mission_type": String,
## "timer": float, ...}. `captain_id` pairs by CaptainData.captain_id; `captain_index` is only the
## fallback for a captain that has no id (test fixtures).
var active_missions: Dictionary = {}

## M27 — the ScheduleManager job target for ship construction.
const SHIP_TARGET := "fleet"

func _ready() -> void:
	# Give the player a starter ship if empty. Must match PlayerShip.tscn's
	# own ship_stats (Sloop) — a mismatch here previously made the Shipyard
	# tab show a phantom Dinghy as "Owned" and the actual Sloop the player
	# was sailing as still buyable.
	if owned_ships.size() == 0:
		var starter = load("res://resources/ships/Sloop.tres")
		if starter:
			var starter_owned := OwnedShipData.new()
			starter_owned.ship_stats = starter
			owned_ships.append(starter_owned)
			
	if owned_captains.size() == 0:
		var starter_cap = load("res://resources/captains/Jack.tres")
		if starter_cap:
			owned_captains.append(starter_cap)
			
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(on_economy_tick)

	ScheduleManager.job_completed.connect(_on_job_completed)

## M27 — a new hull takes time at the Shipyard: pays now (ResourceManager.pay(),
## which can cover a shortfall with Eights), and add_ship() runs when the job
## completes. `shipyard_level` is the building level of the Shipyard it's built
## at — the speed source (design.md §4). Refuses a hull already owned or already
## on the slipway, so it can't be paid for twice.
func start_ship_construction(ship: ShipStats, cost: Dictionary, shipyard_level: int, allow_cover: bool = false) -> bool:
	if owns_ship_stats(ship) or is_ship_under_construction(ship):
		return false
	if not ResourceManager.pay(cost, allow_cover):
		return false
	var duration := get_ship_build_seconds(ship, shipyard_level)
	if duration <= 0.0:
		add_ship(ship)
	else:
		ScheduleManager.start_job("ship", SHIP_TARGET, ship.resource_path, duration)
	return true

func get_ship_build_seconds(ship: ShipStats, shipyard_level: int) -> float:
	return ScheduleManager.pricing.effective_duration("ship", ship.build_seconds, shipyard_level)

## The running construction job for this hull, or {}.
func get_ship_construction_job(ship: ShipStats) -> Dictionary:
	for job in ScheduleManager.get_jobs_of_kind("ship"):
		if job["payload"] == ship.resource_path:
			return job
	return {}

func is_ship_under_construction(ship: ShipStats) -> bool:
	return not get_ship_construction_job(ship).is_empty()

func _on_job_completed(job: Dictionary) -> void:
	if job["kind"] != "ship":
		return
	var path: String = job["payload"]
	var ship: ShipStats = null
	if ResourceLoader.exists(path):
		ship = load(path) as ShipStats
	if not ship:
		push_error("FleetManager: ship construction completed for unresolvable hull '%s'." % path)
		return
	add_ship(ship)

## === Hull identity (M30 W2 2.7) ===

## The uid of the hull at `ship_index`, assigning one if it has none yet (a hull appended to
## `owned_ships` directly, or loaded from a save that predates uids). "" for a bad index.
func uid_of(ship_index: int) -> String:
	if ship_index < 0 or ship_index >= owned_ships.size() or owned_ships[ship_index] == null:
		return ""
	var owned := owned_ships[ship_index]
	if owned.uid.is_empty():
		owned.uid = _new_uid()
	return owned.uid


## The current position of the hull with this uid, or -1.
func index_of_uid(uid: String) -> int:
	for i in owned_ships.size():
		if owned_ships[i] != null and owned_ships[i].uid == uid and not uid.is_empty():
			return i
	return -1


func get_ship_by_uid(uid: String) -> OwnedShipData:
	var i := index_of_uid(uid)
	return owned_ships[i] if i >= 0 else null


## The mission of the hull at `ship_index` ({} if none).
func get_mission(ship_index: int) -> Dictionary:
	return active_missions.get(uid_of(ship_index), {})


func _new_uid() -> String:
	var taken := {}
	for o in owned_ships:
		if o != null and not o.uid.is_empty():
			taken[o.uid] = true
	var uid := ""
	while uid.is_empty() or taken.has(uid):
		uid = "s%x%x" % [int(Time.get_unix_time_from_system()), randi() % 0xFFFFFF]
	return uid


## A captain's stable key: its authored id, else its resource path.
static func captain_key(c: CaptainData) -> String:
	if c == null:
		return ""
	return c.captain_id if not c.captain_id.is_empty() else c.resource_path


func _captain_for(mission: Dictionary) -> CaptainData:
	var key := str(mission.get("captain_id", ""))
	if not key.is_empty():
		for c in owned_captains:
			if captain_key(c) == key:
				return c
	var idx := int(mission.get("captain_index", -1))
	if idx >= 0 and idx < owned_captains.size():
		return owned_captains[idx]
	return null


func on_economy_tick() -> void:
	for ship_uid in active_missions.keys():
		var mission = active_missions[ship_uid]
		var cap = _captain_for(mission)
		if cap == null:
			continue

		# Give XP to captain
		cap.add_xp(10)
		
		# Generate resources
		if mission["mission_type"] == "trade":
			var amount = 10 * cap.level
			ResourceManager.add_resource("gold", amount)
		elif mission["mission_type"] == "patrol":
			if FactionManager.has_method("add_reputation"):
				FactionManager.add_reputation("merchant_guild", 1)
		elif mission["mission_type"] == "trade_route":
			# M11 Requirement 6 — same tick mechanism as "trade", scaled by the
			# route's region_tier so a route into more dangerous waters is
			# worth more, not just a rename of the flat-rate mission.
			var tier = int(mission.get("region_tier", 1))
			var amount = 10 * cap.level * tier
			ResourceManager.add_resource("gold", amount)
			if FactionManager.has_method("add_reputation"):
				FactionManager.add_reputation("merchant_guild", 1)

func assign_mission(ship_index: int, captain_index: int, mission_type: String) -> void:
	if ship_index == active_ship_index: return # Active ship cannot run background missions
	var uid := uid_of(ship_index)
	if uid.is_empty():
		return
	active_missions[uid] = {
		"captain_id": captain_key(owned_captains[captain_index]) if captain_index >= 0 and captain_index < owned_captains.size() else "",
		"captain_index": captain_index,
		"mission_type": mission_type,
		"timer": 0.0
	}
	fleet_changed.emit()

## M11 Requirement 6 — a trade route is a named, region-tied variant of the
## existing "trade" mission (same active_missions dict, same economy-tick
## mechanism), not a parallel system. route_name/region_tier are exposed so
## the player can see and reassign the route rather than it being an
## invisible background timer.
func assign_trade_route(ship_index: int, captain_index: int, route_name: String, region_tier: int) -> void:
	if ship_index == active_ship_index: return
	var uid := uid_of(ship_index)
	if uid.is_empty():
		return
	active_missions[uid] = {
		"captain_id": captain_key(owned_captains[captain_index]) if captain_index >= 0 and captain_index < owned_captains.size() else "",
		"captain_index": captain_index,
		"mission_type": "trade_route",
		"timer": 0.0,
		"route_name": route_name,
		"region_tier": clampi(region_tier, 1, 3),
	}
	fleet_changed.emit()

func get_mission_display_text(ship_index: int) -> String:
	var mission = get_mission(ship_index)
	if mission.is_empty():
		return ""
	if mission["mission_type"] == "trade_route" and mission.get("route_name", "") != "":
		return mission["route_name"]
	return String(mission["mission_type"]).capitalize()

func set_defend_home(ship_index: int, defend: bool) -> void:
	var uid := uid_of(ship_index)
	if uid.is_empty():
		return
	if defend:
		if not defend_home_ship_uids.has(uid):
			defend_home_ship_uids.append(uid)
	else:
		if defend_home_ship_uids.has(uid):
			defend_home_ship_uids.erase(uid)
	fleet_changed.emit()

func is_defending_home(ship_index: int) -> bool:
	return defend_home_ship_uids.has(uid_of(ship_index))

func get_ships_defending_home() -> int:
	var count = 0
	for uid in defend_home_ship_uids:
		var idx := index_of_uid(uid)
		if idx >= 0 and idx != active_ship_index and not is_on_mission(idx):
			count += 1
	return count

func unassign_mission(ship_index: int) -> void:
	var uid := uid_of(ship_index)
	if active_missions.has(uid):
		active_missions.erase(uid)
		fleet_changed.emit()

func is_on_mission(ship_index: int) -> bool:
	return active_missions.has(uid_of(ship_index))

func add_ship(ship: ShipStats) -> void:
	if owns_ship_stats(ship):
		return
	var owned := OwnedShipData.new()
	owned.ship_stats = ship
	owned.uid = _new_uid()
	owned_ships.append(owned)
	fleet_changed.emit()


func owns_ship_stats(ship: ShipStats) -> bool:
	## The Shipyard roster is a catalog of shared `ShipStats` templates, so
	## "do I already own this hull" has to compare against each entry's
	## template, not identity of the `OwnedShipData` wrapper.
	for o in owned_ships:
		if o and o.ship_stats == ship:
			return true
	return false

func add_captain(captain: CaptainData) -> void:
	if not captain in owned_captains:
		owned_captains.append(captain)
		fleet_changed.emit()
		captain_recruited.emit(captain)

func get_active_ship() -> ShipStats:
	## Returns the ship's EFFECTIVE stats (template + level/module bonuses) —
	## every existing caller (IslandMenu's ship-switch, SaveManager's fleet
	## load) already treats this as a plain ShipStats to assign onto the player,
	## so the wrapper stays internal rather than changing that contract.
	var owned := get_active_owned_ship()
	return owned.get_effective_stats() if owned else null


func get_active_owned_ship() -> OwnedShipData:
	if active_ship_index >= 0 and active_ship_index < owned_ships.size():
		return owned_ships[active_ship_index]
	return null


func level_up_ship(index: int, allow_cover: bool = false) -> bool:
	if index < 0 or index >= owned_ships.size():
		return false
	var owned := owned_ships[index]
	if owned.level >= OwnedShipData.MAX_LEVEL:
		return false
	# M23 — Town-Hall gating: every component must have caught up first.
	if not owned.can_level_up_ship():
		return false
	var cost := owned.get_level_up_cost()
	if not ResourceManager or not ResourceManager.pay(cost, allow_cover):
		return false
	owned.level += 1
	if AudioManager: AudioManager.play_sound("level_up")
	fleet_changed.emit()
	_refresh_ship_on_deck(index)
	return true


func upgrade_component(index: int, component_id: String, allow_cover: bool = false) -> bool:
	## M23 Requirement 3 — raise one part of a hull by a level, capped at the
	## ship's own level (OwnedShipData.can_upgrade_component).
	if index < 0 or index >= owned_ships.size():
		return false
	var owned := owned_ships[index]
	if not owned.can_upgrade_component(component_id):
		return false
	var cost := owned.get_component_upgrade_cost(component_id)
	if not ResourceManager or not ResourceManager.pay(cost, allow_cover):
		return false
	owned.component_levels[component_id] = owned.get_component_level(component_id) + 1
	if AudioManager: AudioManager.play_sound("level_up")
	fleet_changed.emit()
	_refresh_ship_on_deck(index)
	return true


func equip_module(index: int, module: ShipModuleData, allow_cover: bool = false) -> bool:
	if index < 0 or index >= owned_ships.size() or not module:
		return false
	var owned := owned_ships[index]
	if owned.ship_stats and not module.is_compatible_with_class(owned.ship_stats.ship_class):
		return false
	var cost := {"gold": module.cost_gold, "wood": module.cost_wood, "iron": module.cost_iron}
	if not ResourceManager or not ResourceManager.pay(cost, allow_cover):
		return false
	owned_ships[index].equip_module(module)
	fleet_changed.emit()
	_refresh_ship_on_deck(index)
	return true


func _refresh_ship_on_deck(index: int) -> void:
	## Leveling/equipping the ship the player is currently sailing must be felt
	## immediately, not just on the next ship switch — mirrors the assignment
	## IslandMenu's own ship-purchase flow already does.
	if index != active_ship_index:
		return
	var player = get_tree().get_first_node_in_group("player_ship")
	if player and "ship_stats" in player:
		player.ship_stats = get_active_ship()

## M28 — the one write path for "which ship am I sailing, under which captain".
## IslandMenu's Make Active used to write both indices directly, so
## active_ship_changed (declared long before) never fired and nothing could react
## to a captain assignment. The captain follows the ship's row pairing, falling
## back to the first captain, exactly as the fleet list displays it.
func set_active_ship(index: int) -> void:
	active_ship_index = index
	active_captain_index = index if index < owned_captains.size() else 0
	active_ship_changed.emit(get_active_ship(), get_active_captain())

func get_active_captain() -> CaptainData:
	if active_captain_index >= 0 and active_captain_index < owned_captains.size():
		return owned_captains[active_captain_index]
	return null

func get_save_data() -> Dictionary:
	var ship_data = []
	for o in owned_ships:
		if o:
			ship_data.append(o.get_save_data())

	# M30 0.2 — captain level/XP live on the CaptainData itself (add_xp()), so
	# the bare path this used to save reset every captain to level 1 on load.
	var cap_data = []
	for c in owned_captains:
		cap_data.append({
			"path": c.resource_path,
			"level": c.level,
			"current_xp": c.current_xp,
		})
	# Entries whose .tres no longer resolves are carried forward untouched, so
	# a missing file (content gating, a rename) never deletes the captain.
	cap_data.append_array(_unresolved_captains)

	# Every hull is saved with a uid, including ones appended without one.
	for i in owned_ships.size():
		uid_of(i)
	ship_data.clear()
	for o in owned_ships:
		if o:
			ship_data.append(o.get_save_data())

	return {
		"owned_ships": ship_data,
		"owned_captains": cap_data,
		"active_ship_index": active_ship_index,
		"active_ship_uid": uid_of(active_ship_index),
		"active_captain_index": active_captain_index,
		"active_missions": active_missions.duplicate(true),
		"defend_home_ship_uids": defend_home_ship_uids.duplicate()
	}


## M30 W2 (2.7) - turns a fleet save written before hull uids (schema 1) into the uid form:
## every ship gets a uid, `active_missions` and Defend Home are re-keyed from position to that
## uid, and each mission records its captain's id. Pure and idempotent: a fleet that already
## carries uids (and uid-keyed missions) comes back unchanged. The uid is "legacy-<position>",
## deterministic so two devices migrating the same save agree.
static func migrate_fleet_save(fleet: Dictionary) -> Dictionary:
	var out := fleet.duplicate(true)
	var ships: Array = out.get("owned_ships", [])
	var uid_by_index: Array = []
	for i in ships.size():
		var entry = ships[i]
		if entry is Dictionary:
			if str(entry.get("uid", "")).is_empty():
				entry["uid"] = "legacy-%d" % i
			uid_by_index.append(str(entry["uid"]))
		else:
			uid_by_index.append("legacy-%d" % i)  # a pre-M8 bare path: the loader gives it the same uid
	var captains: Array = out.get("owned_captains", [])
	var missions: Dictionary = {}
	for key in (out.get("active_missions", {}) as Dictionary).keys():
		var mission: Dictionary = (out["active_missions"][key] as Dictionary).duplicate(true)
		var uid := ""
		if str(key).is_valid_int():
			var idx := int(str(key))
			uid = uid_by_index[idx] if idx >= 0 and idx < uid_by_index.size() else ""
		else:
			uid = str(key)
		if uid.is_empty():
			continue  # a mission on a hull that no longer exists
		if not mission.has("captain_id"):
			var cidx := int(mission.get("captain_index", -1))
			var cap = captains[cidx] if cidx >= 0 and cidx < captains.size() else null
			var path := ""
			if cap is Dictionary:
				path = str(cap.get("path", ""))
			elif cap is String:
				path = cap
			mission["captain_id"] = _captain_id_for_path(path)
		missions[uid] = mission
	out["active_missions"] = missions
	if out.has("defend_home_ship_indices"):
		var uids: Array = out.get("defend_home_ship_uids", [])
		for idx in out["defend_home_ship_indices"]:
			if int(idx) >= 0 and int(idx) < uid_by_index.size() and not uid_by_index[int(idx)].is_empty():
				if not uids.has(uid_by_index[int(idx)]):
					uids.append(uid_by_index[int(idx)])
		out["defend_home_ship_uids"] = uids
		out.erase("defend_home_ship_indices")
	if not out.has("active_ship_uid"):
		var ai := int(out.get("active_ship_index", 0))
		out["active_ship_uid"] = uid_by_index[ai] if ai >= 0 and ai < uid_by_index.size() else ""
	return out


## The captain_id of the authored captain at `path`, falling back to the path itself.
static func _captain_id_for_path(path: String) -> String:
	if path.is_empty():
		return ""
	if ResourceLoader.exists(path):
		var c := load(path) as CaptainData
		if c and not c.captain_id.is_empty():
			return c.captain_id
	return path

func load_save_data(data: Dictionary) -> void:
	owned_ships.clear()
	owned_captains.clear()
	active_missions.clear()
	# Defence in depth: SaveManager migrates schema-1 saves, but a fleet that arrives some other
	# way (cloud merge, a hand-built test fixture) still lands on uids. Idempotent.
	data = migrate_fleet_save(data)
	
	if data.has("owned_ships"):
		for entry in data["owned_ships"]:
			if entry is Dictionary:
				owned_ships.append(OwnedShipData.from_save_data(entry))
			elif entry is String and ResourceLoader.exists(entry):
				# Pre-M8 save format: a flat ship path, no level/modules yet.
				var legacy := OwnedShipData.new()
				legacy.uid = "legacy-%d" % owned_ships.size()
				legacy.ship_stats = load(entry)
				owned_ships.append(legacy)
				
	_unresolved_captains.clear()
	if data.has("owned_captains"):
		for entry in data["owned_captains"]:
			# Pre-M30 saves hold a bare path (level 1, no XP); M30 saves a dict.
			var path := ""
			var level := 1
			var current_xp := 0
			if entry is String:
				path = entry
			elif entry is Dictionary:
				path = str(entry.get("path", ""))
				level = int(entry.get("level", 1))
				current_xp = int(entry.get("current_xp", 0))
			if path.is_empty():
				continue
			if not ResourceLoader.exists(path):
				push_error("FleetManager: unresolvable captain path '%s' (kept in the save)" % path)
				_unresolved_captains.append(entry if entry is Dictionary else {"path": path, "level": level, "current_xp": current_xp})
				continue
			# Deliberately the shared cached resource, not a duplicate(): the
			# Tavern, Codex and DevConsole test ownership by identity
			# (`cap in owned_captains`), and a copy would read as un-hired.
			var captain: CaptainData = load(path)
			captain.level = maxi(1, level)
			captain.current_xp = maxi(0, current_xp)
			owned_captains.append(captain)

	active_ship_index = int(data.get("active_ship_index", 0))
	active_captain_index = int(data.get("active_captain_index", 0))
	# Resolve the active hull by uid when the save has one, so it survives a reordered fleet.
	var active_uid := str(data.get("active_ship_uid", ""))
	if not active_uid.is_empty() and index_of_uid(active_uid) >= 0:
		active_ship_index = index_of_uid(active_uid)
	if data.has("active_missions"):
		for k in data["active_missions"].keys():
			active_missions[str(k)] = data["active_missions"][k]

	defend_home_ship_uids.clear()
	for uid in data.get("defend_home_ship_uids", []):
		defend_home_ship_uids.append(str(uid))

	fleet_changed.emit()
