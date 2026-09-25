extends GutTest

## M17 Task 20 — every design.md §5 state-machine invariant, plus the §6
## caps ledger and reward-shape entry points that live in the same
## AdManager. The single most important invariant here: no ad SDK call
## (init, load, show) may ever happen outside a READY_* state (Requirement
## 5.5) — this is a compliance surface, not a feature, per this milestone's
## own Notes.

const _SURFACE := &"offline_double"

var _saved_state: AdManager.State
var _saved_is_under_age: bool
var _saved_ledger: Dictionary
var _saved_sdk_initialized: bool
var _saved_pending_surface: StringName
var _had_state_file: bool
var _backup_path := "user://ad_permission_data_test_backup.json"
var _had_ad_free: bool
var _ad_free_record


func before_each():
	_saved_state = AdManager.state
	_saved_is_under_age = AdManager._is_under_age
	_saved_ledger = AdManager._ledger.duplicate(true)
	_saved_sdk_initialized = AdManager._sdk_initialized
	_saved_pending_surface = AdManager._pending_surface

	if FileAccess.file_exists(AdManager.STATE_DATA_PATH):
		_had_state_file = true
		var src := FileAccess.open(AdManager.STATE_DATA_PATH, FileAccess.READ)
		var dst := FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()

	# An Ad-Free entitlement left over from anywhere (a real purchase on this
	# dev profile, or another test's leak) makes request_bonus() grant directly
	# with no SDK call — so every "ad must load" assertion here depends on it
	# being absent. Removed in memory only; restored in after_each.
	_had_ad_free = EntitlementManager._entitlements.has(EntitlementManager.AD_FREE_ID)
	_ad_free_record = EntitlementManager._entitlements.get(EntitlementManager.AD_FREE_ID)
	EntitlementManager._entitlements.erase(EntitlementManager.AD_FREE_ID)

	AdManager.state = AdManager.State.UNKNOWN
	AdManager._is_under_age = false
	AdManager._ledger.clear()
	AdManager._sdk_initialized = false
	AdManager._pending_surface = &""
	AdManager._backend.load_calls.clear()
	AdManager._backend.show_calls.clear()
	AdManager._backend.sdk_initialized = false
	AdManager._backend.next_ad_result = "complete"


func after_each():
	if _had_ad_free:
		EntitlementManager._entitlements[EntitlementManager.AD_FREE_ID] = _ad_free_record
	else:
		EntitlementManager._entitlements.erase(EntitlementManager.AD_FREE_ID)
	AdManager.state = _saved_state
	AdManager._is_under_age = _saved_is_under_age
	AdManager._ledger = _saved_ledger.duplicate(true)
	AdManager._sdk_initialized = _saved_sdk_initialized
	AdManager._pending_surface = _saved_pending_surface

	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("ad_permission_data.json"):
		dir.remove("ad_permission_data.json")
	if _had_state_file:
		var src := FileAccess.open(_backup_path, FileAccess.READ)
		var dst := FileAccess.open(AdManager.STATE_DATA_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("ad_permission_data_test_backup.json")
	_had_state_file = false


# --- State machine shape ---

func test_unknown_is_the_startup_state():
	assert_eq(AdManager.state, AdManager.State.UNKNOWN)


func test_begin_age_gate_if_needed_moves_unknown_to_age_gate_pending():
	AdManager.begin_age_gate_if_needed()
	assert_eq(AdManager.state, AdManager.State.AGE_GATE_PENDING)


func test_begin_age_gate_if_needed_is_a_noop_once_resolved():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.begin_age_gate_if_needed()
	assert_eq(AdManager.state, AdManager.State.CONSENT_PENDING,
		"begin_age_gate_if_needed must never re-enter the age gate once resolved")


func test_adult_declining_consent_still_reaches_ready_nonpersonalized():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	assert_eq(AdManager.state, AdManager.State.CONSENT_PENDING)
	AdManager.submit_consent_choice(false)
	assert_eq(AdManager.state, AdManager.State.READY_NONPERSONALIZED,
		"a genuine decline must resolve to non-personalized ads, never block play")


func test_adult_accepting_consent_reaches_ready_personalized():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)
	assert_eq(AdManager.state, AdManager.State.READY_PERSONALIZED)


func test_under_age_answer_reaches_ready_nonpersonalized_via_child_directed():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(true)
	assert_eq(AdManager.state, AdManager.State.READY_NONPERSONALIZED,
		"CHILD_DIRECTED must resolve straight to non-personalized, never offering a personalize choice")


func test_reopen_consent_returns_a_ready_account_to_consent_pending():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)
	AdManager.reopen_consent()
	assert_eq(AdManager.state, AdManager.State.CONSENT_PENDING)


func test_reopen_consent_is_a_noop_for_child_directed():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(true)
	AdManager.reopen_consent()
	assert_eq(AdManager.state, AdManager.State.READY_NONPERSONALIZED,
		"a child-directed account is never offered a personalization choice, even from settings")


func test_reopen_consent_is_a_noop_before_the_age_gate_has_ever_resolved():
	AdManager.reopen_consent()
	assert_eq(AdManager.state, AdManager.State.UNKNOWN)
	AdManager.begin_age_gate_if_needed()
	AdManager.reopen_consent()
	assert_eq(AdManager.state, AdManager.State.AGE_GATE_PENDING)


# --- Requirement 5.5: no SDK touch outside READY_* ---

func test_no_sdk_init_or_ad_call_while_unknown():
	AdManager.request_bonus(_SURFACE)
	assert_true(AdManager._backend.load_calls.is_empty())
	assert_false(AdManager._backend.sdk_initialized)


func test_no_sdk_init_or_ad_call_while_age_gate_pending():
	AdManager.begin_age_gate_if_needed()
	AdManager.request_bonus(_SURFACE)
	assert_true(AdManager._backend.load_calls.is_empty())
	assert_false(AdManager._backend.sdk_initialized)


func test_no_sdk_init_or_ad_call_while_consent_pending():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.request_bonus(_SURFACE)
	assert_true(AdManager._backend.load_calls.is_empty())
	assert_false(AdManager._backend.sdk_initialized)


func test_sdk_initializes_exactly_once_on_reaching_ready():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	assert_false(AdManager._backend.sdk_initialized)
	AdManager.submit_consent_choice(true)
	assert_true(AdManager._backend.sdk_initialized)


func test_ready_state_actually_allows_an_ad_request():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)
	AdManager.request_bonus(_SURFACE)
	assert_true(AdManager._backend.load_calls.has(_SURFACE), "expected an ad load call for the surface")


# --- Account-level persistence, not the save ---

func test_state_is_not_persisted_through_the_save_file():
	assert_false(AdManager.has_method("get_save_data"),
		"AdManager must never round-trip through SaveManager — it's account-scoped, not save-scoped")


func test_state_file_is_its_own_path_not_entitlement_managers():
	assert_ne(AdManager.STATE_DATA_PATH, EntitlementManager.ACCOUNT_DATA_PATH)


# --- Reward-shape entry points (design.md §6) ---

func test_ad_free_entitlement_grants_the_bonus_directly_with_zero_sdk_contact():
	EntitlementManager.grant(EntitlementManager.AD_FREE_ID, "test")
	watch_signals(AdManager)
	AdManager.request_bonus(_SURFACE)
	assert_signal_emitted_with_parameters(AdManager, "bonus_granted", [_SURFACE])
	assert_true(AdManager._backend.load_calls.is_empty(),
		"an ad-free supporter must never trigger an actual ad load")
	EntitlementManager.revoke(EntitlementManager.AD_FREE_ID)


func test_a_capped_surface_reports_unavailable_and_never_touches_the_backend():
	AdManager._ledger[AdManager._today_key()] = {_SURFACE: AdManager.SURFACE_DAILY_CAPS[_SURFACE]}
	watch_signals(AdManager)
	AdManager.request_bonus(_SURFACE)
	assert_signal_emitted_with_parameters(AdManager, "bonus_unavailable", [_SURFACE])
	assert_true(AdManager._backend.load_calls.is_empty())


func test_completed_ad_grants_bonus_and_consumes_exactly_one_cap_use():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)

	watch_signals(AdManager)
	AdManager.request_bonus(_SURFACE)
	await wait_for_signal(AdManager.bonus_granted, 1.0)

	assert_signal_emitted_with_parameters(AdManager, "bonus_granted", [_SURFACE])
	assert_eq(AdManager._ledger[AdManager._today_key()][_SURFACE], 1)


func test_failed_ad_does_not_consume_a_cap_and_offer_stays_available():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)
	AdManager._backend.next_ad_result = "fail"

	watch_signals(AdManager)
	AdManager.request_bonus(_SURFACE)
	await wait_for_signal(AdManager.bonus_ad_failed, 1.0)

	assert_false(AdManager._ledger.get(AdManager._today_key(), {}).has(_SURFACE),
		"a failed ad must not consume a cap use")
	assert_true(AdManager.can_offer(_SURFACE))


func test_dismissed_ad_does_not_consume_a_cap():
	AdManager.begin_age_gate_if_needed()
	AdManager.submit_age_gate_answer(false)
	AdManager.submit_consent_choice(true)
	AdManager._backend.next_ad_result = "dismiss"

	AdManager.request_bonus(_SURFACE)
	await wait_for_signal(AdManager.bonus_ad_failed, 1.0)

	assert_false(AdManager._ledger.get(AdManager._today_key(), {}).has(_SURFACE))


func test_cap_rolls_over_on_a_new_day():
	AdManager._ledger["2000-01-01"] = {_SURFACE: 999}
	assert_true(AdManager.can_offer(_SURFACE),
		"a stale prior-day entry must never count against today's cap")


func test_request_bonus_rejects_an_unregistered_surface():
	AdManager.request_bonus(&"not_a_real_surface")
	assert_true(AdManager._backend.load_calls.is_empty())
