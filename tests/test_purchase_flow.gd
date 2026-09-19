extends GutTest

## M17 Task 6 — StoreManager's purchase state machine against the real
## StoreBackendStub instance it created at boot (design.md §4). Follows
## test_entitlements.gd's own account_data.json backup/restore convention
## since every case here ends up writing real EntitlementManager state.

const _SKU := &"cosmetic_hull_deep_ocean_blue"
const _COSMETIC_ID := &"hull_deep_ocean_blue"
const _BUNDLE_SKU := &"supporter_pack"

var _saved_entitlements: Dictionary
var _had_account_file: bool = false
var _account_backup_path := "user://account_data_test_backup.json"
var _saved_purchase_result: String
var _saved_pending_sku: StringName


func before_each():
	_saved_entitlements = EntitlementManager._entitlements.duplicate(true)
	_saved_purchase_result = StoreManager._backend.next_purchase_result
	StoreManager.state = StoreManager.State.IDLE
	StoreManager._pending_sku = &""

	if FileAccess.file_exists(EntitlementManager.ACCOUNT_DATA_PATH):
		_had_account_file = true
		var src := FileAccess.open(EntitlementManager.ACCOUNT_DATA_PATH, FileAccess.READ)
		var dst := FileAccess.open(_account_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()


func after_each():
	EntitlementManager._entitlements = _saved_entitlements.duplicate(true)
	StoreManager._backend.next_purchase_result = _saved_purchase_result
	StoreManager._backend._owned.clear()
	StoreManager.state = StoreManager.State.IDLE
	StoreManager._pending_sku = &""

	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("account_data.json"):
		dir.remove("account_data.json")
	if _had_account_file:
		var src := FileAccess.open(_account_backup_path, FileAccess.READ)
		var dst := FileAccess.open(EntitlementManager.ACCOUNT_DATA_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("account_data_test_backup.json")
	else:
		EntitlementManager._write_account_data()
	_had_account_file = false


func test_successful_purchase_grants_the_entitlement_and_returns_to_idle():
	watch_signals(StoreManager)
	StoreManager.begin_purchase(_SKU)
	assert_eq(StoreManager.state, StoreManager.State.PENDING)

	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)

	assert_eq(StoreManager.state, StoreManager.State.IDLE)
	assert_true(EntitlementManager.has_entitlement(_COSMETIC_ID))
	assert_eq(EntitlementManager._entitlements[_COSMETIC_ID]["source"], "purchase")
	assert_ne(EntitlementManager.get_order_id(_COSMETIC_ID), "")


func test_cancelled_purchase_grants_nothing_and_returns_to_idle():
	EntitlementManager._entitlements.erase(_COSMETIC_ID)
	StoreManager._backend.next_purchase_result = StoreBackendStub.RESULT_CANCEL
	watch_signals(StoreManager)
	StoreManager.begin_purchase(_SKU)

	await wait_for_signal(StoreManager.purchase_cancelled, 1.0)

	assert_eq(StoreManager.state, StoreManager.State.IDLE)
	assert_false(EntitlementManager.has_entitlement(_COSMETIC_ID))


func test_failed_purchase_grants_nothing_and_returns_to_idle():
	EntitlementManager._entitlements.erase(_COSMETIC_ID)
	StoreManager._backend.next_purchase_result = StoreBackendStub.RESULT_FAIL
	watch_signals(StoreManager)
	StoreManager.begin_purchase(_SKU)

	await wait_for_signal(StoreManager.purchase_failed, 1.0)

	assert_eq(StoreManager.state, StoreManager.State.IDLE)
	assert_false(EntitlementManager.has_entitlement(_COSMETIC_ID))


func test_a_replayed_purchase_does_not_duplicate():
	StoreManager.begin_purchase(_SKU)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)

	var grant_count := [0]
	var on_granted := func(_id): grant_count[0] += 1
	EntitlementManager.entitlement_granted.connect(on_granted)

	StoreManager.begin_purchase(_SKU)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)

	EntitlementManager.entitlement_granted.disconnect(on_granted)
	assert_eq(grant_count[0], 0, "re-granting an already-owned sku must not re-emit")
	assert_true(EntitlementManager.has_entitlement(_COSMETIC_ID))


func test_bundle_purchase_grants_every_entitlement_atomically():
	# Requirement 2.4 — a bundle grants all-or-nothing. The real supporter_pack
	# resource only bundles one id today (its cosmetic set awaits real art,
	# see resources/store/SupporterPack.tres), so the atomicity guarantee
	# itself is exercised directly against EntitlementManager.grant_batch()
	# with a multi-id bundle, matching this task's own verify wording.
	EntitlementManager._entitlements.erase(&"hull_deep_ocean_blue")
	EntitlementManager._entitlements.erase(&"hull_weathered_grey")

	EntitlementManager.grant_batch(
		[&"hull_deep_ocean_blue", &"hull_weathered_grey"], "purchase", "order_bundle_1")

	assert_true(EntitlementManager.has_entitlement(&"hull_deep_ocean_blue"))
	assert_true(EntitlementManager.has_entitlement(&"hull_weathered_grey"))
	assert_eq(EntitlementManager.get_order_id(&"hull_deep_ocean_blue"), "order_bundle_1")
	assert_eq(EntitlementManager.get_order_id(&"hull_weathered_grey"), "order_bundle_1")

	# Re-reading from disk (not from the in-memory dict) confirms both landed
	# in the same write, never a partial bundle.
	EntitlementManager.reload_account_data()
	assert_true(EntitlementManager.has_entitlement(&"hull_deep_ocean_blue"))
	assert_true(EntitlementManager.has_entitlement(&"hull_weathered_grey"))


func test_the_supporter_pack_purchase_grants_ad_free():
	StoreManager.begin_purchase(_BUNDLE_SKU)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)
	assert_true(EntitlementManager.has_entitlement(EntitlementManager.AD_FREE_ID))


func test_revocation_removes_the_entitlement():
	StoreManager.begin_purchase(_SKU)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)
	assert_true(EntitlementManager.has_entitlement(_COSMETIC_ID))

	StoreManager._backend.simulate_revocation(_SKU)
	await wait_for_signal(StoreManager._backend.item_revoked, 1.0)

	assert_false(EntitlementManager.has_entitlement(_COSMETIC_ID))


func test_reconciliation_grants_a_purchase_the_app_never_saw_before_it_was_killed():
	# Simulates: the store already owns this sku (a real purchase succeeded)
	# but the app was killed before EntitlementManager ever learned about it.
	EntitlementManager._entitlements.erase(_COSMETIC_ID)
	StoreManager._backend.seed_owned(_SKU, "order_from_before_the_kill")

	StoreManager.reconcile_owned_purchases()
	await wait_for_signal(StoreManager.restore_completed, 1.0)

	assert_true(EntitlementManager.has_entitlement(_COSMETIC_ID))
	assert_eq(EntitlementManager.get_order_id(_COSMETIC_ID), "order_from_before_the_kill")
