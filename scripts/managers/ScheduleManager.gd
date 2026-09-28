extends Node

## Purpose: the one clock for every timed empire-layer action (M27) — building
##   construction and upgrades, research, ship construction and shipyard repair.
## Responsibilities: owns every running job, wall-clock remaining time, "Finish now"
##   pricing, persistence (the optional "schedule" save section) and exactly-once
##   completion. It never knows what a job *produces*: owners (Island, TechManager,
##   FleetManager, IslandMenu) listen to `job_completed`, filter on `kind`/`target`,
##   and apply the result themselves.
## Dependencies: ResourceManager (Eights spend), SaveManager.game_loaded (arming),
##   SceneManager.is_campaign().
##
## AGENTS.md: only the empire layer may be time-gated. No job kind here may ever gate
## sailing, combat, boarding, encounters or the Maelstrom.
##
## Completion only runs while a campaign World scene is loaded, and only after its
## save has finished loading. That keeps one order of events: every owner (Island
## nodes, IslandMenu's relay, CampaignManager's objective wiring) exists before a
## job can complete. Arming is deferred from `game_loaded` because World.gd queues
## `CampaignManager.on_world_ready` *after* `load_game` — a synchronous completion on
## `game_loaded` would advance a building before the campaign was listening for it.

signal job_started(job: Dictionary)
signal job_completed(job: Dictionary)

const KINDS: Array[String] = ["build", "upgrade", "research", "ship", "repair"]

## How many completed ids the idempotency record keeps across saves.
const COMPLETED_ID_HISTORY := 200

## preload rather than the bare class name — headless GUT runs don't always have a
## freshly rebuilt global-script-class cache (same note as SaveManager).
const EconomyPricingScript := preload("res://scripts/world/EconomyPricingData.gd")
const PRICING_PATH := "res://resources/balance/EconomyPricing.tres"

## Loaded in _ready(), like EmpireManager's heat curve: preloading the .tres in a
## member initializer instantiates it while this autoload is still compiling, which
## yields a placeholder instance with the data but none of the methods.
var pricing: EconomyPricingScript

## Added to the wall clock. DevConsole and tests only — never set by gameplay code.
var now_offset: float = 0.0

## job id -> job, in start order (Dictionary preserves insertion order).
## job = {id, kind, target, payload, start_unix, duration}
##   target  — who owns the result: island_id for build/upgrade/repair, "tech", "fleet"
##   payload — what it produces: building_id, tech/ship resource path, "" for repair
var _jobs: Dictionary = {}
## id -> true. The idempotency record: an id in here never completes again.
var _completed_ids: Dictionary = {}
var _completion_armed: bool = false
var _id_counter: int = 0


func _ready() -> void:
	# Wall-clock jobs keep finishing while IslandMenu (or any modal) pauses the tree
	# — otherwise a job row would sit at 0:00 until the player closed the menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pricing = load(PRICING_PATH) as EconomyPricingScript
	if not pricing:
		push_error("ScheduleManager: could not load %s; timers fall back to defaults." % PRICING_PATH)
		pricing = EconomyPricingScript.new()
	SaveManager.game_loaded.connect(_on_game_loaded)


func _process(_delta: float) -> void:
	if _completion_armed and not _jobs.is_empty() and _is_campaign_world_loaded():
		process_due_jobs()


func now() -> float:
	return Time.get_unix_time_from_system() + now_offset


## Starts a job and returns its id ("" if refused). A duration of 0 or less
## completes immediately.
func start_job(kind: String, target: String, payload: String, duration: float) -> String:
	if not kind in KINDS:
		push_error("ScheduleManager: unknown job kind '%s'." % kind)
		return ""
	var start := now()
	_id_counter += 1
	var id := "%s:%s:%d:%d" % [kind, payload, int(start * 1000.0), _id_counter]
	var job := {
		"id": id,
		"kind": kind,
		"target": target,
		"payload": payload,
		"start_unix": start,
		"duration": maxf(duration, 0.0),
	}
	_jobs[id] = job
	job_started.emit(job.duplicate())
	if job["duration"] <= 0.0:
		_complete(job)
	return id


func has_job(id: String) -> bool:
	return _jobs.has(id)


## A copy of the job, or {} if it isn't running.
func get_job(id: String) -> Dictionary:
	return _jobs[id].duplicate() if _jobs.has(id) else {}


## Every running job owned by `target`, in start order.
func get_jobs_for(target: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in _jobs.values():
		if job["target"] == target:
			result.append(job.duplicate())
	return result


## Every running job of `kind`, in start order.
func get_jobs_of_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in _jobs.values():
		if job["kind"] == kind:
			result.append(job.duplicate())
	return result


func get_all_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in _jobs.values():
		result.append(job.duplicate())
	return result


## Seconds left on a running job, 0 once due (or if it isn't running).
func remaining(id: String) -> float:
	if not _jobs.has(id):
		return 0.0
	var job: Dictionary = _jobs[id]
	return maxf(0.0, job["start_unix"] + job["duration"] - now())


## 0..1, for progress bars.
func progress(id: String) -> float:
	if not _jobs.has(id):
		return 1.0
	var duration: float = _jobs[id]["duration"]
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - remaining(id) / duration, 0.0, 1.0)


## Eights to finish a job now. Priced off remaining time only, never total.
func finish_cost_eights(id: String) -> int:
	if not _jobs.has(id):
		return 0
	return pricing.finish_cost(remaining(id))


## Spends Eights to complete a running job immediately. Refuses, spending nothing,
## when the job isn't running or the Eights aren't there. A job that is already due
## completes for free rather than charging for time that has passed.
func finish_now(id: String) -> bool:
	if not _jobs.has(id):
		return false
	var cost := finish_cost_eights(id)
	if cost > 0 and not ResourceManager.spend_resources({ResourceManager.PREMIUM_CURRENCY: cost}):
		return false
	_complete(_jobs[id])
	return true


## Completes every due job, in start order. The single completion pass — _process
## calls it while a campaign World is loaded; tests and DevConsole call it directly.
## Returns how many jobs completed.
func process_due_jobs() -> int:
	var due: Array[Dictionary] = []
	for job in _jobs.values():
		if remaining(job["id"]) <= 0.0:
			due.append(job)
	for job in due:
		_complete(job)
	return due.size()


## Clears every job and disarms completion. SaveManager.load_game() calls this first,
## so an omitted "schedule" section (no jobs) never leaves a previous session's jobs
## alive in this autoload.
func reset() -> void:
	_jobs.clear()
	_completed_ids.clear()
	_completion_armed = false


## {} when no job is running, so SaveManager omits the section entirely (an optional
## section is never written empty).
func get_save_data() -> Dictionary:
	if _jobs.is_empty():
		return {}
	var jobs: Array = []
	for job in _jobs.values():
		jobs.append(job.duplicate())
	var ids: Array = _completed_ids.keys()
	if ids.size() > COMPLETED_ID_HISTORY:
		ids = ids.slice(ids.size() - COMPLETED_ID_HISTORY)
	return {"jobs": jobs, "completed_ids": ids}


func load_save_data(data: Dictionary) -> void:
	_jobs.clear()
	_completed_ids.clear()
	for id in data.get("completed_ids", []):
		_completed_ids[str(id)] = true
	var jobs: Array = data.get("jobs", []) if data.get("jobs") is Array else []
	# Rebuild in start order so completion order survives the round-trip.
	var sorted := jobs.filter(func(j): return j is Dictionary)
	sorted.sort_custom(func(a, b): return float(a.get("start_unix", 0.0)) < float(b.get("start_unix", 0.0)))
	for raw in sorted:
		var id := str(raw.get("id", ""))
		var kind := str(raw.get("kind", ""))
		if id.is_empty() or not kind in KINDS:
			push_error("ScheduleManager: dropping unreadable saved job %s." % str(raw))
			continue
		if _completed_ids.has(id):
			continue
		_jobs[id] = {
			"id": id,
			"kind": kind,
			"target": str(raw.get("target", "")),
			"payload": str(raw.get("payload", "")),
			"start_unix": float(raw.get("start_unix", 0.0)),
			"duration": maxf(float(raw.get("duration", 0.0)), 0.0),
		}


func _complete(job: Dictionary) -> void:
	var id: String = job["id"]
	_jobs.erase(id)
	if _completed_ids.has(id):
		return
	_completed_ids[id] = true
	job_completed.emit(job.duplicate())


func _on_game_loaded() -> void:
	_arm_completion.call_deferred()


func _arm_completion() -> void:
	_completion_armed = true
	if _is_campaign_world_loaded():
		process_due_jobs()


func _is_campaign_world_loaded() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "World" and SceneManager.is_campaign()
