class_name ResourceLookup

## Purpose: the "find a Resource file in a directory whose exported id field
## matches a value" scan, shared by CampaignManager's and
## SeasonalEventManager's reward-lookup (captain/ship/tech by id) — the same
## shape EmpireManager._get_faction_by_id() also uses independently. Extracted
## here rather than duplicated a third time (AGENTS.md: "never duplicate
## systems").

static func find_by_id(dir_path: String, id_field: String, id_value: String) -> Resource:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res and res.get(id_field) == id_value:
				dir.list_dir_end()
				return res
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


## MVP scope gate (2026-09-28). The repo carries more authored content than the
## five-chapter / five-island MVP ships: chapters 6-10, regions 4-5, eight extra
## captains and nine extra islands. Rather than delete authored work, each of
## those resources carries `content_enabled = false` and every loader filters
## through here.
##
## Defaults to TRUE for any resource that has no such field, so a resource type
## that was never gated keeps loading unchanged.
static func is_content_enabled(res: Resource) -> bool:
	if res == null:
		return false
	var value: Variant = res.get("content_enabled")
	if value == null:
		return true
	return bool(value)
