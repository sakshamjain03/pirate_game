class_name CosmeticCatalogue

## CosmeticCatalogue
## Lazily scans every CosmeticData resource under resources/cosmetics/** on
## first access and indexes it by id and by slot. A plain static utility, not
## an autoload — there is no per-frame state and nothing to signal, so this
## does not earn a fourteenth singleton (design.md §6).

const COSMETICS_ROOT := "res://resources/cosmetics/"

static var _scan_root: String = COSMETICS_ROOT
static var _by_id: Dictionary = {}
static var _by_slot: Dictionary = {}
static var _scanned: bool = false


static func get_cosmetic(id: StringName) -> CosmeticData:
	_ensure_scanned()
	return _by_id.get(id, null)


static func get_by_slot(slot: String) -> Array[CosmeticData]:
	_ensure_scanned()
	var result: Array[CosmeticData] = []
	if _by_slot.has(slot):
		for cosmetic in _by_slot[slot]:
			result.append(cosmetic)
	return result


static func get_all() -> Array[CosmeticData]:
	_ensure_scanned()
	var result: Array[CosmeticData] = []
	for cosmetic in _by_id.values():
		result.append(cosmetic)
	return result


static func get_all_slots() -> Array[String]:
	_ensure_scanned()
	var slots: Array[String] = []
	for slot in _by_slot.keys():
		slots.append(slot)
	return slots


## Test-only: re-scans from a different root (e.g. a temp fixture directory
## with a deliberately duplicated id) instead of the real cosmetics tree,
## clearing cached state first so results never mix with production content.
static func set_scan_root_for_testing(root: String) -> void:
	_scan_root = root
	reset_cache()


## Test-only: restores the real scan root, still with cleared cache so the
## next access re-scans production content instead of reusing fixture data.
static func restore_default_scan_root_for_testing() -> void:
	set_scan_root_for_testing(COSMETICS_ROOT)


static func reset_cache() -> void:
	_by_id.clear()
	_by_slot.clear()
	_scanned = false


static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_directory(_scan_root)


static func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := path.path_join(entry)
			if dir.current_is_dir():
				_scan_directory(full_path + "/")
			elif entry.ends_with(".tres"):
				_register(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _register(resource_path: String) -> void:
	var cosmetic := load(resource_path) as CosmeticData
	if not cosmetic:
		return
	if _by_id.has(cosmetic.id):
		var existing: CosmeticData = _by_id[cosmetic.id]
		push_error("CosmeticCatalogue: duplicate cosmetic id '%s' in '%s' and '%s'" % [
			cosmetic.id, existing.resource_path, resource_path])
		return
	_by_id[cosmetic.id] = cosmetic
	if not _by_slot.has(cosmetic.slot):
		_by_slot[cosmetic.slot] = []
	_by_slot[cosmetic.slot].append(cosmetic)
