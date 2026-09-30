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
## M28 — a chapter lesson's trigger fired. LessonCoachCard queues and shows it.
signal lesson_requested(lesson: LessonData)

const CHAPTERS_DIR := "res://resources/campaign/chapters/"
## Chapters whose Eights reward has been paid on this install. Outside the
## campaign save on purpose: Pieces of Eight survive a New Game (owner decision
## 2026-09-30), so without this record every restart would pay Chapter 1's Eights
## again and New Game would become an Eights farm.
const EIGHTS_LEDGER_PATH := "user://eights_ledger.json"
var eights_ledger_path := EIGHTS_LEDGER_PATH   # test seam
var _chapter_eights_paid: Dictionary = {}      # chapter_id -> true

var chapters: Array[ChapterData] = []
var current_chapter_index: int = -1
var completed_chapter_ids: Array[String] = []

var _objective_progress: Dictionary = {}   # objective_id -> int
var _completed_objective_ids: Array[String] = []

## M28 — last-seen player/heat state the lesson triggers and new conditions
## compare against (a rise/fall is only visible relative to the previous value).
var _last_heat_level: int = 0
var _player_pool_last: Dictionary = {}   # pool -> float
var _player_ammo_id: String = ""
## Enemy instance ids already counted for CRIPPLE_SAILS — a ship whose sails
## are shot to zero twice (repair, then again) is still one crippled ship.
var _crippled_ship_ids: Dictionary = {}
## The player's DockingSystem (scene-local, replaced per World). Read-only:
## REPAIR_SHIP only counts a repair made while docked.
var _docking_system: Node = null


func _ready() -> void:
	_load_eights_ledger()
	_load_chapters()
	_connect_global_signals()
	_connect_lesson_signals()
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
			# MVP scope gate — chapters 6-10 are authored but not shipped.
			if chapter and ResourceLookup.is_content_enabled(chapter):
				chapters.append(chapter)
		file_name = dir.get_next()
	dir.list_dir_end()
	chapters.sort_custom(func(a, b): return a.chapter_number < b.chapter_number)
	_validate_lessons()


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
		if FleetManager.has_signal("active_ship_changed"):
			FleetManager.active_ship_changed.connect(_on_active_ship_changed)
	if FactionManager and FactionManager.has_signal("reputation_changed"):
		FactionManager.reputation_changed.connect(_on_reputation_changed)
	if TechManager:
		TechManager.tech_unlocked.connect(_on_tech_unlocked)
	if ResourceManager:
		ResourceManager.resources_changed.connect(_on_resources_changed)
	if EmpireManager and EmpireManager.has_signal("heat_tier_changed"):
		EmpireManager.heat_tier_changed.connect(_on_heat_tier_changed)
	if SaveManager and SaveManager.has_signal("game_loaded"):
		SaveManager.game_loaded.connect(_seed_heat_level)
	_connect_schedule_manager()


## M28 Requirement 4.2 — ScheduleManager (M27) is optional: no autoload, or one
## without the signal, means the timer lesson simply never fires. No error.
func _connect_schedule_manager(schedule: Node = null) -> void:
	if schedule == null:
		schedule = get_node_or_null("/root/ScheduleManager")
	if schedule and schedule.has_signal("job_started") \
			and not schedule.job_started.is_connected(_on_job_started):
		schedule.job_started.connect(_on_job_started)


## Lessons key off this manager's own chapter/objective events, so they fire
## from exactly the places the story and objectives already do.
func _connect_lesson_signals() -> void:
	chapter_started.connect(_on_chapter_started_lessons)
	chapter_completed.connect(_on_chapter_completed_lessons)
	objective_completed.connect(_on_objective_completed_lessons)


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

	_connect_player_ship()
	_connect_schedule_manager()
	_seed_heat_level()
	_docking_system = world_manager.get_node_or_null("../DockingSystem") if world_manager else null

	var world_map := get_tree().get_first_node_in_group("world_map_screen")
	if world_map and world_map.has_signal("course_requested") \
			and not world_map.course_requested.is_connected(_on_course_requested):
		world_map.course_requested.connect(_on_course_requested)

	# CRIPPLE_SAILS needs every enemy hull's pools, and enemies arrive by three
	# routes with no shared spawn signal (EnemySpawner roamers, EncounterManager
	# compositions, Island defenders added via call_deferred). The "enemy_ship"
	# scene group is the one thing they share: sweep it now, then catch new ones.
	for enemy in get_tree().get_nodes_in_group("enemy_ship"):
		_watch_enemy(enemy)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	# Deferred: the coach card is created by WorldHUD, and a lesson only fires
	# (and is marked seen) while a card exists to show it.
	call_deferred("_refire_world_ready_lessons")

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
	if not chapter.required_seasonal_event_id.is_empty() \
			and not SeasonalEventManager.has_ever_completed(chapter.required_seasonal_event_id):
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
	var current := ObjectiveDispatch.advance_count(_objective_progress, _completed_objective_ids, objective, amount)
	objective_progressed.emit(key, current, objective.target_count)
	if _completed_objective_ids.has(key):
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
	var current := ObjectiveDispatch.advance_level(_objective_progress, _completed_objective_ids, objective, value)
	objective_progressed.emit(key, current, int(threshold))
	if _completed_objective_ids.has(key):
		objective_completed.emit(key)


func _for_each_matching(condition: int, target_id: String, body: Callable) -> void:
	var chapter := _current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if not ObjectiveDispatch.matches(objective, condition, target_id):
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
	# Fire once, after rewards are granted — the positive confirmation the
	# player's progress actually paid off. Never fires per-objective; only
	# per completed chapter. Gateway is a no-op on PC / when toggle is off.
	HapticFeedbackManager.reward()
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
	_fire_trigger(LessonData.Trigger.FIRST_DOCK, island_id)
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
		if not ObjectiveDispatch.matches_any(objective, ObjectiveData.Condition.BOARD_SHIPS,
				target_faction_id, target_ship_id):
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
	if ResourceManager and int(resources.get(ResourceManager.PREMIUM_CURRENCY, 0)) > 0:
		_fire_trigger(LessonData.Trigger.FIRST_EIGHTS)
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


# --- M28 conditions ---

## SWAP_AMMO. ammo_changed also fires from any set_ammo(), so only a change to a
## DIFFERENT ammo counts — re-selecting the loaded shot, or a load/ship-swap that
## sets the same one, is not a swap.
func _on_player_ammo_changed(ammo: AmmoData) -> void:
	var ammo_id: String = ammo.ammo_id if ammo else ""
	var previous := _player_ammo_id
	_player_ammo_id = ammo_id
	if ammo_id.is_empty() or ammo_id == previous:
		return
	_for_each_matching(ObjectiveData.Condition.SWAP_AMMO, ammo_id, func(o): _advance_objective(o, 1))


func _on_node_added(node: Node) -> void:
	if node.is_in_group("enemy_ship"):
		# Deferred: the root enters the tree before its children finish entering.
		_watch_enemy.call_deferred(node)


func _watch_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy) or enemy.has_meta(&"_m28_sails_watched"):
		return
	var damage := enemy.get_node_or_null("ShipDamage")
	if not damage or not damage.has_signal("pool_changed"):
		return
	enemy.set_meta(&"_m28_sails_watched", true)
	damage.pool_changed.connect(_on_enemy_pool_changed.bind(enemy))


## CRIPPLE_SAILS: an enemy's sails shot to zero, counted once per ship, and
## only if the player is the one fighting it — EnemyAI.provoke() is set by a
## player cannonball, ram or boarding attempt, never by enemies hitting each other.
func _on_enemy_pool_changed(pool: String, current: float, _maximum: float, enemy: Node) -> void:
	if pool != "sails" or current > 0.0 or not is_instance_valid(enemy):
		return
	var key := enemy.get_instance_id()
	if _crippled_ship_ids.has(key):
		return
	var ai := enemy.get_node_or_null("EnemyAI")
	if not ai or not ai.has_method("is_provoked") or not ai.is_provoked():
		return
	_crippled_ship_ids[key] = true
	var faction_id := ""
	if "faction" in enemy and enemy.get("faction"):
		faction_id = str(enemy.get("faction").get("faction_id"))
	_for_each_matching(ObjectiveData.Condition.CRIPPLE_SAILS, faction_id, func(o): _advance_objective(o, 1))


## REPAIR_SHIP: ShipDamage.repaired (repair() only — never restore_all()) while
## the player is docked. Covers the dock's passive repair and the shipyard's.
func _on_player_repaired(_pool: String, amount: float) -> void:
	if amount <= 0.0 or not _is_player_docked():
		return
	_for_each_matching(ObjectiveData.Condition.REPAIR_SHIP, "", func(o): _advance_objective(o, 1))


func _is_player_docked() -> bool:
	if not _docking_system or not is_instance_valid(_docking_system):
		return false
	return _docking_system.get("current_state") == DockingSystem.DockState.DOCKED


func _on_active_ship_changed(_ship_stats: ShipStats, captain: CaptainData) -> void:
	if captain == null:
		return
	_for_each_matching(ObjectiveData.Condition.ASSIGN_CAPTAIN, "", func(o): _advance_objective(o, 1))


func _on_reputation_changed(faction_id: String, new_rep: int) -> void:
	_for_each_matching(ObjectiveData.Condition.CHANGE_REPUTATION, faction_id,
		func(o): _advance_level(o, float(new_rep)))


func _on_course_requested(island: IslandData) -> void:
	if not island:
		return
	_for_each_matching(ObjectiveData.Condition.SET_COURSE, island.island_id,
		func(o): _advance_objective(o, 1))


func _on_raid_resolved(_report: Dictionary) -> void:
	## Either outcome satisfies SURVIVE_RAID — being robbed is a lesson, not a
	## fail state (docs/13_CAMPAIGN_LEVELS_1-5.md §5, Chapter 3's 3.4).
	_for_each_matching(ObjectiveData.Condition.SURVIVE_RAID, "", func(o): _advance_objective(o, 1))


# === Lessons (M28) ===
# Lessons are chapter content (ChapterData.lessons), fired from signals this
# manager already listens to. TutorialManager only holds the on/off flag and
# the seen set. A lesson fires at most once per profile, only while its own
# chapter is current, and only while a LessonCoachCard exists to show it —
# Chapter 1 starts at autoload boot, on the menu, and a lesson "seen" there
# would be seen by nobody.

func _validate_lessons() -> void:
	var seen_ids := {}
	for chapter in chapters:
		for lesson in chapter.lessons:
			if lesson == null:
				push_error("CampaignManager: chapter '%s' has a null lesson" % chapter.chapter_id)
				continue
			if lesson.lesson_id.is_empty():
				push_error("CampaignManager: chapter '%s' has a lesson with no lesson_id" % chapter.chapter_id)
				continue
			if seen_ids.has(lesson.lesson_id):
				push_error("CampaignManager: duplicate lesson_id '%s' (chapters '%s' and '%s')" \
					% [lesson.lesson_id, seen_ids[lesson.lesson_id], chapter.chapter_id])
				continue
			seen_ids[lesson.lesson_id] = chapter.chapter_id


func has_lesson(lesson_id: String) -> bool:
	return _find_lesson(lesson_id) != null


## Resolves a lesson id. An unknown id is an authoring or save error and is
## reported, never skipped silently (M28 Requirement 1.5).
func get_lesson(lesson_id: String) -> LessonData:
	var lesson := _find_lesson(lesson_id)
	if lesson == null:
		push_error("CampaignManager.get_lesson: unknown lesson_id '%s'" % lesson_id)
	return lesson


func _find_lesson(lesson_id: String) -> LessonData:
	if lesson_id.is_empty():
		return null
	for chapter in chapters:
		for lesson in chapter.lessons:
			if lesson and lesson.lesson_id == lesson_id:
				return lesson
	return null


## The objective a player is "on": the first incomplete, non-optional one in
## authored order — the same pick WorldHUD's stall hint makes. Objectives all
## progress in parallel; this only decides which one a lesson introduces.
func get_current_objective() -> ObjectiveData:
	var chapter := _current_chapter()
	if not chapter:
		return null
	for objective in chapter.objectives:
		if objective.is_optional or _completed_objective_ids.has(objective.objective_id):
			continue
		return objective
	return null


## `chapter` defaults to the current one; CHAPTER_COMPLETED passes the chapter
## explicitly because it is no longer "current" once completed.
func _fire_trigger(trigger: int, arg: String = "", chapter: ChapterData = null) -> void:
	if chapter == null:
		chapter = _current_chapter()
	if chapter == null or not TutorialManager or not TutorialManager.lessons_enabled:
		return
	if not _lesson_card_present():
		return
	for lesson in chapter.lessons:
		if lesson == null or lesson.trigger != trigger:
			continue
		if not lesson.trigger_arg.is_empty() and lesson.trigger_arg != arg:
			continue
		if TutorialManager.has_seen(lesson.lesson_id):
			continue
		TutorialManager.mark_seen(lesson.lesson_id)
		lesson_requested.emit(lesson)


func _lesson_card_present() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(&"lesson_coach_card") != null


func _fire_current_objective() -> void:
	var objective := get_current_objective()
	if objective:
		_fire_trigger(LessonData.Trigger.OBJECTIVE_CURRENT, objective.objective_id)


func _on_chapter_completed_lessons(chapter: ChapterData) -> void:
	_fire_trigger(LessonData.Trigger.CHAPTER_COMPLETED, "", chapter)


func _on_objective_completed_lessons(_objective_id: String) -> void:
	_fire_current_objective()


func _on_chapter_started_lessons(chapter: ChapterData) -> void:
	_fire_trigger(LessonData.Trigger.CHAPTER_STARTED, "", chapter)
	_fire_current_objective()


## A chapter that started with no World (Chapter 1 at boot) or during a scene
## change fires its start/current-objective lessons here instead. The seen set
## makes a repeat a no-op.
func _refire_world_ready_lessons() -> void:
	var chapter := _current_chapter()
	if chapter:
		_on_chapter_started_lessons(chapter)


## Player-ship sources: the ship is scene-local and replaced per World, so this
## runs from on_world_ready(), after SaveManager.load_game() (both deferred, in
## that order, from World.gd).
func _connect_player_ship() -> void:
	var player := get_tree().get_first_node_in_group("player_ship")
	if not player:
		return
	var combat := player.get_node_or_null("ShipCombat")
	if combat and combat.has_signal("arc_lock_changed") \
			and not combat.arc_lock_changed.is_connected(_on_player_arc_lock_changed):
		combat.arc_lock_changed.connect(_on_player_arc_lock_changed)
	if combat and combat.has_signal("ammo_changed"):
		var loaded = combat.get("current_ammo")
		_player_ammo_id = loaded.ammo_id if loaded else ""
		if not combat.ammo_changed.is_connected(_on_player_ammo_changed):
			combat.ammo_changed.connect(_on_player_ammo_changed)
	var damage := player.get_node_or_null("ShipDamage")
	if damage and damage.has_signal("pool_changed"):
		_player_pool_last.clear()
		for pool in ["hull", "sails", "crew"]:
			if pool in damage:
				_player_pool_last[pool] = float(damage.get(pool))
		if not damage.pool_changed.is_connected(_on_player_pool_changed):
			damage.pool_changed.connect(_on_player_pool_changed)
	if damage and damage.has_signal("repaired") \
			and not damage.repaired.is_connected(_on_player_repaired):
		damage.repaired.connect(_on_player_repaired)


func _on_player_arc_lock_changed(_side: String, locked: bool) -> void:
	if locked:
		_fire_trigger(LessonData.Trigger.FIRST_ENEMY_IN_RANGE)


func _on_player_pool_changed(pool: String, current: float, _maximum: float) -> void:
	var previous: float = _player_pool_last.get(pool, current)
	_player_pool_last[pool] = current
	if current < previous:
		_fire_trigger(LessonData.Trigger.FIRST_DAMAGE_TAKEN)


func _seed_heat_level() -> void:
	if EmpireManager and EmpireManager.has_method("get_heat_level"):
		_last_heat_level = EmpireManager.get_heat_level()


func _on_heat_tier_changed(tier: HeatTierData) -> void:
	var level: int = tier.tier if tier else 0
	var previous := _last_heat_level
	_last_heat_level = level
	if level > previous:
		_fire_trigger(LessonData.Trigger.HEAT_TIER_UP)
	elif level < previous:
		# LOWER_HEAT — any downward crossing while the chapter is current,
		# whether by free decay or the optional Eights clear.
		_for_each_matching(ObjectiveData.Condition.LOWER_HEAT, "", func(o): _advance_objective(o, 1))


func _on_job_started(job: Dictionary) -> void:
	_fire_trigger(LessonData.Trigger.FIRST_JOB_STARTED, str(job.get("kind", "")))


# === Rewards ===

func _grant_rewards(chapter: ChapterData) -> void:
	if chapter.reward_gold > 0 and ResourceManager:
		ResourceManager.add_resource("gold", chapter.reward_gold)
	if chapter.reward_eights > 0 and ResourceManager and not _chapter_eights_paid.has(chapter.chapter_id):
		ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, chapter.reward_eights)
		_chapter_eights_paid[chapter.chapter_id] = true
		_write_eights_ledger()
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
	return ResourceLookup.find_by_id(dir_path, id_field, id_value)


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


func has_paid_chapter_eights(chapter_id: String) -> bool:
	return _chapter_eights_paid.has(chapter_id)


func _load_eights_ledger() -> void:
	_chapter_eights_paid.clear()
	if not FileAccess.file_exists(eights_ledger_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(eights_ledger_path))
	if not (parsed is Dictionary) or not (parsed.get("chapters_paid") is Array):
		push_error("CampaignManager: %s is unreadable; chapter Eights ledger starts empty." % eights_ledger_path)
		return
	for id in parsed["chapters_paid"]:
		_chapter_eights_paid[str(id)] = true


func _write_eights_ledger() -> void:
	var file := FileAccess.open(eights_ledger_path, FileAccess.WRITE)
	if not file:
		push_error("CampaignManager: failed to write %s." % eights_ledger_path)
		return
	file.store_string(JSON.stringify({"chapters_paid": _chapter_eights_paid.keys()}, "\t"))
	file.close()
