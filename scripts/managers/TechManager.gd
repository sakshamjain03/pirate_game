extends Node

## Purpose: Tracks unlocked technologies and provides their global modifiers.

signal tech_unlocked(tech: Resource)
signal tech_recalculated()

var unlocked_techs: Array[Resource] = []

## M27 — the ScheduleManager job target for research (empire-wide, not an island).
const RESEARCH_TARGET := "tech"

# Cached global modifiers
var global_health_mod: float = 1.0
var global_damage_mod: float = 1.0
var global_speed_mod: float = 1.0
var global_storage_mod: float = 1.0

func _ready() -> void:
	ScheduleManager.job_completed.connect(_on_job_completed)

func is_unlocked(tech_id: String) -> bool:
	for t in unlocked_techs:
		if t.tech_id == tech_id:
			return true
	return false

## M11 — whether `tech` can be researched given the player's current home island
## tier. Mirrors BuildingData's tier-gate pattern plus a prerequisite chain.
## Does not check affordability — that's ResourceManager's concern, checked
## separately by the caller.
func can_research(tech: TechData, island_tier: int) -> bool:
	if is_unlocked(tech.tech_id):
		return false
	if tech.required_island_tier > island_tier:
		return false
	if not tech.required_prerequisite_tech_id.is_empty() and not is_unlocked(tech.required_prerequisite_tech_id):
		return false
	return true

## M27 — research takes time: pays now (ResourceManager.pay(), which can cover a
## shortfall with Eights), and unlock_tech() runs when the ScheduleManager job
## completes. One research job at a time, empire-wide (Requirement 2.7). Does not
## check can_research() — the caller already gates on island tier.
func start_research(tech: TechData, cost: Dictionary, allow_cover: bool = false) -> bool:
	if is_unlocked(tech.tech_id) or is_researching():
		return false
	if not ResourceManager.pay(cost, allow_cover):
		return false
	var duration := get_research_seconds(tech)
	if duration <= 0.0:
		unlock_tech(tech)
	else:
		ScheduleManager.start_job("research", RESEARCH_TARGET, tech.resource_path, duration)
	return true

## Effective research time at the highest Academy level the player owns.
func get_research_seconds(tech: TechData) -> float:
	return ScheduleManager.pricing.effective_duration("research", tech.research_seconds, get_academy_level())

## Research is empire-wide, so its speed source is the best Academy on any owned
## island (design.md §4). 0 = no Academy.
func get_academy_level() -> int:
	var best := 0
	for island in get_tree().get_nodes_in_group("islands"):
		if island.island_data and island.island_data.is_owned_by_player() and island.has_method("get_building_level"):
			best = maxi(best, island.get_building_level("academy"))
	return best

## The running research job, or {}.
func get_research_job() -> Dictionary:
	var jobs := ScheduleManager.get_jobs_of_kind("research")
	return jobs[0] if not jobs.is_empty() else {}

func is_researching() -> bool:
	return not get_research_job().is_empty()

func _on_job_completed(job: Dictionary) -> void:
	if job["kind"] != "research":
		return
	var path: String = job["payload"]
	var tech: TechData = null
	if ResourceLoader.exists(path):
		tech = load(path) as TechData
	if not tech:
		push_error("TechManager: research job completed for unresolvable tech '%s'." % path)
		return
	unlock_tech(tech)

func unlock_tech(tech: Resource) -> void:
	if not is_unlocked(tech.tech_id):
		unlocked_techs.append(tech)
		_recalculate_modifiers()
		tech_unlocked.emit(tech)

func _recalculate_modifiers() -> void:
	global_health_mod = 1.0
	global_damage_mod = 1.0
	global_speed_mod = 1.0
	global_storage_mod = 1.0
	
	for t in unlocked_techs:
		global_health_mod *= t.health_modifier
		global_damage_mod *= t.damage_modifier
		global_speed_mod *= t.speed_modifier
		global_storage_mod *= t.storage_modifier
		
	tech_recalculated.emit()

func get_save_data() -> Dictionary:
	var paths = []
	for t in unlocked_techs:
		paths.append(t.resource_path)
	return {"unlocked": paths}

func load_save_data(data: Dictionary) -> void:
	unlocked_techs.clear()
	if data.has("unlocked"):
		for p in data["unlocked"]:
			var tech = load(p) if ResourceLoader.exists(p) else null
			if tech is TechData:
				unlocked_techs.append(tech)
			else:
				# CLAUDE.md fragile area: an unresolvable id must be loud, never a
				# silent skip — dropping it here quietly un-researches the tech on
				# the next save.
				push_error("TechManager: saved tech '%s' could not be resolved; dropped from unlocked techs." % p)
	_recalculate_modifiers()
