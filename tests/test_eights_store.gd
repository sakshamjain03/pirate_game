extends GutTest

## M27 Task 7 — Eights packs as store consumables (Requirement 6.1-6.6), end to end
## on StoreBackendStub. An order grants its Eights exactly once however often it is
## delivered or restored, and purchased Eights reach disk even when bought from the
## main menu (entering World reloads the economy from the save file).

const POUCH := &"eights_pouch"
const CHEST := &"eights_chest"
const EIGHTS := "eights"
## Every file a grant can write — the developer's real ones are kept aside.
const USER_FILES := ["user://save_data.json", "user://save_data.json.bak",
	"user://maelstrom_pending.json", "user://store_orders.json"]

var _file_backup := {}
var _resources_before: Dictionary
var _granted_before: Dictionary
var _owned_before: Dictionary
var _pending_claimed_before: bool


func before_each() -> void:
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)
	_resources_before = ResourceManager.current_resources.duplicate()
	ResourceManager.current_resources[EIGHTS] = 0
	_granted_before = StoreManager._granted_orders.duplicate()
	StoreManager._granted_orders.clear()
	_owned_before = StoreManager._backend._owned.duplicate()
	StoreManager._backend._owned.clear()
	StoreManager._backend.next_purchase_result = StoreBackendStub.RESULT_SUCCESS
	StoreManager.state = StoreManager.State.IDLE
	StoreManager._pending_sku = &""
	_pending_claimed_before = SaveManager._maelstrom_pending_claimed


func after_each() -> void:
	ResourceManager.current_resources = _resources_before
	StoreManager._granted_orders = _granted_before
	StoreManager._backend._owned = _owned_before
	StoreManager.state = StoreManager.State.IDLE
	StoreManager._pending_sku = &""
	SaveManager._maelstrom_pending_claimed = _pending_claimed_before
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


func _eights() -> int:
	return ResourceManager.get_resource(EIGHTS)


func _grant(sku: StringName) -> int:
	return StoreManager.get_product(sku).grants_eights


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func test_four_packs_are_authored_as_consumables() -> void:
	var packs := StoreManager.get_all_products().filter(func(p): return p.grants_eights > 0)
	assert_eq(packs.size(), 4)
	for p in packs:
		assert_true(p.entitlement_ids.is_empty(), "%s grants Eights, never an entitlement" % p.sku)
		assert_false(StoreManager.is_owned(p.sku), "a consumable is never 'owned'")
		assert_true(ResourceLoader.exists("res://resources/store/EightsPack%s.tres" % [
			{"eights_pouch": "Pouch", "eights_chest": "Chest", "eights_hoard": "Hoard", "eights_kings_ransom": "KingsRansom"}[String(p.sku)]]))


func test_existing_products_are_not_consumables() -> void:
	for p in StoreManager.get_all_products():
		if not p.entitlement_ids.is_empty():
			assert_eq(p.grants_eights, 0, "%s stays a non-consumable" % p.sku)


func test_a_stub_purchase_grants_once_and_can_be_bought_again() -> void:
	StoreManager.begin_purchase(POUCH)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)
	assert_eq(_eights(), _grant(POUCH))
	assert_false(StoreManager._backend._owned.has(POUCH), "consumed after granting")
	assert_eq(StoreManager.state, StoreManager.State.IDLE)

	StoreManager.begin_purchase(POUCH)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)
	assert_eq(_eights(), _grant(POUCH) * 2, "a consumable can be bought repeatedly")


func test_the_same_order_delivered_twice_grants_once() -> void:
	StoreManager._on_purchase_completed(POUCH, "dup_order_1")
	StoreManager._on_purchase_completed(POUCH, "dup_order_1")
	assert_eq(_eights(), _grant(POUCH))


func test_restore_never_grants_an_already_granted_order() -> void:
	StoreManager.begin_purchase(POUCH)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)
	var after_purchase := _eights()
	var order_id: String = StoreManager._granted_orders.keys()[0]

	StoreManager.restore_purchases()
	await wait_for_signal(StoreManager.restore_completed, 1.0)
	assert_eq(_eights(), after_purchase)

	# Even if the store reports it again (never consumed on its side).
	StoreManager._backend.seed_owned(POUCH, order_id)
	watch_signals(StoreManager)
	StoreManager.restore_purchases()
	await wait_for_signal(StoreManager.restore_completed, 1.0)
	assert_eq(_eights(), after_purchase)
	assert_eq(get_signal_parameters(StoreManager, "restore_completed"), [0])
	assert_false(StoreManager._backend._owned.has(POUCH), "the repeat is consumed")


func test_restore_recovers_an_order_that_never_granted_exactly_once() -> void:
	# The app died between payment and grant: the store still reports the order.
	StoreManager._backend.seed_owned(CHEST, "lost_order_1")
	StoreManager.restore_purchases()
	await wait_for_signal(StoreManager.restore_completed, 1.0)
	assert_eq(_eights(), _grant(CHEST), "a paid pack is never lost")

	StoreManager._backend.seed_owned(CHEST, "lost_order_1")
	StoreManager.restore_purchases()
	await wait_for_signal(StoreManager.restore_completed, 1.0)
	assert_eq(_eights(), _grant(CHEST), "...and never granted twice")


func test_granted_orders_persist_across_a_relaunch() -> void:
	StoreManager._on_purchase_completed(POUCH, "persist_order_1")
	StoreManager._granted_orders.clear()
	StoreManager._load_granted_orders()   # what _ready() does on the next launch
	assert_true(StoreManager._granted_orders.has("persist_order_1"))
	StoreManager._on_purchase_completed(POUCH, "persist_order_1")
	assert_eq(_eights(), _grant(POUCH))


func test_eights_bought_outside_world_reach_the_campaign_save() -> void:
	# The main-menu store: World would otherwise reload economy from disk and
	# silently drop the purchase.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION,
		"economy": {"gold": 10, EIGHTS: 5}, "campaign": {"chapter": 2}}))
	f.close()
	StoreManager._on_purchase_completed(POUCH, "menu_order_1")
	var saved := _read_json(SaveManager.SAVE_PATH)
	assert_eq(int(saved["economy"][EIGHTS]), 5 + _grant(POUCH))
	assert_eq(int(saved["economy"]["gold"]), 10, "nothing else in the save changes")
	assert_eq(int(saved["campaign"]["chapter"]), 2)


func test_eights_bought_before_any_save_wait_in_the_pending_file() -> void:
	StoreManager._on_purchase_completed(POUCH, "fresh_install_order_1")
	assert_false(FileAccess.file_exists(SaveManager.SAVE_PATH), "a purchase never creates a campaign save")
	assert_eq(int(_read_json(SaveManager.MAELSTROM_PENDING_PATH).get("eights", 0)), _grant(POUCH))


func test_a_consumable_without_an_order_id_grants_nothing() -> void:
	# push_errors by design.
	StoreManager._on_purchase_completed(POUCH, "")
	assert_eq(_eights(), 0)
