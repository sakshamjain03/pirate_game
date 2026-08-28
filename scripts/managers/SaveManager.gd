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

var _save_timer: float = 0.0
var _auto_save_interval: float = 60.0
var _pending_offline_ticks: int = 0

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

func _ready() -> void:
	# fresh_sign_in, not signed_in — a background token refresh also emits signed_in (for UI
	# reactivity) and must NOT re-trigger a cloud-conflict check mid-session. See AuthManager.gd.
	AuthManager.fresh_sign_in.connect(_on_signed_in)

func _process(delta: float) -> void:
	if not get_tree().current_scene or get_tree().current_scene.name != "World":
		return

	_save_timer += delta
	if _save_timer >= _auto_save_interval:
		_save_timer = 0.0
		save_game()

func save_game() -> void:
	var save_dict = {
		"save_schema_version": SAVE_SCHEMA_VERSION,
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
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.has_method("get_island_id") and island.has_method("get_built_building_ids"):
			save_dict["islands"][island.get_island_id()] = {
				"buildings": island.get_built_building_ids(),
				# M10 Requirement 4 — IslandData.discovered was never actually
				# persisted before this; the write path (dock/proximity) set
				# it at runtime but every load silently reset it to false.
				"discovered": island.island_data.discovered if island.island_data else false,
			}

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

	# Preserve the last known save before replacing it. A failed backup is safer
	# than a write that could destroy the player's only recoverable copy.
	if not _backup_existing_save():
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("SaveManager: Failed to open save file for writing.")
		return

	# M15 Requirement 3.4/4.2 — mirrors the existing local format exactly, no second schema.
	# Fire-and-forget: never awaited here, so a slow/failed network call can't delay or block
	# the caller (auto-save timer, dock completion, etc.) — Requirement 4.2.
	if AuthManager.is_signed_in():
		_sync_to_cloud(save_dict)

func load_game() -> void:
	if not has_recoverable_save_data():
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

	# 5. Islands State
	if data.has("islands"):
		var islands_data = data["islands"]
		var active_islands = get_tree().get_nodes_in_group("islands")
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

	# 10. Offline catch-up (must run after islands and fleet are restored above)
	if data.has("last_saved_unix"):
		var elapsed = int(Time.get_unix_time_from_system()) - int(data["last_saved_unix"])
		elapsed = max(elapsed, 0)
		elapsed = min(elapsed, MAX_OFFLINE_SECONDS)
		var offline_ticks = int(elapsed / ResourceManager.ECONOMY_TICK_INTERVAL)
		if offline_ticks > 0:
			var islands = get_tree().get_nodes_in_group("islands")
			for i in range(offline_ticks):
				for island in islands:
					island._on_economy_tick()
				FleetManager._on_economy_tick()
			_pending_offline_ticks = offline_ticks

	game_loaded.emit()


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

	var choice: int = await ChoiceDialogScript.new(
		tr("Cloud Save Found"),
		tr("This device's empire and your cloud save differ. Which one do you want to keep?"),
		PackedStringArray([tr("Keep This Device"), tr("Keep Cloud")])
	).ask(_get_dialog_parent())

	if choice == 0:
		var local_result := _read_save_file(SAVE_PATH)
		if not local_result["data"].is_empty():
			_sync_to_cloud(local_result["data"])
	else:
		_apply_cloud_save(cloud_row)

## Writes a cloud save row's save_data as the new local save. Applying it to a live in-session
## World is out of scope for this milestone — the normal load_game() path on the next scene
## entry (or app restart) picks it up, same as any other save-file change.
func _apply_cloud_save(cloud_row: Dictionary) -> void:
	var save_data = cloud_row.get("save_data", {})
	if typeof(save_data) != TYPE_DICTIONARY or save_data.is_empty():
		return
	if not _backup_existing_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func _get_dialog_parent() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree and tree.current_scene:
		return tree.current_scene
	return self
