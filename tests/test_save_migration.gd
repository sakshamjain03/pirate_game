extends GutTest

## M12 Tasks 3–4 — schema migration is deliberately pure, so historical saves
## can be checked without touching the user's real save or backup files.

func test_unversioned_islands_migrate_to_schema_one():
	var migrated := SaveManager._migrate({
		"islands": {"tortuga": ["farm_l1", "mine_l2"]},
	}, 0)
	assert_eq(migrated.get("save_schema_version"), SaveManager.SAVE_SCHEMA_VERSION)
	assert_eq(migrated["islands"]["tortuga"]["buildings"], ["farm_l1", "mine_l2"])
	assert_false(migrated["islands"]["tortuga"]["discovered"])


func test_migration_keeps_existing_discovery_data():
	var migrated := SaveManager._migrate({
		"islands": {"tortuga": {"buildings": ["farm_l1"], "discovered": true}},
	}, 0)
	assert_true(migrated["islands"]["tortuga"]["discovered"])


func test_current_schema_is_not_rewritten():
	var source := {"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION, "economy": {"gold": 42}}
	assert_eq(SaveManager._migrate(source, SaveManager.SAVE_SCHEMA_VERSION), source)
