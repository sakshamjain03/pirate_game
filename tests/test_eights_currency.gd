extends GutTest

## Guards Pieces of Eight, the single premium currency (M25).
##
## The rule these tests exist to enforce is constitutional, not mechanical
## (`docs/00_VISION.md` §19.2 / `AGENTS.md`):
##
##   - exactly ONE premium currency, never a second;
##   - it is NEVER granted by island production or the economy tick;
##   - a zero-spend player can still earn and hold it.
##
## The production rule is the dangerous one. If a building is ever authored with
## `produces_resource = "eights"`, the entire monetization model breaks quietly —
## premium currency becomes farmable and every price in the game is wrong. So it
## fails loudly rather than being skipped, and that behaviour is pinned here.

const PREMIUM := "eights"

var _saved_resources: Dictionary


func before_each() -> void:
	_saved_resources = ResourceManager.current_resources.duplicate(true)


func after_each() -> void:
	ResourceManager.current_resources = _saved_resources.duplicate(true)


func test_eights_is_a_declared_resource() -> void:
	assert_true(ResourceManager.current_resources.has(PREMIUM),
		"Eights must be a declared resource or add_resource() rejects it as a data bug")
	assert_true(ResourceManager.max_storage.has(PREMIUM),
		"Eights must have a declared cap or recalculate_storage_capacity() drops it")


func test_there_is_exactly_one_premium_currency() -> void:
	assert_eq(ResourceManager.PREMIUM_CURRENCY, PREMIUM)
	assert_true(ResourceManager.is_premium_currency(PREMIUM))
	assert_true(ResourceManager.is_premium_currency("EIGHTS"), "should be case-insensitive")
	for key in ResourceManager.current_resources.keys():
		if key == PREMIUM:
			continue
		assert_false(ResourceManager.is_premium_currency(key),
			"'%s' must not also be treated as premium currency — AGENTS.md permits exactly one" % key)


func test_eights_can_be_granted_and_spent() -> void:
	var before: int = int(ResourceManager.get_resource(PREMIUM))
	ResourceManager.add_resource(PREMIUM, 50)
	assert_eq(int(ResourceManager.get_resource(PREMIUM)), before + 50)
	assert_true(ResourceManager.can_afford({PREMIUM: 30}))
	assert_true(ResourceManager.spend_resources({PREMIUM: 30}))
	assert_eq(int(ResourceManager.get_resource(PREMIUM)), before + 20)


func test_eights_cap_does_not_destroy_a_realistic_balance() -> void:
	# A purchased balance silently clamped away would be a refund request.
	assert_gte(int(ResourceManager.max_storage[PREMIUM]), 10000,
		"The Eights cap must be a practical ceiling, not a balance lever")


func test_storage_recalculation_keeps_the_eights_cap() -> void:
	# recalculate_storage_capacity() REBUILDS max_storage from a literal; a key
	# omitted there loses its cap on the first building constructed. That exact bug
	# already happened once with `research` (D50).
	ResourceManager.recalculate_storage_capacity()
	assert_true(ResourceManager.max_storage.has(PREMIUM),
		"recalculate_storage_capacity() dropped the Eights cap — see D50 for the same bug in `research`")


func test_island_production_cannot_mint_eights() -> void:
	# THE guard. An island asked to produce premium currency must grant nothing.
	var island := Node3D.new()
	island.set_script(load("res://scripts/world/Island.gd"))
	add_child_autoqfree(island)

	var before: int = int(ResourceManager.get_resource(PREMIUM))
	# This call push_errors by design — that loudness IS the behaviour under test.
	island._produce_resource(PREMIUM, 100)

	assert_eq(
		int(ResourceManager.get_resource(PREMIUM)), before,
		"Island production minted premium currency — docs/00_VISION.md §19.2 forbids this, and it "
		+ "would make Eights farmable and every price in the game wrong"
	)


func test_island_production_still_works_for_normal_resources() -> void:
	# The guard must not have broken the ordinary economy path.
	var island := Node3D.new()
	island.set_script(load("res://scripts/world/Island.gd"))
	add_child_autoqfree(island)

	# Start well under the storage cap: earlier suites can leave wood sitting at
	# max_storage, where +5 clamps to +0 and this failed depending on test order.
	ResourceManager.current_resources["wood"] = 0
	var before: int = int(ResourceManager.get_resource("wood"))
	island._produce_resource("wood", 5)
	assert_eq(int(ResourceManager.get_resource("wood")), before + 5,
		"The premium guard must not block normal production")


func test_no_authored_building_produces_eights() -> void:
	# Belt and braces alongside the runtime guard: catch it at author time too.
	var offenders: Array[String] = []
	var dir := DirAccess.open("res://resources/buildings/")
	if dir:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".tres"):
				var building = load("res://resources/buildings/" + entry)
				if building and str(building.get("produces_resource")).to_lower() == PREMIUM:
					offenders.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	assert_eq(offenders, [] as Array[String],
		"Buildings authored to produce premium currency: %s" % str(offenders))


func test_shipping_chapters_grant_eights_so_a_free_player_holds_some() -> void:
	# The heat clear needs a sink the player already has. If no shipping chapter
	# grants Eights, a zero-spend player can never use the feature, and the currency
	# only ever appears attached to a purchase prompt.
	var total := 0
	var dir := DirAccess.open("res://resources/campaign/chapters/")
	assert_not_null(dir)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var chapter = load("res://resources/campaign/chapters/" + entry)
			if chapter and ResourceLookup.is_content_enabled(chapter):
				total += int(chapter.reward_eights)
		entry = dir.get_next()
	dir.list_dir_end()
	assert_gt(total, 0,
		"No shipping chapter grants Eights — a zero-spend player would never hold any")
