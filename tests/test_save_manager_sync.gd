extends GutTest

## M15 Wave 3 — SaveManager's cloud-sync trigger logic: calls sync exactly when signed in, skips
## cleanly when not, retries on the next save after a failure, and never touches the local save
## on sign-out. Mirrors test_auth_manager.gd's HTTP-fake seam pattern.
##
## Counters/flags a lambda needs to mutate (and have the outer test observe afterward) are
## wrapped in a single-element Array — GDScript lambdas capture local variables by value, not by
## reference, so a plain `var call_count := 0` mutated inside the lambda never reflects back to
## the outer scope. An Array is a reference type, so mutating its contents (not reassigning the
## variable) does.

var _saved_access_token: String
var _saved_refresh_token: String
var _saved_user_id: String
var _saved_auth_override: Callable
var _saved_save_override: Callable
var _saved_cloud_sync_pending: bool

var _had_backup: bool = false
var _backup_path := "user://save_data_test_backup_sync.json"

func before_each():
	_saved_access_token = AuthManager._access_token
	_saved_refresh_token = AuthManager._refresh_token
	_saved_user_id = AuthManager._user_id
	_saved_auth_override = AuthManager._request_override
	_saved_save_override = SaveManager._request_override
	_saved_cloud_sync_pending = SaveManager._cloud_sync_pending

	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()

	SaveManager._request_override = Callable()
	AuthManager._request_override = Callable()

func after_each():
	AuthManager._access_token = _saved_access_token
	AuthManager._refresh_token = _saved_refresh_token
	AuthManager._user_id = _saved_user_id
	AuthManager._request_override = _saved_auth_override
	SaveManager._request_override = _saved_save_override
	SaveManager._cloud_sync_pending = _saved_cloud_sync_pending

	if _had_backup:
		var src = FileAccess.open(_backup_path, FileAccess.READ)
		var dst = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		var dir := DirAccess.open("user://")
		dir.remove("save_data_test_backup_sync.json")
	else:
		SaveManager.delete_save()
	_had_backup = false

func _sign_in_fake(user_id: String = "user-abc") -> void:
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh"
	AuthManager._user_id = user_id

func test_save_game_does_not_sync_when_signed_out():
	var calls := [0]
	SaveManager._request_override = func(_m, _e, _h, _b):
		calls[0] += 1
		return {"code": 200, "body": {}}

	SaveManager.save_game()
	await wait_process_frames(1)

	assert_eq(calls[0], 0, "a signed-out player should never trigger a cloud sync call")

func test_save_game_syncs_when_signed_in():
	_sign_in_fake()
	var calls := [0]
	var last_endpoint := [""]
	SaveManager._request_override = func(_method, endpoint, _headers, _body):
		calls[0] += 1
		last_endpoint[0] = endpoint
		return {"code": 201, "body": {}}

	SaveManager.save_game()
	await wait_process_frames(2)

	assert_eq(calls[0], 1, "a signed-in player's save should trigger exactly one cloud sync call")
	assert_string_contains(last_endpoint[0], "/rest/v1/player_saves")
	assert_false(SaveManager._cloud_sync_pending, "a successful sync should clear the pending flag")

func test_failed_sync_marks_pending_then_clears_on_next_successful_save():
	_sign_in_fake()
	var should_fail := [true]
	var calls := [0]
	SaveManager._request_override = func(_method, _endpoint, _headers, _body):
		calls[0] += 1
		if should_fail[0]:
			return {"code": 500, "body": {"error": "server error"}}
		return {"code": 201, "body": {}}

	SaveManager.save_game()
	await wait_process_frames(2)
	assert_true(SaveManager._cloud_sync_pending, "a failed sync should mark itself pending")

	should_fail[0] = false
	SaveManager.save_game()
	await wait_process_frames(2)

	assert_eq(calls[0], 2, "the next save should retry with the latest state")
	assert_false(SaveManager._cloud_sync_pending, "a subsequent successful sync should clear pending")

func test_sign_out_does_not_touch_local_save():
	_sign_in_fake()
	SaveManager._request_override = func(_m, _e, _h, _b):
		return {"code": 201, "body": {}}

	SaveManager.save_game()
	await wait_process_frames(2)
	assert_true(SaveManager.has_save_data())

	var before_result = SaveManager._read_save_file(SaveManager.SAVE_PATH)

	AuthManager._request_override = func(_m, _u, _h, _b):
		return {"code": 200, "body": {}}
	AuthManager.sign_out()

	assert_true(SaveManager.has_save_data(), "signing out must never delete the local save")
	var after_result = SaveManager._read_save_file(SaveManager.SAVE_PATH)
	assert_eq(
		after_result["data"].get("last_saved_unix", -1),
		before_result["data"].get("last_saved_unix", -2),
		"the local save's content must be untouched by sign-out")

func test_delete_account_does_not_touch_local_save():
	# M15 Requirement 8.4 — deleting the cloud account must never touch local progress; the
	# player keeps playing locally exactly as if they had signed out (Requirement 4.5).
	_sign_in_fake()
	SaveManager._request_override = func(_m, _e, _h, _b):
		return {"code": 201, "body": {}}

	SaveManager.save_game()
	await wait_process_frames(2)
	assert_true(SaveManager.has_save_data())
	var before_result = SaveManager._read_save_file(SaveManager.SAVE_PATH)

	AuthManager._request_override = func(_m, _u, _h, _b):
		return {"code": 200, "body": {"success": true}}
	await AuthManager.delete_account()

	assert_true(SaveManager.has_save_data(), "deleting the account must never delete the local save")
	var after_result = SaveManager._read_save_file(SaveManager.SAVE_PATH)
	assert_eq(
		after_result["data"].get("last_saved_unix", -1),
		before_result["data"].get("last_saved_unix", -2),
		"the local save's content must be untouched by account deletion")

func test_401_triggers_one_refresh_and_retry():
	_sign_in_fake()
	var sync_calls := [0]
	SaveManager._request_override = func(_method, _endpoint, _headers, _body):
		sync_calls[0] += 1
		if sync_calls[0] == 1:
			return {"code": 401, "body": {"message": "expired"}}
		return {"code": 201, "body": {}}

	var refresh_calls := [0]
	AuthManager._request_override = func(_method, _url, _headers, _body):
		refresh_calls[0] += 1
		return {"code": 200, "body": {
			"access_token": "tok_access_2",
			"refresh_token": "tok_refresh_2",
			"user": {"id": "user-abc"},
		}}

	SaveManager.save_game()
	await wait_process_frames(3)

	assert_eq(refresh_calls[0], 1, "a 401 should trigger exactly one refresh attempt")
	assert_eq(sync_calls[0], 2, "the sync should retry exactly once after a successful refresh")
	assert_false(SaveManager._cloud_sync_pending)
