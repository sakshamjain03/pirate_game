extends GutTest

## M16 Requirements 1.3, 1.4, 1.6, 1.7, 5.3 — EntitlementManager's account-scoped
## store: idempotent grants, no quantity/count/balance field ever appears,
## survives a simulated new game and a simulated save deletion, and a
## malformed account file yields defaults rather than throwing or blocking.
## Touches the real EntitlementManager autoload directly, matching
## test_auth_manager.gd's save/restore-state convention for a manager that
## owns its own JSON file outside SaveManager.

const _TEST_COSMETIC_ID := &"sail_storm_torn"  # authored, non-default_owned

var _saved_entitlements: Dictionary
var _had_account_file: bool = false
var _account_backup_path := "user://account_data_test_backup.json"


func before_each():
	_saved_entitlements = EntitlementManager._entitlements.duplicate(true)

	if FileAccess.file_exists(EntitlementManager.ACCOUNT_DATA_PATH):
		_had_account_file = true
		var src := FileAccess.open(EntitlementManager.ACCOUNT_DATA_PATH, FileAccess.READ)
		var dst := FileAccess.open(_account_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()


func after_each():
	EntitlementManager._entitlements = _saved_entitlements.duplicate(true)

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


func test_granting_the_same_id_twice_is_idempotent():
	EntitlementManager._entitlements.erase(_TEST_COSMETIC_ID)

	var grant_count := [0]
	var on_granted := func(_id): grant_count[0] += 1
	EntitlementManager.entitlement_granted.connect(on_granted)

	EntitlementManager.grant(_TEST_COSMETIC_ID, "test")
	EntitlementManager.grant(_TEST_COSMETIC_ID, "test")

	EntitlementManager.entitlement_granted.disconnect(on_granted)

	assert_true(EntitlementManager.has_entitlement(_TEST_COSMETIC_ID))
	assert_eq(grant_count[0], 1, "entitlement_granted should fire exactly once across two grants of the same id")

	var ids := EntitlementManager.get_all_entitlement_ids()
	var occurrences := 0
	for id in ids:
		if id == _TEST_COSMETIC_ID:
			occurrences += 1
	assert_eq(occurrences, 1, "the entitlement set should have exactly one entry for a repeatedly-granted id")


func test_grant_of_unknown_cosmetic_id_is_rejected():
	EntitlementManager.grant(&"__not_a_real_cosmetic__", "test")
	assert_false(EntitlementManager.has_entitlement(&"__not_a_real_cosmetic__"))


func test_no_entitlement_record_ever_carries_a_quantity_style_field():
	EntitlementManager._entitlements.erase(_TEST_COSMETIC_ID)
	EntitlementManager.grant(_TEST_COSMETIC_ID, "test")

	var record: Dictionary = EntitlementManager._entitlements[_TEST_COSMETIC_ID]
	var forbidden_keys := ["quantity", "count", "balance", "amount", "stock"]
	for key in forbidden_keys:
		assert_false(record.has(key), "entitlement record must never carry a '%s' field" % key)
	assert_true(record.has("source"))
	assert_true(record.has("granted_at"))


func test_entitlement_survives_a_simulated_new_game():
	EntitlementManager._entitlements.erase(_TEST_COSMETIC_ID)
	EntitlementManager.grant(_TEST_COSMETIC_ID, "test")

	# MainMenu._on_new_game_pressed()'s own actions: delete the save, reset
	# ResourceManager. Neither touches EntitlementManager at all — that
	# absence of interaction IS the requirement (Req 1.3).
	SaveManager.delete_save()

	assert_true(EntitlementManager.has_entitlement(_TEST_COSMETIC_ID),
		"an entitlement must survive starting a new game")


func test_entitlement_survives_every_save_slot_being_deleted():
	EntitlementManager._entitlements.erase(_TEST_COSMETIC_ID)
	EntitlementManager.grant(_TEST_COSMETIC_ID, "test")

	SaveManager.delete_save()

	assert_true(EntitlementManager.has_entitlement(_TEST_COSMETIC_ID),
		"an entitlement must survive every save slot being deleted")


func test_malformed_account_file_yields_defaults_without_throwing():
	var file := FileAccess.open(EntitlementManager.ACCOUNT_DATA_PATH, FileAccess.WRITE)
	file.store_string("{")  # deliberately truncated/invalid JSON
	file.close()

	EntitlementManager.reload_account_data()

	for cosmetic in CosmeticCatalogue.get_all():
		if cosmetic.default_owned:
			assert_true(EntitlementManager.has_entitlement(cosmetic.id),
				"default_owned cosmetic '%s' should be re-seeded after a malformed account file" % cosmetic.id)


func test_empty_account_file_yields_defaults_without_throwing():
	var file := FileAccess.open(EntitlementManager.ACCOUNT_DATA_PATH, FileAccess.WRITE)
	file.store_string("")
	file.close()

	EntitlementManager.reload_account_data()

	for cosmetic in CosmeticCatalogue.get_all():
		if cosmetic.default_owned:
			assert_true(EntitlementManager.has_entitlement(cosmetic.id))
