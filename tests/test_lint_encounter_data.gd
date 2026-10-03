extends GutTest

## M29 A.4 lint: every authored EncounterData .tres must pass
## EncounterManager._validate(), so no shipped encounter can start unwinnable.

const ENCOUNTER_DIRS := ["res://resources/combat/encounters"]


func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(path, out)
		elif entry.ends_with(".tres"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func test_every_encounter_validates() -> void:
	var manager: Node = autofree(EncounterManager.new())
	var paths: Array = []
	for d in ENCOUNTER_DIRS:
		_collect(d, paths)

	var checked := 0
	var failures: Array[String] = []
	for path in paths:
		var data = load(path)
		if not (data is EncounterData):
			continue
		checked += 1
		var reason: String = manager._validate(data)
		if reason != "":
			failures.append("%s: %s" % [path, reason])

	gut.p("EncounterData lint: %d checked, %d failing" % [checked, failures.size()])
	assert_gt(checked, 0, "Found no EncounterData resources under %s" % [ENCOUNTER_DIRS])
	assert_eq(failures.size(), 0, "Invalid encounters:\n" + "\n".join(failures))
