extends Node

## AdManager
## Autoload. Owns two things, both account-scoped (never in the save):
## 1. The ad permission state machine (design.md §5) — age gate, then
##    consent, then (and only then) any ad SDK touch. Task 17 is a
##    compliance surface, not a feature: requesting an ad before consent
##    resolves is a real policy violation, and it fails silently in
##    development because test ad units serve regardless of consent state.
## 2. The rewarded-surface caps ledger (design.md §6) — day-bucketed by
##    local date, so no individual surface can implement its own counting.
##
## Every reward this manager ever grants is a BONUS on an amount the caller
## already granted unconditionally — this file never computes or reduces a
## baseline itself (design.md §6's reward-shape rule; the caller owns the
## baseline, this manager only owns whether a bonus is available).

signal state_changed(new_state: State)
signal bonus_granted(surface: StringName)
## Cap exhausted, or ads not ready yet (age gate/consent unresolved) — the
## caller should hide/disable the offer for this occurrence.
signal bonus_unavailable(surface: StringName)
## A real ad failed to load or was dismissed before completing — the caller
## keeps the baseline and the offer stays available for next time
## (Requirement 6.8); this is NOT the same as bonus_unavailable.
signal bonus_ad_failed(surface: StringName, reason: String)

enum State {
	UNKNOWN,
	AGE_GATE_PENDING,
	CONSENT_PENDING,
	CHILD_DIRECTED,
	READY_PERSONALIZED,
	READY_NONPERSONALIZED,
}

const STATE_DATA_PATH := "user://ad_permission_data.json"
## Play Families / COPPA-oriented threshold (Requirement 5.3) — under this
## age routes to CHILD_DIRECTED, never the normal personalized-consent path.
const CHILD_AGE_THRESHOLD := 13

## design.md §2.3 — the complete, closed list. Adding a fourth requires
## amending docs/17_MONETIZATION.md first, per that document's own rule.
const SURFACE_DAILY_CAPS := {
	&"offline_double": 3,
	&"event_reroll": 2,
	&"salvage_double": 3,
}

var state: State = State.UNKNOWN
var _is_under_age := false
var _ledger: Dictionary = {}          # {"YYYY-MM-DD": {surface: count}}
var _backend: IAdBackend
var _pending_surface: StringName = &""
var _sdk_initialized := false


func _ready() -> void:
	_backend = _create_backend()
	_backend.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	_backend.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	_backend.rewarded_ad_failed.connect(_on_rewarded_ad_failed)
	_backend.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	_load_state()
	if is_ready_for_ads():
		# A prior session already resolved permission — the SDK still needs
		# initializing on this fresh launch, since _sdk_initialized (an
		# in-memory-only flag) always starts false.
		_ensure_sdk_initialized()


func is_ready_for_ads() -> bool:
	return state == State.READY_PERSONALIZED or state == State.READY_NONPERSONALIZED


## The whole point of Requirement 5.5 — checked by every caller in this file
## before anything below is allowed to touch the backend.
func _can_touch_ad_sdk() -> bool:
	return is_ready_for_ads()


## Starts the age gate if (and only if) permission has never been resolved.
## Callers invoke this lazily, the first time a rewarded surface would want
## to make an offer — never proactively at boot, and never during the
## tutorial or first session, because no surface calls request_bonus() then
## either (Requirement 6.6 already keeps those surfaces silent that early).
func begin_age_gate_if_needed() -> void:
	if state != State.UNKNOWN:
		return
	state = State.AGE_GATE_PENDING
	_save_state()
	state_changed.emit(state)


## The age gate UI's own answer callback. Neutral input in, neutral
## handling out — this function has no opinion on how the question was
## phrased (that's AgeGate.tscn's job, Requirement 5.2).
func submit_age_gate_answer(is_under_threshold: bool) -> void:
	if state != State.AGE_GATE_PENDING:
		return
	_is_under_age = is_under_threshold
	if is_under_threshold:
		state = State.CHILD_DIRECTED
		_save_state()
		state_changed.emit(state)
		# Requirement 5.3 — non-personalized only, no consent dialog needed;
		# a child-directed player is never asked to personalize ads at all.
		state = State.READY_NONPERSONALIZED
		_save_state()
		_ensure_sdk_initialized()
		state_changed.emit(state)
	else:
		state = State.CONSENT_PENDING
		_save_state()
		state_changed.emit(state)
		# ConsentPanel (listening to state_changed) shows itself here and
		# reports back via submit_consent_choice() below. No real UMP SDK
		# exists yet to render its own native dialog instead (that
		# integration point arrives with M20's real ad backend); until then
		# this custom panel *is* the consent flow, not a placeholder for one.


## Settings → review/change consent later (Requirement 5.6). A no-op for a
## child-directed account — that path never offers a personalization choice.
## Checked via _is_under_age, not state == CHILD_DIRECTED: that state is
## transient (it advances to READY_NONPERSONALIZED in the same call that
## sets it, per submit_age_gate_answer()), so by the time this is ever
## called a child-directed account is already sitting in READY_NONPERSONALIZED
## — indistinguishable from an adult who simply declined, unless the
## account's actual origin is tracked separately.
func reopen_consent() -> void:
	if _is_under_age or state == State.UNKNOWN or state == State.AGE_GATE_PENDING:
		return
	state = State.CONSENT_PENDING
	_save_state()
	state_changed.emit(state)


## ConsentPanel's own answer callback (Requirement 5.4's genuine decline
## path — declining still resolves to READY_NONPERSONALIZED, never blocks
## play). Requirement 5.6 review-later also lands here.
func submit_consent_choice(personalized: bool) -> void:
	if state != State.CONSENT_PENDING:
		return
	state = State.READY_PERSONALIZED if personalized else State.READY_NONPERSONALIZED
	_save_state()
	_ensure_sdk_initialized()
	state_changed.emit(state)


## Requirement 5.5 — the SDK is initialized exactly once, the first time
## (and only once) the state machine actually reaches a READY_* state.
## Never called from anywhere else in this file.
func _ensure_sdk_initialized() -> void:
	if not _sdk_initialized:
		_sdk_initialized = true
		_backend.initialize_sdk()


## True if this surface can currently make an offer at all — capped or not.
## Does not consider ad-readiness: the caller may still want to show a
## (disabled, or age-gate-triggering) affordance even before ads are ready.
func can_offer(surface: StringName) -> bool:
	return not _is_capped(surface)


## The one entry point every rewarded surface calls, after already granting
## its baseline unconditionally (Requirement 6.5 — never call this instead
## of granting the baseline, only in addition to it).
func request_bonus(surface: StringName) -> void:
	if not SURFACE_DAILY_CAPS.has(surface):
		push_error("AdManager: '%s' is not one of the three permitted surfaces" % surface)
		return
	if _is_capped(surface):
		bonus_unavailable.emit(surface)
		return
	if EntitlementManager.has_entitlement(EntitlementManager.AD_FREE_ID):
		# Requirement 6.7 — granted directly, same value, no ad, no delay.
		_record_cap_use(surface)
		bonus_granted.emit(surface)
		return
	if not _can_touch_ad_sdk():
		begin_age_gate_if_needed()
		bonus_unavailable.emit(surface)
		return
	_pending_surface = surface
	_backend.load_rewarded_ad(surface)


func _on_rewarded_ad_loaded(surface: StringName) -> void:
	if surface != _pending_surface:
		return
	_backend.show_rewarded_ad(surface)


func _on_rewarded_ad_completed(surface: StringName) -> void:
	if surface != _pending_surface:
		return
	_pending_surface = &""
	_record_cap_use(surface)
	bonus_granted.emit(surface)


func _on_rewarded_ad_failed(surface: StringName, reason: String) -> void:
	if surface != _pending_surface:
		return
	_pending_surface = &""
	bonus_ad_failed.emit(surface, reason)


func _on_rewarded_ad_dismissed(surface: StringName) -> void:
	if surface != _pending_surface:
		return
	_pending_surface = &""
	bonus_ad_failed.emit(surface, "dismissed")


func _is_capped(surface: StringName) -> bool:
	var limit: int = SURFACE_DAILY_CAPS.get(surface, 0)
	var used: int = _ledger.get(_today_key(), {}).get(surface, 0)
	return used >= limit


func _record_cap_use(surface: StringName) -> void:
	var today := _today_key()
	if not _ledger.has(today):
		# Rolls over at local midnight — no reason to keep any prior day
		# around, only "today" is ever read.
		_ledger.clear()
		_ledger[today] = {}
	_ledger[today][surface] = int(_ledger[today].get(surface, 0)) + 1
	_save_state()


func _today_key() -> String:
	var dt := Time.get_datetime_dict_from_system(false)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


func _create_backend() -> IAdBackend:
	return AdBackendStub.new()


func _save_state() -> void:
	var file := FileAccess.open(STATE_DATA_PATH, FileAccess.WRITE)
	if not file:
		push_error("AdManager: could not open %s for writing" % STATE_DATA_PATH)
		return
	file.store_string(JSON.stringify({
		"state": State.keys()[state],
		"is_under_age": _is_under_age,
		"ledger": _ledger,
	}))
	file.close()


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_DATA_PATH):
		return
	var file := FileAccess.open(STATE_DATA_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	var state_name: String = data.get("state", "UNKNOWN")
	var index: int = State.keys().find(state_name)
	state = index if index >= 0 else State.UNKNOWN
	_is_under_age = data.get("is_under_age", false)
	var ledger = data.get("ledger", {})
	_ledger = ledger if typeof(ledger) == TYPE_DICTIONARY else {}
