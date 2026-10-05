extends Node

## Purpose: Drives the M4 empire-escalation loop — notoriety, region activation, and raids.
## Responsibilities: Tracks notoriety (with idle decay); loads the 3 RegionData resources and
##   activates each once notoriety crosses its threshold; computes home-island defense score
##   (buildings + Defend Home fleet) and empire attack score; periodically rolls and resolves
##   raids against the home island, deducting stolen resources on a loss; persists all of the
##   above via get_save_data()/load_save_data().
## Dependencies: RegionData resources (resources/world/regions/), Island.gd (built_buildings,
##   island id lookup), FleetManager (get_ships_defending_home), ResourceManager (raid theft).

signal notoriety_changed(new_value: float)
signal region_activated(region_id: String)
signal island_captured(island_id: String)
## M29 B.3 — emitted when an island is captured from a faction
signal island_captured_from(island_id: String, previous_faction_id: String)
## M25 — emitted only when the band changes, not on every notoriety tick. The
## HUD and EnemySpawner both react to this rather than polling.
signal heat_tier_changed(tier: HeatTierData)

## M25 "Heat" is the player's wanted level: a BAND over `notoriety`, not a second
## stat. Nothing may write a `heat` variable -- if something starts to, the design
## has been lost (see .kiro/specs/milestone-m25-heat-and-combat-feel/design.md).
## Heat governs how many ambient enemies exist and whether they engage first. It
## must NEVER gate sailing, combat or boarding: that line is what keeps it a
## pressure system rather than the energy meter docs/00_VISION.md §19.2 forbids.
const HEAT_CURVE_PATH := "res://resources/balance/HeatCurve.tres"
## The only resources an AI raid may take. Never Eights or research
## (docs/00_VISION.md §19.2; Multiplayer Charter rule 4 uses the same list).
const RAID_LOOTABLE: Array[String] = ["gold", "wood", "iron", "rum"]
var heat_config: HeatConfigData
var _current_tier: HeatTierData = null
## Set by WorldManager from DockingSystem. Docked at an owned island = "lying
## low", where heat bleeds off faster.
var _lying_low: bool = false

var notoriety: float = 0.0
var _last_gain_unix: int = 0
var _regions: Array[RegionData] = []
var _region_active: Dictionary = {}
var home_island_id: String = ""
var pending_raid_report = null
var _last_raid_check_unix: int = 0

signal raid_resolved(report: Dictionary)

func _ready() -> void:
	set_process(true)
	_last_gain_unix = int(Time.get_unix_time_from_system())

	heat_config = load(HEAT_CURVE_PATH) as HeatConfigData
	if not heat_config:
		push_error("EmpireManager: could not load the heat curve at %s. Ambient danger will not scale." % HEAT_CURVE_PATH)
	
	for path in ResourceLookup.list_resource_paths("res://resources/world/regions/"):
		var region = load(path) as RegionData
		# MVP scope gate — regions 4-5 are authored but not shipped.
		if region and ResourceLookup.is_content_enabled(region):
			if region.tier <= 0:
				push_error("EmpireManager: RegionData %s has no authored tier (got %d) - raid difficulty for this region will be wrong." % [path.get_file(), region.tier])
			_regions.append(region)
			# Region 1 is true, others false initially
			_region_active[region.id] = (region.tier == 1)
			
	notoriety_changed.connect(_check_region_activation)
	_refresh_heat_tier(false)

func is_region_active(region_id: String) -> bool:
	return _region_active.get(region_id, false)

func get_region_for_island(island_id: String) -> RegionData:
	for region in _regions:
		if island_id in region.island_ids:
			return region
	return null

func _check_region_activation(new_notoriety: float) -> void:
	for region in _regions:
		if not _region_active.get(region.id, false):
			if new_notoriety >= region.activation_notoriety_threshold:
				_region_active[region.id] = true
				region_activated.emit(region.id)

func _process(delta: float) -> void:
	var now = int(Time.get_unix_time_from_system())

	# M25 — cooling off. Pre-M25 this was a flat 1.0/60 per second after a 600s
	# grace, which meant a player had to stop playing for ten minutes to observe
	# any change at all; heat never read as something they could manage. Rate and
	# grace are now authored per tier, and doubled while lying low in port.
	#
	# Free decay must always be able to reach tier 0 unaided. The paid clear is a
	# shortcut, never the only way down -- docs/00_VISION.md §19.2 forbids a timer
	# whose removal is only for sale. tests/test_heat_system.gd pins that every
	# tier authors a non-zero decay.
	if notoriety > 0.0 and heat_config:
		var grace: float = heat_config.decay_grace_seconds
		if float(now - _last_gain_unix) > grace:
			var tier := get_heat_tier()
			var per_minute: float = tier.decay_per_minute if tier else 0.0
			if _lying_low:
				per_minute *= heat_config.lying_low_multiplier
			if per_minute > 0.0:
				notoriety = maxf(0.0, notoriety - (per_minute / 60.0) * delta)
				notoriety_changed.emit(notoriety)
				_refresh_heat_tier()

	# Also check raid periodically
	if _last_raid_check_unix == 0:
		_last_raid_check_unix = now
	elif now - _last_raid_check_unix > 900: 
		_last_raid_check_unix = now
		_check_raid()

func notify_island_captured(island_id: String, previous_faction_id: String = "") -> void:
	island_captured.emit(island_id)
	# M29 B.3 — also emit the new signal with the previous owner (always, even if empty)
	island_captured_from.emit(island_id, previous_faction_id)

signal island_tier_changed(island_id: String, new_tier: int)

func notify_island_tier_changed(island_id: String, new_tier: int) -> void:
	island_tier_changed.emit(island_id, new_tier)

func add_notoriety(amount: float) -> void:
	if amount > 0.0:
		_last_gain_unix = int(Time.get_unix_time_from_system())
		
	notoriety += amount
	if notoriety < 0.0:
		notoriety = 0.0
	notoriety_changed.emit(notoriety)
	_refresh_heat_tier()


# ---------------------------------------------------------------------- Heat
# M25. Heat is a read-only band over `notoriety`. Everything that wants to know
# how dangerous the sea currently is asks here, so the thresholds live in exactly
# one authored place (resources/balance/HeatCurve.tres).

func get_heat_tier() -> HeatTierData:
	if not heat_config:
		return null
	if _current_tier == null:
		_current_tier = heat_config.tier_for(notoriety)
	return _current_tier


func get_heat_level() -> int:
	var tier := get_heat_tier()
	return tier.tier if tier else 0


func get_heat_name() -> String:
	var tier := get_heat_tier()
	return tier.display_name if tier else ""


## True when ambient ships attack without being provoked. Below this, an enemy
## patrols and ignores the player until that specific ship is shot, rammed or
## boarded -- which is what stops a new player being farmed before they can steer.
func enemies_engage_unprovoked() -> bool:
	var tier := get_heat_tier()
	return tier.engages_unprovoked if tier else true


## Set by WorldManager off DockingSystem. Signals over direct references: the
## docking system lives on the player ship and is created at runtime, so it
## cannot be reached from an autoload without a fragile lookup chain.
func set_lying_low(value: bool) -> void:
	_lying_low = value


func is_lying_low() -> bool:
	return _lying_low


## Optional relief, never the only way down (docs/00_VISION.md §19.2 -- free decay
## always reaches tier 0 unaided). Drops exactly ONE tier per purchase, so clearing
## from Nemesis is a repeated deliberate choice rather than one button that erases
## every consequence.
##
## Returns false and changes nothing when there is no tier below, the tier is not
## purchasable, or the player cannot afford it.
func spend_to_reduce_heat() -> bool:
	if not heat_config:
		return false
	var tier := get_heat_tier()
	if tier == null or tier.clear_cost_eights <= 0:
		return false
	var below := heat_config.tier_below(tier)
	if below == null:
		return false   # already at the bottom band
	var cost := {ResourceManager.PREMIUM_CURRENCY: tier.clear_cost_eights}
	if not ResourceManager.can_afford(cost) or not ResourceManager.spend_resources(cost):
		return false

	# Land just inside the tier below rather than at its floor, so one purchase is
	# one band -- not a slide to zero.
	notoriety = maxf(below.min_notoriety, tier.min_notoriety - 1.0)
	notoriety_changed.emit(notoriety)
	_refresh_heat_tier()
	return true


## Re-resolves the band and emits only on an actual crossing, so the HUD is not
## spammed once per frame during decay.
func _refresh_heat_tier(allow_emit: bool = true) -> void:
	if not heat_config:
		return
	var resolved := heat_config.tier_for(notoriety)
	if resolved == _current_tier:
		return
	_current_tier = resolved
	if allow_emit:
		heat_tier_changed.emit(_current_tier)

func _compute_defense_score() -> float:
	if home_island_id.is_empty():
		return 0.0
		
	var target_island = null
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("get_island_id") and island.get_island_id() == home_island_id:
			target_island = island
			break
			
	if not target_island:
		return 0.0
		
	# Any level counts (ids are level-suffixed: "fortress_l1" — see
	# Island.has_building_type()); the exact has_building("fortress") this
	# used never matched real data, so defence was always 0.
	var fortress_tier: float = 1.0 if target_island.has_building_type("fortress") else 0.0
	var watchtower_tier: float = 1.0 if target_island.has_building_type("watchtower") else 0.0
	
	var num_ships_defending_home: int = 0
	# Task 18 will update num_ships_defending_home via FleetManager
	if FleetManager.has_method("get_ships_defending_home"):
		num_ships_defending_home = FleetManager.get_ships_defending_home()
	
	return (fortress_tier * 20.0) + (watchtower_tier * 15.0) + (10.0 * float(num_ships_defending_home))

func _compute_attack_score() -> float:
	var highest_tier = 1
	for region in _regions:
		if is_region_active(region.id) and region.tier > highest_tier:
			highest_tier = region.tier
	return float(highest_tier * 25.0) + (notoriety * 0.3)

func _get_faction_by_id(f_id: String) -> Resource:
	for path in ResourceLookup.list_resource_paths("res://resources/factions/"):
		var res = load(path)
		if res and res.get("faction_id") == f_id:
			return res
	return null

func _check_raid() -> void:
	if home_island_id.is_empty():
		return
	
	var active_empire_regions = []
	for region in _regions:
		if is_region_active(region.id):
			var faction = _get_faction_by_id(region.dominant_faction)
			if faction and faction.get("is_empire") == true:
				active_empire_regions.append(region)
				
	if active_empire_regions.is_empty():
		return
		
	# Reverted probability floor
	var prob = clamp(notoriety / 200.0, 0.05, 0.25)

	# M29 B.4 — apply per-faction raid frequency multiplier if available
	# (we'll know the attacking faction below, but this is estimated)
	var avg_frequency_mult = 1.0
	if not active_empire_regions.is_empty():
		var mults = []
		for region in active_empire_regions:
			var faction = _get_faction_by_id(region.dominant_faction) as FactionData
			if faction:
				var mult = faction.raid_frequency_mult
				mults.append(mult)
		if not mults.is_empty():
			avg_frequency_mult = mults.reduce(func(a, b): return a + b) / float(mults.size())

	prob *= avg_frequency_mult
	prob = clamp(prob, 0.0, 1.0)

	if randf() <= prob:
		# Pick the highest tier empire region to raid
		var attacking_region = active_empire_regions[0]
		for r in active_empire_regions:
			if r.tier > attacking_region.tier:
				attacking_region = r
		
		var attacking_faction = _get_faction_by_id(attacking_region.dominant_faction)
		if attacking_faction:
			var report = _resolve_raid(attacking_faction, attacking_region)
			pending_raid_report = report
			raid_resolved.emit(report)

func _resolve_raid(attacking_faction: Resource, region: RegionData) -> Dictionary:
	var defense_score = _compute_defense_score()
	var attack_score = _compute_attack_score()
	
	var repelled = defense_score >= attack_score
	var stolen = {}
	
	if not repelled:
		var steal_fraction = clamp((attack_score - defense_score) / attack_score, 0.05, 0.25)
		var current_resources = ResourceManager.current_resources
		for res_name in RAID_LOOTABLE:
			# M30 0.3 — raids never steal Eights (AGENTS.md never-list); the
			# whitelist also keeps research and any future key out of loot.
			if ResourceManager.is_premium_currency(res_name) or not current_resources.has(res_name):
				continue
			var current_amount = current_resources[res_name]
			var amount = floor(current_amount * steal_fraction)
			if amount > 0:
				stolen[res_name] = int(amount)
				ResourceManager.spend_resource(res_name, int(amount))
	
	var faction_id = attacking_faction.get("faction_id") if attacking_faction else "unknown"
	return {
		"faction_id": faction_id,
		"repelled": repelled,
		"stolen": stolen,
		"timestamp_unix": int(Time.get_unix_time_from_system())
	}

## Single source of truth for the raid outcome's one-sentence summary, reused by
## RaidReportScreen (full report) and LocalNotificationManager (notification body)
## so the two surfaces can't drift out of sync in wording (M12 Task 11).
func describe_raid_outcome(report: Dictionary) -> String:
	var faction_name: String = str(report.get("faction_id", "unknown")).capitalize()
	if report.get("repelled", true):
		return tr("Your home island defenses held off an attack from %s.") % faction_name
	return tr("Your home island was raided by %s.") % faction_name

func get_save_data() -> Dictionary:
	return {
		"notoriety": notoriety,
		"region_active": _region_active.duplicate(),
		"home_island_id": home_island_id,
		"last_raid_check_unix": _last_raid_check_unix,
		"pending_raid_report": pending_raid_report
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("notoriety"):
		notoriety = float(data["notoriety"])
	if data.has("region_active") and typeof(data["region_active"]) == TYPE_DICTIONARY:
		_region_active = data["region_active"].duplicate()
	if data.has("home_island_id"):
		home_island_id = str(data["home_island_id"])
	if data.has("last_raid_check_unix"):
		_last_raid_check_unix = int(data["last_raid_check_unix"])
	if data.has("pending_raid_report"):
		pending_raid_report = data["pending_raid_report"]
		
	notoriety_changed.emit(notoriety)
	# Heat is derived, so it needs no save section of its own -- but the band must
	# be re-resolved after a load or the world keeps the tier it booted with.
	_refresh_heat_tier()
