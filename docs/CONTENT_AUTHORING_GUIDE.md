# CONTENT_AUTHORING_GUIDE.md

> Version: 1.1 — merged with the former `docs/BALANCE_MODEL.md` during the 2026-09-20 docs
> consolidation pass (schema/how-to and numeric guidance are both "how to author new content,"
> for the same author, at the same time — see §5 below for the balance model).
> Status: Living Document — how to add a chapter, region, island, or seasonal event, and what
> numbers to give it
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
@export var speaker_id: String = ""       # lowercase snake_case, must match docs/06_NARRATIVE_AND_WORLD.md §10
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

---

# 5. Balance model — what numbers to give new content

> Folded in from `docs/BALANCE_MODEL.md` (created M11 "Depth," Requirement 10). Purpose: every new
> economy number introduced by new content (tech costs/effects, boss rewards, event outcomes)
> traces back to this section instead of being an isolated guess. This is the exact discipline the
> D53 defect (ship prices derived from hull mass, making the best warship in the game cost less
> than a quarter of one farm) skipped. Extend these tables when authoring new content rather than
> starting a new balance doc.

## 5.1 Reference scale — the ship-cost ladder

The one balance ladder this project has real, shipped numbers for (confirmed live in
`resources/ships/*.tres` — `cost_gold`/`cost_wood`/`cost_iron` match this table exactly):

| Ship | Class | Gold | Wood | Iron | Available from |
|---|---|---|---|---|---|
| Dinghy | 1 | 150 | 40 | 10 | start |
| Sloop | 1 | 400 | 90 | 25 | start (player's first hull) |
| Schooner | 2 | 1,200 | 200 | 60 | Ch2 |
| Corvette | 2 | 1,800 | 280 | 90 | Ch2 |
| Brigantine | 3 | 3,000 | 420 | 150 | Ch3 |
| Frigate | 3 | 6,500 | 700 | 300 | Ch4 |
| Galleon | 4 | 14,000 | 1,300 | 650 | Ch5 |
| Man O'War | 5 | 28,000 | 2,400 | 1,200 | Ch5 (endgame) |

Every new number below is expressed as "roughly N% of the ship a player owns at that point in the
campaign" — never an isolated figure.

### Per-chapter economy snapshot

| Chapter | Island tier | Player ship | Chapter gold turnover | Notes |
|---|---|---|---|---|
| 1 | 1→2 | Sloop (already owned) | ≈600–900 | No ship purchase required |
| 2 | 2→3 | → Schooner (1,200g) | first real "must save" purchase | 7–8 buildings, avg level 3 |
| 3 | 3→4 | → Brigantine/Corvette | storage caps become binding | all 10 building types, avg level 4 |
| 4 | 4 | → Frigate (6,500g) | Academy built, `reinforced_hulls` researched (Objective 4.3/4.4) | HMS Intransigent boss |
| 5 | 4→5 | → Galleon/Man O'War | level-5 tiers across the board | Cárdenas' escort boss |

This is the affordability ladder new tech/boss/event costs must respect — a tech gated at island
tier N should cost roughly what a player at that tier can plausibly save toward, not what a
tier-5 player could shrug off.

## 5.2 Tech costing formula

Two existing techs are the only real reference points already in the game — use them, don't
invent a ratio from scratch:

| Tech | Cost (G/W/I) | Modifier |
|---|---|---|
| `reinforced_hulls` | 1,000 / 500 / 200 | health ×1.20 |
| `advanced_cannons` | 1,500 / 200 / 600 | damage ×1.25 |

Both are unlocked from game start (no gate) and both are required or strongly implied by Ch4
objectives (`UNLOCK_TECH reinforced_hulls` is Objective 4.4) — so despite having no formal tier
gate today, they function as roughly "Tier 1, affordable well before Ch4."

**New tech tier bands** (gold anchor; wood/iron follow each existing tech's own gold:wood:iron
ratio for its dominant modifier — health-leaning techs skew wood-heavy like `reinforced_hulls`
[1,000:500:200 ≈ 5:2.5:1], damage-leaning techs skew iron-heavy like `advanced_cannons`
[1,500:200:600 ≈ 7.5:1:3]):

| Tier | Gold anchor | Gate | Roughly | Chapter fit |
|---|---|---|---|---|
| T1 (existing) | 1,000–1,500 | none | ~2–3× starting purse (200g) | Ch1–2 |
| T2 | 250–600 | island tier 2–3 | ~20–40% of Schooner (1,200g) | Ch2 |
| T3 | 800–1,300 | island tier 3–4, may chain off a T1/T2 tech | ~25–40% of Brigantine (3,000g) | Ch3 |
| T4 | 2,000–2,800 | island tier 4, chains off a T2/T3 tech | ~30–40% of Frigate (6,500g) | Ch4 |
| T5 | 4,000–6,500 | island tier 5, capstone chaining off a T4 tech | ~15–25% of Galleon (14,000g) | Ch5 |

Rationale for T2 being *cheaper* than T1 in absolute gold: T1's two techs were authored (correctly,
per this same discipline) against a Ch1–2 purse; T2 techs need to be reachable earlier in the
tier-2/Ch2 window than the existing T1 pair currently sit, since a real gated progression is
wanted, not a flat unlock-anything-anytime list. T3–T5 then climb with the ship ladder.

**Modifier magnitude:** stay in the 1.10–1.30× range per tech (matching the two existing techs'
1.20×/1.25×) so multiple stacked techs compound meaningfully without any single tech trivializing a
stat. A capstone T5 tech may go slightly higher (up to ~1.30×) since it's gated behind a full
prerequisite chain.

## 5.3 Boss reward tiers

Existing anchors (`resources/combat/encounters/*.tres`, read directly):

| Boss | bonus_gold | captain_xp | notoriety_reward | Tier |
|---|---|---|---|---|
| Ghost Ship (ambient, T1-ish) | 500 | 300 | 25 | low gate, high reward — rewards seeking it out |
| HMS Intransigent (Ch4) | 800 | 250 | 20 | chapter-gated, ~13% of a Frigate in gold |
| Cárdenas' Escort (Ch5) | (multi-stage — read at implementation time; treat as the ceiling) | — | — | endgame |

**New boss reward bands:**
- **Tier 2 ambient boss** (Contested Waters, below Intransigent): bonus_gold ≈ 250–350 (roughly
  30–40% of Intransigent's), captain_xp ≈ 120–180, notoriety_reward ≈ 12–18. Positioned between
  Ghost Ship's low-gate/ambient reward and Intransigent's chapter-gated one.
- **Tier 4 boss** (late-Ch4/early-Ch5, between Intransigent and Cárdenas): bonus_gold ≈ 900–1,100
  (slightly above Intransigent, since it's later/harder), captain_xp ≈ 280–320, notoriety_reward
  ≈ 22–28.

## 5.4 World event outcome bands

Existing `EventData` resources (`resources/world/events/*.tres`) carry `weight`/`min_region_tier`
but the actual gold/loot outcome is resolved wherever `EventManager` applies the event (check at
implementation time). Anchor new events' outcomes the same way as boss rewards — express as a
fraction of the region-tier-appropriate ship cost:

| Region tier | Reference ship | Small event outcome (~2–4%) | Large event outcome (~8–12%) |
|---|---|---|---|
| 1 (Beginner) | Sloop (400g) | 8–16g | 32–48g |
| 2 (Contested) | Brigantine (3,000g) | 60–120g | 240–360g |
| 3 (Imperial) | Galleon (14,000g) | 280–560g | 1,120–1,680g |

A "small" event is a passive discovery (floating treasure); a "large" event is a real
risk/combat-gated payout (a convoy raid, a boss-adjacent event). This mirrors the existing
`MerchantConvoy`/`FloatingTreasure`/`GhostShipBoss` weight spread (0.3 weight on the boss-tier
event, implying it's rarer and higher-value).

## 5.5 Buildings

Read directly from `resources/buildings/*.tres` (`BuildingData.gd`: `cost_gold`/`cost_wood`/
`cost_iron`, 10 building types × 5 levels each = 50 files). Buildings carry no
`required_island_tier` field of their own — gating is by island tier elsewhere, not authored
per-building — so this section only covers per-level cost scaling, not a chapter gate.

| Building (L1) | Gold | Wood | Iron | Produces |
|---|---|---|---|---|
| Rum Distillery (Farm) | 75 | 15 | 5 | 3 rum/tick |
| Iron Mine | 100 | 20 | 0 | 2 iron/tick |
| Warehouse | 100 | 50 | 10 | (storage) |
| Shipyard | 200 | 150 | 100 | (unlocks ship purchase) |
| Academy | 500 | 100 | 20 | research |
| Market | 0 | 100 | 50 | 10 gold/tick |
| Tavern | 0 | 100 | 0 | gold (crew) |
| Watchtower | 0 | 200 | 100 | (defense) |
| Fortress | 1,000 | 500 | 500 | (defense) |

**Per-level scaling is a single uniform curve applied to every building type's own L1 base cost** —
confirmed identical ratios across Academy, Farm, Fortress, and Market despite very different
absolute L1 costs:

| Level | Cost relative to L1 |
|---|---|
| L1 | 1× (base) |
| L3 | ~3.5× |
| L5 | ~18× |

A new building type should pick a fair L1 cost against the table above (by comparing what it
produces/unlocks to an existing building's role), then apply this same 3.5×/18× curve for L3/L5
rather than inventing a new one — L2/L4 sit between these two checkpoints on the same curve.

## 5.6 Ship modules

Read directly from `resources/modules/*.tres` (`ShipModuleData.gd`: `cost_gold`/`cost_wood`/
`cost_iron` plus one or two `*_mult` fields; 10 modules across 5 slots — Hull, Cannon, Sail,
Utility, Special):

| Module | Slot | Gold | Effect |
|---|---|---|---|
| Reinforced Planking | Hull | 900 | health ×1.20 |
| Reinforced Rigging | Sail | 900 | sails ×1.30 |
| Extra Berths | Utility | 900 | crew ×1.25 |
| Full Canvas | Sail | 1,000 | speed ×1.20 |
| Long Glass | Utility | 1,100 | cannon range ×1.20 |
| Heavy Cannons | Cannon | 1,800 | damage ×1.25 |
| Swift Loaders | Cannon | 1,600 | fire rate ×1.30 |
| Master Gunners | Special | 2,600 | damage ×1.15 **+** fire rate ×1.10 |
| Copper Bottom | Special | 2,400 | speed ×1.15 **+** sails ×1.15 |
| Iron Hull | Hull | 3,200 | health ×1.35 |

Two clean price bands: a **single ~1.20–1.30× modifier costs ~900–1,800g** scaled to the
modifier's own strength (900g ≈1.20–1.30×, 1,600–1,800g ≈1.25–1.30×); a module that either stacks
**two** modifiers or pushes a single one past ~1.30× costs **2,400–3,200g** (the Special slot's two
modules are both dual-effect at this tier; Iron Hull is the one single-effect outlier, priced for
its unusually high 1.35×). A new module should be priced by which band its effect(s) land in, not
by slot.

## 5.7 Captains

Read directly from `resources/captains/*.tres` (`CaptainData.gd`: `hire_cost_gold`, 20 captains).
Grouped by `unlock_chapter_id` (captains with no `unlock_chapter_id` are hireable from game start):

| Gate | Captains (gold) | Range |
|---|---|---|
| Start (no gate) | Jack 500, Anne 700, Mary 900, Redbeard 1,100 | 500–1,100 |
| Ch1 (`ch1_the_drowned_port`) | Diego 850, Fiona 1,230, Bartholomew 1,350, Cutlass 1,390, Whistler 1,575 | 850–1,575 |
| Ch2 (`ch2_blood_in_the_shallows`) | Isabela 750, Grace 960, OldTom 1,085, Marguerite 1,780, Rook 2,280 | 750–2,280 |
| Ch3 (`ch3_the_kings_answer`) | Ezra 2,015, Barnaby 2,920, Constance 3,300 | 2,015–3,300 |
| Ch4 (`ch4_the_admirals_gambit`) | Selene 2,580, Yusuf 3,730, Ophelia 4,000 | 2,580–4,000 |

Expressed against §5.1's chapter ship purchase (the other big-ticket spend at that point in the
campaign): a Ch1 captain runs ~70–130% of the Schooner (1,200g); a Ch4 captain runs ~40–62% of the
Frigate (6,500g) — hiring gets cheaper *relative to* the ship ladder as chapters progress, which
tracks with a player having more simultaneous demands on gold later (fleet size, modules, techs).
Note Isabela (750g, Ch2) already undercuts the Ch1 range — an existing outlier, not something this
pass corrects (renumbering it would ripple into save-compatible balance elsewhere); flag rather
than silently fix if it's revisited.

A new captain's cost should land inside its unlock chapter's range above, or explicitly explain
why it's an outlier (a themed reward captain, a joke/easter-egg discount, etc.).

## 5.8 Raid theft fraction

`EmpireManager._resolve_raid()` (scripts/managers/EmpireManager.gd) — not a `.tres`-authored value,
computed at raid-resolution time:

```
steal_fraction = clamp((attack_score - defense_score) / attack_score, 0.05, 0.25)
defense_score  = (has fortress ? 20 : 0) + (has watchtower ? 15 : 0) + (10 × ships defending home)
attack_score   = (highest active region tier × 25) + (notoriety × 0.3)
```

A raid that isn't repelled steals **5–25% of every current resource stockpile** (gold/wood/iron/
rum alike — not a fixed amount, and not scoped to a single resource). The 5% floor means even a
maxed-out defense against a low-tier attacker still loses something on a failed defense; the 25%
ceiling caps how much a single raid can hurt regardless of how far behind defense falls. This
range is already tuned and bounded — a future change should adjust the score weights (fortress/
watchtower/ship values, region-tier multiplier) rather than the 5–25% clamp itself, since that
clamp is what keeps a raid from ever being a full wipeout or a total non-event.

## 5.9 Loot tables → encounter mapping

`resources/loot/*.tres` (`LootTableData.gd`: `min_x`/`max_x` per resource) are referenced by
`resources/combat/encounters/*.tres` (`EncounterData.gd`: `loot_table` + `bonus_gold`/
`captain_xp`/`notoriety_reward` on top of the loot roll):

| Loot table | Gold | Wood | Iron | Rum | Used by |
|---|---|---|---|---|---|
| `StandardEnemyLoot` | 20–60 | 5–15 | 2–8 | 0–2 | Skirmish, Ambush, Defense |
| `MerchantLoot` | 100–250 | 20–50 | 10–25 | 5–15 | ConvoyRaid, EliteHunters |
| `BossLoot` | 500–1,000 | 100–200 | 50–100 | 20–40 | GhostShipBoss, IntransigentBoss, CardenasBoss |

Each encounter's fixed `bonus_gold`/`captain_xp`/`notoriety_reward` scales with the same three-tier
split (ambient skirmish → merchant-adjacent → boss), already covered for the boss row in §5.3. A
new ambient/merchant-tier encounter should reuse `StandardEnemyLoot`/`MerchantLoot` rather than
authoring a fourth loot table, unless it's introducing a genuinely new resource type.

## 5.10 Maintenance note

When new milestones add further content, extend the tables above rather than re-deriving the
anchor — the ship-cost ladder in §5.1 is the one number set this project has actually playtested
pricing against (per the D53 postmortem). If the ship ladder itself changes, every table here
needs re-deriving against the new numbers, not just the newest addition.

Ammo, battle upgrades, and AI profiles have no cost/reward fields (ammo isn't purchasable, battle
upgrades are free in-battle picks, AI profiles are pure behavior tuning) and are out of scope for
this balance model.
