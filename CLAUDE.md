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

For visual/physics/UI defects — proven repeatedly to be invisible to the GUT suite (rendering
glitches, HUD overlap, ship capsizing) — run the headful screenshot harness and actually look at
the output rather than reasoning about the fix from code alone:

```
<godot-binary> --path <project-root> scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
```

Must run headful (no `--headless` — the dummy renderer produces blank images) with zero player
input; it captures screenshots at t≈0/1/3/7/12s. See `docs/09_VISUAL_BUG_TRACKER.md` for the
history of what this has caught that code review and GUT both missed.

Some behavior genuinely cannot be verified in this environment at all, headful capture included:
camera *feel* (as opposed to camera position, which the capture harness shows fine), gamepad input
feel, on-device frame rate, audio, and anything needing a real Android/iOS device (touch feel,
notification delivery, billing/ad flows). Say so explicitly rather than claiming a check passed;
there's repeated precedent for this across the milestone specs.

## Architecture

**Autoload singletons** (`project.godot` → `[autoload]`) are the system-level managers, loaded
once globally. Core gameplay: `SaveManager`, `SceneManager`, `SettingsManager`, `InputManager`,
`AudioManager`, `ResourceManager`, `FleetManager`, `TechManager`, `EventManager`,
`FactionManager`, `EmpireManager`, `CampaignManager`, `TutorialManager`. Backend/monetization
(M15–M17): `AuthManager`, `EntitlementManager`, `StoreManager`, `AdManager`,
`RemoteConfigManager`. Live ops/telemetry: `SeasonalEventManager`, `LiveOpsConfig`,
`AnalyticsManager`, `CrashReporter`, `LocalNotificationManager`. Each owns one domain (economy
ticks, fleet/captain rosters, tech modifiers, faction reputation, save/load, etc.) and most expose
`get_save_data()`/`load_save_data()` for `SaveManager` to round-trip — new persistent state should
follow that same pair-of-methods convention rather than inventing a new persistence path. This
list changes every few milestones — `project.godot`'s `[autoload]` block is the actual source of
truth, not this file or even `docs/05_CURRENT_SYSTEMS.md` §4 (which has gone stale before).

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

**Platform and backend**: Android (phone + tablet) is the primary launch target (M13); Windows
desktop is an actively-maintained secondary platform, not just the dev environment; iOS is planned
for M20 behind the same platform-abstracted billing interface `StoreManager` already establishes —
see `docs/20_PLATFORM_MATRIX.md`. The Supabase backend (`AuthManager`, cloud save sync, a
`remote_config` table, a `delete-account` Edge Function) is a real, deployed project, not a stub —
see `docs/SUPABASE_SETUP.md` for the schema, RLS policies, and what's still unconfigured.
**Monetization is hard-gated**: no paid feature ships before the M13 launch build, and afterward
only within `AGENTS.md`'s absolute never-list (no pay-to-win, no hard/premium currency, no energy
systems, cosmetics only, never gating gameplay-affecting content behind money or ads) — read that
section before touching `EntitlementManager`, `StoreManager`, or `AdManager`.

### Fragile areas — do not regress

These are past defects, each costly to re-debug, not hypothetical risks — full history in
`docs/07_AI_AGENT_WORKFLOW.md`:

- **Ship stability** (`BuoyancySimulator.gd`/`ShipMovement.gd`'s buoyancy/stability-torque/yaw-servo
  code) took four separate root-cause fixes to stabilize; the yaw servo deliberately preserves roll
  and pitch. Don't touch it without a task explicitly calling for it.
- **Cannon firing direction** derives forward from the hull basis
  (`parent.global_transform.basis.x`), never from marker rotation — a bug across all 12 markers on
  all 3 ship scenes was fixed exactly this way; don't revert it.
- **Enemy obstacle avoidance** (`_get_avoidance_turn`/`_probe`/`_push_to_open_water` in
  `EnemyAI.gd`) is what stops enemy ships from beaching on islands — don't bypass it.
- **`tests/test_ship_combat.gd`** guards the `ShipDamage` migration and must keep passing
  unmodified; if it fails, the migration is wrong, not the test.
- **Resource id resolvers must `push_error` on an unresolvable id**, never skip silently — a silent
  skip on load has previously destroyed player data.
- **Ship/building/captain costs are authored `cost_*` fields**, never derived from an unrelated
  stat (deriving cost from hull `mass` once made every ship nearly free).
- **Narrative/onboarding content lives in `CampaignManager` + `ChapterData`**, not
  `TutorialManager` (which now only tracks UI-tab-unlock flags) — check `CampaignManager` before
  adding a second onboarding system.
- **An optional save section must be omitted entirely when there's nothing to write**, not written
  as an empty object — `SaveManager` previously couldn't tell "no data" from "empty section" apart
  and silently reset ship position on load.
- **New chapter-specific content needs an explicit gate**, e.g.
  `CampaignManager.is_chapter_current()` — fully authored content with no in-world trigger has
  shipped uncompletable before.
- **A UI element's position relative to a sibling belongs in container layout** (e.g. a shared
  `VBoxContainer`), not two independently hardcoded pixel offsets — those have drifted apart with
  no code change in between to explain it.

### Commit and push after each major phase

Once a coherent unit of work is done and verified — a task wave, a milestone checkpoint, or any
other natural stopping point where the GUT suite passes and the working tree is in a state you'd
be comfortable handing off — commit and push to `origin/main` without waiting to be asked each
time. This is a standing instruction, not a one-off approval: the user does not need to say
"commit and push" again for it to apply going forward. Before committing:

- Run the GUT suite (`docs/07_AI_AGENT_WORKFLOW.md`/the `godot-verify` skill) and confirm it
  passes — never commit a state you haven't verified.
- Check `git status`/`git diff` for anything unexpected before staging broadly (`.env` and similar
  secret-bearing files must already be gitignored — verify, don't assume).
- Write a real commit message describing what changed and why, matching this repo's existing
  style (see `git log`) — not a generic "checkpoint" placeholder.

The one case where this default doesn't apply: if a destructive or history-rewriting action would
be needed (force-push, rewriting existing commits, resolving a real conflict against another
session's push) — stop and ask, per this project's general safety rules; a plain fast-forward
commit+push is not itself something to ask permission for anymore.

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
