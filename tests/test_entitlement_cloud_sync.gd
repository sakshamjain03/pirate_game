extends GutTest

## M17 Task 11/Requirement 3.3/3.6 — EntitlementManager's cloud entitlement
## sync: union-merge only, never removes except via revoke(), and mirrors
## test_save_manager_sync.gd's own HTTP-fake seam pattern exactly (counters
## wrapped in single-element Arrays since GDScript lambdas capture by value).

var _saved_access_token: String
var _saved_refresh_token: String
var _saved_user_id: String
var _saved_auth_override: Callable
var _saved_entitlement_override: Callable
var _saved_entitlements: Dictionary
var _saved_did_launch_check: bool
var _saved_session_file: Variant = null  # String contents, or null when absent


func before_each():
	# The 401 test's refresh persists user://auth_session.json; left behind, the
	# next launch restores it and fires a real refresh, so every later run sees
	# two refreshes where the test expects one. Snapshot it, restore it after.
	_saved_session_file = null
	if FileAccess.file_exists("user://auth_session.json"):
		_saved_session_file = FileAccess.get_file_as_string("user://auth_session.json")
	_saved_access_token = AuthManager._access_token
	_saved_refresh_token = AuthManager._refresh_token
	_saved_user_id = AuthManager._user_id
	_saved_auth_override = AuthManager._request_override
	_saved_entitlement_override = EntitlementManager._request_override
	_saved_entitlements = EntitlementManager._entitlements.duplicate(true)
	_saved_did_launch_check = EntitlementManager._did_launch_cloud_check

	AuthManager._request_override = Callable()
	EntitlementManager._request_override = Callable()
	EntitlementManager._did_launch_cloud_check = false
	# An earlier script (test_auth_manager / test_purchase_flow, whichever shard order puts them
	# first) can leave a refresh "in flight"; refresh_session() then waits for it forever and the
	# 401 test sees no refresh attempt at all.
	AuthManager._refresh_in_flight = false
	# ...and can leave the player signed in, so "signed out" tests would sync and the 401 test
	# would see a second refresh. Start every test from a signed-out AuthManager.
	AuthManager._access_token = ""
	AuthManager._refresh_token = ""
	AuthManager._user_id = ""


func after_each():
	if _saved_session_file == null:
		if FileAccess.file_exists("user://auth_session.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://auth_session.json"))
	else:
		var f := FileAccess.open("user://auth_session.json", FileAccess.WRITE)
		if f:
			f.store_string(_saved_session_file)
			f.close()
	AuthManager._access_token = _saved_access_token
	AuthManager._refresh_token = _saved_refresh_token
	AuthManager._user_id = _saved_user_id
	AuthManager._request_override = _saved_auth_override
	EntitlementManager._request_override = _saved_entitlement_override
	EntitlementManager._entitlements = _saved_entitlements.duplicate(true)
	EntitlementManager._did_launch_cloud_check = _saved_did_launch_check
	EntitlementManager._write_account_data()


func _sign_in_fake(user_id: String = "user-abc") -> void:
	AuthManager._access_token = "tok_access"
	AuthManager._refresh_token = "tok_refresh"
	AuthManager._user_id = user_id


func test_grant_does_not_sync_when_signed_out():
	EntitlementManager._entitlements.erase(&"hull_deep_ocean_blue")
	var calls := [0]
	EntitlementManager._request_override = func(_m, _e, _h, _b):
		calls[0] += 1
		return {"code": 201, "body": {}}

	EntitlementManager.grant(&"hull_deep_ocean_blue", "test")
	await wait_process_frames(2)

	assert_eq(calls[0], 0, "a signed-out grant should never trigger a cloud sync call")


func test_grant_pushes_the_full_set_when_signed_in():
	_sign_in_fake()
	EntitlementManager._entitlements.erase(&"hull_deep_ocean_blue")
	var calls := [0]
	var last_endpoint := [""]
	var last_body := [""]
	EntitlementManager._request_override = func(_method, endpoint, _headers, body):
		calls[0] += 1
		last_endpoint[0] = endpoint
		last_body[0] = body
		return {"code": 201, "body": {}}

	EntitlementManager.grant(&"hull_deep_ocean_blue", "test")
	await wait_process_frames(2)

	assert_eq(calls[0], 1)
	assert_string_contains(last_endpoint[0], "/rest/v1/player_entitlements")
	assert_string_contains(last_body[0], "hull_deep_ocean_blue")


func test_revoke_pushes_the_smaller_set():
	_sign_in_fake()
	EntitlementManager.grant(&"hull_deep_ocean_blue", "test")
	await wait_process_frames(1)

	var last_body := [""]
	EntitlementManager._request_override = func(_method, _endpoint, _headers, body):
		last_body[0] = body
		return {"code": 201, "body": {}}

	EntitlementManager.revoke(&"hull_deep_ocean_blue")
	await wait_process_frames(2)

	assert_false(last_body[0].contains("hull_deep_ocean_blue"),
		"a revoked entitlement must not appear in the pushed cloud payload")


func test_launch_sync_grants_a_cloud_only_entitlement_without_removing_local_ones():
	_sign_in_fake()
	EntitlementManager._entitlements.erase(&"hull_deep_ocean_blue")
	EntitlementManager._entitlements[&"hull_weathered_grey"] = {
		"source": "test", "granted_at": 0, "order_id": "",
	}

	EntitlementManager._request_override = func(method, endpoint, _headers, _body):
		if method == HTTPClient.METHOD_GET:
			return {"code": 200, "body": [{"entitlements": {"hull_deep_ocean_blue": {}}}]}
		return {"code": 201, "body": {}}

	await EntitlementManager.check_cloud_sync_on_launch()

	assert_true(EntitlementManager.has_entitlement(&"hull_deep_ocean_blue"),
		"a cloud-only entitlement must be granted locally (the union)")
	assert_true(EntitlementManager.has_entitlement(&"hull_weathered_grey"),
		"a local-only entitlement must never be removed by sync")


func test_launch_sync_is_a_no_op_when_signed_out():
	var calls := [0]
	EntitlementManager._request_override = func(_m, _e, _h, _b):
		calls[0] += 1
		return {"code": 200, "body": []}

	await EntitlementManager.check_cloud_sync_on_launch()

	assert_eq(calls[0], 0, "a signed-out launch check should never call the network")


func test_401_triggers_one_refresh_and_retry():
	_sign_in_fake()
	EntitlementManager._entitlements.erase(&"hull_deep_ocean_blue")
	var sync_calls := [0]
	EntitlementManager._request_override = func(_method, _endpoint, _headers, _body):
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

	EntitlementManager.grant(&"hull_deep_ocean_blue", "test")
	await wait_process_frames(3)

	assert_eq(refresh_calls[0], 1, "a 401 should trigger exactly one refresh attempt")
	assert_eq(sync_calls[0], 2, "the sync should retry exactly once after a successful refresh")
