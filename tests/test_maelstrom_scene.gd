extends GutTest

## Guards M26 Task 9: the Maelstrom scene is isolated by construction
## (Requirements 2.3, 2.4) and wired end to end (1.1, 1.2, 5.2, 6.1).

const SCENE_PATH := "res://scenes/modes/Maelstrom.tscn"
const MAIN_MENU := preload("res://scenes/ui/MainMenu.tscn")
const USER_FILES := ["user://save_data.json", "user://save_data.json.bak", "user://maelstrom_pending.json"]

var _root: Node = null
var _saved_current_scene: Node
var _file_backup := {}


func before_each() -> void:
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
	_saved_current_scene = get_tree().current_scene


func after_each() -> void:
	get_tree().paused = false
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	if is_instance_valid(_root):
		if get_tree().current_scene == _root:
			get_tree().current_scene = _saved_current_scene
		_root.free()
	_root = null
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


var _placeholder: Node = null


func _enter_scene() -> Node:
	# A real scene change makes the scene current before its _ready() runs;
	# EnvironmentController._ready() relies on that, so stand in a placeholder.
	_placeholder = Node.new()
	get_tree().root.add_child(_placeholder)
	get_tree().current_scene = _placeholder
	_root = load(SCENE_PATH).instantiate()
	get_tree().root.add_child(_root)
	get_tree().current_scene = _root
	_placeholder.free()
	return _root


func test_scene_is_isolated_by_construction() -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	assert_ne(scene.name, "World", "Req 2.4: SaveManager autosaves only a scene named World")
	assert_null(scene.get_node_or_null("Systems/EnemySpawner"), "Req 2.3: CampaignManager hooks Systems/EnemySpawner")
	assert_null(scene.get_node_or_null("Systems/EncounterManager"), "Req 2.3")
	assert_null(scene.get_node_or_null("Systems"), "no Systems/ node at all")
	assert_null(scene.find_child("WorldUI", true, false), "no campaign-wired WorldHUD")
	assert_true(scene.get_node_or_null("Run/EnemySpawner") is EnemySpawner)
	assert_true(scene.get_node_or_null("Run") is MaelstromRun)
	var islands := scene.find_children("*", "", true, false).filter(
		func(n): return n.scene_file_path.ends_with("Island.tscn"))
	assert_eq(islands.size(), 0, "open water, no islands")
	scene.free()


func test_entering_the_scene_starts_a_run() -> void:
	_enter_scene()
	var run: MaelstromRun = _root.get_node("Run")
	assert_eq(SceneManager.game_mode, SceneManager.GameMode.MAELSTROM)
	assert_eq(run.state, MaelstromRun.State.RUNNING)
	assert_true(run.get_node("EnemySpawner").spawn_profile_override.is_valid())
	var screen = _root.get_node("UI/UpgradeChoiceScreen")
	assert_eq(screen._encounter_manager, run, "UpgradeChoiceScreen bound to the run")
	var wall: MeshInstance3D = _root.get_node("StormWall")
	assert_almost_eq((wall.mesh as CylinderMesh).top_radius, run.curve.arena_radius, 0.01,
		"the wall you see is where the push starts")


func test_level_up_shows_the_choice_screen_paused() -> void:
	_enter_scene()
	var run: MaelstromRun = _root.get_node("Run")
	var screen: Control = _root.get_node("UI/UpgradeChoiceScreen")
	run.add_plunder(run.curve.xp_for_level(1))
	run._maybe_offer()
	assert_true(screen.visible, "Req 5.2: choice screen shown")
	assert_true(get_tree().paused, "with the tree paused")
	assert_string_contains(screen._subtitle.text, "Level", "open-ended run: no 'offer N of 0'")


func test_death_shows_results() -> void:
	_enter_scene()
	var run: MaelstromRun = _root.get_node("Run")
	var results: MaelstromResults = _root.get_node("UI/MaelstromResults")
	run.elapsed = 305.0
	run._end_run()
	assert_true(results.visible, "Req 6.1: results panel")
	var rows := "\n".join(results.get_row_texts())
	assert_string_contains(rows, "5:05", "time survived")
	assert_string_contains(rows, "+%d" % run.curve.eights_for(305.0), "Eights earned")
	assert_eq(results.get_row_texts().size(), 5, "time, kills, level, best, Eights")
	assert_not_null(results.find_child("RetryButton", true, false))
	assert_not_null(results.find_child("MenuButton", true, false))


func test_main_menu_offers_the_maelstrom_and_resets_mode() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	var menu: Node = MAIN_MENU.instantiate()
	add_child_autofree(menu)
	var btn: Button = menu.get_node("Control/MainVBox/ButtonPanel/VBoxContainer/MaelstromButton")
	assert_true(btn.visible, "Req 1.1: always offered, save or no save")
	assert_ne(btn.theme_type_variation, &"PrimaryButton", "a secondary, never the menu's one Primary")
	assert_eq(SceneManager.game_mode, SceneManager.GameMode.CAMPAIGN, "the menu means no run is active")
	assert_true(btn.pressed.is_connected(menu._on_maelstrom_pressed))
