extends GutTest

## M15 Wave 2 — AuthManager state transitions and session persistence.
## Establishes this project's first HTTPRequest-mocking pattern: AuthManager exposes a
## _request_override Callable test seam (see AuthManager.gd's _send_request()); tests replace it
## with a fake that returns a canned {"code": int, "body": Dictionary} instead of hitting the
## network. Touches the real AuthManager autoload directly, matching test_resource_manager.gd's
## save/restore-state convention rather than a testable subclass.

var _saved_access_token: String
var _saved_refresh_token: String
var _saved_user_id: String
var _saved_override: Callable
var _had_session_file: bool = false
var _session_backup_path := "user://auth_session_test_backup.json"

func before_each():
	_saved_access_token = AuthManager._access_token
	_saved_refresh_token = AuthManager._refresh_token
	_saved_user_id = AuthManager._user_id
	_saved_override = AuthManager._request_override

	if FileAccess.file_exists(AuthManager.SESSION_PATH):
		_had_session_file = true
		var src = FileAccess.open(AuthManager.SESSION_PATH, FileAccess.READ)
		var dst = FileAccess.open(_session_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()

	AuthManager._access_token = ""
	AuthManager._refresh_token = ""
	AuthManager._user_id = ""

func after_each():
	AuthManager._access_token = _saved_access_token
	AuthManager._refresh_token = _saved_refresh_token
	AuthManager._user_id = _saved_user_id
	AuthManager._request_override = _saved_override

	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("auth_session.json"):
		dir.remove("auth_session.json")
	if _had_session_file:
		var src = FileAccess.open(_session_backup_path, FileAccess.READ)
		var dst = FileAccess.open(AuthManager.SESSION_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("auth_session_test_backup.json")
	_had_session_file = false

func _fake_response(code: int, body: Dictionary) -> Callable:
	return func(_method, _url, _headers, _body):
		return {"code": code, "body": body}

func test_starts_signed_out():
	assert_false(AuthManager.is_signed_in(), "no session state should mean signed out")

func test_sign_up_success_establishes_session():
	AuthManager._request_override = _fake_response(200, {
		"access_token": "tok_access",
		"refresh_token": "tok_refresh",
		"user": {"id": "user-123"},
	})
	watch_signals(AuthManager)

	await AuthManager.sign_up("pirate@example.com", "hunt3rX!")

	assert_true(AuthManager.is_signed_in())
	assert_eq(AuthManager.get_user_id(), "user-123")
	assert_signal_emitted_with_parameters(AuthManager, "signed_in", ["user-123"])

func test_sign_up_pending_email_confirmation_does_not_sign_in():
	# Supabase's default: sign-up succeeds (200) but returns no access_token until the player
	# confirms via email.
	AuthManager._request_override = _fake_response(200, {"id": "user-456"})
	watch_signals(AuthManager)

	await AuthManager.sign_up("pirate@example.com", "hunt3rX!")

	assert_false(AuthManager.is_signed_in())
	assert_signal_emitted(AuthManager, "sign_up_pending_confirmation")

func test_sign_in_failure_emits_auth_error_and_stays_signed_out():
	AuthManager._request_override = _fake_response(400, {"error_description": "Invalid login credentials"})
	watch_signals(AuthManager)

	await AuthManager.sign_in("pirate@example.com", "wrong-password")

	assert_false(AuthManager.is_signed_in())
	assert_signal_emitted_with_parameters(AuthManager, "auth_error", ["Invalid login credentials"])

func test_sign_out_clears_session_regardless_of_network_result():
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh"
	AuthManager._user_id = "user-123"
	# The logout network call itself fails — sign_out() must still clear local state
	# unconditionally (Requirement 5.3).
	AuthManager._request_override = _fake_response(500, {})
	watch_signals(AuthManager)

	AuthManager.sign_out()

	assert_false(AuthManager.is_signed_in())
	assert_eq(AuthManager.get_user_id(), "")
	assert_signal_emitted(AuthManager, "signed_out")

func test_session_persists_and_reloads_via_refresh():
	AuthManager._request_override = _fake_response(200, {
		"access_token": "tok_access_1",
		"refresh_token": "tok_refresh_1",
		"user": {"id": "user-789"},
	})
	await AuthManager.sign_in("pirate@example.com", "hunt3rX!")
	assert_true(FileAccess.file_exists(AuthManager.SESSION_PATH), "sign-in should persist a session file")

	# Simulate an app restart: wipe in-memory state, keep the persisted refresh token, and let a
	# fresh refresh call re-derive an access token from it.
	AuthManager._access_token = ""
	AuthManager._user_id = ""
	AuthManager._request_override = _fake_response(200, {
		"access_token": "tok_access_2",
		"refresh_token": "tok_refresh_2",
		"user": {"id": "user-789"},
	})

	await AuthManager._load_session()

	assert_true(AuthManager.is_signed_in())
	assert_eq(AuthManager.get_user_id(), "user-789")

func test_refresh_session_clears_session_on_dead_refresh_token():
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh_dead"
	AuthManager._user_id = "user-123"
	AuthManager._request_override = _fake_response(401, {"error": "invalid_grant"})

	var ok: bool = await AuthManager.refresh_session()

	assert_false(ok)
	assert_false(AuthManager.is_signed_in(), "a dead refresh token should leave the player signed out, not crash or hang")

func test_no_session_file_means_load_session_makes_no_network_call():
	var call_count := 0
	AuthManager._request_override = func(_method, _url, _headers, _body):
		call_count += 1
		return {"code": 200, "body": {}}

	if FileAccess.file_exists(AuthManager.SESSION_PATH):
		var dir := DirAccess.open("user://")
		dir.remove("auth_session.json")

	await AuthManager._load_session()

	assert_eq(call_count, 0, "a player who never signed in should trigger zero network calls on load")
	assert_false(AuthManager.is_signed_in())

func test_delete_account_success_clears_session():
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh"
	AuthManager._user_id = "user-123"
	AuthManager._request_override = _fake_response(200, {"success": true})
	watch_signals(AuthManager)

	await AuthManager.delete_account()

	assert_false(AuthManager.is_signed_in())
	assert_signal_emitted(AuthManager, "signed_out")

func test_delete_account_failure_keeps_session_and_emits_error():
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh"
	AuthManager._user_id = "user-123"
	AuthManager._request_override = _fake_response(500, {"error": "Failed to delete account"})
	watch_signals(AuthManager)

	await AuthManager.delete_account()

	assert_true(AuthManager.is_signed_in(), "a failed deletion must not silently sign the player out")
	assert_signal_emitted(AuthManager, "auth_error")
