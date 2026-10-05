extends GutTest
## M30 Wave 0 (0.7-0.10): cloud sync must never lose progress.
## 0.7 — a failed fetch used to look like "no cloud save", so the device's
##       state (even fresh defaults) was uploaded over a good cloud empire;
##       a cloud row from a newer game version is now refused, not downgraded.
## 0.8 — uploads: one in flight, only the newest snapshot queued, identical
##       snapshots skipped, a pending flag that survives a restart.
## 0.9 — the save is stamped with its account; signing into another account
##       asks before anything is uploaded; save_revision; ledger in the save.
## 0.10 — a readable status ("Cloud sync failing since …").
## Isolation mirrors test_save_manager_sync.gd: real autoloads, fakes on the
## HTTP seams, and the real user:// save backed up and restored.

const BACKUP := "user://save_data_test_backup_m30sync.json"

var _saved := {}
var _had_save := false
var _posts: Array = []
var _gets := 0
var _get_response := {"code": 200, "body": []}
var _post_code := 201
var _post_frames := 0


func before_each() -> void:
	_saved = {
		"access": AuthManager._access_token, "refresh": AuthManager._refresh_token,
		"user": AuthManager._user_id, "auth_override": AuthManager._request_override,
		"save_override": SaveManager._request_override, "pending": SaveManager._cloud_sync_pending,
		"revision": SaveManager._save_revision, "owner": SaveManager._save_owner_user_id,
		"state": SaveManager.sync_state, "launch": SaveManager._did_launch_cloud_check,
		"ledger": CampaignManager._chapter_eights_paid.duplicate(),
		"resources": ResourceManager.current_resources.duplicate(),
	}
	_had_save = SaveManager.has_save_data()
	if _had_save:
		DirAccess.copy_absolute(SaveManager.SAVE_PATH, BACKUP)
	_reset_sync()
	_posts = []
	_gets = 0
	_get_response = {"code": 200, "body": []}
	_post_code = 201
	_post_frames = 0
	SaveManager._request_override = func(method, endpoint, _h, body):
		if method == HTTPClient.METHOD_GET:
			_gets += 1
			await get_tree().process_frame
			return _get_response
		_posts.append(JSON.parse_string(body))
		for i in _post_frames:
			await get_tree().process_frame
		return {"code": _post_code, "body": {}}
	AuthManager._request_override = func(_m, _u, _h, _b):
		return {"code": 0, "body": {}}


func after_each() -> void:
	_reset_sync()
	AuthManager._access_token = _saved["access"]
	AuthManager._refresh_token = _saved["refresh"]
	AuthManager._user_id = _saved["user"]
	AuthManager._request_override = _saved["auth_override"]
	SaveManager._request_override = _saved["save_override"]
	SaveManager._cloud_sync_pending = _saved["pending"]
	SaveManager._save_revision = _saved["revision"]
	SaveManager._save_owner_user_id = _saved["owner"]
	SaveManager.sync_state = _saved["state"]
	SaveManager._did_launch_cloud_check = _saved["launch"]
	CampaignManager._chapter_eights_paid = _saved["ledger"]
	ResourceManager.current_resources = _saved["resources"]
	for d in get_tree().root.get_children():
		if d is ChoiceDialog:
			d.queue_free()
	if _had_save:
		DirAccess.copy_absolute(BACKUP, SaveManager.SAVE_PATH)
		DirAccess.remove_absolute(BACKUP)
	else:
		SaveManager.delete_save()


func _reset_sync() -> void:
	SaveManager._cloud_baseline_user = ""
	SaveManager._sync_refused_user = ""
	SaveManager._last_uploaded_hash = ""
	SaveManager._queued_upload = {}
	SaveManager._upload_in_flight = false
	SaveManager._load_blocked = false
	SaveManager.load_blocked_reason = ""
	SaveManager._suspend_autosave = false
	SaveManager._backoff_step = 0
	SaveManager._cancel_retry()
	if FileAccess.file_exists(SaveManager.CLOUD_PENDING_PATH):
		DirAccess.remove_absolute(SaveManager.CLOUD_PENDING_PATH)


func _sign_in(user := "user-b") -> void:
	AuthManager._access_token = "tok"
	AuthManager._refresh_token = "ref"
	AuthManager._user_id = user


func _write_local(extra: Dictionary) -> void:
	var data := {"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION, "last_saved_unix": 1000, "economy": {"gold": 5}}
	data.merge(extra, true)
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _row(save_data: Dictionary, schema := 1) -> Dictionary:
	return {"save_data": save_data, "save_schema_version": schema, "client_updated_at": "2020-01-01T00:00:00Z"}


# === 0.7 fetch guard ===

func test_fetch_error_holds_every_upload() -> void:
	_sign_in()
	_get_response = {"code": 503, "body": {}}
	await SaveManager._sync_with_cloud(false)
	SaveManager.save_game()
	await wait_process_frames(2)
	assert_eq(_posts.size(), 0, "a failed fetch must never be read as 'no cloud save'")
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_FAILING)
	assert_true(FileAccess.file_exists(SaveManager.CLOUD_PENDING_PATH), "the held upload is remembered")


func test_no_cloud_row_allows_uploads() -> void:
	_sign_in()
	_get_response = {"code": 200, "body": []}
	await SaveManager._sync_with_cloud(false)
	SaveManager.save_game()
	await wait_process_frames(2)
	assert_eq(_posts.size(), 1)
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_OK)


func test_newer_schema_cloud_row_blocks_saving() -> void:
	_sign_in()
	_write_local({"owner_user_id": "user-b"})
	var before := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	_get_response = {"code": 200, "body": [_row({"economy": {}}, SaveManager.SAVE_SCHEMA_VERSION + 1)]}
	await SaveManager._sync_with_cloud(false)
	SaveManager.save_game()
	await wait_process_frames(2)
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_BLOCKED)
	assert_eq(FileAccess.get_file_as_string(SaveManager.SAVE_PATH), before, "save_game must be a no-op")
	assert_eq(_posts.size(), 0)
	assert_string_contains(SaveManager.get_sync_status_text(), "newer version")


# === 0.8 upload queue ===

func test_rapid_saves_send_at_most_two_and_the_last_is_final() -> void:
	_sign_in()
	SaveManager._cloud_baseline_user = "user-b"
	_post_frames = 3
	ResourceManager.current_resources["gold"] = 101
	SaveManager.save_game()
	ResourceManager.current_resources["gold"] = 102
	SaveManager.save_game()
	ResourceManager.current_resources["gold"] = 103
	SaveManager.save_game()
	await wait_process_frames(12)
	assert_lte(_posts.size(), 2, "one in flight, only the newest queued")
	var last: Dictionary = _posts[_posts.size() - 1]["save_data"]
	assert_eq(int(last["economy"]["gold"]), 103, "the final state is what lands in the cloud")


func test_unchanged_snapshot_is_not_resent() -> void:
	_sign_in()
	SaveManager._cloud_baseline_user = "user-b"
	SaveManager.save_game()
	await wait_process_frames(3)
	var sent := _posts.size()
	SaveManager.save_game()  # same state, only last_saved_unix/save_revision differ
	await wait_process_frames(3)
	assert_eq(_posts.size(), sent, "an identical snapshot costs no request")


func test_pending_upload_survives_a_restart_and_flushes() -> void:
	_sign_in()
	SaveManager._cloud_baseline_user = "user-b"
	_post_code = 500
	SaveManager.save_game()
	await wait_process_frames(3)
	assert_true(FileAccess.file_exists(SaveManager.CLOUD_PENDING_PATH))
	# "Restart": fresh session state; the flag comes back from disk.
	_reset_sync_keep_pending_file()
	SaveManager._cloud_sync_pending = FileAccess.file_exists(SaveManager.CLOUD_PENDING_PATH)
	assert_true(SaveManager._cloud_sync_pending)
	_post_code = 201
	var before := _posts.size()
	_get_response = {"code": 200, "body": []}
	await SaveManager._sync_with_cloud(false)
	await wait_process_frames(3)
	assert_eq(_posts.size(), before + 1, "the held save is uploaded once the cloud state is known")
	assert_false(FileAccess.file_exists(SaveManager.CLOUD_PENDING_PATH))


func _reset_sync_keep_pending_file() -> void:
	SaveManager._cloud_baseline_user = ""
	SaveManager._last_uploaded_hash = ""
	SaveManager._queued_upload = {}
	SaveManager._upload_in_flight = false
	SaveManager._cancel_retry()


# === 0.9 account scope ===

func test_another_accounts_empire_asks_before_uploading() -> void:
	_write_local({"owner_user_id": "user-a"})
	_sign_in("user-b")
	_get_response = {"code": 200, "body": []}
	SaveManager._sync_with_cloud(false)  # suspends on the dialog
	await wait_process_frames(3)
	var dialog: ChoiceDialog = null
	for d in get_tree().root.get_children():
		if d is ChoiceDialog:
			dialog = d
	assert_not_null(dialog, "signing into B over A's empire must ask")
	assert_eq(_posts.size(), 0, "nothing is uploaded while the player decides")
	if dialog:
		dialog._on_choice(1)  # Don't Sync This Device
	await wait_process_frames(2)
	SaveManager.save_game()
	await wait_process_frames(2)
	assert_eq(_posts.size(), 0, "'Don't Sync' keeps A's empire out of B's cloud row")
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_BLOCKED)


func test_save_is_stamped_with_its_account_and_revision() -> void:
	_sign_in("user-b")
	SaveManager._cloud_baseline_user = "user-b"
	var rev := SaveManager._save_revision
	SaveManager.save_game()
	SaveManager.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	assert_eq(data.get("owner_user_id"), "user-b")
	assert_eq(int(data.get("save_revision")), rev + 2, "the revision increments on every save")


func test_eights_ledger_round_trips_in_the_save() -> void:
	CampaignManager._chapter_eights_paid["m30_test_ch"] = true
	SaveManager.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	assert_has(data.get("chapter_eights_paid", []), "m30_test_ch")
	CampaignManager._chapter_eights_paid.clear()
	CampaignManager.merge_eights_ledger(data["chapter_eights_paid"])
	assert_true(CampaignManager.has_paid_chapter_eights("m30_test_ch"))


func test_cloud_revision_ahead_counts_as_newer_despite_the_clock() -> void:
	var local := {"last_saved_unix": 9999999999, "save_revision": 4}
	var row := _row({"save_revision": 7})
	assert_true(SaveManager._cloud_is_newer(row, local), "a device with a fast clock must still be asked")
	assert_false(SaveManager._cloud_is_newer(_row({"save_revision": 2}), local))


# === 0.10 status ===

func test_status_reports_failing_since_and_recovers() -> void:
	_sign_in()
	SaveManager._cloud_baseline_user = "user-b"
	watch_signals(SaveManager)
	_post_code = 500
	SaveManager.save_game()
	await wait_process_frames(3)
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_FAILING)
	assert_gt(SaveManager.sync_since_unix, 0)
	assert_string_contains(SaveManager.get_sync_status_text(), "failing since")
	assert_signal_emitted(SaveManager, "sync_status_changed")
	_post_code = 201
	ResourceManager.current_resources["gold"] = int(ResourceManager.current_resources.get("gold", 0)) + 1
	SaveManager.save_game()
	await wait_process_frames(3)
	assert_eq(SaveManager.sync_state, SaveManager.SYNC_OK)
	assert_string_contains(SaveManager.get_sync_status_text(), "up to date")
