class_name ObjectiveDispatch

## Purpose: the condition-match + progress-arithmetic logic shared between
## `CampaignManager` (permanent chapters) and `SeasonalEventManager` (M14,
## repeatable events) — extracted from `CampaignManager`'s own
## `_advance_objective()`/`_advance_level()` verbatim (behavior-identical, not
## a rewrite) so a repeatable event's objectives progress via the exact same
## arithmetic a chapter's do, per `docs/06_NARRATIVE_AND_WORLD.md`'s
## `ObjectiveData` schema being shared by both. Pure functions only — no
## signals, no state of its own; the caller owns its own progress/completed
## containers and its own signal emission, since chapters and events have
## different completion semantics (permanent vs. per-window).
##
## `CampaignManager` still owns its own signal wiring and its 3 handlers with
## bespoke target-matching (`_on_boarding_resolved`'s faction-or-ship-id union,
## `_on_fleet_changed`'s recompute-not-increment, `_on_resources_changed`'s
## dict lookup) — those don't reduce to a single generic tuple without
## restructuring CampaignManager itself, out of scope for this milestone.
## `SeasonalEventManager` mirrors those same three shapes independently
## (see its own handlers) using the same `matches()`/`matches_any()` predicates
## below, rather than CampaignManager forwarding into it — the lower-risk
## choice given CampaignManager's handlers are dense and already covered by
## 60+ passing tests.

## True if `objective` is authored for `condition` and either has no
## `target_id` (matches anything) or matches `target_id` exactly.
static func matches(objective: ObjectiveData, condition: int, target_id: String) -> bool:
	if objective.condition != condition:
		return false
	if not objective.target_id.is_empty() and objective.target_id != target_id:
		return false
	return true


## Same as matches(), but accepts two candidate ids — BOARD_SHIPS' faction-id-
## or-boss-ship-id union (a boss's dedicated ship_id and its faction's id are
## both valid matches for the same objective).
static func matches_any(objective: ObjectiveData, condition: int, target_id_a: String, target_id_b: String) -> bool:
	if objective.condition != condition:
		return false
	if objective.target_id.is_empty():
		return true
	return objective.target_id == target_id_a or objective.target_id == target_id_b


## Increments `progress[objective.objective_id]` by `amount`; marks it
## completed in `completed` once it reaches `objective.target_count`. Returns
## the new current value (so the caller can emit its own progress signal) —
## the caller checks `completed.has(objective.objective_id)` for whether it
## just finished.
static func advance_count(progress: Dictionary, completed: Array, objective: ObjectiveData, amount: int) -> int:
	var key := objective.objective_id
	if completed.has(key):
		return int(progress.get(key, 0))
	var current: int = int(progress.get(key, 0)) + amount
	progress[key] = current
	if current >= objective.target_count:
		completed.append(key)
	return current


## For REACH_ISLAND_TIER / REACH_NOTORIETY / ACCUMULATE_RESOURCE-shaped
## objectives: sets progress to the current absolute value rather than
## incrementing a counter. Returns the new current value (clamped to the
## threshold), same caller contract as advance_count().
static func advance_level(progress: Dictionary, completed: Array, objective: ObjectiveData, value: float) -> int:
	var key := objective.objective_id
	if completed.has(key):
		return int(progress.get(key, 0))
	var threshold: float = float(objective.target_count) \
		if objective.condition == ObjectiveData.Condition.REACH_ISLAND_TIER \
		else objective.target_value
	var current: int = int(min(value, threshold))
	progress[key] = current
	if value >= threshold:
		completed.append(key)
	return current
