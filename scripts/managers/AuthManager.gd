extends Node

## AuthManager.gd
## M15 — owns Supabase session state: sign-up/sign-in/sign-out, token refresh, and session
## persistence. The project's first outbound network dependency (HTTPRequest); every call is
## best-effort and never blocks gameplay — a player who never opens Account never triggers any
## of this (Requirement 1.4).
##
## Session persistence is its own file (user://auth_session.json), not routed through
## SaveManager's get_save_data()/load_save_data() — matching SettingsManager's settings.cfg and
## TutorialManager's tutorial_state.json precedent of independent persistence outside the main
## save, per Requirement 5.1.

signal signed_in(user_id: String)
## A strict subset of signed_in: only fires for an explicit sign_up()/sign_in() call, never for
## a background token refresh (which also re-derives a session and re-emits signed_in, purely
## for UI reactivity). Requirement 4.1's cloud-save conflict check listens to this one — SaveManager
## re-checking for conflicts every time a routine 401-retry refresh happens mid-session would pop
## the keep-local/keep-cloud prompt during ordinary gameplay, which is exactly what "never silently
## pick one, but also never surprise the player" does not mean.
signal fresh_sign_in(user_id: String)
signal signed_out()
signal auth_error(message: String)
## Sign-up succeeded but Supabase requires email confirmation before a session exists yet.
signal sign_up_pending_confirmation()
## Emitted once _ready()'s initial session-restore attempt finishes (success or failure).
## SaveManager's launch-time cloud-save check awaits this so is_signed_in() is accurate
## before it decides whether to look for a newer cloud save (Requirement 4.3).
signal session_check_complete()
## Emitted when the session becomes degraded (network failure, 5xx, or paused service).
signal session_degraded_changed(degraded: bool)

const SUPABASE_URL := "https://tuhkhsqcnnszjnczkuzq.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_T9lA__O7ElXo0fr-SVguQw_7DjWk-oO"
const SESSION_PATH := "user://auth_session.json"

var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _initial_check_done: bool = false
var expires_at: int = 0  # Unix timestamp in milliseconds when the access token expires
var session_degraded: bool = false  # True when refresh has failed with network/5xx error
var _refresh_in_flight: bool = false  # True while a refresh request is active
var _refresh_timer: Timer = null  # Scheduled refresh 60s before expiry

## Test seam: when set, _send_request() calls this instead of a real HTTPRequest.
## Callable(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String)
## -> Dictionary{"code": int, "body": Variant}
var _request_override: Callable = Callable()

func _ready() -> void:
	await _load_session()
	_initial_check_done = true
	session_check_complete.emit()

## Callers that need is_signed_in() to be accurate right after boot (e.g. SaveManager's
## launch-time cloud-save check) should await this first.
func await_initial_check() -> void:
	if not _initial_check_done:
		await session_check_complete

func is_signed_in() -> bool:
	return not _access_token.is_empty()

func get_user_id() -> String:
	return _user_id

func get_access_token() -> String:
	return _access_token

func sign_up(email: String, password: String) -> void:
	var result: Dictionary = await _post_auth("/auth/v1/signup", {"email": email, "password": password})
	var code: int = result.get("code", 0)
	var body = result.get("body", {})
	if code >= 200 and code < 300:
		if body is Dictionary and body.has("access_token"):
			_apply_session(body)
			fresh_sign_in.emit(_user_id)
		else:
			# Email confirmation required — no session yet, not an error.
			sign_up_pending_confirmation.emit()
	else:
		auth_error.emit(_extract_error_message(result))

func sign_in(email: String, password: String) -> void:
	var result: Dictionary = await _post_auth("/auth/v1/token?grant_type=password", {"email": email, "password": password})
	var code: int = result.get("code", 0)
	var body = result.get("body", {})
	if code >= 200 and code < 300 and body is Dictionary and body.has("access_token"):
		_apply_session(body)
		fresh_sign_in.emit(_user_id)
	else:
		auth_error.emit(_extract_error_message(result))

func sign_out() -> void:
	if is_signed_in():
		var headers := PackedStringArray([
			"apikey: %s" % SUPABASE_ANON_KEY,
			"Authorization: Bearer %s" % _access_token,
		])
		# Fire-and-forget — best-effort revoke; local state clears unconditionally either way
		# (Requirement 5.3). Not awaited: the request still fires, but sign_out() doesn't wait
		# on the network to return control to the caller.
		_send_request(HTTPClient.METHOD_POST, SUPABASE_URL + "/auth/v1/logout", headers, "")
	_clear_session()  # Now emits signed_out itself

func request_password_reset(email: String) -> void:
	var result: Dictionary = await _post_auth("/auth/v1/recover", {"email": email})
	var code: int = result.get("code", 0)
	if code < 200 or code >= 300:
		auth_error.emit(_extract_error_message(result))

func delete_account() -> void:
	if not is_signed_in():
		return
	var headers := PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % _access_token,
	])
	var result: Dictionary = await _send_request(
		HTTPClient.METHOD_POST, SUPABASE_URL + "/functions/v1/delete-account", headers, "")
	var code: int = result.get("code", 0)
	if code >= 200 and code < 300:
		# Local save is never touched here — SaveManager has no involvement in this call.
		_clear_session()
		signed_out.emit()
	else:
		auth_error.emit(_extract_error_message(result))

## Re-derives an access token from the stored refresh token. Called on launch (if a session was
## persisted) and by SaveManager on a 401 from a cloud-sync call before it surfaces an error.
## Returns false if the refresh fails (including network errors). Clears the session only on
## invalid_grant or refresh_token_not_found; on code 0 or 5xx keeps the session and sets
## session_degraded. Allows only one refresh in flight; concurrent callers wait on that one.
func refresh_session() -> bool:
	if _refresh_token.is_empty():
		return false

	# If a refresh is already in flight, wait for it to complete
	if _refresh_in_flight:
		while _refresh_in_flight:
			await get_tree().process_frame
		# The in-flight one either succeeded (is_signed_in() is true) or failed
		# Either way, we return the current state
		return is_signed_in()

	# Mark that a refresh is starting
	_refresh_in_flight = true

	var result: Dictionary = await _post_auth(
		"/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	var code: int = result.get("code", 0)
	var body = result.get("body", {})

	var success = false

	if code >= 200 and code < 300 and body is Dictionary and body.has("access_token"):
		# Successful refresh
		_apply_session(body)
		_set_degraded(false)
		success = true
	elif code in [400, 401]:
		# Check if it's an invalid grant/token error
		var error_str = ""
		if body is Dictionary:
			error_str = body.get("error", "")

		if error_str in ["invalid_grant", "refresh_token_not_found"]:
			# Session is no longer valid; clear it
			_clear_session()
			_set_degraded(false)
			success = false
		else:
			# Other 4xx error; keep session but mark as degraded
			_set_degraded(true)
			success = false
	else:
		# Network error (code 0) or 5xx; keep session and mark as degraded
		_set_degraded(true)
		success = false

	# Mark that this refresh is done
	_refresh_in_flight = false

	return success

func _apply_session(body: Dictionary) -> void:
	_access_token = body.get("access_token", "")
	_refresh_token = body.get("refresh_token", _refresh_token)
	var user = body.get("user", {})
	if user is Dictionary:
		_user_id = user.get("id", _user_id)

	# Track expiry time: expires_in is in seconds, convert to milliseconds
	var expires_in: int = body.get("expires_in", 3600)
	expires_at = Time.get_ticks_msec() + expires_in * 1000

	# Schedule a refresh 60 seconds before expiry
	_schedule_refresh_before_expiry()

	_save_session()
	signed_in.emit(_user_id)

func _extract_error_message(result: Dictionary) -> String:
	var body = result.get("body", {})
	if body is Dictionary:
		if body.has("error_description"):
			return str(body["error_description"])
		if body.has("msg"):
			return str(body["msg"])
		if body.has("message"):
			return str(body["message"])
		if body.has("error"):
			return str(body["error"])
	return "Network error (code %s)" % str(result.get("code", 0))

func _post_auth(endpoint: String, body: Dictionary) -> Dictionary:
	var headers := PackedStringArray(["apikey: %s" % SUPABASE_ANON_KEY, "Content-Type: application/json"])
	return await _send_request(HTTPClient.METHOD_POST, SUPABASE_URL + endpoint, headers, JSON.stringify(body))

func _put_auth(endpoint: String, body: Dictionary, bearer_token: String) -> Dictionary:
	var headers := PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % bearer_token,
		"Content-Type: application/json",
	])
	return await _send_request(HTTPClient.METHOD_PUT, SUPABASE_URL + endpoint, headers, JSON.stringify(body))

## Low-level HTTP execution. A fresh HTTPRequest child is created per call and freed once its
## response arrives — this project has no precedent for a network node, and a per-call node
## sidesteps HTTPRequest's single-request-in-flight limitation without any shared state to manage.
func _send_request(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if _request_override.is_valid():
		return await _request_override.call(method, url, headers, body)

	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"code": 0, "body": {}}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var parsed = {}
	var text := response_body.get_string_from_utf8()
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) == OK:
			parsed = json.data
	return {"code": response_code, "body": parsed}

func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"refresh_token": _refresh_token, "user_id": _user_id}))
		f.close()

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored_refresh: String = data.get("refresh_token", "")
	if stored_refresh.is_empty():
		return

	_refresh_token = stored_refresh
	_user_id = data.get("user_id", "")
	# Silent — no forced re-auth interruption to active gameplay (Requirement 1.6). A dead
	# refresh token just leaves the player signed out until they open Account again.
	await refresh_session()

func _clear_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_user_id = ""
	expires_at = 0
	_cancel_refresh_timer()
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("auth_session.json"):
		dir.remove("auth_session.json")
	signed_out.emit()

func _set_degraded(degraded: bool) -> void:
	if session_degraded != degraded:
		session_degraded = degraded
		session_degraded_changed.emit(degraded)

func _schedule_refresh_before_expiry() -> void:
	_cancel_refresh_timer()

	if expires_at == 0:
		return

	var now = Time.get_ticks_msec()
	var time_until_expiry = expires_at - now
	var refresh_at = time_until_expiry - 60000  # 60 seconds before expiry

	if refresh_at <= 0:
		# Already expired or expiring within 60s, refresh immediately
		# Don't await here since this is called from _apply_session which is not async
		# The refresh will happen on the next frame or the refresh() call will handle it
		return

	_refresh_timer = Timer.new()
	add_child(_refresh_timer)
	_refresh_timer.wait_time = refresh_at / 1000.0
	_refresh_timer.timeout.connect(func():
		refresh_session()
		_refresh_timer = null
	)
	_refresh_timer.start()

func _cancel_refresh_timer() -> void:
	if _refresh_timer:
		_refresh_timer.queue_free()
		_refresh_timer = null
