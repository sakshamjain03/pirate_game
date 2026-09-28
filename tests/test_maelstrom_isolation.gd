extends GutTest

## Guards M26's campaign isolation (Requirements 1.2, 1.4, 2.x): a Maelstrom run
## must leave the campaign exactly as it found it, apart from the Eights grant.


const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const LOOT_DROP := preload("res://scenes/combat/LootDrop.tscn")
const EMPIRE_FACTION := preload("res://resources/factions/RoyalNavy.tres")

const PLAYER_SHIP := preload("res://scenes/world/PlayerShip.tscn")
const USER_FILES := ["user://save_data.json", "user://save_data.json.bak", "user://maelstrom_pending.json"]

var _scene: Node3D = null
var _notoriety_before: float
var _resources_before: Dictionary
var _file_backup := {}
var _maelstrom_before: Dictionary


func before_each() -> void:
	# Every persistence test writes user:// — keep the developer's real files.
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)
	_maelstrom_before = SaveManager._maelstrom_data.duplicate()
	SaveManager._maelstrom_data = {}
	SaveManager._maelstrom_pending_claimed = false
	# _on_died()/_spawn_loot() add explosions and crates to current_scene.
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_notoriety_before = EmpireManager.notoriety
	_resources_before = ResourceManager.current_resources.duplicate()


func after_each() -> void:
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	EmpireManager.notoriety = _notoriety_before
	ResourceManager.current_resources = _resources_before
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.free()
	_scene = null
	SaveManager._maelstrom_data = _maelstrom_before
	SaveManager._maelstrom_pending_claimed = false
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


func _kill_enemy() -> ShipController:
	var enemy := ENEMY_SHIP.instantiate() as ShipController
	enemy.faction = EMPIRE_FACTION
	_scene.add_child(enemy)
	enemy._on_died()
	return enemy


func _crates_in_scene() -> int:
	var n := 0
	for child in _scene.get_children():
		if child is LootDrop:
			n += 1
	return n


func test_empire_faction_fixture_is_empire() -> void:
	# If this ever flips, the notoriety assertions below would pass for the wrong reason.
	assert_true(EMPIRE_FACTION.get("is_empire"))


func test_maelstrom_kill_changes_no_notoriety_and_drops_no_crate() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	_kill_enemy()
	assert_eq(EmpireManager.notoriety, _notoriety_before, "Req 2.1: no notoriety from a Maelstrom kill")
	assert_eq(_crates_in_scene(), 0, "no campaign-resource crate from a Maelstrom kill")


func test_campaign_kill_still_grants_notoriety_and_crate() -> void:
	_kill_enemy()
	assert_eq(EmpireManager.notoriety, _notoriety_before + 5.0, "empire kill still +5 in the campaign")
	assert_eq(_crates_in_scene(), 1, "campaign kill still drops a crate")


func test_maelstrom_pickup_grants_no_campaign_resource_but_still_emits() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	var drop := LOOT_DROP.instantiate() as LootDrop
	drop.loot_data = {"gold": 50, "wood": 10}
	_scene.add_child(drop)
	watch_signals(drop)
	drop._collect()
	assert_signal_emitted(drop, "collected", "collected still fires so MaelstromRun can route it")
	assert_eq(ResourceManager.current_resources, _resources_before, "Req 2.2: no add_resource in the Maelstrom")


func test_campaign_pickup_still_grants_resources() -> void:
	ResourceManager.current_resources["gold"] = 0   # below any storage cap
	var gold_before: int = ResourceManager.get_resource("gold") if ResourceManager.has_method("get_resource") else int(ResourceManager.current_resources.get("gold", 0))
	var drop := LOOT_DROP.instantiate() as LootDrop
	drop.loot_data = {"gold": 50}
	_scene.add_child(drop)
	drop._collect()
	var gold_after: int = ResourceManager.get_resource("gold") if ResourceManager.has_method("get_resource") else int(ResourceManager.current_resources.get("gold", 0))
	assert_gt(gold_after, gold_before, "campaign crate still pays out")


func test_game_mode_defaults_to_campaign() -> void:
	assert_eq(SceneManager.game_mode, SceneManager.GameMode.CAMPAIGN)
	assert_true(SceneManager.is_campaign())


func test_is_campaign_flips_with_mode() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	assert_false(SceneManager.is_campaign())
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	assert_true(SceneManager.is_campaign())


# ------------------------------------------------------------------ persistence (Task 8)

const MANAGERS := ["ResourceManager", "FleetManager", "TechManager", "FactionManager",
	"EmpireManager", "TutorialManager", "CampaignManager", "SeasonalEventManager"]


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _snapshot_managers() -> Dictionary:
	var snap := {}
	for name in MANAGERS:
		var mgr = get_tree().root.get_node_or_null(name)
		if mgr and mgr.has_method("get_save_data"):
			snap[name] = JSON.parse_string(JSON.stringify(mgr.get_save_data()))
	return snap


## A campaign save as a real World session writes it — including a `player`
## section far from the Maelstrom arena, the specific hazard tasks.md names.
func _seed_campaign_save() -> Dictionary:
	var data := {
		"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION,
		"player": {"pos_x": 812.5, "pos_y": 0.3, "pos_z": -233.0, "rot_y": 1.2,
			"damage": {"hull": 41.0, "sails": 12.0, "crew": 3.0}, "captain_id": "jack"},
		"economy": {"gold": 1234, "wood": 77, "iron": 9, "rum": 4, "research": 5, "eights": 7},
		"islands": {"port_royal": {"buildings": ["dock"], "discovered": true}},
		"fleet": {"marker": "fleet"}, "tech": {"marker": "tech"}, "factions": {"marker": "factions"},
		"empire": {"notoriety": 88.0}, "tutorial": {"marker": "tutorial"},
		"campaign": {"chapter": 3}, "seasonal_events": {"marker": "seasonal"},
		"last_saved_unix": 1700000000,
	}
	_write_json(SaveManager.SAVE_PATH, data)
	return _read_json(SaveManager.SAVE_PATH)


## Kills, pickups, level-ups and a death, through the real MaelstromRun.
func _play_scripted_run(seconds: float) -> MaelstromRun:
	var player := PLAYER_SHIP.instantiate()
	_scene.add_child(player)
	var run := MaelstromRun.new()
	var spawner := EnemySpawner.new()
	spawner.name = "EnemySpawner"
	spawner.initial_enemies = 0
	run.add_child(spawner)
	_scene.add_child(run)
	spawner._initialize()
	for i in range(4):
		run._on_kill(Vector3(40 + i * 5, 0, 0))
	for drop in _scene.get_children():
		if drop is LootDrop:
			drop._collect()
	run._on_pickup({"kind": "repair", "amount": 0.1})
	run.add_plunder(run.curve.xp_for_level(1) + run.curve.xp_for_level(2))
	run._maybe_offer()
	run.apply_upgrade_choice(run.pick_choices()[0])
	run.elapsed = seconds
	player.ship_destroyed.emit()
	return run


func test_scripted_run_changes_only_the_maelstrom_section_and_eights() -> void:
	# Requirement 2.5 / 6.3.
	var before_file := _seed_campaign_save()
	var before_mgrs := _snapshot_managers()
	var run := _play_scripted_run(500.0)
	var eights := run.curve.eights_for(500.0)
	assert_gt(eights, 0, "fixture: the run is long enough to earn Eights")
	assert_eq(run.state, MaelstromRun.State.ENDED)

	var after_file := _read_json(SaveManager.SAVE_PATH)
	for key in before_file.keys():
		if key == "economy":
			continue
		assert_eq(after_file.get(key), before_file[key], "save section '%s' untouched by a run" % key)
	assert_eq(after_file["player"], before_file["player"], "the Maelstrom ship never overwrites the campaign ship")
	for res in before_file["economy"]:
		if res == "eights":
			assert_eq(int(after_file["economy"]["eights"]), int(before_file["economy"]["eights"]) + eights, "Eights granted")
		else:
			assert_eq(after_file["economy"][res], before_file["economy"][res], "economy.%s untouched" % res)
	assert_true(after_file.has("maelstrom"), "record written")
	assert_eq(int(after_file["maelstrom"]["runs"]), 1)
	assert_almost_eq(float(after_file["maelstrom"]["best_seconds"]), 500.0, 0.01)
	var extra := after_file.keys().filter(func(k): return not before_file.has(k))
	assert_eq(extra, ["maelstrom"], "the only new section is 'maelstrom'")

	var after_mgrs := _snapshot_managers()
	for name in before_mgrs:
		if name == "ResourceManager":
			for res in before_mgrs[name]:
				if res != "eights":
					assert_eq(after_mgrs[name][res], before_mgrs[name][res], "%s.%s unchanged" % [name, res])
		else:
			assert_eq(after_mgrs[name], before_mgrs[name], "%s.get_save_data() unchanged by a run" % name)


func test_fresh_save_has_no_maelstrom_key() -> void:
	# Requirement 6.4 — the optional section is omitted, never written empty.
	SaveManager.save_game()
	assert_false(_read_json(SaveManager.SAVE_PATH).has("maelstrom"))


func test_record_survives_a_campaign_autosave_and_load() -> void:
	# Seeded from the managers' real state (not the synthetic fixture) because
	# load_game() below pushes the file back into the global autoloads.
	SaveManager.save_game()
	_play_scripted_run(200.0)
	# A later World session loads, then autosaves: the section must round-trip.
	SaveManager.load_game()
	assert_eq(int(SaveManager.get_maelstrom_data().get("runs", 0)), 1)
	SaveManager.save_game()
	assert_eq(int(_read_json(SaveManager.SAVE_PATH)["maelstrom"]["runs"]), 1, "autosave keeps the record")


func test_best_run_is_kept_across_runs() -> void:
	_seed_campaign_save()
	SaveManager.save_maelstrom_result(0, 300.0, 6)
	var rec := SaveManager.save_maelstrom_result(0, 100.0, 2)
	assert_eq(int(rec["runs"]), 2)
	assert_almost_eq(float(rec["best_seconds"]), 300.0, 0.01)
	assert_eq(int(rec["best_level"]), 6)


func test_no_campaign_save_parks_the_run_without_creating_one() -> void:
	# A fresh install: the run must not create a half-empty save that turns on
	# "Continue" and skips New Game's onboarding.
	var run := _play_scripted_run(500.0)
	var eights := run.curve.eights_for(500.0)
	assert_false(FileAccess.file_exists(SaveManager.SAVE_PATH), "no campaign save created")
	assert_false(SaveManager.has_recoverable_save_data(), "Continue stays hidden")
	var pending := _read_json(SaveManager.MAELSTROM_PENDING_PATH)
	assert_eq(int(pending.get("eights", 0)), eights)
	assert_eq(int(pending["record"]["runs"]), 1)
	assert_eq(int(SaveManager.load_maelstrom_record()["runs"]), 1, "best is readable before any campaign")

	# New Game: the wallet is reset, World loads with no save -> the run is claimed.
	ResourceManager.current_resources = {"gold": 200, "wood": 50, "iron": 20, "rum": 10}
	SaveManager.load_game()
	assert_eq(ResourceManager.get_resource("eights"), eights, "pending Eights claimed into the campaign")
	assert_eq(int(SaveManager.get_maelstrom_data()["runs"]), 1)
	assert_true(FileAccess.file_exists(SaveManager.MAELSTROM_PENDING_PATH), "kept until a real save holds it")

	SaveManager.save_game()
	assert_false(FileAccess.file_exists(SaveManager.MAELSTROM_PENDING_PATH), "deleted once saved")
	var saved := _read_json(SaveManager.SAVE_PATH)
	assert_eq(int(saved["economy"]["eights"]), eights)
	assert_eq(int(saved["maelstrom"]["runs"]), 1)


func test_unclaimed_pending_claims_again_after_a_lost_session() -> void:
	# Claimed in memory, app closed before any save: the next load claims once more.
	SaveManager.save_maelstrom_result(4, 130.0, 3)
	ResourceManager.current_resources = {"gold": 200, "eights": 0}
	SaveManager.load_game()
	ResourceManager.current_resources = {"gold": 200, "eights": 0}   # the lost session
	SaveManager.load_game()
	assert_eq(ResourceManager.get_resource("eights"), 4, "claimed exactly once into this session")


func test_unreadable_campaign_save_is_never_overwritten() -> void:
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	SaveManager.save_maelstrom_result(2, 130.0, 2)
	assert_eq(FileAccess.get_file_as_string(SaveManager.SAVE_PATH), "{ not json", "corrupt primary left for recovery")
	assert_eq(int(_read_json(SaveManager.MAELSTROM_PENDING_PATH).get("eights", 0)), 2, "the run is kept pending")