extends GutTest

# test_cosmetics.gd
# M16 Requirements 2.1, 2.3, 2.6 — every authored CosmeticData .tres must match
# the exported schema exactly (the D3/D14 silent-typo hazard: a property set
# in a .tres that the script doesn't actually @export is dropped without
# error), no two cosmetics may share an id, and no cosmetic may carry a
# gameplay-affecting field — enforced here as a locked allow-list so a future
# edit to CosmeticData.gd that adds a stat/modifier field breaks this test
# immediately rather than silently shipping.

const _ALLOWED_PROPERTIES := [
	"id", "display_name", "description", "slot", "rarity_label", "icon",
	"default_owned", "albedo_texture", "tint", "mesh_override",
]

const _DUP_FIXTURE_DIR := "user://test_fixtures_cosmetics_dup/"


func test_every_authored_cosmetic_matches_the_exact_schema():
	var all_cosmetics := CosmeticCatalogue.get_all()
	assert_gt(all_cosmetics.size(), 0, "expected at least one authored cosmetic to test against")
	for cosmetic in all_cosmetics:
		for prop in cosmetic.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			assert_true(_ALLOWED_PROPERTIES.has(prop.name),
				"cosmetic '%s' (%s) has an out-of-schema property '%s' — either a gameplay-affecting field slipped in, or CosmeticData.gd's schema changed without updating this test" % [
					cosmetic.id, cosmetic.resource_path, prop.name])


func test_no_two_authored_cosmetics_share_an_id():
	var seen: Dictionary = {}
	for cosmetic in CosmeticCatalogue.get_all():
		assert_false(seen.has(cosmetic.id),
			"duplicate cosmetic id '%s' — CosmeticCatalogue._register() should have already caught this at scan time" % cosmetic.id)
		seen[cosmetic.id] = true


func test_every_default_owned_cosmetic_has_a_resolvable_id():
	for cosmetic in CosmeticCatalogue.get_all():
		if not cosmetic.default_owned:
			continue
		assert_false(String(cosmetic.id).is_empty(),
			"a default_owned cosmetic at '%s' has an empty id" % cosmetic.resource_path)
		assert_eq(CosmeticCatalogue.get_cosmetic(cosmetic.id), cosmetic)


func test_duplicate_id_across_two_resources_is_reported_and_only_one_survives():
	DirAccess.make_dir_recursive_absolute(_DUP_FIXTURE_DIR)

	var a := CosmeticData.new()
	a.id = &"__test_dup_id__"
	a.display_name = "Fixture A"
	a.slot = "hull"
	var b := CosmeticData.new()
	b.id = &"__test_dup_id__"
	b.display_name = "Fixture B"
	b.slot = "hull"

	assert_eq(ResourceSaver.save(a, _DUP_FIXTURE_DIR + "a.tres"), OK)
	assert_eq(ResourceSaver.save(b, _DUP_FIXTURE_DIR + "b.tres"), OK)

	CosmeticCatalogue.set_scan_root_for_testing(_DUP_FIXTURE_DIR)

	var resolved := CosmeticCatalogue.get_cosmetic(&"__test_dup_id__")
	assert_not_null(resolved, "one of the two conflicting resources should still resolve")
	assert_eq(CosmeticCatalogue.get_all().size(), 1,
		"the second resource sharing an id must be rejected, not silently added alongside the first")

	CosmeticCatalogue.restore_default_scan_root_for_testing()
	DirAccess.remove_absolute(_DUP_FIXTURE_DIR + "a.tres")
	DirAccess.remove_absolute(_DUP_FIXTURE_DIR + "b.tres")
	DirAccess.remove_absolute(_DUP_FIXTURE_DIR)
