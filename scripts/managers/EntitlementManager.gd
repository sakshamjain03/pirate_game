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

const ACCOUNT_DATA_PATH := "user://account_data.json"
const ACCOUNT_SCHEMA_VERSION := 1

# Each entry: id -> { "source": String, "granted_at": int }. Deliberately no
# quantity/count/balance field anywhere in this dictionary shape — an
# entitlement is owned or not, never spent, never stacked (AGENTS.md).
var _entitlements: Dictionary = {}


func _ready() -> void:
	_load_or_seed_account_data()
	_connect_play_earned_grants()


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
## flow must route through this same function rather than adding a second one
## (see this milestone's own tasks.md Notes).
func grant(id: StringName, source: String) -> void:
	if _entitlements.has(id):
		return
	if CosmeticCatalogue.get_cosmetic(id) == null:
		push_error("EntitlementManager: grant of unknown cosmetic '%s'" % id)
		return
	_entitlements[id] = {"source": source, "granted_at": _now_unix()}
	_write_account_data()
	entitlement_granted.emit(id)


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
