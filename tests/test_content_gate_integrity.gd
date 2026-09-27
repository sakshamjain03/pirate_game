extends GutTest

## Purpose: stop the MVP scope gate (`content_enabled`, 2026-09-28) from silently
## breaking shipping content.
##
## Why this exists: the first scope cut gated six islands and left Chapter 4 with two
## MANDATORY objectives targeting `frozen_island` and Chapter 5 with one targeting
## `volcano_island`. Both chapters became uncompletable, and the whole GUT suite still
## went green — nothing asserted that a shipping chapter only depends on shipping
## content. `CLAUDE.md` already lists "fully authored content with no in-world trigger
## has shipped uncompletable before" as a known failure mode of this codebase; this is
## that failure mode, caught by a reviewer rather than by a test.
##
## Every time a resource is gated off, these tests are what prove nothing shipping
## depended on it.

const CHAPTERS_DIR := "res://resources/campaign/chapters/"
const ISLANDS_DIR := "res://resources/world/"
const REGIONS_DIR := "res://resources/world/regions/"
const CAPTAINS_DIR := "res://resources/captains/"
const ENCOUNTERS_DIR := "res://resources/combat/encounters/"

## ObjectiveData.Condition members whose `target_id` names an island.
const ISLAND_CONDITIONS := [
	ObjectiveData.Condition.REACH_ISLAND_TIER,
	ObjectiveData.Condition.CAPTURE_ISLAND,
	ObjectiveData.Condition.DISCOVER_ISLAND,
	ObjectiveData.Condition.DOCK_AT_ISLAND,
]

var _enabled_island_ids: Array[String] = []
var _enabled_region_ids: Array[String] = []
var _enabled_chapter_ids: Array[String] = []
var _enabled_captain_ids: Array[String] = []
var _enabled_chapters: Array = []


func _load_dir(path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if not dir:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var res = load(path + entry)
			if res:
				out.append(res)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func before_all() -> void:
	for island in _load_dir(ISLANDS_DIR):
		if island is IslandData and ResourceLookup.is_content_enabled(island):
			_enabled_island_ids.append(island.island_id)
	for region in _load_dir(REGIONS_DIR):
		if region is RegionData and ResourceLookup.is_content_enabled(region):
			_enabled_region_ids.append(region.id)
	for captain in _load_dir(CAPTAINS_DIR):
		if captain is CaptainData and ResourceLookup.is_content_enabled(captain):
			_enabled_captain_ids.append(captain.captain_id)
	for chapter in _load_dir(CHAPTERS_DIR):
		if chapter is ChapterData and ResourceLookup.is_content_enabled(chapter):
			_enabled_chapters.append(chapter)
			_enabled_chapter_ids.append(chapter.chapter_id)

	# Sanity: if these come back empty the assertions below would all pass vacuously.
	assert_gt(_enabled_island_ids.size(), 0, "Expected at least one enabled island")
	assert_gt(_enabled_chapters.size(), 0, "Expected at least one enabled chapter")


func test_shipping_chapter_objectives_only_target_shipping_islands() -> void:
	# THE regression guard. A mandatory objective pointing at a gated island makes its
	# chapter uncompletable, and nothing else in the suite notices.
	var broken: Array[String] = []
	for chapter in _enabled_chapters:
		for objective in chapter.objectives:
			if objective == null or not ISLAND_CONDITIONS.has(objective.condition):
				continue
			var target: String = objective.target_id
			if target.is_empty():
				continue
			if not _enabled_island_ids.has(target):
				broken.append(
					"%s objective %s ('%s') targets gated island '%s'%s"
					% [chapter.chapter_id, objective.objective_id, objective.description,
						target, "" if objective.is_optional else "  [MANDATORY]"]
				)
	assert_eq(
		broken, [] as Array[String],
		"Shipping chapters depend on gated islands — those chapters cannot be completed: %s"
		% str(broken)
	)


func test_shipping_chapters_are_gated_only_by_shipping_content() -> void:
	var broken: Array[String] = []
	for chapter in _enabled_chapters:
		var region: String = chapter.required_region_id
		if not region.is_empty() and not _enabled_region_ids.has(region):
			broken.append("%s requires gated region '%s'" % [chapter.chapter_id, region])
		var prev: String = chapter.required_previous_chapter
		if not prev.is_empty() and not _enabled_chapter_ids.has(prev):
			broken.append("%s requires gated chapter '%s'" % [chapter.chapter_id, prev])
	assert_eq(
		broken, [] as Array[String],
		"A shipping chapter is gated behind content that does not ship, so it can never "
		+ "start: %s" % str(broken)
	)


func test_shipping_chapter_rewards_resolve_to_shipping_content() -> void:
	# A reward pointing at a gated captain would hand the player someone the tavern and
	# codex both filter out.
	var broken: Array[String] = []
	for chapter in _enabled_chapters:
		var captain_id: String = chapter.reward_captain_id
		if not captain_id.is_empty() and not _enabled_captain_ids.has(captain_id):
			broken.append("%s rewards gated captain '%s'" % [chapter.chapter_id, captain_id])
	assert_eq(broken, [] as Array[String], "Chapter rewards reference gated content: %s" % str(broken))


func test_boss_encounters_are_reachable_from_a_shipping_chapter() -> void:
	# EncounterData.required_chapter_id is what makes a boss spawnable at all (D65). If it
	# names a gated chapter the boss is authored but unreachable — the exact "uncompletable
	# content" class CLAUDE.md warns about.
	var unreachable: Array[String] = []
	for encounter in _load_dir(ENCOUNTERS_DIR):
		var chapter_id: String = str(encounter.get("required_chapter_id"))
		if chapter_id.is_empty() or chapter_id == "<null>":
			continue
		if not _enabled_chapter_ids.has(chapter_id):
			unreachable.append("%s requires gated chapter '%s'"
				% [encounter.resource_path.get_file(), chapter_id])
	assert_eq(
		unreachable, [] as Array[String],
		"Encounters gated behind chapters that do not ship: %s" % str(unreachable)
	)


func test_every_shipping_chapter_has_at_least_one_mandatory_objective() -> void:
	# An all-optional chapter completes instantly and silently skips its own content.
	for chapter in _enabled_chapters:
		var mandatory := 0
		for objective in chapter.objectives:
			if objective and not objective.is_optional:
				mandatory += 1
		assert_gt(
			mandatory, 0,
			"Chapter '%s' has no mandatory objective — it would complete the moment it starts"
			% chapter.chapter_id
		)
