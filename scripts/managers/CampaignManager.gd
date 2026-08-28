extends Node

## Purpose: the M7 campaign spine — chapter loading, gating, objective tracking,
## rewards. `docs/04_GAME_LOOP.md`: "the chapter loop is a frame around the
## other loops — never a gate." A player who ignores it loses nothing but the
## frame; every objective resolves from a signal that already exists.
## Responsibilities: load `resources/campaign/chapters/*.tres`, advance through
## them as their gates (`required_region_id`/`required_previous_chapter`) and
## objectives are satisfied, grant chapter rewards, and round-trip progress
## through save/load. Never calls into gameplay except through existing public
## APIs (`FleetManager.add_ship()`, `TechManager.unlock_tech()`, ...) — the
## same discipline `TutorialManager` already follows via `spawn_hunter()`.
## Dependencies: EmpireManager, FleetManager, TechManager, ResourceManager
##   (autoloads, connected directly); WorldManager, IslandMenu, EnemySpawner,
##   EncounterManager, BoardingSystem (scene-local, connected via
##   `on_world_ready()`, mirroring `TutorialManager`'s own pattern).

signal chapter_started(chapter: ChapterData)
signal objective_progressed(objective_id: String, current: int, target: int)
signal objective_completed(objective_id: String)
signal chapter_completed(chapter: ChapterData)

const CHAPTERS_DIR := "res://resources/campaign/chapters/"

var chapters: Array[ChapterData] = []
var current_chapter_index: int = -1
var completed_chapter_ids: Array[String] = []

var _objective_progress: Dictionary = {}   # objective_id -> int
var _completed_objective_ids: Array[String] = []


func _ready() -> void:
	_load_chapters()
	_connect_global_signals()
	call_deferred("_catch_up")


func _load_chapters() -> void:
	chapters.clear()
	var dir := DirAccess.open(CHAPTERS_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var chapter := load(CHAPTERS_DIR + file_name) as ChapterData
			if chapter:
				chapters.append(chapter)
		file_name = dir.get_next()
	dir.list_dir_end()
	chapters.sort_custom(func(a, b): return a.chapter_number < b.chapter_number)


func _connect_global_signals() -> void:
	if EmpireManager:
		EmpireManager.notoriety_changed.connect(_on_notoriety_changed)
		EmpireManager.region_activated.connect(_on_region_activated)
		EmpireManager.island_captured.connect(_on_island_captured)
		EmpireManager.island_tier_changed.connect(_on_island_tier_changed)
		EmpireManager.raid_resolved.connect(_on_raid_resolved)
	if FleetManager:
		FleetManager.captain_recruited.connect(_on_captain_recruited)
		FleetManager.fleet_changed.connect(_on_fleet_changed)
	if TechManager:
		TechManager.tech_unlocked.connect(_on_tech_unlocked)
	if ResourceManager:
		ResourceManager.resources_changed.connect(_on_resources_changed)


## Scene-local wiring, called deferred from `World.gd` exactly like
## `TutorialManager.on_world_ready()` — these systems don't exist until a World
## scene does, so they can't be connected from this autoload's own `_ready()`.
func on_world_ready(world_manager: Node) -> void:
	if world_manager and world_manager.has_signal("player_docked"):
		if not world_manager.player_docked.is_connected(_on_player_docked):
			world_manager.player_docked.connect(_on_player_docked)

	if world_manager and world_manager.has_signal("island_discovered"):
		if not world_manager.island_discovered.is_connected(_on_island_discovered):
			world_manager.island_discovered.connect(_on_island_discovered)

	var island_menu := get_tree().get_first_node_in_group("island_menu")
	if island_menu and island_menu.has_signal("structure_changed"):
		if not island_menu.structure_changed.is_connected(_on_structure_changed):
			island_menu.structure_changed.connect(_on_structure_changed)

	var scene := get_tree().current_scene
	var systems := scene.get_node_or_null("Systems") if scene else null
	if not systems:
		return

	var spawner := systems.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_signal("enemy_destroyed") \
			and not spawner.enemy_destroyed.is_connected(_on_ship_destroyed):
		spawner.enemy_destroyed.connect(_on_ship_destroyed)

	# EnemySpawner's own signal only covers its ambient roamers, never a
	# bounded encounter's composition or boss — EncounterManager's mirrored
	# signal (M7 Task 11) is what makes DESTROY_SHIPS/DEFEAT_BOSS see those too.
	var encounter_mgr := systems.get_node_or_null("EncounterManager")
	if encounter_mgr and encounter_mgr.has_signal("ship_destroyed") \
			and not encounter_mgr.ship_destroyed.is_connected(_on_ship_destroyed):
		encounter_mgr.ship_destroyed.connect(_on_ship_destroyed)

	var boarding := systems.get_node_or_null("BoardingSystem")
	if boarding and boarding.has_signal("boarding_resolved") \
			and not boarding.boarding_resolved.is_connected(_on_boarding_resolved):
		boarding.boarding_resolved.connect(_on_boarding_resolved)


# === Gating ===

func _gate_satisfied(chapter: ChapterData) -> bool:
	if not chapter.required_previous_chapter.is_empty() \
			and not completed_chapter_ids.has(chapter.required_previous_chapter):
		return false
	if not chapter.required_region_id.is_empty() \
			and not (EmpireManager and EmpireManager.is_region_active(chapter.required_region_id)):
		return false
	return true


func _current_chapter() -> ChapterData:
	if current_chapter_index < 0 or current_chapter_index >= chapters.size():
		return null
	var chapter := chapters[current_chapter_index]
	if completed_chapter_ids.has(chapter.chapter_id):
		return null
	return chapter


## The overshoot case (Requirement 6.8): a save can load with, say, notoriety
## already past every gate (or a fresh game with no save at all). Runs once, at
## `_ready()`/after `load_save_data()` — mid-play advancement always goes
## through `_complete_chapter()` -> `_advance_to_next_chapter()` instead, so a
## chapter is never skipped just because a *later* gate happens to be open.
func _catch_up() -> void:
	## Walks forward using the plain, strict gate check — never speculatively
	## completing a chapter just to unblock the next one. A real overshoot only
	## exists when `completed_chapter_ids` already holds real completions (e.g.
	## loaded from a save) and/or a region independently activated while
	## `current_chapter_index` hadn't caught up yet.
	while current_chapter_index + 1 < chapters.size():
		# Never advance past the chapter currently in progress just because a
		# later chapter's own gate (typically a region-only gate with no
		# required_previous_chapter — ch3/ch5) already happens to be open.
		# Notoriety climbs from ordinary combat throughout every chapter, so a
		# player who kept fighting while mid-chapter can cross a later
		# region's threshold before finishing (or even drawing) the current
		# chapter's own content. Left unguarded, this silently abandons that
		# chapter: its objectives freeze (dispatch only ever targets
		# _current_chapter()), its D65 ambient-gated boss becomes
		# unreachable, and its completion reward is never granted.
		if current_chapter_index >= 0 and _current_chapter() != null:
			return
		var next := chapters[current_chapter_index + 1]
		if not _gate_satisfied(next):
			return
		current_chapter_index += 1
		chapter_started.emit(chapters[current_chapter_index])


func _advance_to_next_chapter() -> void:
	var next_index := current_chapter_index + 1
	if next_index >= chapters.size():
		return
	if _gate_satisfied(chapters[next_index]):
		current_chapter_index = next_index
		chapter_started.emit(chapters[next_index])
	# Else: no chapter is "current" until a later gate-relevant signal
	# (_on_region_activated) re-checks and finds it satisfied.


func _on_region_activated(_region_id: String) -> void:
	if current_chapter_index == -1 or completed_chapter_ids.has(_current_chapter_id_or_empty()):
		_advance_to_next_chapter()


func _current_chapter_id_or_empty() -> String:
	if current_chapter_index < 0 or current_chapter_index >= chapters.size():
		return ""
	return chapters[current_chapter_index].chapter_id


# === Objective progress — the generic dispatch, reusing TutorialManager's shape ===

func _advance_objective(objective: ObjectiveData, amount: int) -> void:
	var key := objective.objective_id
	if _completed_objective_ids.has(key):
		return
	var current: int = int(_objective_progress.get(key, 0)) + amount
	_objective_progress[key] = current
	objective_progressed.emit(key, current, objective.target_count)
	if current >= objective.target_count:
		_completed_objective_ids.append(key)
		objective_completed.emit(key)


## For REACH_ISLAND_TIER / REACH_NOTORIETY / ACCUMULATE_RESOURCE: sets progress
## to the current absolute value rather than incrementing a counter.
func _advance_level(objective: ObjectiveData, value: float) -> void:
	var key := objective.objective_id
	if _completed_objective_ids.has(key):
		return
	var threshold: float = float(objective.target_count) \
		if objective.condition == ObjectiveData.Condition.REACH_ISLAND_TIER \
		else objective.target_value
	var current: int = int(min(value, threshold))
	_objective_progress[key] = current
	objective_progressed.emit(key, current, int(threshold))
	if value >= threshold:
		_completed_objective_ids.append(key)
		objective_completed.emit(key)


func _for_each_matching(condition: int, target_id: String, body: Callable) -> void:
	var chapter := _current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.condition != condition:
			continue
		if not objective.target_id.is_empty() and objective.target_id != target_id:
			continue
		body.call(objective)
	_check_chapter_complete(chapter)


func _check_chapter_complete(chapter: ChapterData) -> void:
	for objective in chapter.objectives:
		if objective.is_optional:
			continue
		if not _completed_objective_ids.has(objective.objective_id):
			return
	_complete_chapter(chapter)


func _complete_chapter(chapter: ChapterData) -> void:
	if completed_chapter_ids.has(chapter.chapter_id):
		return
	completed_chapter_ids.append(chapter.chapter_id)
	_grant_rewards(chapter)
	chapter_completed.emit(chapter)
	_advance_to_next_chapter()


func is_chapter_completed(chapter_id: String) -> bool:
	return chapter_id.is_empty() or completed_chapter_ids.has(chapter_id)


## True if `chapter_id` is empty (no gate) or is the chapter currently in
## progress. Lets a chapter-specific system (e.g. `EncounterManager`'s ambient
## boss gate) key off "is this chapter live right now" without duplicating
## `_current_chapter()`'s completed/index bookkeeping.
func is_chapter_current(chapter_id: String) -> bool:
	if chapter_id.is_empty():
		return true
	var chapter := _current_chapter()
	return chapter != null and chapter.chapter_id == chapter_id


# === Condition handlers — one per real signal, mirroring TutorialManager ===

func _on_player_docked(island_id: String) -> void:
	_on_island_discovered(island_id)
	_for_each_matching(ObjectiveData.Condition.DOCK_AT_ISLAND, island_id,
		func(o): _advance_objective(o, 1))


## M10 Requirement 4 — the write path used to be dock-only (docking always
## implies discovery, so this used to live inline in _on_player_docked).
## Factored out so WorldManager's new proximity check (reveal-on-approach,
## not reveal-only-on-dock) can dispatch the same DISCOVER_ISLAND objective
## progress and discovered-flag write without duplicating either.
func _on_island_discovered(island_id: String) -> void:
	_mark_discovered(island_id)
	_for_each_matching(ObjectiveData.Condition.DISCOVER_ISLAND, island_id,
		func(o): _advance_objective(o, 1))


func _mark_discovered(island_id: String) -> void:
	## E2: the write path IslandData.discovered was authored but never set by
	## anything until M7 wired the dock path in. M10 added the
	## WorldManager.island_discovered proximity signal (reveal-on-approach)
	## alongside it — both paths converge here as the single writer.
	for island in get_tree().get_nodes_in_group("islands"):
		if island.has_method("get_island_id") and island.get_island_id() == island_id:
			if island.island_data and not island.island_data.discovered:
				island.island_data.discovered = true
			return


func _on_structure_changed(building_id: String, is_upgrade: bool) -> void:
	var condition := ObjectiveData.Condition.UPGRADE_STRUCTURE_TO_LEVEL if is_upgrade \
		else ObjectiveData.Condition.BUILD_STRUCTURE
	_for_each_matching(condition, building_id, func(o): _advance_objective(o, 1))


func _on_ship_destroyed(ship: Node3D) -> void:
	if not is_instance_valid(ship):
		return
	var faction_id := ""
	if "faction" in ship and ship.get("faction"):
		faction_id = str(ship.get("faction").get("faction_id"))
	# A dedicated (non-shared) boss ShipStats authors a unique ship_id, so this
	# doubles as boss identification (E1) without a second id field — as long
	# as boss encounters use their own ShipStats rather than a shared hull
	# template also sold to the player.
	var ship_id := ""
	if "ship_stats" in ship and ship.ship_stats:
		ship_id = ship.ship_stats.ship_id

	_for_each_matching(ObjectiveData.Condition.DESTROY_SHIPS, faction_id,
		func(o): _advance_objective(o, 1))
	if not ship_id.is_empty():
		_for_each_matching(ObjectiveData.Condition.DEFEAT_BOSS, ship_id,
			func(o): _advance_objective(o, 1))


func _on_boarding_resolved(success: bool, _loot: Dictionary, target_faction_id: String,
		target_ship_id: String) -> void:
	if not success:
		return
	var chapter := _current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.condition != ObjectiveData.Condition.BOARD_SHIPS:
			continue
		if not objective.target_id.is_empty() and objective.target_id != target_faction_id \
				and objective.target_id != target_ship_id:
			continue
		_advance_objective(objective, 1)
	_check_chapter_complete(chapter)


func _on_captain_recruited(_captain: CaptainData) -> void:
	_for_each_matching(ObjectiveData.Condition.RECRUIT_CAPTAIN, "", func(o): _advance_objective(o, 1))


func _on_fleet_changed() -> void:
	## OWN_SHIP_CLASS is authored as target_value = the required class, checked
	## against the best hull currently owned — recomputed rather than
	## incremented, since there is no "sell a ship" path to make it non-monotonic.
	var max_class := 0
	for owned in FleetManager.owned_ships:
		if owned and owned.ship_stats and owned.ship_stats.ship_class > max_class:
			max_class = owned.ship_stats.ship_class
	var chapter := _current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.condition != ObjectiveData.Condition.OWN_SHIP_CLASS:
			continue
		if _completed_objective_ids.has(objective.objective_id):
			continue
		var owns_one := 1 if max_class >= int(objective.target_value) else 0
		_objective_progress[objective.objective_id] = owns_one
		objective_progressed.emit(objective.objective_id, owns_one, 1)
		if owns_one >= 1:
			_completed_objective_ids.append(objective.objective_id)
			objective_completed.emit(objective.objective_id)
	_check_chapter_complete(chapter)


func _on_tech_unlocked(tech: Resource) -> void:
	var tech_id: String = str(tech.get("tech_id")) if tech else ""
	_for_each_matching(ObjectiveData.Condition.UNLOCK_TECH, tech_id, func(o): _advance_objective(o, 1))


func _on_island_captured(island_id: String) -> void:
	_for_each_matching(ObjectiveData.Condition.CAPTURE_ISLAND, island_id, func(o): _advance_objective(o, 1))


func _on_island_tier_changed(island_id: String, new_tier: int) -> void:
	_for_each_matching(ObjectiveData.Condition.REACH_ISLAND_TIER, island_id,
		func(o): _advance_level(o, float(new_tier)))


func _on_notoriety_changed(new_value: float) -> void:
	_for_each_matching(ObjectiveData.Condition.REACH_NOTORIETY, "", func(o): _advance_level(o, new_value))


func _on_resources_changed(resources: Dictionary) -> void:
	var chapter := _current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.condition != ObjectiveData.Condition.ACCUMULATE_RESOURCE:
			continue
		if objective.target_id.is_empty() or not resources.has(objective.target_id):
			continue
		_advance_level(objective, float(resources[objective.target_id]))
	_check_chapter_complete(chapter)


func _on_raid_resolved(_report: Dictionary) -> void:
	## Either outcome satisfies SURVIVE_RAID — being robbed is a lesson, not a
	## fail state (docs/13_CAMPAIGN_LEVELS_1-5.md §5, Chapter 3's 3.4).
	_for_each_matching(ObjectiveData.Condition.SURVIVE_RAID, "", func(o): _advance_objective(o, 1))


# === Rewards ===

func _grant_rewards(chapter: ChapterData) -> void:
	if chapter.reward_gold > 0 and ResourceManager:
		ResourceManager.add_resource("gold", chapter.reward_gold)
	if not chapter.reward_captain_id.is_empty():
		var cap := _find_by_id("res://resources/captains/", "captain_id", chapter.reward_captain_id)
		if cap and FleetManager.has_method("add_captain"):
			FleetManager.add_captain(cap)
	if not chapter.reward_ship_id.is_empty():
		var ship := _find_by_id("res://resources/ships/", "ship_id", chapter.reward_ship_id)
		if ship and FleetManager.has_method("add_ship"):
			FleetManager.add_ship(ship)
	if not chapter.reward_tech_id.is_empty():
		var tech := _find_by_id("res://resources/techs/", "tech_id", chapter.reward_tech_id)
		if tech and TechManager.has_method("unlock_tech"):
			TechManager.unlock_tech(tech)


func _find_by_id(dir_path: String, id_field: String, id_value: String) -> Resource:
	## Mirrors EmpireManager._get_faction_by_id()'s directory-scan pattern.
	var dir := DirAccess.open(dir_path)
	if not dir:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res and res.get(id_field) == id_value:
				dir.list_dir_end()
				return res
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


# === Save/load ===

func get_save_data() -> Dictionary:
	return {
		"current_chapter_index": current_chapter_index,
		"completed_chapter_ids": completed_chapter_ids.duplicate(),
		"objective_progress": _objective_progress.duplicate(),
		"completed_objective_ids": _completed_objective_ids.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	current_chapter_index = int(data.get("current_chapter_index", -1))
	completed_chapter_ids = []
	for id in data.get("completed_chapter_ids", []):
		completed_chapter_ids.append(str(id))
	_objective_progress = data.get("objective_progress", {}).duplicate()
	_completed_objective_ids = []
	for id in data.get("completed_objective_ids", []):
		_completed_objective_ids.append(str(id))
	call_deferred("_catch_up")
