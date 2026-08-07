extends Node

## Purpose: First-time-player onboarding tutorial (light, gated, 8-step sequence).
## Responsibilities: Owns the step list, advances on real gameplay signals (not
##                   polling), tracks which UI tabs are unlocked, persists
##                   in-progress step index via SaveManager and the one-time
##                   completion flag in its own file (see note on COMPLETION_PATH).
## Dependencies: WorldManager, ShipController, EnemySpawner, FleetManager,
##               EmpireManager, IslandMenu (via "island_menu" group)

signal step_changed(step: Dictionary)
signal step_condition_met()
signal tutorial_finished()

const COMPLETION_PATH := "user://tutorial_state.json"

var steps: Array[Dictionary] = [
	{
		"id": "welcome",
		"mentor": "Quartermaster Higgins",
		"text": "Ahoy, Captain! Name's Higgins — I'll show you the ropes before you sail off to your doom. Ready?",
	},
	{
		"id": "sail",
		"mentor": "Quartermaster Higgins",
		"text": "First things first: get a feel for her. Sail with WASD until she's making way.",
		"wait_for": "speed",
		"min_value": 5.0,
	},
	{
		"id": "dock",
		"mentor": "Quartermaster Higgins",
		"text": "Good. Now steer alongside an island and press F to come alongside and dock.",
		"wait_for": "player_docked",
	},
	{
		"id": "build",
		"mentor": "Quartermaster Higgins",
		"text": "Every empire starts with a roof over its head. Open Buildings and put something up.",
		"wait_for": "structure_changed",
	},
	{
		"id": "recruit",
		"mentor": "Quartermaster Higgins",
		"text": "A ship's nothing without a crew. Build a Tavern if you haven't, then hire yourself a captain.",
		"wait_for": "captain_recruited",
		"unlocks": ["tab_fleet"],
	},
	{
		"id": "combat",
		"mentor": "Quartermaster Higgins",
		"text": "Sail's on the horizon — and she's not friendly. Ready your cannons, Captain!",
		"wait_for": "enemy_destroyed",
		"on_enter": "spawn_hunter",
		"unlocks": ["tab_research"],
	},
	{
		"id": "capture",
		"mentor": "Quartermaster Higgins",
		"text": "Time to make your mark. Claim an island for your empire.",
		"wait_for": "island_captured",
		"unlocks": ["tab_trade"],
	},
	{
		"id": "outro",
		"mentor": "Quartermaster Higgins",
		"text": "You've got the makings of a legend, Captain. The horizon's yours now. Fair winds!",
	},
]

var current_step_index: int = -1
var tutorial_active: bool = false
var tutorial_completed: bool = false

var _unlocked_ui: Array[String] = []
var _ready_to_advance: bool = false

const _ALL_UNLOCK_IDS := ["tab_fleet", "tab_research", "tab_trade"]

func _ready() -> void:
	_load_completion_flag()

# --- Session lifecycle ---

func start_new_game_session() -> void:
	if tutorial_completed:
		tutorial_active = false
		current_step_index = -1
		return
	tutorial_active = true
	current_step_index = 0
	_unlocked_ui.clear()
	_ready_to_advance = false

func reset_and_replay() -> void:
	tutorial_completed = false
	tutorial_active = true
	current_step_index = 0
	_unlocked_ui.clear()
	_ready_to_advance = false
	_save_completion_flag()

func on_world_ready(world_manager: Node) -> void:
	if not tutorial_active:
		return
	_connect_step_signals(world_manager)
	_emit_current_step()

func _connect_step_signals(world_manager: Node) -> void:
	if world_manager and world_manager.has_signal("player_docked"):
		if not world_manager.player_docked.is_connected(_on_player_docked):
			world_manager.player_docked.connect(_on_player_docked)

	var ship: Node = world_manager.get("player_ship") if world_manager else null
	if ship and ship.has_signal("ship_speed_changed"):
		if not ship.ship_speed_changed.is_connected(_on_ship_speed_changed):
			ship.ship_speed_changed.connect(_on_ship_speed_changed)

	var spawner := _get_enemy_spawner()
	if spawner and spawner.has_signal("enemy_destroyed"):
		if not spawner.enemy_destroyed.is_connected(_on_enemy_destroyed):
			spawner.enemy_destroyed.connect(_on_enemy_destroyed)

	var island_menu := get_tree().get_first_node_in_group("island_menu")
	if island_menu and island_menu.has_signal("structure_changed"):
		if not island_menu.structure_changed.is_connected(_on_structure_changed):
			island_menu.structure_changed.connect(_on_structure_changed)

	if FleetManager.has_signal("captain_recruited"):
		if not FleetManager.captain_recruited.is_connected(_on_captain_recruited):
			FleetManager.captain_recruited.connect(_on_captain_recruited)

	if EmpireManager.has_signal("island_captured"):
		if not EmpireManager.island_captured.is_connected(_on_island_captured):
			EmpireManager.island_captured.connect(_on_island_captured)

# --- Step progression ---

func get_current_step() -> Dictionary:
	if current_step_index < 0 or current_step_index >= steps.size():
		return {}
	return steps[current_step_index]

func advance_step() -> void:
	var step := get_current_step()
	if step.is_empty():
		return
	if step.has("wait_for") and not _ready_to_advance:
		return

	for unlock_id in step.get("unlocks", []):
		if not _unlocked_ui.has(unlock_id):
			_unlocked_ui.append(unlock_id)

	current_step_index += 1
	_ready_to_advance = false

	if current_step_index >= steps.size():
		_complete_tutorial()
		return

	_emit_current_step()

func skip_tutorial() -> void:
	tutorial_active = false
	tutorial_completed = true
	current_step_index = -1
	for unlock_id in _ALL_UNLOCK_IDS:
		if not _unlocked_ui.has(unlock_id):
			_unlocked_ui.append(unlock_id)
	_save_completion_flag()
	tutorial_finished.emit()

func is_ui_unlocked(id: String) -> bool:
	return not tutorial_active or _unlocked_ui.has(id)

func _emit_current_step() -> void:
	var step := get_current_step()
	if step.is_empty():
		return
	_ready_to_advance = not step.has("wait_for")
	if step.get("on_enter", "") == "spawn_hunter":
		_spawn_tutorial_hunter()
	step_changed.emit(step)

func _complete_tutorial() -> void:
	tutorial_active = false
	tutorial_completed = true
	current_step_index = -1
	_save_completion_flag()
	tutorial_finished.emit()

func _spawn_tutorial_hunter() -> void:
	var spawner := _get_enemy_spawner()
	if spawner and spawner.has_method("spawn_hunter"):
		var faction := load("res://resources/factions/PirateClans.tres")
		if faction:
			spawner.spawn_hunter(faction)

func _get_enemy_spawner() -> Node:
	var scene := get_tree().current_scene
	if not scene:
		return null
	return scene.get_node_or_null("Systems/EnemySpawner")

# --- Condition handlers (generic dispatch — one handler per condition type) ---

func _check_condition(condition_name: String, value = null) -> void:
	if not tutorial_active:
		return
	var step := get_current_step()
	if step.get("wait_for", "") != condition_name:
		return
	if step.has("min_value") and typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		if value < step["min_value"]:
			return
	_ready_to_advance = true
	step_condition_met.emit()

func _on_ship_speed_changed(speed: float) -> void:
	_check_condition("speed", speed)

func _on_player_docked(island_id: String) -> void:
	_check_condition("player_docked", island_id)

func _on_structure_changed(_building_id: String, _is_upgrade: bool) -> void:
	_check_condition("structure_changed")

func _on_captain_recruited(_captain: CaptainData) -> void:
	_check_condition("captain_recruited")

func _on_enemy_destroyed(_enemy: Node3D) -> void:
	_check_condition("enemy_destroyed")

func _on_island_captured(_island_id: String) -> void:
	_check_condition("island_captured")

# --- Persistence ---
# tutorial_completed is intentionally NOT part of save_data.json: MainMenu's
# New Game flow unconditionally calls SaveManager.delete_save(), which would
# wipe a returning player's completion flag and wrongly replay the tutorial.

func get_save_data() -> Dictionary:
	return {
		"current_step_index": current_step_index,
		"tutorial_active": tutorial_active,
		"unlocked_ui": _unlocked_ui.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	current_step_index = int(data.get("current_step_index", -1))
	tutorial_active = bool(data.get("tutorial_active", false))
	var unlocked = data.get("unlocked_ui", [])
	_unlocked_ui = []
	for id in unlocked:
		_unlocked_ui.append(str(id))
	_ready_to_advance = false

func _load_completion_flag() -> void:
	if not FileAccess.file_exists(COMPLETION_PATH):
		return
	var file := FileAccess.open(COMPLETION_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error == OK and typeof(json.data) == TYPE_DICTIONARY:
		tutorial_completed = bool(json.data.get("completed", false))

func _save_completion_flag() -> void:
	var file := FileAccess.open(COMPLETION_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"completed": tutorial_completed}))
		file.close()
