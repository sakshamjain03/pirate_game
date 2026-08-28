extends GutTest

## M15 Wave 6 — RemoteConfigManager: fetch-once, in-memory cache, and the never-block/
## never-error-on-failure contract (Requirement 11.3). Mirrors test_auth_manager.gd's HTTP-fake
## seam pattern; counters mutated inside a Callable are Array-wrapped (see
## test_save_manager_sync.gd's header note — GDScript lambdas capture locals by value).

var _saved_cache: Dictionary
var _saved_fetched: bool
var _saved_override: Callable

func before_each():
	_saved_cache = RemoteConfigManager._cache
	_saved_fetched = RemoteConfigManager._fetched
	_saved_override = RemoteConfigManager._request_override
	RemoteConfigManager._cache = {}
	RemoteConfigManager._fetched = false
	RemoteConfigManager._request_override = Callable()

func after_each():
	RemoteConfigManager._cache = _saved_cache
	RemoteConfigManager._fetched = _saved_fetched
	RemoteConfigManager._request_override = _saved_override

func test_get_value_returns_default_before_any_fetch():
	assert_eq(RemoteConfigManager.get_value("seasonal_event_active", false), false)
	assert_eq(RemoteConfigManager.get_value("some_missing_key", "fallback"), "fallback")

func test_successful_fetch_populates_cache():
	RemoteConfigManager._request_override = func():
		return {"code": 200, "body": [
			{"key": "seasonal_event_active", "value": true},
			{"key": "kill_switch_boss_fight", "value": false},
		]}

	await RemoteConfigManager._fetch()

	assert_eq(RemoteConfigManager.get_value("seasonal_event_active", false), true)
	assert_eq(RemoteConfigManager.get_value("kill_switch_boss_fight", true), false)
	assert_eq(RemoteConfigManager.get_value("never_defined_key", "safe_default"), "safe_default")

func test_failed_fetch_never_errors_and_returns_caller_default():
	RemoteConfigManager._request_override = func():
		return {"code": 500, "body": {}}

	await RemoteConfigManager._fetch()

	assert_eq(RemoteConfigManager.get_value("anything", "safe_default"), "safe_default")

func test_failed_refetch_leaves_stale_cache_usable_rather_than_clearing_it():
	# First fetch succeeds and populates the cache...
	RemoteConfigManager._request_override = func():
		return {"code": 200, "body": [{"key": "seasonal_event_active", "value": true}]}
	await RemoteConfigManager._fetch()
	assert_eq(RemoteConfigManager.get_value("seasonal_event_active", false), true)

	# ...a later refresh fails (wrong URL / network down) — the stale value must still be usable,
	# never wiped out from under a caller mid-session.
	RemoteConfigManager._request_override = func():
		return {"code": 0, "body": {}}
	await RemoteConfigManager._fetch()

	assert_eq(
		RemoteConfigManager.get_value("seasonal_event_active", false), true,
		"a failed refresh must not clear a previously-cached value")

func test_network_error_zero_code_also_falls_back_safely():
	# code 0 is what _send_request() returns on an HTTPRequest.request() error (e.g. malformed
	# URL / network disabled), distinct from a real HTTP error status.
	RemoteConfigManager._request_override = func():
		return {"code": 0, "body": []}

	await RemoteConfigManager._fetch()

	assert_eq(RemoteConfigManager.get_value("anything", "safe_default"), "safe_default")
