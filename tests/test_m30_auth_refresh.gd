extends GutTest

func test_network_failure_code_0_keeps_session_and_sets_degraded():
	var auth = AuthManager
	auth._clear_session()
	await get_tree().process_frame

	auth._request_override = func(_method, _url, _headers, _body):
		await get_tree().process_frame  # Simulate async call
		return {"code": 0, "body": {}}

	auth._apply_session({"access_token": "token", "expires_in": 3600, "refresh_token": "refresh"})
	var original_signed_in = auth.is_signed_in()
	assert_true(original_signed_in)

	await auth.refresh_session()

	assert_true(auth.is_signed_in(), "Session should be kept on network failure")
	assert_true(auth.session_degraded, "Session should be marked as degraded")

func test_invalid_grant_clears_session():
	var auth = AuthManager
	auth._clear_session()
	await get_tree().process_frame

	auth._request_override = func(_method, _url, _headers, _body):
		await get_tree().process_frame
		return {"code": 400, "body": {"error": "invalid_grant"}}

	auth._apply_session({"access_token": "token", "expires_in": 3600, "refresh_token": "refresh"})
	assert_true(auth.is_signed_in())

	await auth.refresh_session()

	assert_false(auth.is_signed_in(), "Session should be cleared on invalid_grant")

func test_refresh_token_not_found_clears_session():
	var auth = AuthManager
	auth._clear_session()
	await get_tree().process_frame

	auth._request_override = func(_method, _url, _headers, _body):
		await get_tree().process_frame
		return {"code": 401, "body": {"error": "refresh_token_not_found"}}

	auth._apply_session({"access_token": "token", "expires_in": 3600, "refresh_token": "refresh"})
	assert_true(auth.is_signed_in())

	await auth.refresh_session()

	assert_false(auth.is_signed_in(), "Session should be cleared on refresh_token_not_found")

func test_server_error_5xx_keeps_session():
	var auth = AuthManager
	auth._clear_session()
	await get_tree().process_frame

	auth._request_override = func(_method, _url, _headers, _body):
		await get_tree().process_frame
		return {"code": 500, "body": {}}

	auth._apply_session({"access_token": "token", "expires_in": 3600, "refresh_token": "refresh"})
	assert_true(auth.is_signed_in())

	await auth.refresh_session()

	assert_true(auth.is_signed_in(), "Session should be kept on 5xx error")
	assert_true(auth.session_degraded, "Session should be marked as degraded")

func test_expires_at_is_tracked():
	var auth = AuthManager
	auth._clear_session()
	await get_tree().process_frame

	auth._apply_session({"access_token": "token", "expires_in": 3600, "refresh_token": "refresh"})

	assert_not_null(auth.expires_at, "expires_at should be set")
	var now = Time.get_ticks_msec()
	var expected = now + 3600000
	var delta = abs(auth.expires_at - expected)
	assert_lt(delta, 2000, "expires_at should be set to approximately now + expires_in")
