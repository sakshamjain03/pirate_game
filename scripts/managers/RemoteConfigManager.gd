extends Node

## RemoteConfigManager.gd
## M15 Requirement 11 — a small set of values the game reads from the backend at runtime, so
## live content (seasonal event windows, an emergency kill-switch) can be adjusted without an
## app-store resubmission. Deliberately separate from AuthManager: remote_config is public,
## RLS-permissive-read data that needs no session, unlike everything else M15 builds.
##
## get_value(key, default)'s two-argument, always-returns-something contract is the entire
## point: every caller (M14's seasonal-event window, its kill-switch flag, anything added later)
## is structurally incapable of blocking on this or treating an absent key/failed fetch as an
## error — Requirement 11.3's "never block or degrade gameplay waiting on it," the same
## never-block-on-network discipline AuthManager's Requirement 1.4 already establishes.

const REMOTE_CONFIG_ENDPOINT := "/rest/v1/remote_config?select=key,value"

var _cache: Dictionary = {}
var _fetched: bool = false

## Test seam, mirrors AuthManager's/SaveManager's: when set, _send_request() calls this instead
## of a real HTTPRequest.
var _request_override: Callable = Callable()

func _ready() -> void:
	_fetch() # Fire-and-forget; never blocks _ready() or anything waiting on it.

## Always returns a usable value — fetched or not, present or not. Never blocks, never errors.
func get_value(key: String, default_value):
	return _cache.get(key, default_value)

func _fetch() -> void:
	var result: Dictionary = await _send_request()
	var code: int = result.get("code", 0)
	if code < 200 or code >= 300:
		# Leave _cache exactly as it was — empty on first launch, stale-but-usable on a later
		# failed refresh. Never clear it out from under a caller mid-session.
		_fetched = true
		return

	var body = result.get("body", [])
	if body is Array:
		for row in body:
			if row is Dictionary and row.has("key"):
				_cache[row["key"]] = row.get("value")
	_fetched = true

func _send_request() -> Dictionary:
	if _request_override.is_valid():
		return await _request_override.call()

	var headers := PackedStringArray(["apikey: %s" % AuthManager.SUPABASE_ANON_KEY])
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(AuthManager.SUPABASE_URL + REMOTE_CONFIG_ENDPOINT, headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {"code": 0, "body": []}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var parsed = []
	var text := response_body.get_string_from_utf8()
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) == OK:
			parsed = json.data
	return {"code": response_code, "body": parsed}
