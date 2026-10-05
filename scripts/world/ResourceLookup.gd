class_name ResourceLookup

## Purpose: the "find a Resource file in a directory whose exported id field
## matches a value" scan, shared by CampaignManager's and
## SeasonalEventManager's reward-lookup (captain/ship/tech by id) — the same
## shape EmpireManager._get_faction_by_id() also uses independently. Extracted
## here rather than duplicated a third time (AGENTS.md: "never duplicate
## systems").

static func find_by_id(dir_path: String, id_field: String, id_value: String) -> Resource:
	for path in list_resource_paths(dir_path):
		var res := load(path)
		if res and res.get(id_field) == id_value:
			return res
	return null


## M30 — every `.tres` path in a directory, export-safe. An exported build
## converts text resources to binary and leaves `X.tres.remap` in the pack in
## place of `X.tres`, so a raw `ends_with(".tres")` DirAccess scan finds
## nothing on Android; load() still resolves the original `.tres` path through
## the remap. Every directory scan of authored content goes through here.
static func list_resource_paths(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	var base := dir_path if dir_path.ends_with("/") else dir_path + "/"
	for file_name in dir.get_files():
		var name := file_name.trim_suffix(".remap")
		if name.ends_with(".tres") and not out.has(base + name):
			out.append(base + name)
	out.sort()
	return out


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
