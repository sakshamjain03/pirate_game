extends GutTest
## M30 Wave 0 (0.6): refresh_session() used to clear the session on ANY
## failure — so a network blip, or the Supabase free-tier project being paused
## (2026-10-05), silently signed the player out and stopped cloud sync. Now
## only a dead refresh token clears it; everything else keeps the session and
## marks it degraded. Isolation mirrors test_auth_manager.gd: the real
## autoload, its fields and user://auth_session.json saved and restored.

var _saved_access_token: String
var _saved_refresh_token: String
var _saved_user_id: String
var _saved_override: Callable
var _saved_degraded: bool
var _had_session_file := false
var _session_text := ""
var _calls := 0


func before_each() -> void:
	_saved_access_token = AuthManager._access_token
	_saved_refresh_token = AuthManager._refresh_token
	_saved_user_id = AuthManager._user_id
	_saved_override = AuthManager._request_override
	_saved_degraded = AuthManager.session_degraded
	_had_session_file = FileAccess.file_exists(AuthManager.SESSION_PATH)
	if _had_session_file:
		_session_text = FileAccess.get_file_as_string(AuthManager.SESSION_PATH)
	_calls = 0


func after_each() -> void:
	AuthManager._cancel_refresh_timer()
	AuthManager._access_token = _saved_access_token
	AuthManager._refresh_token = _saved_refresh_token
	AuthManager._user_id = _saved_user_id
	AuthManager._request_override = _saved_override
	AuthManager.session_degraded = _saved_degraded
	AuthManager._refresh_in_flight = false
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("auth_session.json"):
		dir.remove("auth_session.json")
	if _had_session_file:
		var f := FileAccess.open(AuthManager.SESSION_PATH, FileAccess.WRITE)
		f.store_string(_session_text)
		f.close()


func _respond(code: int, body: Dictionary) -> void:
	AuthManager._request_override = func(_m, _u, _h, _b):
		_calls += 1
		await get_tree().process_frame
		return {"code": code, "body": body}


func _signed_in() -> void:
	AuthManager._apply_session({"access_token": "tok", "refresh_token": "ref",
		"expires_in": 3600, "user": {"id": "u1"}})


func test_network_failure_keeps_session_and_marks_degraded() -> void:
	_signed_in()
	_respond(0, {})
	var ok: bool = await AuthManager.refresh_session()
	assert_false(ok)
	assert_true(AuthManager.is_signed_in(), "a network failure must not sign the player out")
	assert_true(AuthManager.session_degraded)


func test_server_error_keeps_session() -> void:
	_signed_in()
	_respond(503, {})
	await AuthManager.refresh_session()
	assert_true(AuthManager.is_signed_in())
	assert_true(AuthManager.session_degraded)


func test_legacy_invalid_grant_clears_session() -> void:
	_signed_in()
	_respond(400, {"error": "invalid_grant"})
	await AuthManager.refresh_session()
	assert_false(AuthManager.is_signed_in())
	assert_false(AuthManager.session_degraded)


func test_current_gotrue_error_code_clears_session() -> void:
	_signed_in()
	_respond(400, {"code": 400, "error_code": "refresh_token_not_found", "msg": "Invalid Refresh Token"})
	await AuthManager.refresh_session()
	assert_false(AuthManager.is_signed_in(), "GoTrue's error_code form must also count as a dead token")


func test_success_clears_degraded() -> void:
	_signed_in()
	AuthManager.session_degraded = true
	_respond(200, {"access_token": "tok2", "refresh_token": "ref2", "expires_in": 3600})
	var ok: bool = await AuthManager.refresh_session()
	assert_true(ok)
	assert_false(AuthManager.session_degraded)
	assert_eq(AuthManager._access_token, "tok2")


func test_concurrent_callers_share_one_request_and_its_result() -> void:
	_signed_in()
	_respond(0, {})
	AuthManager.refresh_session()  # deliberately not awaited: left in flight
	var second: bool = await AuthManager.refresh_session()
	assert_eq(_calls, 1, "only one refresh request may be in flight")
	assert_false(second, "a waiter must get the failed result, not is_signed_in()")


func test_expiry_schedules_a_single_shot_refresh() -> void:
	_signed_in()
	var timer: Timer = AuthManager._refresh_timer
	assert_not_null(timer, "a refresh must be scheduled before expiry")
	assert_true(timer.one_shot, "a repeating timer would refresh every hour forever")
	assert_almost_eq(timer.wait_time, 3540.0, 2.0, "refresh 60 s before a 3600 s expiry")
