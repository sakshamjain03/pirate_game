# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pirate Empire — a mobile-first empire-building strategy game (Godot 4.3, GDScript). The player
builds and leads a pirate empire (islands, fleets, captains, economy) rather than piloting a
single ship. See `readme.md` for vision/pillars and `docs/00_VISION.md`/`docs/04_GAME_LOOP.md`
for product detail.

`AGENTS.md` is this repo's constitution — non-negotiable engineering/architecture rules (naming
conventions, composition over inheritance, data-driven balance via `Resource` files, signals over
direct references, no hardcoded gameplay values, never duplicate systems). It takes precedence
over every other doc. Read it before making changes.

## Commands

There is no build step (GDScript is interpreted by the engine). Verification is the GUT test
suite.

**Never run `godot --headless --path . --check-only`** — in this project it does not reliably
exit. `project.godot` sets `run/main_scene`, so `--check-only` boots straight into real gameplay
(Boot → MainMenu) and idles forever instead of quitting, producing a false "hang" and orphaned
processes.

Use the GUT suite instead — it calls `-gexit` and actually terminates, and a clean run already
proves every test script (and everything it imports) parses correctly:

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Single file (much faster — use for verifying one specific fix):

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit
```

The engine binary is gitignored (`Godot_v*.exe`, matched in `.gitignore`) and not vendored in the
repo — check the project root first, then `where godot`/`where godot4` on PATH; ask rather than
guess if neither is found. Before starting a run, check for a stray leftover Godot process from a
previous killed attempt (`Get-Process | Where-Object {$_.ProcessName -like "*Godot*"}` on
PowerShell) — it's the usual cause of a run looking hung. All tests live flat under `tests/*.gd`
(GUT's `-gdir=res://tests` here does not recurse into subdirectories, despite what older spec text
assumed). The suite has exactly one known/accepted pre-existing failure
(`test_property_21_lod_distance_transitions` — no LOD system exists yet, a real tracked gap, not a
regression); any other failure or a drop in total test count is a real regression. Full details
and the current baseline count are in `docs/05_CURRENT_SYSTEMS.md`.

Manual/visual behavior (camera feel, gamepad input, shader appearance, timed offline-return
prompts) cannot be verified headlessly in this environment — say so explicitly rather than
claiming a visual check passed; there's repeated precedent for this in the milestone specs.

## Architecture

**Autoload singletons** (`project.godot` → `[autoload]`) are the system-level managers, loaded
once globally: `GameManager`, `SaveManager`, `SceneManager`, `SettingsManager`, `AudioManager`,
`ResourceManager`, `FleetManager`, `TechManager`, `EventManager`, `FactionManager`,
`EmpireManager`, `TutorialManager`. Each owns one domain (economy ticks, fleet/captain rosters,
tech modifiers, faction reputation, save/load, etc.) and most expose
`get_save_data()`/`load_save_data()` for `SaveManager` to round-trip — new persistent state should
follow that same pair-of-methods convention rather than inventing a new persistence path.

**Data-driven balance**: gameplay values live in `Resource` (`.tres`) files, not in scripts —
`CaptainData`, `ShipStats`, `BuildingData`, `FactionData`, `TechData`, `LootTableData`,
`RegionData`, etc. under `resources/`. `@export`ed fields on the corresponding `.gd` script define
the schema; a `.tres` that sets a property name the script doesn't actually `@export` fails
silently (this has caused real bugs — see `docs/05_CURRENT_SYSTEMS.md` D3/D14) — always check the
script's real exported properties before authoring or editing a resource file.

**Composition over inheritance**: gameplay objects are composed from focused scripts rather than
deep class hierarchies — e.g. a ship's behavior is split across `ShipController`, `ShipMovement`,
`ShipVisuals`, `ShipCombat`, `BuoyancySimulator`, `DockingSystem`, `CameraRig` rather than one
monolithic class.

**Systems communicate via signals**, not direct cross-references (e.g. `ShipCombat.died`,
`ResourceManager`'s global economy tick, `EmpireManager.notoriety_changed`,
`SaveManager.game_loaded`). When wiring new behavior, prefer connecting to an existing signal over
adding a new direct call path.

**Islands and buildings**: `Island.gd` tracks `built_buildings`, listens for the global economy
tick, and snaps buildings into pre-authored `Marker3D` slots (not free placement).
`FactionManager`/`EmpireManager` gate island defender spawning and capture on
region-active/notoriety state — see `docs/05_CURRENT_SYSTEMS.md` §5 for the full escalation model
(notoriety, region activation thresholds, raid resolution).

**`docs/05_CURRENT_SYSTEMS.md` is the living ground-truth doc** — what is actually implemented,
file by file, including known defects and gaps — as opposed to every other `docs/*.md` file, which
describes intent/vision. Read it before touching `scripts/world/`, `scripts/managers/`,
`scripts/combat/`, or `scripts/ui/IslandMenu.gd`; it exists specifically to stop systems from being
silently reimplemented. When you change a documented system, update its entry in the same change.

### AI agent workflow (this repo specifically)

**As of 2026-08-26, this project is built entirely by Claude Code** — planning, implementation, and
verification all happen here; there is no second implementing agent. (Earlier docs/history
reference an Antigravity/Gemini implementation handoff — that workflow is retired; see
`docs/07_AI_AGENT_WORKFLOW.md`'s "What this replaced" section if you find a stale reference to it
elsewhere.) Plan and maintain `.kiro/specs/<milestone>/{requirements,design,tasks}.md` (scaffold new
ones with the `spec-new` skill), then implement directly against them, one task at a time, per
`docs/07_AI_AGENT_WORKFLOW.md`'s rules. Never let a milestone's next task wave start before its
prior checkpoint has been independently re-verified (not just remembered from the implementing
pass) — use the `checkpoint-reviewer` agent and the `godot-verify` skill for this; that discipline
matters just as much solo as it ever did with two agents, per the self-report failures
`docs/07_AI_AGENT_WORKFLOW.md` documents (several of which happened with no handoff involved at
all).
