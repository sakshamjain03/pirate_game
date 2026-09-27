# Design Document: Milestone M24 — MVP Foundations

## 1. Why this design shape

Three constraints drove every decision here.

**The constitution is amended, not circumvented.** The alternative — writing the premium currency
and letting `AGENTS.md` keep saying it is forbidden — leaves every future PR failing its own
checklist, and leaves the next agent unable to tell which document is true. So the rules are
rewritten with the date and the supersession stated inline. The replacements are deliberately
*narrower* than "anything goes": each is a thing a reviewer can check.

**Gating beats deleting.** Six islands and four chapters are authored, playable content. Deleting
them to hit MVP scope destroys work that each future level will want. A boolean that every loader
respects keeps the content in the repo, out of the build, and one edit away from returning.

**The dev console is made safe by architecture, not by discipline.** "Remember not to reference the
debug folder" fails the first time someone is in a hurry. A one-way dependency plus a test that
greps for violations fails the build instead.

## 2. New/changed files

| File | Change |
|---|---|
| `agents.md` | Monetization rules rewritten; PR checklist gains monetization + dev-tools gates |
| `docs/00_VISION.md` | §19 acceptable list extended; §19.1 rewritten; new §19.2 "limits that survive" |
| `docs/17_MONETIZATION.md` | §1, §3, §7 rewritten for the F2P model |
| `docs/RELEASE_CHECKLIST.md` | §4 gains the dev-tools export-exclusion step |
| `docs/13_CAMPAIGN_LEVELS_1-5.md` | New §0: MVP scope, island roster, terrain briefs, chapter/island allocation |
| `docs/11_WORLD_MAP.md` | New §0: which islands ship, which are deferred |
| `docs/05_CURRENT_SYSTEMS.md` | M24 section + the Ch4/Ch5 follow-up |
| `scripts/world/ResourceLookup.gd` | **+** `is_content_enabled()` |
| `ChapterData` / `CaptainData` / `RegionData` / `IslandData` `.gd` | **+** `content_enabled` export |
| `CampaignManager` / `EmpireManager` / `WorldMapScreen` / `CodexScreen` / `IslandMenu` | filter through the gate |
| `scripts/world/Island.gd` | `_ready()` frees a gated island before `add_to_group()` |
| 20 `.tres` files | `content_enabled = false` |
| `Ch4_TheAdmiralsGambit.tres`, `Ch5_TheSilverFleet.tres` | objectives retargeted to shipping islands |
| **new** `scripts/debug/DevConsole.gd` | the console |
| **new** `scenes/debug/DevHarness.tscn` | World instance + console overlay |
| **new** `tests/test_no_shipping_reference_to_debug.gd` | dev-tools isolation guard |
| **new** `tests/test_content_gate_integrity.gd` | content-gate guard |
| `tests/test_world_map_layout.gd` | layout check reads authored SceneState |
| `export_presets.cfg` *(gitignored)* | exclude filter |

## 3. The content gate

`ResourceLookup` already exists as the shared id-lookup helper, and `AGENTS.md` forbids duplicate
systems, so the gate lives there rather than in a new file:

```gdscript
static func is_content_enabled(res: Resource) -> bool:
    if res == null: return false
    var value: Variant = res.get("content_enabled")
    if value == null: return true   # type was never gated - unaffected
    return bool(value)
```

Returning **true** for a missing field is the load-bearing decision: it means adding the gate cannot
change behaviour for any resource type that does not opt in.

Gated islands are handled at `Island._ready()` rather than by editing `World.tscn`:

```gdscript
if island_data and not ResourceLookup.is_content_enabled(island_data):
    queue_free()
    return
```

Placed **before** `add_to_group("islands")`. Everything downstream — `DockingSystem`,
`_spawn_defenses()`, the economy tick, `WorldMapScreen`, `EmpireManager` — discovers islands through
that group, so one early return covers all of them. A concurrent session was editing `World.tscn`
at the time, which is a second reason not to touch it.

Region `island_ids` deliberately still name gated islands. The only consumer is
`EmpireManager.get_region_for_island()`, a lookup that simply never matches, and leaving them intact
keeps re-enabling a one-bool change.

## 4. The Ch4/Ch5 defect — why it happened and what it teaches

Gating six islands left three **mandatory** objectives pointing at islands that no longer exist:
Ch4 4.1 and 4.7 (`frozen_island`), Ch5 5.1 (`volcano_island`). Both chapters were uncompletable.
**The full 762-test suite passed straight through it**; it was caught by `checkpoint-reviewer`.

`CLAUDE.md` already lists this exact failure mode ("fully authored content with no in-world trigger
has shipped uncompletable before"). It recurred because nothing asserted that shipping content
depends only on shipping content.

The fix required a **content decision, not a find-replace**, because of a constraint worth stating
plainly: five islands, one of which (Tortuga) is never ownable, leaves **four capturable islands for
five chapters** — and Ch1 takes Port Royal while Ch2 already takes Skull Cove.

| Chapter | Island beat |
|---|---|
| Ch1 | Capture Port Royal (tutorial) |
| Ch2 | Capture Skull Cove |
| Ch3 | *None* — the defence chapter |
| Ch4 | Discover + colonize **Pelican Cay** |
| Ch5 | Dock at, then capture, **Cartagena Outpost** |

Colonizing satisfies a `CAPTURE_ISLAND` objective because
`IslandMenu._on_colonize_pressed()` calls `Island.capture_island()`, which emits `island_captured`,
which `CampaignManager._on_island_captured()` dispatches. So Ch4's territory beat is a gold cost
rather than a fight, which suits a chapter already carrying 8 Royal Navy kills and a boss.

**Open balance item:** Pelican Cay is tier 1, so Ch4 acquires a low-tier island at notoriety
110-150. Thematically thin — revisit when Ch4 is tuned.

## 5. Why the layout test changed mechanism

`test_world_position_matches_the_scene_transform` instantiated `World.tscn` and counted islands
carrying `island_data`. Runtime gating drops that from 11 to 5, so it failed.

Rewriting it to expect 5 would have **weakened** it: a deferred island's layout still has to be
correct for the day it ships. Instead it now reads `PackedScene.get_state()` — the authored scene
data, where all eleven transforms and `island_data` overrides are visible regardless of runtime
gating. Same assertion, same strength, and faster (no instantiation).

## 6. Dev console isolation

Four layers, in descending order of how much they can be trusted:

1. **One-way dependency** (repo-enforced). Debug calls shipping; shipping never references debug.
   `tests/test_no_shipping_reference_to_debug.gd` scans `scripts/`, `scenes/`, `resources/` — with
   `scripts/debug/`, `scenes/debug/` and `tests/` exempt — and fails on any hit. It also asserts
   `project.godot`'s `[autoload]` block is clean.
2. **Harness-only entry** (repo-enforced). `scenes/debug/DevHarness.tscn` instances `World.tscn`
   plus a `CanvasLayer` running the console — the `CaptureHarness.tscn` pattern. No autoload.
3. **`OS.is_debug_build()` self-free** (repo-enforced, runtime).
4. **Export exclusion** (*not* repo-enforced). `export_presets.cfg` is gitignored, so this is
   per-machine and a fresh clone lacks it. Documented in `RELEASE_CHECKLIST.md` §4 and stated as
   such in the console's own header — layers 1-3 are what actually survive a clone.

Because nothing imports the console, a parse error in it would never fail the suite. The guard test
therefore also `load()`s it and asserts it instantiates.

Cheats go through public API. Ship level is the one place that writes a field directly
(`owned.level`), because `FleetManager.level_up_ship()` charges resources and enforces the
component catch-up gate, and dev mode must go **down** as well as up — no shipping path offers
that. The downgrade calls `owned.set_all_components(owned.level)` so components stay legal and the
ship never lands in a state the game itself could not produce.

## Hazards

- **Amending a constitution is not a licence to ignore it.** The replacement rules in §19.2 are
  binding, and the PR checklist now tests them individually.
- **The five-island constraint has no slack.** Four conquests across five chapters works, but
  wanting a capture beat in Ch3 later means moving one.
- `home_island_id` on Constance/Ezra/Isabela (`frozen_island`) and Selene (`volcano_island`) points
  at gated islands. **The field has zero consumers in `scripts/`** — left alone deliberately so it
  becomes valid again when those islands ship. Do not "fix" it by rewriting their home ports.
- `GhostFleetBoss.tres` requires the gated `ghost_reaches` region and is correctly dormant.
- The dev console can reach states fast; it is a verification *aid*, never a substitute for a GUT
  run or a screenshot.
