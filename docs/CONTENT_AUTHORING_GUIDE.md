# CONTENT_AUTHORING_GUIDE.md

> Version: 1.0
> Status: Living Document — how to add a chapter, region, island, or seasonal event
> Owner: Project Lead
>
> Written for `.kiro/specs/milestone-m14-live-operations/` Requirement 4, and validated by
> actually using it to author Chapters 6–10 and Regions 4/5 in that same milestone — every
> point below reflects what the real schema requires, not what a design doc guessed it might.

---

# 0. The one rule that matters more than anything else here

**A `.tres` resource file that sets a property its script does not `@export` fails silently.**
Godot does not error, does not warn — it just drops the value, and the property quietly keeps
its script-declared default. This has caused real, hours-to-find bugs in this project more than
once (`docs/05_CURRENT_SYSTEMS.md` D3, D14): an authored stat difference between two captains that
was never actually applied; a themed island override that silently no-op'd.

**Before authoring or editing any `.tres` file below, open the corresponding `.gd` script and
check its real `@export` field names.** Every section below shows the real field list as of this
writing — but scripts change, and this document can go stale. The script is the ground truth, not
this guide.

---

# 1. Adding a chapter (`ChapterData`)

Chapters are permanent, one-time content — `CampaignManager.is_chapter_completed()` never resets
once true. For a *repeatable* piece of content, see §3 (`SeasonalEventData`) instead — retrofitting
a permanent-completion resource to support "available again next season" is a bigger, riskier
change than authoring a separate small schema, which is exactly why this project has both.

## 1.1 The real schema (`scripts/world/ChapterData.gd`)

```gdscript
@export var chapter_id: String = ""              # snake_case, must be globally unique
@export var chapter_number: int = 1               # sort order — chapters load and sort by this
@export var title: String = ""
@export_multiline var log_summary: String = ""    # shown in Captain's Log once completed

@export_group("Gating")
@export var required_region_id: String = ""              # "" = no region gate
@export var required_previous_chapter: String = ""        # "" = no prior-chapter gate
@export var required_seasonal_event_id: String = ""        # "" = no seasonal-event gate (M14)

@export_group("Content")
@export var opening_beats: Array[DialogueBeatData] = []
@export var objectives: Array[ObjectiveData] = []
@export var closing_beats: Array[DialogueBeatData] = []

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""    # "" = no captain reward
@export var reward_ship_id: String = ""       # "" = no ship reward
@export var reward_tech_id: String = ""       # "" = no tech reward
```

**Gating rules, all checked in `CampaignManager._gate_satisfied()`:**
- Leave a gate field empty to skip that check entirely.
- `required_region_id` checks `EmpireManager.is_region_active(id)` — the region's own
  `activation_notoriety_threshold` (§4 below) is the real gate; don't duplicate a notoriety number
  here, it will drift out of sync.
- `required_previous_chapter` checks `CampaignManager.is_chapter_completed(id)`.
- `required_seasonal_event_id` (M14) checks `SeasonalEventManager.has_ever_completed(id)` — the
  one-way "ever completed at least once" flag, not "completed in the current window." Use this
  only when a chapter's real-world prerequisite is "a repeatable event has happened once," which
  no other gate field can express.
- **Chapters advance strictly in `chapter_number` order** — `CampaignManager` walks one array
  index at a time and never skips an incomplete chapter, regardless of what a *later* chapter's
  own gate says. A new chapter's `chapter_number` should slot it into the story order you actually
  want, not just "the next unused integer."

## 1.2 A real annotated example (`Ch7_MargueritesHarbour.tres`, abridged)

```ini
[gd_resource type="Resource" script_class="ChapterData" load_steps=12 format=3]

[ext_resource type="Script" path="res://scripts/world/ChapterData.gd" id="1_chapter"]
[ext_resource type="Script" path="res://scripts/world/ObjectiveData.gd" id="2_objective"]
[ext_resource type="Script" path="res://scripts/world/DialogueBeatData.gd" id="3_beat"]

[sub_resource type="Resource" id="Open_1"]
script = ExtResource("3_beat")
speaker_id = "marguerite"
speaker_name = "Marguerite the Merciless"
text = "You already know what Vance and Hollis did to my port..."
mood = 2

[sub_resource type="Resource" id="Obj_7_2"]
script = ExtResource("2_objective")
objective_id = "7.2"
description = "Take Marguerite's harbour back"
condition = 6
target_id = "blackwater_shoal"
target_count = 1

[resource]
script = ExtResource("1_chapter")
chapter_id = "ch7_marguerites_harbour"
chapter_number = 7
title = "Marguerite's Harbour"
required_previous_chapter = "ch6_the_wandering_widow"
opening_beats = Array[DialogueBeatData]([SubResource("Open_1")])
objectives = Array[ObjectiveData]([SubResource("Obj_7_2")])
reward_gold = 11000
```

**Important, easy-to-miss convention:** objectives and dialogue beats are authored as
**sub-resources embedded in the same `.tres` file**, not as separate files under
`resources/campaign/objectives/`/`resources/campaign/dialogue/` — an earlier design doc
(`docs/06_NARRATIVE_AND_WORLD.md` §9) describes a separate-file convention that was never actually
built this way; every real chapter since M7 uses the embedded-sub-resource shape above. Follow the
real files, not that doc section.

## 1.3 `ObjectiveData` — the condition enum

```gdscript
enum Condition {
    BUILD_STRUCTURE, UPGRADE_STRUCTURE_TO_LEVEL, REACH_ISLAND_TIER,
    DESTROY_SHIPS, BOARD_SHIPS, DEFEAT_BOSS,
    CAPTURE_ISLAND, DISCOVER_ISLAND, DOCK_AT_ISLAND,
    RECRUIT_CAPTAIN, OWN_SHIP_CLASS, UNLOCK_TECH,
    ACCUMULATE_RESOURCE, REACH_NOTORIETY, SURVIVE_RAID,
}
# integer values in .tres files, in the order above: 0-14

@export var objective_id: String = ""       # unique across ALL chapters/events, not just this one
@export var description: String = ""
@export var condition: Condition = Condition.DOCK_AT_ISLAND
@export var target_id: String = ""          # meaning depends on condition — see table below
@export var target_count: int = 1
@export var target_value: float = 0.0       # used by the "level check" conditions below
@export var is_optional: bool = false       # optional objectives never block chapter completion
@export var hint_text: String = ""          # shown via WorldHUD if the objective stalls
```

| Condition | `target_id` must be a real... | Counts up, or reads a level? |
|---|---|---|
| `BUILD_STRUCTURE` / `UPGRADE_STRUCTURE_TO_LEVEL` | building id (level-suffixed, e.g. `"farm_l1"` — **not** `"farm"`) | counts up |
| `REACH_ISLAND_TIER` | island id | level check — `target_count` is the tier |
| `DESTROY_SHIPS` | faction id | counts up |
| `BOARD_SHIPS` | faction id **or** a dedicated boss `ship_id` (both pools are valid) | counts up |
| `DEFEAT_BOSS` | a dedicated boss's `ship_id` (not a faction) | counts up |
| `CAPTURE_ISLAND` / `DISCOVER_ISLAND` / `DOCK_AT_ISLAND` | island id | counts up |
| `RECRUIT_CAPTAIN` | (leave empty) | counts up |
| `OWN_SHIP_CLASS` | (leave empty; use `target_value` for the class number) | level check — recomputed from the best hull currently owned, not incremented |
| `UNLOCK_TECH` | tech id | counts up |
| `ACCUMULATE_RESOURCE` | a resource key: `gold`/`wood`/`iron`/`rum`/`research` | level check — absolute amount, not a delta |
| `REACH_NOTORIETY` | (leave empty; use `target_value`) | level check |
| `SURVIVE_RAID` | (leave empty) | counts up — either outcome (repelled or looted) satisfies it |

`tests/test_campaign_content.gd` (and its M14 sibling `tests/test_seasonal_event_content.gd`)
automatically check every `target_id` against the real registry of factions/islands/buildings/
techs/ships — run the GUT suite after authoring and a typo'd id will fail loudly there, not
silently in play.

## 1.4 `DialogueBeatData`

```gdscript
@export var speaker_id: String = ""       # lowercase snake_case, must match docs/12_CHARACTER_BIBLE.md
@export var speaker_name: String = ""     # display name
@export var portrait_path: String = ""    # "" is fine — falls back to a themed monogram
@export_multiline var text: String = ""   # ≤ 3 sentences (docs/06_NARRATIVE_AND_WORLD.md's tone rule)
enum Mood { NEUTRAL, WARM, GRIM, ANGRY, AMUSED }   # 0-4 in .tres files
@export var mood: Mood = Mood.NEUTRAL
```

---

# 2. Adding a seasonal (repeatable) event (`SeasonalEventData`)

Use this instead of `ChapterData` when the content should be **available again next season**, not
permanently marked done once completed — the Spring Crossing (Ch8) is the only one authored so
far.

## 2.1 The real schema (`scripts/world/SeasonalEventData.gd`)

```gdscript
@export var event_id: String = ""
@export var display_name: String = ""
@export_multiline var log_summary: String = ""

@export_group("Window")
@export var fallback_window_start_month_day: String = "03-01"   # "MM-DD", no year
@export var fallback_window_end_month_day: String = "05-31"

@export_group("Content")
@export var objectives: Array[ObjectiveData] = []   # same schema and Condition enum as §1.3

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""
@export var reward_ship_id: String = ""
@export var reward_tech_id: String = ""
```

Load path: `resources/campaign/seasonal_events/*.tres` (a `DirAccess` scan, same pattern as
chapters — no registration list to update anywhere else).

## 2.2 What "the window" actually means

- `fallback_window_start_month_day`/`end` are **month-day only, no year** — the event recurs every
  year in that range. A window can wrap the year boundary (e.g. `"12-01"` to `"01-31"` for a winter
  event) — `SeasonalEventManager._month_day_in_window()` handles this correctly.
- This is the **local fallback**. `LiveOpsConfig.get_seasonal_window(event_id)` checks a remote
  `seasonal_window_<event_id>` key first (M15's `RemoteConfigManager`) and only falls back to these
  two fields if that key is absent — so the *authored* window here is what ships to players before
  anyone configures a remote override, and what they get if the remote config is ever removed.
- `SeasonalEventManager.has_ever_completed(event_id)` is the one-way flag a `ChapterData`'s
  `required_seasonal_event_id` gate reads (§1.1) — it stays true forever once true, unlike
  `is_completed_this_window()`, which resets every new window.
- **Reward re-granting:** repeat completions grant the same reward as the first completion — no
  second, reduced reward tier exists. If a future event genuinely needs different repeat rewards,
  that's a real schema change to make deliberately, not something to improvise around.

## 2.3 A real annotated example (`SpringCrossing.tres`, abridged)

```ini
[gd_resource type="Resource" script_class="SeasonalEventData" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/world/SeasonalEventData.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/world/ObjectiveData.gd" id="2_objective"]

[sub_resource type="Resource" id="Obj_8_1"]
script = ExtResource("2_objective")
objective_id = "8.1"
description = "Break the crossing"
condition = 3
target_id = "spanish_empire"
target_count = 10

[resource]
script = ExtResource("1_event")
event_id = "spring_crossing"
display_name = "The Spring Crossing"
fallback_window_start_month_day = "03-01"
fallback_window_end_month_day = "05-31"
objectives = Array[ObjectiveData]([SubResource("Obj_8_1")])
reward_gold = 2000
```

---

# 3. Adding a region (`RegionData`) and an island (`IslandData`)

## 3.1 `RegionData` schema (`scripts/world/RegionData.gd`)

```gdscript
@export var id: String                              # snake_case, e.g. "ghost_reaches"
@export var display_name: String
@export var tier: int                                # difficulty tier — higher = further out, harder
@export var dominant_faction: String                 # a real faction_id — reuse an existing one
                                                        # unless the story genuinely needs a new
                                                        # faction (rare — check docs/06 first)
@export var activation_notoriety_threshold: float     # EmpireManager activates the region here
@export var island_ids: Array[String]                 # must list every island whose region_id
                                                        # points back at this region (two-way link)
@export var display_ring_radius: float = 0.0          # world-map ring — see §3.3 for the pattern
@export var wave_intensity_multiplier: float = 1.0
@export var fog_density_multiplier: float = 1.0
@export var enemy_ship_pool: Array[ShipStats] = []    # ambient enemies spawned in this region
@export var wind_strength: float = 0.0                # 0-1
@export var wind_direction_degrees: float = 0.0        # 0-360
```

## 3.2 `IslandData` schema (`scripts/world/IslandData.gd`)

```gdscript
@export var island_id: String = "island_001"          # snake_case, globally unique
@export var island_name: String = "Unknown Island"
@export var discovered: bool = false                   # always author false — the fog-of-war
                                                          # write path sets this at runtime
enum IslandType { NEUTRAL, FRIENDLY, ENEMY, CAPITAL, LEGENDARY }
@export var island_type: IslandType = IslandType.NEUTRAL
@export var owner_faction: Resource = null             # a FactionData .tres, or leave unset for
                                                          # NEUTRAL/LEGENDARY sites with no owner

@export_group("World")
@export var world_position: Vector2 = Vector2.ZERO     # must match World.tscn's node transform
                                                          # exactly (x, z) — a mismatch silently
                                                          # breaks distance/region-ring math
@export var region_id: String = ""                     # must match a real RegionData.id, and that
                                                          # region's island_ids must list this island

@export_group("Progression")
@export var min_buildings_for_tier: int = 2

@export_group("Docking")
@export var has_dock: bool = true
@export var docking_speed_limit: float = 5.0

@export_group("Visual")
@export var model_path: String = ""
enum TerrainTheme { TROPICAL, VOLCANIC, FROZEN }
@export var terrain_theme: TerrainTheme = TerrainTheme.TROPICAL
```

## 3.3 The full checklist for adding a region + island

1. Author `resources/world/regions/<Name>.tres` (§3.1). Pick `display_ring_radius` by continuing
   the existing progression rather than inventing a new scale: each tier's ring radius is roughly
   100–225 world units past the previous tier's, e.g. tier 3 → 675, tier 4 → 900, tier 5 → 1150.
2. Author `resources/world/<Name>.tres` (§3.2, an `IslandData`) — id must be unique snake_case.
3. Set `world_position` to a point roughly at (or just inside) the new region's ring radius, along
   whatever bearing the story calls for, **≥ 40 world units clear of every existing island**
   (the beach/terrain union radius is ~13.7u; 40u leaves navigable water between any two islands).
4. Add the island's id to the region's `island_ids` array (step 1's file) — this link is two-way
   and both directions are tested (`tests/test_world_map_layout.gd`).
5. Instance `Island.tscn` under `World.tscn`'s `Islands` node, `transform` matching
   `world_position` exactly (`Transform3D(1,0,0, 0,1,0, 0,0,1, x, 0, z)`), `island_data` pointing at
   step 2's resource.
6. If the region needs ambient enemies with a distinct identity (not just reusing existing player
   ships), author new `ShipStats` under `resources/enemies/` and reference them in the region's
   `enemy_ship_pool` — enemy stats don't need `cost_*` fields set (never purchasable).
7. For a region that needs a **dedicated boss** (not just ambient ships): give `EncounterData`'s
   `required_region_id` field a real region id (mirrors `required_chapter_id` exactly — empty
   means always eligible) and add the encounter to `World.tscn`'s
   `EncounterManager.encounter_pool` export array. Author the boss with its own dedicated
   `ShipStats`/scene/`AIProfileData` (copy an existing boss scene like `CardenasBoss.tscn` and
   repoint its resource references) — **never** reuse a shared, player-purchasable `ShipStats` for
   a boss, since `CampaignManager`/`EncounterManager` identify bosses by `ship_id`, and a
   player-owned hull of the same class would falsely satisfy a `DEFEAT_BOSS` objective.
8. Add a dossier entry to `docs/11_WORLD_MAP.md` §6 (what it gives, costs, and its story, mirroring
   the existing island entries' shape).
9. Run the GUT suite. A new region/island must not drop the total test count — if you're adding
   real content, the count should go *up* (new content-integrity assertions per island/region), not
   stay flat or drop.

---

# 4. Where the real ids live (for cross-referencing while authoring)

- Factions: `resources/factions/*.tres` (`faction_id`)
- Islands: `resources/world/*.tres` (`island_id`)
- Buildings: `resources/buildings/*.tres` (`building_id` — **level-suffixed**, e.g. `"farm_l1"`)
- Techs: `resources/techs/*.tres` (`tech_id`)
- Captains: `resources/captains/*.tres` (`captain_id`)
- Ships (player-purchasable): `resources/ships/*.tres` (`ship_id`)
- Ships (enemy/boss): `resources/enemies/*.tres` (`ship_id`)
- Chapters: `resources/campaign/chapters/*.tres` (`chapter_id`)
- Seasonal events: `resources/campaign/seasonal_events/*.tres` (`event_id`)
- Regions: `resources/world/regions/*.tres` (`id`)

Never guess an id's spelling from memory — `grep` the real `.tres` file (or its loader test) first.
