extends GutTest

## Purpose: enforce the dev-tools safety contract (AGENTS.md "Dev-tools gate").
##
## The dev console can reach any game state — max resources, jump chapters,
## downgrade ships, capture islands. The ONLY thing keeping it out of a player's
## hands is a strict one-way dependency: debug code may call shipping code, and
## shipping code may never reference debug code. If that is ever violated, the
## export exclusion stops protecting anything, because a shipping script would
## fail to load without the file it references.
##
## This test is the thing that keeps that rule true six months from now, when
## nobody remembers it. It is cheap and it should never be deleted.

const DEBUG_DIRS := ["scripts/debug/", "scenes/debug/"]
const SHIPPING_ROOTS := ["res://scripts/", "res://scenes/", "res://resources/"]
## Debug code referencing debug code is the whole point, so those paths are the
## one exemption. `tests/` is excluded too: a test may legitimately name a debug
## path (this file does).
const EXEMPT_PREFIXES := ["res://scripts/debug/", "res://scenes/debug/", "res://tests/"]


func _collect_files(root: String, out: Array) -> void:
	var dir := DirAccess.open(root)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_files(full, out)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_exempt(path: String) -> bool:
	for prefix in EXEMPT_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func test_no_shipping_file_references_the_debug_folders() -> void:
	var files: Array = []
	for root in SHIPPING_ROOTS:
		_collect_files(root, files)
	assert_gt(files.size(), 100, "Sanity: the scan should find the whole project")

	var offenders: Array[String] = []
	for path in files:
		if _is_exempt(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		for needle in DEBUG_DIRS:
			if text.contains(needle):
				offenders.append("%s references %s" % [path, needle])

	assert_eq(
		offenders, [] as Array[String],
		"Shipping code must never reference the debug folders — the dev console would then "
		+ "ship, or the build would break once export excludes it. Offenders: %s" % str(offenders)
	)


func test_project_does_not_autoload_anything_from_debug() -> void:
	# An autoload entry would load the console in every build, bypassing the
	# harness-scene entry point entirely.
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_false(text.is_empty(), "project.godot should be readable")
	var autoload_block := ""
	var in_block := false
	for line in text.split("\n"):
		if line.begins_with("[autoload]"):
			in_block = true
			continue
		if in_block and line.begins_with("["):
			break
		if in_block:
			autoload_block += line + "\n"
	for needle in DEBUG_DIRS:
		assert_false(
			autoload_block.contains(needle),
			"project.godot autoloads %s — the dev console must only be reachable through "
			% needle + "scenes/debug/DevHarness.tscn"
		)


func test_dev_console_and_harness_exist_where_the_contract_says() -> void:
	assert_true(
		FileAccess.file_exists("res://scripts/debug/DevConsole.gd"),
		"DevConsole.gd must live in scripts/debug/ so the export filter catches it"
	)
	assert_true(
		FileAccess.file_exists("res://scenes/debug/DevHarness.tscn"),
		"DevHarness.tscn is the only sanctioned entry point to the dev console"
	)


func test_dev_console_script_parses() -> void:
	# Nothing in the shipping game imports DevConsole.gd — that is the whole
	# point — which also means the GUT suite would never notice it failing to
	# parse. This is the only thing standing between the console and silent rot.
	var script := load("res://scripts/debug/DevConsole.gd")
	assert_not_null(script, "DevConsole.gd failed to load — it has a parse error")
	assert_true(script is GDScript, "DevConsole.gd should load as a GDScript")
	if script is GDScript:
		assert_true(script.can_instantiate(), "DevConsole.gd should be instantiable")


func test_dev_harness_scene_loads() -> void:
	var packed := load("res://scenes/debug/DevHarness.tscn")
	assert_not_null(packed, "DevHarness.tscn failed to load")
	assert_true(packed is PackedScene, "DevHarness.tscn should load as a PackedScene")
