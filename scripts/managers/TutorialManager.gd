extends Node

## Purpose: UI-tab unlock tracking (M7). A thin wrapper over `CampaignManager`.
## Its old job — driving onboarding through 8 hardcoded steps/dialogue lines —
## is retired: Chapter 1's own opening/closing beats
## (`docs/13_CAMPAIGN_LEVELS_1-5.md` §3) cover exactly that narrative role, and
## `TutorialDialogue.tscn` now renders `CampaignManager`'s chapter events
## directly instead of this manager's steps.
## Responsibilities: track which UI tabs have unlocked as specific Chapter 1
## objectives complete, and the one-time completion flag
## (`user://tutorial_state.json`) that must survive a "New Game" reset without
## replaying for a returning player.
## Dependencies: CampaignManager.

signal tutorial_finished()

const COMPLETION_PATH := "user://tutorial_state.json"

## objective_id -> unlock_id. Maps Chapter 1's real objectives onto the tabs
## the old hardcoded step list used to gate — `docs/13_CAMPAIGN_LEVELS_1-5.md`
## §3's own mapping: 1.7 (recruit) -> Fleet, 1.5 (combat) -> Research. The old
## "capture" step's tab_trade unlock has no direct successor objective (M7
## Task 6 grants Port Royal up front instead), so it unlocks on chapter
## completion rather than a specific objective.
const _UNLOCK_ON_OBJECTIVE := {
	"1.7": "tab_fleet",
	"1.5": "tab_research",
}
const _UNLOCK_ON_CHAPTER_COMPLETE := {
	"ch1_the_drowned_port": "tab_trade",
}
const _ALL_UNLOCK_IDS := ["tab_fleet", "tab_research", "tab_trade"]
const _ONBOARDING_CHAPTER_ID := "ch1_the_drowned_port"

var tutorial_active: bool = false
var tutorial_completed: bool = false

var _unlocked_ui: Array[String] = []


func _ready() -> void:
	_load_completion_flag()
	if CampaignManager:
		CampaignManager.objective_completed.connect(_on_objective_completed)
		CampaignManager.chapter_completed.connect(_on_chapter_completed)


# --- Session lifecycle ---

func start_new_game_session() -> void:
	if tutorial_completed:
		tutorial_active = false
		return
	tutorial_active = true
	_unlocked_ui.clear()


func reset_and_replay() -> void:
	tutorial_completed = false
	tutorial_active = true
	_unlocked_ui.clear()
	_save_completion_flag()


func skip_tutorial() -> void:
	tutorial_active = false
	tutorial_completed = true
	for id in _ALL_UNLOCK_IDS:
		if not _unlocked_ui.has(id):
			_unlocked_ui.append(id)
	_save_completion_flag()
	tutorial_finished.emit()


func is_ui_unlocked(id: String) -> bool:
	return not tutorial_active or _unlocked_ui.has(id)


# --- Driven by CampaignManager ---

func _on_objective_completed(objective_id: String) -> void:
	if _UNLOCK_ON_OBJECTIVE.has(objective_id):
		_unlock(_UNLOCK_ON_OBJECTIVE[objective_id])


func _on_chapter_completed(chapter: ChapterData) -> void:
	if _UNLOCK_ON_CHAPTER_COMPLETE.has(chapter.chapter_id):
		_unlock(_UNLOCK_ON_CHAPTER_COMPLETE[chapter.chapter_id])
	if chapter.chapter_id == _ONBOARDING_CHAPTER_ID and tutorial_active:
		tutorial_active = false
		tutorial_completed = true
		_save_completion_flag()
		tutorial_finished.emit()


func _unlock(id: String) -> void:
	if not _unlocked_ui.has(id):
		_unlocked_ui.append(id)


# --- Persistence ---
# tutorial_completed is intentionally NOT part of save_data.json: MainMenu's
# New Game flow unconditionally calls SaveManager.delete_save(), which would
# wipe a returning player's completion flag and wrongly replay onboarding.

func get_save_data() -> Dictionary:
	return {
		"tutorial_active": tutorial_active,
		"unlocked_ui": _unlocked_ui.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	tutorial_active = bool(data.get("tutorial_active", false))
	var unlocked = data.get("unlocked_ui", [])
	_unlocked_ui = []
	for id in unlocked:
		_unlocked_ui.append(str(id))


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
