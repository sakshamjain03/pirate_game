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
## §3: 1.8 ("Sign your first captain") -> Fleet, 1.6 ("Sink whatever comes
## sniffing") -> Research. (M28 Requirement 2.5: this used to read 1.7/1.5,
## which are the tavern and the warehouse — building either unlocked a tab
## meant for recruiting/fighting.) The old "capture" step's tab_trade unlock
## has no direct successor objective (M7 Task 6 grants Port Royal up front
## instead), so it unlocks on chapter completion rather than a specific objective.
const _UNLOCK_ON_OBJECTIVE := {
	"1.8": "tab_fleet",
	"1.6": "tab_research",
}
const _UNLOCK_ON_CHAPTER_COMPLETE := {
	"ch1_the_drowned_port": "tab_trade",
}
const _ALL_UNLOCK_IDS := ["tab_fleet", "tab_research", "tab_trade"]
const _ONBOARDING_CHAPTER_ID := "ch1_the_drowned_port"

var tutorial_active: bool = false
var tutorial_completed: bool = false

var _unlocked_ui: Array[String] = []

## M28 — lessons (`LessonData`, fired by CampaignManager). On by default; New
## Game's "I know these waters" turns them off without touching story or
## objectives, and Settings' "Replay lessons" turns them back on.
var lessons_enabled: bool = true
var _seen_lessons: Array[String] = []
## Set by replay_lessons(). Settings -> Replay -> Continue runs load_save_data()
## straight afterwards, which would otherwise restore the pre-replay seen set
## and flag; cleared once that load (or a no-save boot) has finished.
var _replay_pending: bool = false
## M28 — chapters whose opening beats TutorialDialogue actually rendered.
## CampaignManager can start a chapter while no dialogue exists (Chapter 1
## starts at autoload boot, on the menu), so "the chapter started" is not proof
## the player ever saw its opening — this is.
var _shown_opening_ids: Array[String] = []
## True after loading a pre-M28 save (no "shown_openings" key) — see
## _effective_shown_openings().
var _openings_legacy: bool = false


func _ready() -> void:
	_load_completion_flag()
	if CampaignManager:
		CampaignManager.objective_completed.connect(_on_objective_completed)
		CampaignManager.chapter_completed.connect(_on_chapter_completed)
	if SaveManager and SaveManager.has_signal("game_loaded"):
		# A bound method, not a lambda: tests free fresh instances of this
		# script, and a lambda left on an autoload signal outlives its capture.
		SaveManager.game_loaded.connect(_on_game_loaded)


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


# --- Lessons (M28) ---

## New Game's lessons choice. A new game starts with nothing seen and every
## opening beat unshown, whichever way the player answered.
func start_new_game_lessons(enabled: bool) -> void:
	lessons_enabled = enabled
	_seen_lessons.clear()
	_shown_opening_ids.clear()
	_openings_legacy = false
	_replay_pending = false


func mark_seen(lesson_id: String) -> void:
	if lesson_id.is_empty():
		push_error("TutorialManager.mark_seen: empty lesson_id")
		return
	if not _seen_lessons.has(lesson_id):
		_seen_lessons.append(lesson_id)


func has_seen(lesson_id: String) -> bool:
	return _seen_lessons.has(lesson_id)


## Settings' "Replay lessons": clears the seen set and turns lessons on. The
## current chapter's lessons fire again as their triggers recur.
func replay_lessons() -> void:
	_seen_lessons.clear()
	lessons_enabled = true
	_replay_pending = true


func _on_game_loaded() -> void:
	_replay_pending = false


func mark_opening_shown(chapter_id: String) -> void:
	if not chapter_id.is_empty() and not _shown_opening_ids.has(chapter_id):
		_shown_opening_ids.append(chapter_id)


func has_shown_opening(chapter_id: String) -> bool:
	return _effective_shown_openings().has(chapter_id)


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
		"lessons_enabled": lessons_enabled,
		"seen_lessons": _seen_lessons.duplicate(),
		"shown_openings": _effective_shown_openings(),
	}


func load_save_data(data: Dictionary) -> void:
	tutorial_active = bool(data.get("tutorial_active", false))
	var unlocked = data.get("unlocked_ui", [])
	_unlocked_ui = []
	for id in unlocked:
		_unlocked_ui.append(str(id))

	# M28 — a pre-M28 save has none of these keys: lessons on, nothing seen.
	lessons_enabled = bool(data.get("lessons_enabled", true))
	_seen_lessons = []
	for id in data.get("seen_lessons", []):
		var lesson_id := str(id)
		# Never dropped — a lesson removed from content just never fires again —
		# but never skipped silently either (CLAUDE.md resolver rule).
		if CampaignManager and CampaignManager.has_method("has_lesson") \
				and not CampaignManager.has_lesson(lesson_id):
			push_error("TutorialManager: saved lesson id '%s' matches no authored lesson" % lesson_id)
		_seen_lessons.append(lesson_id)
	_shown_opening_ids = []
	for id in data.get("shown_openings", []):
		_shown_opening_ids.append(str(id))
	_openings_legacy = not data.has("shown_openings")
	if _replay_pending:
		_seen_lessons.clear()
		lessons_enabled = true
		_replay_pending = false


## A pre-M28 save predates opening tracking, but any chapter it already
## completed or was part-way through had long since started in a real World
## session. Those count as shown so Continue never replays an opening the
## player already sat through. Resolved lazily, not in load_save_data():
## SaveManager loads this section BEFORE "campaign", so CampaignManager still
## holds the previous state at that point.
func _effective_shown_openings() -> Array[String]:
	var ids: Array[String] = _shown_opening_ids.duplicate()
	if not _openings_legacy or not CampaignManager:
		return ids
	for id in CampaignManager.completed_chapter_ids:
		if not ids.has(id):
			ids.append(id)
	var current: String = CampaignManager._current_chapter_id_or_empty()
	if not current.is_empty() and not ids.has(current):
		ids.append(current)
	return ids


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
