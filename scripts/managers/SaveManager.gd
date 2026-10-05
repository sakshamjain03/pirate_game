extends Node

## SaveManager
## Handles saving and loading player empire data.
##
## Responsibilities:
## - Complete JSON save/load covering player position/health, economy, per-island built buildings, fleet, tech, and faction reputation
## - Auto-saves every 60s and on dock completion
## - Persists last_saved_unix and, on load, replays capped offline economy/fleet ticks directly
##   (not via the shared global_economy_tick signal, since FactionManager also subscribes to it
##   for hunter-ship spawning — see docs/05_CURRENT_SYSTEMS.md D-notes / milestone-m5 design.md)

## Emitted after load_game() has fully applied a save (including offline catch-up and
## empire/raid-report restoration). WorldManager and WorldHUD's _ready() run before the
## deferred load_game() call completes, so they must react to this signal instead of
## reading pending_raid_report / _pending_offline_ticks synchronously at scene start.
signal game_loaded()

## M2 Task 12.3 — emitted instead of silently falling through to a blank
## game whenever load_game() can't use the save it found on disk. WorldHUD
## surfaces this to the player via announce_event() rather than leaving a
## lost save unexplained.
signal load_failed(reason: String)

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data.json.bak"
const MAX_OFFLINE_SECONDS := 4 * 60 * 60

## M10 Requirement 9 — a version stamp for M12's full migration/backup pass
## to build on. Deliberately inert beyond the field itself: no migration
## logic yet, just recording what schema version wrote a given save.
const SAVE_SCHEMA_VERSION := 1

## preload rather than the bare global class name — see the matching note in SettingsMenu.gd;
## headless GUT runs don't always have a freshly rebuilt global-script-class cache.
const ChoiceDialogScript := preload("res://scripts/ui/ChoiceDialog.gd")
## Same reason as ChoiceDialogScript: a bare class_name reference resolves through the
## global class cache, which a stale .godot/ cache (e.g. a fresh worktree) can miss.
const MaelstromRecordScript := preload("res://scripts/modes/MaelstromRecord.gd")

var _save_timer: float = 0.0
var _auto_save_interval: float = 60.0
## M30 0.4 — true while the cloud-conflict dialog is open; the autosave must
## not write (and upload) the in-memory World before the player has chosen.
var _suspend_autosave := false
var _pending_offline_ticks: int = 0

## M17 Requirement 6.1/6.5 — the resource delta actually gained during the
## catch-up loop below, so the offline-return surface can offer to double
## the exact amount already granted (never a separately-computed guess).
## Cleared by whoever reads it (WorldHUD), same one-shot convention as
## _pending_offline_ticks above.
var _pending_offline_income: Dictionary = {}

## M14 Requirement 5.2 — compared by WorldHUD._check_whats_new() against
## PatchNotesData's latest entry to decide whether to auto-show the What's
## New panel once. Seeded to the current latest version on a genuinely new
## game (World._seed_whats_new_version()) so a first-time player never sees
## a "what's new" popup for content they're about to experience firsthand;
## left at "" for an existing pre-M14 save, which is the correct trigger to
## show it once.
var last_seen_whats_new_version: String = ""

## M15 Wave 3 — cloud sync. True while the most recent cloud push failed; the *next* successful
## save_game() call (whenever that happens to be — auto-save, dock, etc.) simply tries again with
## whatever the local state is by then, which already satisfies Requirement 4.4's "only the latest
## state needs to eventually reach the cloud, not every intermediate one" — this flag exists only
## so the retry behavior is observable/testable, not because a queue is needed.
var _cloud_sync_pending: bool = false
var _did_launch_cloud_check: bool = false

## Test seam, mirrors AuthManager's: when set, _send_cloud_request() calls this instead of a
## real HTTPRequest.
var _request_override: Callable = Callable()

## M26 — the Maelstrom's best-run record, round-tripped as the optional
## "maelstrom" section (omitted entirely until a run has finished).
var _maelstrom_data: Dictionary = {}
## M26 — where a finished run's Eights and record wait when there is no campaign
## save to patch yet (a fresh install). Claimed into the campaign by load_game()
## and deleted by the next successful save_game(). Never creates the main save,
## so a run can't make "Continue" appear over a near-empty file.
const MAELSTROM_PENDING_PATH := "user://maelstrom_pending.json"
var _maelstrom_pending_claimed: bool = false

func _ready() -> void:
	# fresh_sign_in, not signed_in — a background token refresh also emits signed_in (for UI
	# reactivity) and must NOT re-trigger a cloud-conflict check mid-session. See AuthManager.gd.
	AuthManager.fresh_sign_in.connect(_on_signed_in)
	# Deferred: this is the first autoload, so the managers below haven't run their own
	# _ready() yet. By idle time they have, and nothing has loaded a save (Boot only
	# loads settings), so this captures exactly the state a fresh process starts in.
	call_deferred("_capture_fresh_state")


func _notification(what: int) -> void:
	# M30 Requirement 1.4 — save when leaving the World
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Only save in campaign mode (never outside World per M26 rule)
		if SceneManager.is_campaign() and get_tree().current_scene and get_tree().current_scene.name == "World":
			save_game()


## The campaign-state autoloads a New Game must return to their boot state. Each one's
## load_save_data() fully replaces its state when handed a complete get_save_data()
## snapshot. ScheduleManager has its own reset(); TutorialManager has its own New Game
## session calls (MainMenu); EntitlementManager (owned cosmetics) deliberately survives.
const _NEW_GAME_RESET_MANAGERS := [
	"ResourceManager", "FleetManager", "TechManager", "FactionManager",
	"EmpireManager", "CampaignManager", "SeasonalEventManager",
]
var _fresh_state: Dictionary = {}


func _capture_fresh_state() -> void:
	for manager_name in _NEW_GAME_RESET_MANAGERS:
		var manager := get_node_or_null("/root/" + manager_name)
		if manager and manager.has_method("get_save_data"):
			_fresh_state[manager_name] = manager.get_save_data().duplicate(true)


## New Game used to delete the save file and reset four resources, and nothing else.
## Every other manager is an autoload, and load_game() skips a section a save doesn't
## have, so a New Game after playing in the same session (World -> Main Menu -> New
## Game) kept the previous run's chapter progress, fleet, techs, notoriety/heat,
## reputation and running timers. It also replaced current_resources with a dict with
## no "eights" key, so add_resource() rejected even chapter-reward Eights as unknown.
## True once this session's load_game() has put the on-disk Eights balance into
## ResourceManager; from then on memory is the current balance (it also holds
## anything earned since the last save).
var _wallet_loaded_this_session: bool = false


## The player's true Pieces of Eight balance, whether or not the campaign has
## been loaded this session: memory once it has, otherwise the save (or its
## backup) plus the pending file, which never overlap (writing one folds the
## other in).
func eights_balance() -> int:
	var key := ResourceManager.PREMIUM_CURRENCY
	if _wallet_loaded_this_session:
		return ResourceManager.get_resource(key)
	var total := 0
	if has_recoverable_save_data():
		var data: Dictionary = _read_save_file(SAVE_PATH)["data"]
		if data.is_empty():
			data = _read_save_file(BACKUP_PATH)["data"]
		var economy = data.get("economy", {})
		if economy is Dictionary:
			total += int(economy.get(key, 0))
	total += int(_read_maelstrom_pending().get("eights", 0))
	return total


## Starting over ends the empire, never the wallet: Pieces of Eight (bought or
## earned) and owned cosmetics carry into the new game; everything else returns
## to a fresh start. The balance goes into the pending file BEFORE the save is
## deleted, and the first World load claims it exactly once. Returns false,
## having deleted nothing, if the Eights could not be put somewhere safe first.
func begin_new_game(wants_lessons: bool) -> bool:
	var carried := eights_balance()
	var pending_before := _read_maelstrom_pending()
	var pending := pending_before.duplicate(true)
	pending["eights"] = carried
	if not _write_pending(pending):
		push_error("SaveManager: could not carry %d Eights into a new game; New Game aborted." % carried)
		return false
	delete_save()
	if has_save_data():
		# The old save survived the delete, so load_game() would count it AND the
		# pending balance. Put the pending file back and change nothing.
		push_error("SaveManager: the campaign save could not be deleted; New Game aborted.")
		if pending_before.is_empty():
			DirAccess.remove_absolute(MAELSTROM_PENDING_PATH)
		else:
			_write_pending(pending_before)
		return false
	AnalyticsManager.log_first_event("new_game_started")
	reset_to_new_game()
	_maelstrom_data = {}
	_maelstrom_pending_claimed = false
	_wallet_loaded_this_session = false
	TutorialManager.start_new_game_session()
	TutorialManager.start_new_game_lessons(wants_lessons)
	if not wants_lessons:
		# "I know these waters": every tab open from the start. Chapter 1's
		# dialogue, objectives and rewards still run (M28 Requirement 3.2).
		TutorialManager.skip_tutorial()
	return true


func _write_pending(pending: Dictionary) -> bool:
	var file := FileAccess.open(MAELSTROM_PENDING_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(pending, "\t"))
	file.close()
	return true


func reset_to_new_game() -> void:
	# Base caps first: warehouses from the old run no longer exist.
	if ResourceManager.has_method("recalculate_storage_capacity"):
		ResourceManager.recalculate_storage_capacity()
	for manager_name in _NEW_GAME_RESET_MANAGERS:
		var manager := get_node_or_null("/root/" + manager_name)
		if not manager or not manager.has_method("load_save_data"):
			continue
		if not _fresh_state.has(manager_name):
			push_error("SaveManager: no boot snapshot for %s; New Game cannot reset it." % manager_name)
			continue
		manager.load_save_data(_fresh_state[manager_name].duplicate(true))
	var schedule := get_node_or_null("/root/ScheduleManager")
	if schedule and schedule.has_method("reset"):
		schedule.reset()

func _process(delta: float) -> void:
	if not get_tree().current_scene or get_tree().current_scene.name != "World":
		return

	if _suspend_autosave:
		return
	_save_timer += delta
	if _save_timer >= _auto_save_interval:
		_save_timer = 0.0
		save_game()

func save_game() -> void:
	var save_dict = {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"last_seen_whats_new_version": last_seen_whats_new_version,
		"economy": {},
		"islands": {},
		"fleet": {},
		"tech": {},
		"factions": {},
		"empire": {},
		"tutorial": {},
		"last_saved_unix": Time.get_unix_time_from_system()
	}

	# 1. Player State
	# No "player" key at all when no player_ship exists to read from (a
	# save_game() called outside a real World scene, e.g. from a test harness)
	# — an empty `{}` used to be written and indistinguishable on load from a
	# save that legitimately has nothing else to restore, so load_game()
	# defaulted position to Vector3(0, 1, 0) and silently teleported the ship
	# there. Harmless until M7 made Port Royal (at that exact world origin)
	# the home island — after that, loading such a save embedded the ship in
	# the island's own collision and collapsed the camera's spring arm into
	# the terrain, rendering the 3D viewport solid black while the HUD kept
	# working. Found by actually running the game and looking at the render,
	# not by reading code. See the matching guard in load_game().
	var player = get_tree().get_first_node_in_group("player_ship")
	if player and is_instance_valid(player):
		save_dict["player"] = {}
		save_dict["player"]["pos_x"] = player.global_position.x
		save_dict["player"]["pos_y"] = player.global_position.y
		save_dict["player"]["pos_z"] = player.global_position.z
		save_dict["player"]["rot_y"] = player.global_rotation.y

		# ShipDamage owns all three pools and has always had the
		# get_save_data()/load_save_data() pair the autoload convention expects —
		# it was simply never called from here, so sails and crew were not
		# persisted at all and hull went through the (dead) current_health write.
		var dmg = player.get_node_or_null("ShipDamage")
		if dmg and dmg.has_method("get_save_data"):
			save_dict["player"]["damage"] = dmg.get_save_data()

		# M16 Task 14 — equipped cosmetic *selection* only; ownership is
		# account-scoped (EntitlementManager), never round-tripped here.
		var visuals = player.get_node_or_null("ShipVisuals")
		if visuals and visuals.has_method("get_save_data"):
			save_dict["player"]["cosmetics"] = visuals.get_save_data()

		var combat = player.get_node_or_null("ShipCombat")
		if combat:
			# Kept for backward compatibility with saves written before the
			# "damage" section existed; load prefers "damage" when present.
			save_dict["player"]["health"] = combat.current_health

		if "active_captain" in player and player.active_captain:
			save_dict["player"]["captain_id"] = player.active_captain.captain_id

	# 2. Economy State
	if ResourceManager.has_method("get_save_data"):
		save_dict["economy"] = ResourceManager.get_save_data()

	# 3. Islands State
	# M30 Requirement 1.1 — save island ownership (island_type and owner_faction)
	# Start from the previous save to carry forward gated islands (1.7)
	var islands_data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			json.parse(file.get_as_text())
			var old_save = json.data
			if old_save and old_save.has("islands"):
				islands_data = old_save["islands"].duplicate()

	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("get_island_id") and island.has_method("get_built_building_ids"):
			var island_id = island.get_island_id()
			var owner_faction_id = ""
			if island.island_data and island.island_data.owner_faction:
				owner_faction_id = island.island_data.owner_faction.faction_id

			islands_data[island_id] = {
				"buildings": island.get_built_building_ids(),
				# M10 Requirement 4 — IslandData.discovered was never actually
				# persisted before this; the write path (dock/proximity) set
				# it at runtime but every load silently reset it to false.
				"discovered": island.island_data.discovered if island.island_data else false,
				# M30 Requirement 1.1 — persist island ownership
				"island_type": int(island.island_data.island_type) if island.island_data else int(IslandData.IslandType.NEUTRAL),
				"owner_faction_id": owner_faction_id,
			}
	save_dict["islands"] = islands_data

	# 4. Fleet State
	if FleetManager.has_method("get_save_data"):
		save_dict["fleet"] = FleetManager.get_save_data()

	# 5. Tech State
	if TechManager.has_method("get_save_data"):
		save_dict["tech"] = TechManager.get_save_data()

	# 6. Faction State
	if FactionManager.has_method("get_save_data"):
		save_dict["factions"] = FactionManager.get_save_data()

	# 7. Empire State
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp and emp.has_method("get_save_data"):
		save_dict["empire"] = emp.get_save_data()

	# 8. Tutorial State (progress only — completion flag lives in its own file)
	if TutorialManager.has_method("get_save_data"):
		save_dict["tutorial"] = TutorialManager.get_save_data()

	# 9. Campaign State (M7)
	if CampaignManager.has_method("get_save_data"):
		save_dict["campaign"] = CampaignManager.get_save_data()

	# 9c. Seasonal Events (M14)
	if SeasonalEventManager.has_method("get_save_data"):
		save_dict["seasonal_events"] = SeasonalEventManager.get_save_data()

	# 9e. Maelstrom record (M26) — an optional section: omitted, never written
	# empty (the "no data" vs "empty section" rule).
	if int(_maelstrom_data.get("runs", 0)) > 0:
		save_dict["maelstrom"] = _maelstrom_data.duplicate()

	# 9f. Running timers (M27) — optional: ScheduleManager returns {} with no jobs.
	var schedule: Dictionary = ScheduleManager.get_save_data()
	if not schedule.is_empty():
		save_dict["schedule"] = schedule

	# Preserve the last known save before replacing it. A failed backup is safer
	# than a write that could destroy the player's only recoverable copy.
	var had_existing_save := FileAccess.file_exists(SAVE_PATH)
	if not _backup_existing_save():
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict, "	")
		file.store_string(json_string)
		file.close()
	else:
		push_error("SaveManager: Failed to open save file for writing.")
		# The backup already moved the prior save out of the way, and the new
		# write just failed (disk full/permissions) -- without restoring, the
		# player would be left with neither a current save nor their last-known-
		# good one.
		if had_existing_save:
			_restore_backup()
		return

	# M26 — the claimed pending run is now inside a real save.
	if _maelstrom_pending_claimed:
		_maelstrom_pending_claimed = false
		if FileAccess.file_exists(MAELSTROM_PENDING_PATH):
			DirAccess.remove_absolute(MAELSTROM_PENDING_PATH)

	# M15 Requirement 3.4/4.2 — mirrors the existing local format exactly, no second schema.
	# Fire-and-forget: never awaited here, so a slow/failed network call can't delay or block
	# the caller (auto-save timer, dock completion, etc.) — Requirement 4.2.
	if AuthManager.is_signed_in():
		_sync_to_cloud(save_dict)

func load_game() -> void:
	# M27 — "schedule" is omitted when no job is running, so a stale job from an
	# earlier session in this process must be cleared before anything loads.
	ScheduleManager.reset()
	if not has_recoverable_save_data():
		_maelstrom_data = {}
		# With no campaign save, the pending file is the one record of the Eights
		# balance (earned in the Maelstrom, bought from the menu, or carried over a
		# New Game). Anything in memory is a copy of it, so start from zero and
		# claim it once — adding it on top of memory would count it twice.
		ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 0
		_claim_pending_maelstrom()   # M26 — runs played before the first campaign save
		_wallet_loaded_this_session = true
		game_loaded.emit()
		return

	var primary_result := _read_save_file(SAVE_PATH)
	var data: Dictionary = primary_result["data"]
	if data.is_empty():
		var backup_result := _read_save_file(BACKUP_PATH)
		data = backup_result["data"]
		if data.is_empty():
			push_error("SaveManager: primary and backup saves could not be loaded.")
			load_failed.emit("save data is corrupted; backup recovery also failed")
			game_loaded.emit()
			return
		load_failed.emit("primary save could not be loaded; recovered the previous backup")

	var loaded_schema_version: int = data.get("save_schema_version", 0)
	if loaded_schema_version > SAVE_SCHEMA_VERSION:
		push_error("SaveManager: save schema is newer than this build.")
		load_failed.emit("save was created by a newer version")
		game_loaded.emit()
		return
	if loaded_schema_version < SAVE_SCHEMA_VERSION:
		data = _migrate(data, loaded_schema_version)
		if data.is_empty():
			load_failed.emit("save migration failed")
			game_loaded.emit()
			return

	if data.has("last_seen_whats_new_version"):
		last_seen_whats_new_version = str(data["last_seen_whats_new_version"])

	# 1. Player State
	if data.has("player"):
		var player_data = data["player"]
		var player = get_tree().get_first_node_in_group("player_ship")
		if player and is_instance_valid(player):
			# Transform — only if this save actually recorded one. `save_game()`
			# leaves "player" as `{}` whenever it ran with no `player_ship` group
			# member in the tree (e.g. a test/verification harness without a full
			# World scene); `player_data.get("pos_x", 0.0)` used to default that
			# to Vector3(0, 1, 0) on load, which happens to be Port Royal's exact
			# island origin now that M7 seeds it as the home island — silently
			# teleporting the ship into the island's own collision on every such
			# load. Confirmed live: the SpringArm3D camera collapses into the
			# terrain it's now embedded in, rendering the 3D viewport solid black
			# while the HUD keeps working — found via an actual headful
			# CaptureHarness run, not static reading. Missing position data now
			# means "leave the ship at the scene's authored spawn", not "assume
			# the origin".
			if player_data.has("pos_x"):
				var pos = Vector3(
					player_data.get("pos_x", 0.0),
					player_data.get("pos_y", 1.0),
					player_data.get("pos_z", 0.0)
				)
				player.global_position = pos
				player.global_rotation.y = player_data.get("rot_y", 0.0)

			# Health will be set after fleet loads

	# 2. Economy State
	if data.has("economy") and ResourceManager.has_method("load_save_data"):
		ResourceManager.load_save_data(data["economy"])

	# 3. Fleet State (do this before health to set proper max hp)
	var player = get_tree().get_first_node_in_group("player_ship")
	if data.has("fleet") and FleetManager.has_method("load_save_data"):
		FleetManager.load_save_data(data["fleet"])
		if player and is_instance_valid(player):
			var ship = FleetManager.get_active_ship()
			var cap = FleetManager.get_active_captain()
			if ship: player.ship_stats = ship
			if cap: player.active_captain = cap

	# 4. Player health (independent of whether a fleet section was present in this save)
	if player and is_instance_valid(player):
		var combat = player.get_node_or_null("ShipCombat")
		var dmg = player.get_node_or_null("ShipDamage")
		var player_data = data.get("player", {})

		if dmg and dmg.has_method("load_save_data"):
			if player_data.has("damage"):
				dmg.load_save_data(player_data["damage"])
			elif player_data.has("health"):
				# Pre-"damage" save: hull only, sails/crew default to max.
				dmg.load_save_data({"hull": player_data["health"]})
			else:
				dmg.restore_all()
			if combat and combat.has_signal("health_changed"):
				combat.health_changed.emit(dmg.hull, dmg.get_pool_maximum("hull"))
		elif combat:
			if player_data.has("health"):
				combat.current_health = player_data["health"]
			var cap = player.active_captain if "active_captain" in player else null
			var max_hp = combat.ship_stats.max_health
			if cap: max_hp *= cap.health_modifier
			if combat.has_signal("health_changed"):
				combat.health_changed.emit(combat.current_health, max_hp)

		# M16 Task 14 — restores equipped cosmetic selection. ShipVisuals'
		# own load_save_data() already falls back to default appearance
		# silently for any id the account doesn't own or that no longer
		# resolves (Req 3.5/3.6).
		var visuals = player.get_node_or_null("ShipVisuals")
		if visuals and visuals.has_method("load_save_data") and player_data.has("cosmetics"):
			visuals.load_save_data(player_data["cosmetics"])

	# 5. Islands State
	# M30 Requirement 1.1 — restore island ownership BEFORE buildings and offline catch-up
	if data.has("islands"):
		var islands_data = data["islands"]
		var active_islands = get_tree().get_nodes_in_group("islands")

		# First pass: restore ownership (island_type and owner_faction)
		for island in active_islands:
			var island_id = island.get_island_id() if island.has_method("get_island_id") else ""
			if island_id == "" or not islands_data.has(island_id):
				continue
			var entry = islands_data[island_id]
			if not entry is Dictionary:
				continue
			if not island.island_data:
				continue

			# M30 Requirement 1.2 — migration: old saves without island_type/owner_faction_id
			# If buildings exist or this is the home_island, mark as FRIENDLY with player faction
			var should_migrate = false
			if not entry.has("island_type"):
				var has_buildings = len(entry.get("buildings", [])) > 0
				var is_home_island = island_id == data.get("empire", {}).get("home_island_id", "")
				if has_buildings or is_home_island:
					should_migrate = true

			if should_migrate:
				# Migrate to FRIENDLY with player faction
				island.island_data.island_type = IslandData.IslandType.FRIENDLY
				island.island_data.owner_faction = FactionManager.get_player_faction()
			else:
				# Restore from save
				var saved_type = entry.get("island_type", int(IslandData.IslandType.NEUTRAL))
				island.island_data.island_type = saved_type

				var owner_faction_id = entry.get("owner_faction_id", "")
				if owner_faction_id != "":
					var faction = EmpireManager._get_faction_by_id(owner_faction_id)
					if faction:
						island.island_data.owner_faction = faction
					else:
						push_error("SaveManager: unresolvable faction_id '%s' for island '%s'" % [owner_faction_id, island_id])
						# Keep the authored value

		# Second pass: restore buildings and discovered flag
		for island in active_islands:
			var island_id = island.get_island_id() if island.has_method("get_island_id") else ""
			if island_id == "" or not islands_data.has(island_id):
				continue
			var entry = islands_data[island_id]
			# Pre-M10 saves stored a flat Array of building ids directly;
			# M10 wraps that in a dict alongside "discovered" (see save_game()).
			var building_ids: Array = entry if entry is Array else entry.get("buildings", [])
			if island.has_method("restore_buildings"):
				island.restore_buildings(building_ids)
			if entry is Dictionary and island.island_data:
				island.island_data.discovered = entry.get("discovered", island.island_data.discovered)

	# 6. Tech State
	if data.has("tech") and TechManager.has_method("load_save_data"):
		TechManager.load_save_data(data["tech"])

	# 7. Faction State
	if data.has("factions") and FactionManager.has_method("load_save_data"):
		FactionManager.load_save_data(data["factions"])

	# 8. Empire State
	if data.has("empire"):
		var emp = get_tree().root.get_node_or_null("EmpireManager")
		if emp and emp.has_method("load_save_data"):
			emp.load_save_data(data["empire"])

	# 9. Tutorial State (progress only)
	if data.has("tutorial") and TutorialManager.has_method("load_save_data"):
		TutorialManager.load_save_data(data["tutorial"])

	# 9b. Campaign State (M7)
	if data.has("campaign") and CampaignManager.has_method("load_save_data"):
		CampaignManager.load_save_data(data["campaign"])

	# 9d. Seasonal Events (M14)
	if data.has("seasonal_events") and SeasonalEventManager.has_method("load_save_data"):
		SeasonalEventManager.load_save_data(data["seasonal_events"])

	# 9e. Maelstrom record (M26), then any run waiting in the pending file.
	_maelstrom_data = data["maelstrom"].duplicate() if data.get("maelstrom") is Dictionary else {}
	_claim_pending_maelstrom()
	_wallet_loaded_this_session = true

	# 9f. Running timers (M27). Due jobs complete once game_loaded has fired and the
	# World's owners are wired — see ScheduleManager's header.
	if data.get("schedule") is Dictionary:
		ScheduleManager.load_save_data(data["schedule"])

	# 10. Offline catch-up (must run after islands and fleet are restored above)
	if data.has("last_saved_unix"):
		var elapsed = int(Time.get_unix_time_from_system()) - int(data["last_saved_unix"])
		elapsed = max(elapsed, 0)
		elapsed = min(elapsed, MAX_OFFLINE_SECONDS)
		var offline_ticks = int(elapsed / ResourceManager.ECONOMY_TICK_INTERVAL)
		if offline_ticks > 0:
			var before_resources: Dictionary = ResourceManager.current_resources.duplicate(true)
			var islands = get_tree().get_nodes_in_group("islands")
			for i in range(offline_ticks):
				for island in islands:
					island.on_economy_tick()
				FleetManager.on_economy_tick()
			_pending_offline_ticks = offline_ticks
			_pending_offline_income = _compute_resource_delta(before_resources, ResourceManager.current_resources)

	game_loaded.emit()


func _compute_resource_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for key in after.keys():
		var gained := float(after[key]) - float(before.get(key, 0))
		if gained > 0.0:
			delta[key] = gained
	return delta


## M17 Requirement 6.5 — grants the exact same offline-income delta a second
## time, as a bonus on top of the (already unconditionally granted) baseline
## above. Never computes a new/different amount — that would let the bonus
## drift from what was actually accrued.
func grant_offline_income_bonus() -> void:
	for key in _pending_offline_income.keys():
		ResourceManager.add_resource(key, int(round(_pending_offline_income[key])))


func _backup_existing_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	var source := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not source:
		push_error("SaveManager: Failed to open existing save for backup.")
		return false
	var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if not backup:
		source.close()
		push_error("SaveManager: Failed to open backup save for writing.")
		return false
	backup.store_string(source.get_as_text())
	source.close()
	backup.close()
	return true


func _restore_backup() -> void:
	## Copies the just-made backup back over SAVE_PATH. Only called when a
	## write we just backed up for has failed, so the player isn't left with
	## neither a current save nor their last-known-good one.
	var backup := FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if not backup:
		push_error("SaveManager: Failed to restore backup after a failed save write.")
		return
	var restored := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not restored:
		backup.close()
		push_error("SaveManager: Failed to restore backup after a failed save write.")
		return
	restored.store_string(backup.get_as_text())
	backup.close()
	restored.close()


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "error": "file does not exist"}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"data": {}, "error": "could not open file"}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return {"data": {}, "error": json.get_error_message()}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"data": {}, "error": "root is not a dictionary"}
	return {"data": json.data, "error": ""}


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	## Each arm owns one historical transition. Keep migrations intentionally small
	## and deterministic: they repair only the old schema, never rebalance data.
	var migrated := data.duplicate(true)
	var version := from_version
	while version < SAVE_SCHEMA_VERSION:
		match version:
			0:
				# M10 wrapped island building arrays so it could persist discovery.
				# Pre-versioned saves may still use the flat array representation.
				if migrated.get("islands") is Dictionary:
					for island_id in migrated["islands"]:
						if migrated["islands"][island_id] is Array:
							migrated["islands"][island_id] = {
								"buildings": migrated["islands"][island_id],
								"discovered": false,
							}
				version = 1
			_:
				push_error("SaveManager: no migration exists from schema version %d." % version)
				return {}
	migrated["save_schema_version"] = SAVE_SCHEMA_VERSION
	return migrated


func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func has_recoverable_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if not dir:
		return
	if FileAccess.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH.get_file())
	if FileAccess.file_exists(BACKUP_PATH):
		dir.remove(BACKUP_PATH.get_file())


## M15 Requirement 4.2 — pushes the given save dict to Supabase as an upsert (one row per
## account, enforced by the unique constraint on player_saves.user_id — see supabase/schema.sql).
## Never awaited by save_game(); this coroutine runs on its own.
func _sync_to_cloud(data: Dictionary) -> void:
	var client_updated_at := Time.get_datetime_string_from_unix_time(int(data.get("last_saved_unix", Time.get_unix_time_from_system())), true) + "Z"
	var payload := {
		"user_id": AuthManager.get_user_id(),
		"save_data": data,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"client_updated_at": client_updated_at,
	}
	var result := await _send_cloud_request(
		HTTPClient.METHOD_POST,
		"/rest/v1/player_saves?on_conflict=user_id",
		["Prefer: resolution=merge-duplicates,return=minimal"],
		JSON.stringify(payload))

	var code: int = result.get("code", 0)
	if code == 401:
		# Token refresh (Requirement 1's "on any 401 from a database call, attempt a refresh
		# once before surfacing an error"), then retry exactly once.
		if await AuthManager.refresh_session():
			result = await _send_cloud_request(
				HTTPClient.METHOD_POST,
				"/rest/v1/player_saves?on_conflict=user_id",
				["Prefer: resolution=merge-duplicates,return=minimal"],
				JSON.stringify(payload))
			code = result.get("code", 0)

	_cloud_sync_pending = not (code >= 200 and code < 300)

## Returns the signed-in player's cloud save row, or {} if none exists / the request failed.
## RLS already scopes this to the caller's own row (see supabase/schema.sql) — no user_id filter
## needed client-side.
func _fetch_cloud_save() -> Dictionary:
	var result := await _send_cloud_request(
		HTTPClient.METHOD_GET,
		"/rest/v1/player_saves?select=save_data,save_schema_version,client_updated_at",
		[], "")
	var code: int = result.get("code", 0)
	if code == 401:
		if await AuthManager.refresh_session():
			result = await _send_cloud_request(
				HTTPClient.METHOD_GET,
				"/rest/v1/player_saves?select=save_data,save_schema_version,client_updated_at",
				[], "")
			code = result.get("code", 0)
	if code < 200 or code >= 300:
		return {}
	var body = result.get("body", [])
	if body is Array and body.size() > 0 and body[0] is Dictionary:
		return body[0]
	return {}

func _send_cloud_request(method: HTTPClient.Method, endpoint: String, extra_headers: Array, body: String) -> Dictionary:
	if _request_override.is_valid():
		return await _request_override.call(method, endpoint, extra_headers, body)

	var headers := PackedStringArray([
		"apikey: %s" % AuthManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % AuthManager.get_access_token(),
		"Content-Type: application/json",
	])
	for h in extra_headers:
		headers.append(h)

	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(AuthManager.SUPABASE_URL + endpoint, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"code": 0, "body": {}}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var parsed = {}
	var text := response_body.get_string_from_utf8()
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) == OK:
			parsed = json.data
	return {"code": response_code, "body": parsed}

## Requirement 4.1 — first sign-in on a device with existing local data.
func _on_signed_in(_user_id: String) -> void:
	if not has_save_data():
		# Nothing local to conflict with — just adopt whatever's in the cloud, if anything.
		var cloud_row := await _fetch_cloud_save()
		if not cloud_row.is_empty():
			_apply_cloud_save(cloud_row)
		return

	var cloud_row := await _fetch_cloud_save()
	await _resolve_cloud_conflict(cloud_row)

## Requirement 4.3 — called once per app session (World.gd, alongside the existing load_game()
## call) after AuthManager's own initial session-restore attempt completes, so is_signed_in() is
## accurate. A no-op for a signed-out player or a player with no cloud save.
func check_cloud_save_on_launch() -> void:
	if _did_launch_cloud_check:
		return
	_did_launch_cloud_check = true

	await AuthManager.await_initial_check()
	if not AuthManager.is_signed_in():
		return

	var cloud_row := await _fetch_cloud_save()
	if cloud_row.is_empty():
		return

	var local_unix := 0
	if has_save_data():
		var local_result := _read_save_file(SAVE_PATH)
		local_unix = int(local_result["data"].get("last_saved_unix", 0))
	var cloud_unix := int(Time.get_unix_time_from_datetime_string(String(cloud_row.get("client_updated_at", "")).trim_suffix("Z")))

	if cloud_unix > local_unix:
		await _resolve_cloud_conflict(cloud_row)

## Shared by both conflict-trigger points (Requirements 4.1 and 4.3). Never silently picks a
## side — always either skips (identical saves) or asks (design.md's Requirement 4 section).
func _resolve_cloud_conflict(cloud_row: Dictionary) -> void:
	if cloud_row.is_empty():
		return

	var local_unix := 0
	if has_save_data():
		var local_result := _read_save_file(SAVE_PATH)
		local_unix = int(local_result["data"].get("last_saved_unix", 0))
	var cloud_unix := int(Time.get_unix_time_from_datetime_string(String(cloud_row.get("client_updated_at", "")).trim_suffix("Z")))

	if local_unix == cloud_unix:
		# Trivially identical (design.md: "same client_updated_at down to the second") — it's
		# the same save, nothing to ask.
		return

	# M30 Requirement 2.5 — suspend autosave while the conflict dialog is open
	_suspend_autosave = true

	# M30 Requirement 2.5 — parent the dialog to root to survive scene changes
	var choice: int = await ChoiceDialogScript.new(
		tr("Cloud Save Found"),
		tr("This device's empire and your cloud save differ. Which one do you want to keep?"),
		PackedStringArray([tr("Keep This Device"), tr("Keep Cloud")])
	).ask(get_tree().root)

	_suspend_autosave = false

	if choice == 0:
		# M30 Requirement 1.6 — Keep This Device: max-merge Eights
		var local_result := _read_save_file(SAVE_PATH)
		if not local_result["data"].is_empty():
			var save_data = local_result["data"].duplicate(true)
			var key := ResourceManager.PREMIUM_CURRENCY
			var economy: Dictionary = save_data.get("economy", {}) if save_data.get("economy") is Dictionary else {}
			var cloud_economy: Dictionary = cloud_row.get("save_data", {}).get("economy", {}) if cloud_row.get("save_data", {}).get("economy") is Dictionary else {}
			economy[key] = maxi(int(economy.get(key, 0)), int(cloud_economy.get(key, 0)))
			save_data["economy"] = economy
			# Write the merged save
			var had_existing_save := FileAccess.file_exists(SAVE_PATH)
			if _backup_existing_save():
				var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
				if file:
					file.store_string(JSON.stringify(save_data, "\t"))
					file.close()
			_sync_to_cloud(save_data)
	else:
		# M30 Requirement 1.5 — Keep Cloud: reload the World after applying
		_apply_cloud_save(cloud_row)
		# Reload the World to apply the cloud save to the live game state
		if SceneManager and SceneManager.is_campaign():
			SceneManager.change_scene_with_fade("res://scenes/world/World.tscn", 0.4, false)

## Writes a cloud save row's save_data as the new local save. Applying it to a live in-session
## World is out of scope for this milestone — the normal load_game() path on the next scene
## entry (or app restart) picks it up, same as any other save-file change.
func _apply_cloud_save(cloud_row: Dictionary) -> void:
	var save_data = cloud_row.get("save_data", {})
	if typeof(save_data) != TYPE_DICTIONARY or save_data.is_empty():
		return
	# Keeping the cloud EMPIRE must never cost the wallet: Pieces of Eight bought
	# (or earned) on this device since the last sync would otherwise vanish with
	# the local save. Both are copies of the one wallet at different times, so
	# keep the higher — erring toward the player, the same rule StoreManager's
	# order handling follows. The pending balance is folded in here and cleared
	# below, so load_game() can't count it a second time.
	save_data = save_data.duplicate(true)
	var key := ResourceManager.PREMIUM_CURRENCY
	var economy: Dictionary = save_data.get("economy", {}) if save_data.get("economy") is Dictionary else {}
	economy[key] = maxi(int(economy.get(key, 0)), eights_balance())
	save_data["economy"] = economy
	var had_existing_save := FileAccess.file_exists(SAVE_PATH)
	if not _backup_existing_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		var pending := _read_maelstrom_pending()
		if pending.has("eights"):
			pending.erase("eights")
			if pending.is_empty():
				DirAccess.remove_absolute(MAELSTROM_PENDING_PATH)
			else:
				_write_pending(pending)
		# If memory is the live wallet (campaign loaded this session), give it the
		# merged balance too, or the World's next autosave would write the
		# pre-merge figure back over it.
		if _wallet_loaded_this_session:
			ResourceManager.current_resources[key] = int(economy[key])
			ResourceManager.resources_changed.emit(ResourceManager.current_resources)
	elif had_existing_save:
		push_error("SaveManager: Failed to write cloud save to local save file.")
		_restore_backup()

func _get_dialog_parent() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree and tree.current_scene:
		return tree.current_scene
	return self


# ------------------------------------------------------------------ M26 Maelstrom

## M26 — the ONE write a Maelstrom run makes. Deliberately not save_game(): a run
## started from the main menu has every manager at its defaults (the campaign is
## only loaded when World loads), so a full save would overwrite the player's real
## campaign with them. Instead this patches exactly two things on disk — the
## "maelstrom" record and economy.eights — and leaves every other section
## byte-for-byte as it was. With no campaign save yet, both wait in
## MAELSTROM_PENDING_PATH instead. Returns the updated record.
func save_maelstrom_result(eights: int, seconds: float, level: int) -> Dictionary:
	var record = MaelstromRecordScript.new()
	record.load_save_data(load_maelstrom_record())
	record.merge_run(seconds, level)
	var record_data := record.get_save_data()
	if _patch_eights_outside_world(maxi(eights, 0), record_data):
		_maelstrom_data = record_data
	return record_data


## M27 — purchased Eights (a store consumable) must survive whatever happens
## next. Inside a campaign World the live economy is the truth, so they're added
## and saved at once. Anywhere else (the main menu's store) the economy in memory
## is a default that World will replace from disk, so they go through the same
## patch-on-disk write a Maelstrom run uses. Returns false only if nothing could
## be written — the caller then leaves the order unconsumed for a retry.
func persist_purchased_eights(eights: int) -> bool:
	if eights <= 0:
		return true
	var scene := get_tree().current_scene
	if scene and scene.name == "World" and SceneManager.is_campaign():
		ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, eights)
		save_game()
		return true
	return _patch_eights_outside_world(eights, {})


## M26/M27 — the one out-of-World write of Eights: adds `eights` to
## economy.eights in the campaign save (and, for a Maelstrom run, replaces the
## "maelstrom" record), leaving every other section byte-for-byte as it was. With
## no readable campaign save it parks both in MAELSTROM_PENDING_PATH, which
## load_game() claims. On success the in-memory wallet is credited too; returns
## false (crediting nothing) if the write failed.
func _patch_eights_outside_world(eights: int, maelstrom_record: Dictionary) -> bool:
	var data: Dictionary = {}
	if has_save_data():
		data = _read_save_file(SAVE_PATH)["data"]
		if data.is_empty():
			# An unreadable primary is recovery's business (load_game falls back
			# to the backup) — never overwrite it, and never lose the Eights: park
			# them in the pending file like a fresh install would.
			push_error("SaveManager: campaign save unreadable; Eights kept pending.")

	if not data.is_empty():
		# Fold in anything still pending (e.g. a cloud download replaced the save
		# before the pending file was claimed), so the two never coexist after this.
		var pending := _read_maelstrom_pending()
		eights += int(pending.get("eights", 0))
		if not maelstrom_record.is_empty():
			data["maelstrom"] = maelstrom_record
		if eights > 0:
			var economy: Dictionary = data.get("economy", {}) if data.get("economy") is Dictionary else {}
			var key := ResourceManager.PREMIUM_CURRENCY
			economy[key] = int(economy.get(key, 0)) + eights
			data["economy"] = economy
		if not _backup_existing_save():
			return false
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if not file:
			push_error("SaveManager: failed to write Eights to the campaign save.")
			_restore_backup()
			return false
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		if FileAccess.file_exists(MAELSTROM_PENDING_PATH):
			DirAccess.remove_absolute(MAELSTROM_PENDING_PATH)
		if AuthManager.is_signed_in():
			_sync_to_cloud(data)
	else:
		var pending := _read_maelstrom_pending()
		pending["eights"] = int(pending.get("eights", 0)) + eights
		if not maelstrom_record.is_empty():
			pending["record"] = maelstrom_record
		var pf := FileAccess.open(MAELSTROM_PENDING_PATH, FileAccess.WRITE)
		if not pf:
			push_error("SaveManager: failed to write pending Eights.")
			return false
		pf.store_string(JSON.stringify(pending, "\t"))
		pf.close()

	# Keep the in-memory wallet honest for any menu UI. Safe: every World entry
	# reloads economy from the file patched above (or claims the pending file).
	if eights > 0:
		ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, eights)
	return true


## M26 — the record as it stands on disk right now (campaign section + anything
## pending), so a run started cold from the main menu still shows the true best.
func load_maelstrom_record() -> Dictionary:
	var record = MaelstromRecordScript.new()
	if has_save_data():
		var data: Dictionary = _read_save_file(SAVE_PATH)["data"]
		if data.get("maelstrom") is Dictionary:
			record.load_save_data(data["maelstrom"])
	var pending := _read_maelstrom_pending()
	if pending.get("record") is Dictionary:
		record.merge_record(pending["record"])
	return record.get_save_data()


func get_maelstrom_data() -> Dictionary:
	return _maelstrom_data.duplicate()


func _read_maelstrom_pending() -> Dictionary:
	var result := _read_save_file(MAELSTROM_PENDING_PATH)
	return result["data"]


func _claim_pending_maelstrom() -> void:
	## Called from load_game(): credits runs played before any campaign save
	## existed. The file is only deleted by the next successful save_game(), so a
	## session that ends before that claims it again from scratch — never twice,
	## because load_game() always rebuilds the economy from the file first.
	var pending := _read_maelstrom_pending()
	if pending.is_empty():
		return
	var eights := int(pending.get("eights", 0))
	if eights > 0:
		ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, eights)
	if pending.get("record") is Dictionary:
		var record = MaelstromRecordScript.new()
		record.load_save_data(_maelstrom_data)
		record.merge_record(pending["record"])
		_maelstrom_data = record.get_save_data()
	_maelstrom_pending_claimed = true
