# Design Document — M7 Campaign Spine & Economy Correction

## Guiding constraints

From `AGENTS.md`, repeated here because this milestone touches the two systems most at risk of
being duplicated or silently mis-authored:

- **Never duplicate systems.** `TutorialManager`'s `wait_for` / `_check_condition()` dispatch
  pattern is correct and gets reused, not reimplemented (Requirement 7).
- **Data-driven balance.** Every chapter, objective, and dialogue line lives in a `.tres`. A
  `.tres` that sets a property the script does not `@export` fails **silently**
  (`docs/05_CURRENT_SYSTEMS.md` D3/D14) — always check the script's real exported properties
  before authoring content against it.
- **Signals over direct references.** `CampaignManager` never calls into gameplay systems except
  through public APIs that already exist (the same discipline `TutorialManager` already follows
  via `spawn_hunter()`).
- **Scene-file wiring must be checked directly, not inferred from scripts** — D9/D11's lesson.
  This matters specifically for Requirement 4 (`InputManager`'s real location).

Order of work matters more than usual in this milestone: **Wave 1 (economy correction) must land
before any chapter is authored**, because every economy target in
`docs/13_CAMPAIGN_LEVELS_1-5.md` is written against the corrected ship ladder.

---

## Part A — Economy correction (Wave 1)

### A1. `ShipStats` gains identity and cost fields

```gdscript
@export_group("Identity")
@export var ship_id: String = ""
@export var display_name: String = ""
@export_range(1, 5) var ship_class: int = 1

@export_group("Cost")
@export var cost_gold: int = 0
@export var cost_wood: int = 0
@export var cost_iron: int = 0
@export var cost_rum: int = 0
```

Author all 8 `resources/ships/*.tres` to the ladder in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2 (E1):

| Ship | class | gold | wood | iron |
|---|---|---|---|---|
| Dinghy | 1 | 150 | 40 | 10 |
| Sloop | 1 | 400 | 90 | 25 |
| Schooner | 2 | 1200 | 200 | 60 |
| Corvette | 2 | 1800 | 280 | 90 |
| Brigantine | 3 | 3000 | 420 | 150 |
| Frigate | 3 | 6500 | 700 | 300 |
| Galleon | 4 | 14000 | 1300 | 650 |
| ManOWar | 5 | 28000 | 2400 | 1200 |

`cost_rum` stays 0 for all 8 in v1 — no ship in `docs/13_CAMPAIGN_LEVELS_1-5.md`'s ladder needs
it, and inventing a value with no design reason would violate "no hardcoded values" from the
other direction (arbitrary values are as wrong as missing ones).

### A2. `IslandMenu` stops deriving price from mass

Delete:

```gdscript
var cost_gold = int(ship.mass / 100)
var cost_wood = int(ship.mass / 200)
var cost_iron = int(ship.mass / 400)
```

Replace with a direct read of the four `cost_*` fields into the existing `cost_dict` shape
`_on_buy_ship_pressed()` already expects — the purchase flow (`ResourceManager.spend_resources`,
`FleetManager.add_ship`) does not change. Replace the filename-derived name with
`ship.display_name`.

**Do not** leave the mass formula as a fallback for ships missing the new fields — Requirement
1.2 requires every ship to set them, and a silent fallback is exactly the kind of "fails
silently" failure mode `docs/05_CURRENT_SYSTEMS.md` repeatedly warns about.

### A3. Captain data — boarding modifier and hire cost

Author `base_boarding_modifier` and `hire_cost_gold` on all 20 `resources/captains/*.tres`, per
`docs/12_CHARACTER_BIBLE.md` §5. No script change — `base_boarding_modifier` already exists on
`CaptainData` (D55 is a data gap, not a schema gap).

### A4. Captain identity fields

```gdscript
@export_group("Identity")
@export var home_island_id: String = ""
@export var allegiance_faction_id: String = ""
@export var unlock_chapter_id: String = ""
@export var portrait_path: String = ""
```

Author `home_island_id` and `allegiance_faction_id` on all 20 captains per
`docs/12_CHARACTER_BIBLE.md` §4's table. `unlock_chapter_id` is set once Wave 2's chapter ids
exist — sequence this after chapter authoring, or use the planned ids
(`ch1_the_drowned_port` … `ch5_the_silver_fleet`) up front since they're fixed by
`docs/13_CAMPAIGN_LEVELS_1-5.md`.

`IslandMenu`'s Tavern hire list filters: a captain with a non-empty `unlock_chapter_id` that
`CampaignManager.is_chapter_completed()` reports false for is **excluded from the list**, not
shown disabled.

### A5. Input rebinding fix

Read `SettingsMenu.gd` and the `World.tscn` node tree before choosing an approach — two viable
fixes:

1. **Group-based lookup** — add `InputManager` to a group (e.g. `"input_manager"`) in its
   `_ready()`, and change `SettingsMenu`'s two `get_tree().root.get_node_or_null("InputManager")`
   calls to `get_tree().get_first_node_in_group("input_manager")`. Minimal diff, but only works
   while a `World` scene (or anything containing `InputManager`) is loaded — check whether
   Settings can be opened from `MainMenu` before a World scene exists, since a group lookup
   returns null there just as the current code does. If so, this is a partial fix.
2. **Promote to autoload** — move `InputManager` out of `World/Systems` into `project.godot`'s
   `[autoload]` list, after `SettingsManager` (which it already reads from) and before
   `AudioManager`. Larger diff — check every existing reference to `InputManager` (scene tree
   lookups, `%InputManager` unique-name references if any) before doing this, since an autoload
   is reachable everywhere but a scene-local node search pattern used elsewhere in the codebase
   would need updating too.

Prefer option 2 if Settings must be reachable from the main menu (this needs to be checked, not
assumed); otherwise option 1 is the smaller change. Whichever is chosen, add
`tests/test_input_rebinding.gd`: load a `World` scene (mirroring `test_region_gates.gd`'s
`before_each` pattern), instantiate `SettingsMenu`, simulate a rebind, and assert `InputMap`
actually changed — the missing version of exactly this test is why D57 shipped invisibly.

### A6. Cold start — seed Port Royal as home

In whichever function performs new-game initialization (locate via `SceneManager`'s "New Game"
flow — `MainMenu.gd` calling `SaveManager.delete_save()` is the anchor `TutorialManager.gd`'s own
comments already reference), after the World scene loads for the first time:

```gdscript
var port_royal := _find_island_by_id("port_royal")
port_royal.island_data.island_type = IslandData.IslandType.CAPITAL
port_royal.island_data.owner_faction = load("res://resources/factions/PlayerFaction.tres")
EmpireManager.home_island_id = "port_royal"
```

Guard this behind "is this a genuinely new game" (no existing save), not "is `home_island_id`
empty" — an existing save with a different home island must not be overwritten (Requirement
5.4). The cleanest signal is to run this once, at the same point `TutorialManager.start_new_game_session()`
is called, since that call site already only fires on a real new game.

---

## Part B — Campaign data model (Wave 2)

### B1. Resource schemas

Exactly per `docs/06_NARRATIVE_AND_WORLD.md` §6 — reproduced here for implementation:

```gdscript
# scripts/world/DialogueBeatData.gd
class_name DialogueBeatData extends Resource

@export var speaker_id: String
@export var speaker_name: String
@export var portrait_path: String = ""
@export_multiline var text: String
enum Mood { NEUTRAL, WARM, GRIM, ANGRY, AMUSED }
@export var mood: Mood = Mood.NEUTRAL
```

```gdscript
# scripts/world/ObjectiveData.gd
class_name ObjectiveData extends Resource

enum Condition {
    BUILD_STRUCTURE, UPGRADE_STRUCTURE_TO_LEVEL, REACH_ISLAND_TIER,
    DESTROY_SHIPS, BOARD_SHIPS, DEFEAT_BOSS,
    CAPTURE_ISLAND, DISCOVER_ISLAND, DOCK_AT_ISLAND,
    RECRUIT_CAPTAIN, OWN_SHIP_CLASS, UNLOCK_TECH,
    ACCUMULATE_RESOURCE, REACH_NOTORIETY, SURVIVE_RAID,
}

@export var objective_id: String
@export var description: String
@export var condition: Condition
@export var target_id: String = ""
@export var target_count: int = 1
@export var target_value: float = 0.0
@export var is_optional: bool = false
@export var hint_text: String = ""
```

```gdscript
# scripts/world/ChapterData.gd
class_name ChapterData extends Resource

@export var chapter_id: String
@export var chapter_number: int
@export var title: String
@export_multiline var log_summary: String

@export_group("Gating")
@export var required_region_id: String = ""
@export var required_previous_chapter: String = ""

@export_group("Content")
@export var opening_beats: Array[DialogueBeatData] = []
@export var objectives: Array[ObjectiveData] = []
@export var closing_beats: Array[DialogueBeatData] = []

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""
@export var reward_ship_id: String = ""
@export var reward_tech_id: String = ""
```

Note: `required_notoriety` from the original doc's sketch is dropped in favor of
`required_region_id` alone — Requirement 8.2 requires the gate to *be*
`EmpireManager.region_activated`, and a region's activation threshold already lives in
`RegionData`. Keeping the notoriety number in two places (`RegionData` and `ChapterData`) invites
them drifting apart; `CampaignManager` checks region activation state, never a raw notoriety
float.

### B2. `CampaignManager` autoload

Register in `project.godot` immediately after `EmpireManager`:

```
EmpireManager="*res://scripts/managers/EmpireManager.gd"
CampaignManager="*res://scripts/managers/CampaignManager.gd"
TutorialManager="*res://scripts/managers/TutorialManager.gd"
```

```gdscript
extends Node
class_name CampaignManagerAutoload  # avoid colliding with the CampaignManager global name if any

signal chapter_started(chapter: ChapterData)
signal objective_progressed(objective_id: String, current: int, target: int)
signal objective_completed(objective_id: String)
signal chapter_completed(chapter: ChapterData)

var chapters: Array[ChapterData] = []
var current_chapter_index: int = -1
var completed_chapter_ids: Array[String] = []
var _objective_progress: Dictionary = {}   # objective_id -> int

func _ready() -> void:
    _load_chapters()
    call_deferred("_check_gate")
```

`_load_chapters()` scans `resources/campaign/chapters/*.tres` (`DirAccess`, mirroring how
`EmpireManager` loads `resources/world/regions/*.tres`) and sorts by `chapter_number`.

`_check_gate()` — called on `_ready()` (covers Requirement 6.8, the overshoot case) and on every
relevant signal — advances `current_chapter_index` past any chapter whose gate is already
satisfied:

```gdscript
func _gate_satisfied(chapter: ChapterData) -> bool:
    if not chapter.required_previous_chapter.is_empty() \
       and not completed_chapter_ids.has(chapter.required_previous_chapter):
        return false
    if not chapter.required_region_id.is_empty() \
       and not EmpireManager.is_region_active(chapter.required_region_id):
        return false
    return true
```

(`EmpireManager.is_region_active()` may need adding if no equivalent public getter exists yet —
check `_region_active` before assuming a new method is required.)

### B3. Condition dispatch — reusing `TutorialManager`'s pattern

`CampaignManager` connects to the signal set enumerated in `docs/13_CAMPAIGN_LEVELS_1-5.md` §8
once, in `_ready()` or on world-load (mirroring `TutorialManager.on_world_ready()`), then
dispatches through one generic handler exactly like `TutorialManager._check_condition()`:

```gdscript
func _on_progress_signal(condition: int, target_id: String, amount: int = 1) -> void:
    var chapter := _current_chapter()
    if not chapter:
        return
    for objective in chapter.objectives:
        if objective.condition != condition:
            continue
        if not objective.target_id.is_empty() and objective.target_id != target_id:
            continue
        var key := objective.objective_id
        _objective_progress[key] = _objective_progress.get(key, 0) + amount
        objective_progressed.emit(key, _objective_progress[key], objective.target_count)
        if _objective_progress[key] >= objective.target_count:
            objective_completed.emit(key)
    _check_chapter_complete(chapter)
```

`REACH_ISLAND_TIER`, `REACH_NOTORIETY`, `ACCUMULATE_RESOURCE` are level checks, not counters —
route them through a variant that sets progress to the current absolute value rather than
incrementing.

### B4. Save/load

```gdscript
func get_save_data() -> Dictionary:
    return {
        "current_chapter_index": current_chapter_index,
        "completed_chapter_ids": completed_chapter_ids.duplicate(),
        "objective_progress": _objective_progress.duplicate(),
    }

func load_save_data(data: Dictionary) -> void:
    current_chapter_index = int(data.get("current_chapter_index", -1))
    completed_chapter_ids = data.get("completed_chapter_ids", []).duplicate()
    _objective_progress = data.get("objective_progress", {}).duplicate()
    call_deferred("_check_gate")
```

Follow `FleetManager`'s D12 lesson: return a duplicate, never the live dictionary/array, from
`get_save_data()`.

---

## Part C — Generalizing `TutorialManager` (Requirement 7)

Read `scripts/managers/TutorialManager.gd` in full before choosing an approach — it is short
(276 lines) and its `wait_for`/`_check_condition()` pattern maps almost directly onto
`CampaignManager`'s `_on_progress_signal()` above. Two acceptable outcomes, in order of
preference:

1. **Retire `TutorialManager`'s step logic entirely.** Chapter 1's objectives (authored per
   `docs/13_CAMPAIGN_LEVELS_1-5.md` §3) fully replace the 8 hardcoded steps.
   `TutorialManager` shrinks to just the one thing `CampaignManager` has no reason to own: the
   first-launch mentor dialogue trigger and the `_ALL_UNLOCK_IDS` UI-tab-unlock list — or that
   responsibility moves into `CampaignManager` too and `TutorialManager` is deleted outright if
   nothing else references it (check `SaveManager`'s autoload registry handling and any UI code
   calling `TutorialManager.is_ui_unlocked()` first).
2. **If deletion turns out riskier than expected** (e.g. `is_ui_unlocked()` is called from many
   places and re-threading it through `CampaignManager` is a large diff for no behavior change),
   keep `TutorialManager` as a thin wrapper: its `steps` array is deleted, and
   `start_new_game_session()` / `is_ui_unlocked()` delegate to `CampaignManager` state instead of
   maintaining their own.

Either way, `tutorial_state.json`'s completion flag must continue to suppress a replay for
existing players — check its read path survives whichever refactor is chosen.

---

## Part D — UI (Requirement 9)

### D1. Captain's Log panel

New scene `scenes/ui/CaptainsLog.tscn` + `scripts/ui/CaptainsLog.gd`, opened from a new HUD
button in `WorldHUD.tscn` (same pattern as the existing Pause/Settings buttons). Lists:
completed chapters (title + `log_summary`), the active chapter's objectives with a progress bar
or `current/target` label per non-optional objective, and optional objectives in a visually
distinct (not hidden) section.

### D2. HUD hooks

`WorldHUD` connects to `CampaignManager.objective_completed` and `chapter_completed` and calls
its existing `announce_event()` — no new announcement/toast system. Stall-hint delivery
(Requirement 9.4) reuses the same call with `objective.hint_text`.

### D3. Dialogue beats

`TutorialDialogue.tscn`/`.gd` already renders speaker + portrait + text + Continue. Confirm it
accepts a queue of beats (an `Array[DialogueBeatData]`) rather than only a single step — if it
currently only handles `TutorialManager`'s one-step-at-a-time model, extend it to accept
`opening_beats`/`closing_beats` arrays and advance through them on Continue.

---

## Part E — Enablers and verification (Requirement 10)

### E1. Boss id on the death signal

Locate wherever `WorldEventManager`/`BossShip` currently signals a boss death (check for a
`died`/`destroyed` signal relay similar to `ShipCombat.died`). Add a `boss_id: String` parameter
sourced from a new field on whatever resource identifies the boss instance (likely `ShipStats`
already has enough via `ship_id` from A1, if bosses use `ShipStats` — verify before adding a
second id field).

### E2. `IslandData.discovered` write path

Simplest correct implementation: `WorldManager`'s existing `player_docked` signal (already
connected by `TutorialManager`) sets `island_data.discovered = true` for the docked island if not
already set. This alone satisfies Requirement 10.2 (`DISCOVER_ISLAND` via docking) without
building approach-radius detection — that refinement is explicitly deferred to M9's fog/discovery
work.

### E3. Cartagena as a second buildable island — verify, don't assume

`Island.gd` is per-instance and does not hardcode "there is only one island" anywhere obvious,
but this has never been exercised through the real UI flow. Load a save with Cartagena captured,
open `IslandMenu` while docked there, and confirm build/upgrade/tier all work identically to
Port Royal. If a gap surfaces (e.g. `IslandMenu` assumes it's always looking at the home island
somewhere), fix it here — Chapter 5 requires this to work.

### E4. Objective-id integrity test

`tests/test_campaign_content.gd`: load every `.tres` under `resources/campaign/`, and for every
`ObjectiveData.target_id` that names an island/building/faction/captain, assert it resolves
against the real registry (`resources/world/*.tres`, `resources/buildings/*.tres`,
`resources/factions/*.tres`, `resources/captains/*.tres` — glob and check id fields, not
filenames). This is the automated version of the "authoring warning" repeated throughout
`docs/12_CHARACTER_BIBLE.md` and `docs/13_CAMPAIGN_LEVELS_1-5.md`.

---

## Verification

Standard command (`godot-verify` skill):

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Baseline entering this milestone: **126 tests, 125 passing** (measured 2026-08-14, after the map
repositioning and its own new test file). Any failure beyond the known
`test_property_21_lod_distance_transitions` is a regression. New tests added by this milestone
(input rebinding, campaign content integrity, plus whatever each wave's implementer adds) should
grow that count — expect roughly 135–145 by the milestone's end; treat that as an estimate to
sanity-check against, not a target to hit exactly.
