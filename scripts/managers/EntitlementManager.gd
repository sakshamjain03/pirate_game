extends Node

## EntitlementManager
## Owns the player's cosmetic entitlements (what they own, not what they have
## equipped) at account scope — outside any save slot, so it survives both a
## new game and deleting every save (design.md §3). Ownership is written
## eagerly on every grant rather than waiting for SaveManager.save_game(), so
## an entitlement is never lost to a crash between grant and next save.
##
## get_save_data()/load_save_data() follow the same shape every other manager
## uses, for serialization consistency — but unlike those managers, nothing
## here round-trips through SaveManager's own save_data.json. This manager
## reads/writes user://account_data.json itself.

signal entitlement_granted(id: StringName)
signal entitlement_revoked(id: StringName)

const ACCOUNT_DATA_PATH := "user://account_data.json"
const ACCOUNT_SCHEMA_VERSION := 1

## M17 — the one well-known entitlement id that isn't a cosmetic. Grantable
## through the same single write path as every cosmetic (see grant()/
## grant_batch() below) rather than needing a separate ad-free flag store.
const AD_FREE_ID: StringName = &"ad_free"

# Each entry: id -> { "source": String, "granted_at": int }. Deliberately no
# quantity/count/balance field anywhere in this dictionary shape — an
# entitlement is owned or not, never spent, never stacked (AGENTS.md).
var _entitlements: Dictionary = {}

## Test seam, mirroring SaveManager/AuthManager's own established convention
## for a manager that talks to Supabase — a test replaces this Callable to
## intercept every _send_cloud_request() call instead of hitting the network.
var _request_override: Callable
var _did_launch_cloud_check := false


func _ready() -> void:
	_load_or_seed_account_data()
	_connect_play_earned_grants()
	# fresh_sign_in, not signed_in — a background token refresh also emits
	# signed_in (for UI reactivity) and would otherwise re-trigger a full
	# pull-and-push cycle mid-flight through an unrelated sync's own 401
	# retry, exactly the cascade SaveManager's own identical comment (see
	# SaveManager.gd) already warns about.
	AuthManager.fresh_sign_in.connect(_on_signed_in)


## Re-reads user://account_data.json from disk, seeding defaults if it's
## missing/malformed — the same path _ready() takes at boot. Exposed publicly
## (not just for tests) since re-syncing from disk is a legitimate operation
## in its own right, not merely a test seam.
func reload_account_data() -> void:
	_load_or_seed_account_data()


func has_entitlement(id: StringName) -> bool:
	return _entitlements.has(id)


func get_all_entitlement_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _entitlements:
		ids.append(id)
	return ids


## Grants an entitlement. Idempotent (Req 5.3) — a second grant of the same id
## is a silent no-op, not a duplicate or a re-emit. Rejects an id the
## catalogue doesn't recognize rather than recording an entitlement to
## nothing. This is the ONLY write path into _entitlements — M17's purchase
## flow routes through grant_batch() below rather than adding a second one
## (see this milestone's own tasks.md Notes).
func grant(id: StringName, source: String) -> void:
	if not _stage_entitlement(id, source, ""):
		return
	_write_account_data()
	entitlement_granted.emit(id)
	_sync_to_cloud_if_signed_in()


## M17 Task 5 — stages every id then writes once, so a bundle purchase (e.g.
## the Supporter Pack granting ad-free plus several cosmetics) can never end
## up partially owned after a crash mid-bundle (Requirement 2.4). Still the
## same _entitlements dict, still the same single write path as grant()
## above — this is the one addition to M16's API, per design.md §4.
func grant_batch(ids: Array, source: String, order_id: String = "") -> void:
	var newly_granted: Array[StringName] = []
	for id in ids:
		if _stage_entitlement(id, source, order_id):
			newly_granted.append(id)
	if newly_granted.is_empty():
		return
	_write_account_data()
	for id in newly_granted:
		entitlement_granted.emit(id)
	_sync_to_cloud_if_signed_in()


## The only removal path (Requirement 8.4) — called when the store reports a
## purchase as refunded or revoked, never for any other reason. Touches
## account data only, never the save (design.md §7's "Save integrity" hazard)
## and never runs from inside a save/load operation.
func revoke(id: StringName) -> void:
	if not _entitlements.has(id):
		return
	_entitlements.erase(id)
	_write_account_data()
	entitlement_revoked.emit(id)
	# Pushes the now-smaller set as a full overwrite (not a merge) — this is
	# the one case where cloud sync actively removes something, because a
	# revocation is authoritative, not a passive sync gap (design.md §8: only
	# Requirement 8 revocation ever removes an entitlement).
	_sync_to_cloud_if_signed_in()


## The order id a purchased entitlement was granted under, for the
## purchase-support screen (Requirement 3.5). Empty for a non-purchase grant.
func get_order_id(id: StringName) -> String:
	return _entitlements.get(id, {}).get("order_id", "")


## Distinct, non-empty order ids across every currently-owned entitlement —
## what the purchase-support screen actually lists (a player may have bought
## more than one product).
func get_all_order_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _entitlements.values():
		var order_id: String = entry.get("order_id", "")
		if order_id != "" and not ids.has(order_id):
			ids.append(order_id)
	return ids


## Stages one entitlement into _entitlements without writing or emitting —
## grant()/grant_batch() share this so a bundle purchase writes exactly once
## while a single non-purchase grant still writes immediately. Returns
## whether anything was actually staged (false for an already-owned id or an
## id neither CosmeticCatalogue nor AD_FREE_ID recognizes).
func _stage_entitlement(id: StringName, source: String, order_id: String) -> bool:
	if _entitlements.has(id):
		return false
	if not _is_grantable_id(id):
		push_error("EntitlementManager: grant of unknown entitlement '%s'" % id)
		return false
	_entitlements[id] = {"source": source, "granted_at": _now_unix(), "order_id": order_id}
	return true


func _is_grantable_id(id: StringName) -> bool:
	return id == AD_FREE_ID or CosmeticCatalogue.get_cosmetic(id) != null


func get_save_data() -> Dictionary:
	return {
		"account_schema_version": ACCOUNT_SCHEMA_VERSION,
		"entitlements": _entitlements,
	}


func load_save_data(data: Dictionary) -> void:
	_entitlements.clear()
	if typeof(data) != TYPE_DICTIONARY or not data.has("entitlements"):
		return
	var raw = data["entitlements"]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for id in raw:
		_entitlements[id] = raw[id]


## M16 Task 20 — the 3 required play-earned grants, each tied to an existing
## completion signal per design.md §7, never to SaveManager.game_loaded (that
## fires on every load, and several subscribers already act on it — D15 — so
## a grant condition evaluated from a load event would re-emit
## entitlement_granted on every launch of a completed save; grant()'s own
## idempotence guard makes that harmless but the signal noise would still be
## wrong). CampaignManager and EmpireManager are both autoloads; boss ships
## have no single spawn point to hook (EventManager.gd creates them from 3
## separate, unlisted-for-this-milestone functions), so SceneTree.node_added
## — itself a pre-existing engine signal, not a new mechanism — is used to
## catch each one and connect its own ShipCombat.died once.
func _connect_play_earned_grants() -> void:
	CampaignManager.chapter_completed.connect(_on_chapter_completed)
	EmpireManager.island_captured.connect(_on_island_captured)
	get_tree().node_added.connect(_on_node_added)


func _on_chapter_completed(chapter: ChapterData) -> void:
	if chapter.chapter_number == 3:
		grant(&"sail_storm_torn", "chapter_3")


func _on_island_captured(_island_id: String) -> void:
	grant(&"flag_golden_standard", "island_capture")


func _on_node_added(node: Node) -> void:
	if not node.is_in_group("boss_ship"):
		return
	var combat := node.get_node_or_null("ShipCombat")
	if combat and not combat.died.is_connected(_on_boss_ship_died):
		combat.died.connect(_on_boss_ship_died)


func _on_boss_ship_died() -> void:
	grant(&"figurehead_golden_eagle", "boss_defeat")


func _load_or_seed_account_data() -> void:
	var data := _read_account_data()
	if data.is_empty():
		# Missing, empty, or malformed account_data.json is a first run, not
		# an error (design.md §3.3) — seed every default_owned cosmetic and
		# write a fresh file, logging once rather than failing silently or
		# blocking startup/SaveManager.load_game().
		print("EntitlementManager: no readable account data, seeding defaults")
		_entitlements.clear()
		for cosmetic in CosmeticCatalogue.get_all():
			if cosmetic.default_owned:
				grant(cosmetic.id, "default")
		_write_account_data()
	else:
		load_save_data(data)


func _read_account_data() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNT_DATA_PATH):
		return {}
	var file := FileAccess.open(ACCOUNT_DATA_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func _write_account_data() -> void:
	var file := FileAccess.open(ACCOUNT_DATA_PATH, FileAccess.WRITE)
	if not file:
		push_error("EntitlementManager: could not open %s for writing" % ACCOUNT_DATA_PATH)
		return
	file.store_string(JSON.stringify(get_save_data()))
	file.close()


func _now_unix() -> int:
	return Time.get_unix_time_from_system()


## M17 Requirement 3.3 — called once per session (World.gd, mirroring
## SaveManager.check_cloud_save_on_launch()'s own established convention) so
## a returning signed-in player's other-device purchases show up without
## any action. A no-op for a signed-out player.
func check_cloud_sync_on_launch() -> void:
	if _did_launch_cloud_check:
		return
	_did_launch_cloud_check = true
	await AuthManager.await_initial_check()
	if not AuthManager.is_signed_in():
		return
	await _pull_and_push_union()


func _on_signed_in(_user_id: String) -> void:
	await _pull_and_push_union()


## Requirement 3.6 — the union, never the intersection. Anything the cloud
## has that this device doesn't gets granted locally (never the reverse:
## sync only ever adds); the merged result — now a superset of both — is
## pushed back so a third device converges too. Only revoke() above ever
## removes anything.
func _pull_and_push_union() -> void:
	var cloud_ids := await _fetch_cloud_entitlement_ids()
	var missing: Array[StringName] = []
	for id in cloud_ids:
		var sid := StringName(id)
		if not _entitlements.has(sid) and _is_grantable_id(sid):
			missing.append(sid)
	if not missing.is_empty():
		grant_batch(missing, "cloud_sync")
	else:
		# grant_batch() above already pushes when it writes; if there was
		# nothing new to grant, still push once so a first-time signed-in
		# push actually reaches the cloud.
		await _push_entitlements_to_cloud(_entitlements)


func _sync_to_cloud_if_signed_in() -> void:
	if AuthManager.is_signed_in():
		# Fire-and-forget, exactly like SaveManager._sync_to_cloud() — a
		# grant/revoke must never block on the network to complete locally.
		_push_entitlements_to_cloud(_entitlements)


## Returns every entitlement id the cloud currently has recorded for this
## account, or an empty array if signed out, offline, or nothing exists yet.
func _fetch_cloud_entitlement_ids() -> Array:
	var result := await _send_cloud_request(
		HTTPClient.METHOD_GET, "/rest/v1/player_entitlements?select=entitlements", [], "")
	var code: int = result.get("code", 0)
	if code == 401 and await AuthManager.refresh_session():
		result = await _send_cloud_request(
			HTTPClient.METHOD_GET, "/rest/v1/player_entitlements?select=entitlements", [], "")
		code = result.get("code", 0)
	if code < 200 or code >= 300:
		return []
	var body = result.get("body", [])
	if body is Array and body.size() > 0 and body[0] is Dictionary:
		var ents = body[0].get("entitlements", {})
		if ents is Dictionary:
			return ents.keys()
	return []


## Upserts the given full entitlement set as this account's cloud row (one
## row per account, same on_conflict=user_id shape SaveManager's
## player_saves upsert already uses).
func _push_entitlements_to_cloud(entitlements: Dictionary) -> void:
	var payload := {
		"user_id": AuthManager.get_user_id(),
		"entitlements": entitlements,
	}
	var result := await _send_cloud_request(
		HTTPClient.METHOD_POST,
		"/rest/v1/player_entitlements?on_conflict=user_id",
		["Prefer: resolution=merge-duplicates,return=minimal"],
		JSON.stringify(payload))
	if result.get("code", 0) == 401 and await AuthManager.refresh_session():
		await _send_cloud_request(
			HTTPClient.METHOD_POST,
			"/rest/v1/player_entitlements?on_conflict=user_id",
			["Prefer: resolution=merge-duplicates,return=minimal"],
			JSON.stringify(payload))


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
