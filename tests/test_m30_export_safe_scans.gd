extends GutTest
## M30 Wave 0: authored content was discovered with raw DirAccess scans that
## matched `ends_with(".tres")`. An exported build converts text resources to
## binary and leaves `X.tres.remap` in the pack instead of `X.tres`, so on an
## Android build those scans find nothing — no chapters (CampaignManager), no
## factions, regions, events, store products or seasonal events. Every scan of
## authored content now goes through ResourceLookup.list_resource_paths().

const SCAN_DIR := "user://m30_export_scan_test/"


func after_each() -> void:
	var dir := DirAccess.open(SCAN_DIR)
	if dir:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(SCAN_DIR)


func _touch(file_name: String) -> void:
	var f := FileAccess.open(SCAN_DIR + file_name, FileAccess.WRITE)
	f.store_string("")
	f.close()


func test_exported_remap_names_resolve_to_tres_paths() -> void:
	DirAccess.make_dir_recursive_absolute(SCAN_DIR)
	_touch("Alpha.tres.remap")   # what an export leaves behind
	_touch("Beta.tres")          # what the editor sees
	_touch("Gamma.gd")           # never content
	_touch("Delta.png.import")
	var paths := ResourceLookup.list_resource_paths(SCAN_DIR)
	assert_eq(Array(paths), [SCAN_DIR + "Alpha.tres", SCAN_DIR + "Beta.tres"])


func test_path_without_trailing_slash() -> void:
	DirAccess.make_dir_recursive_absolute(SCAN_DIR)
	_touch("Only.tres")
	assert_eq(Array(ResourceLookup.list_resource_paths(SCAN_DIR.trim_suffix("/"))), [SCAN_DIR + "Only.tres"])


func test_missing_directory_is_empty() -> void:
	assert_eq(ResourceLookup.list_resource_paths("user://no_such_dir_m30/").size(), 0)


func test_no_raw_tres_scans_remain() -> void:
	# The only places allowed to match ".tres" by hand are the helper itself and
	# CosmeticCatalogue's recursive scan, which strips ".remap" explicitly.
	var allowed := ["res://scripts/world/ResourceLookup.gd", "res://scripts/core/CosmeticCatalogue.gd"]
	var offenders: Array = []
	for path in _all_scripts("res://scripts/"):
		if allowed.has(path):
			continue
		if FileAccess.get_file_as_string(path).contains("ends_with(\".tres\")"):
			offenders.append(path)
	assert_eq(offenders, [], "raw .tres scans break on exported builds; use ResourceLookup.list_resource_paths()")


func _all_scripts(root: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(root)
	if not dir:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_all_scripts(root + d + "/"))
	return out
