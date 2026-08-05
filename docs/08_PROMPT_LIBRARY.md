# 08_PROMPT_LIBRARY.md

> Version: 1.0
> Status: Living Document
> Owner: Project Lead

---

# Purpose

Ready-to-paste prompts for Antigravity/Gemini, one per task in `.kiro/specs/milestone-m3-stabilization/tasks.md`
and `.kiro/specs/milestone-m4-empire-escalation/tasks.md`. Paste one prompt, let Gemini finish
that task and stop, review the diff (checkpoints have a dedicated Claude Code review prompt —
use it), then paste the next one. Never paste more than one task-prompt into a session before
reviewing its output. See `docs/07_AI_AGENT_WORKFLOW.md` for why.

Every prompt below is self-contained — it tells Gemini exactly which docs to read and exactly
which task to execute, by number, from the actual `tasks.md` file (not a copy of the task text,
so the prompt never goes stale if `tasks.md` is edited). Do not paraphrase these prompts before
pasting them.

Do not skip the 🛑 checkpoint entries — they are not Gemini prompts, they are instructions for
the human running this project to bring the diff to a Claude Code session for review before
continuing.

---

# How to use this file

1. Open Antigravity, start a fresh session (or continue an existing one — Gemini has no memory
   of prior tasks unless you keep it in the same session, which is fine as long as you still
   review after every single task).
2. Copy exactly one prompt block below, in order, and paste it in.
3. Let Gemini finish. Read its report (files changed, verification output).
4. When you hit a 🛑 checkpoint, stop pasting Gemini prompts. Bring the changes to Claude Code
   using the checkpoint's review prompt instead.
5. Once the checkpoint passes, resume pasting the next task's prompt.

---

# Milestone M3 — Stabilization

## Task 1 — Remove ScreenshotHarness from production autoloads

```
You are working in the Godot 4.3 project at d:\Pirate-game ("Pirate Empire").

Read, in this order: agents.md, docs/05_CURRENT_SYSTEMS.md,
.kiro/specs/milestone-m3-stabilization/requirements.md,
.kiro/specs/milestone-m3-stabilization/design.md,
.kiro/specs/milestone-m3-stabilization/tasks.md.

Execute ONLY Task 1 ("Remove ScreenshotHarness from production autoloads") from that tasks.md.
Do not do any other task.

Rules: touch only the files that task names. Do not refactor or "clean up" anything else. Do not
invent architecture not already in design.md. Run the exact verification step written in the
task and report its real output — do not claim success without running it. Stop after this one
task and report: files changed, verification output, anything that didn't match the spec.
```

## Task 2 — Fix duplicate EventManager instance

```
Same project and required-reading order as before (agents.md, docs/05_CURRENT_SYSTEMS.md, then
the milestone-m3-stabilization requirements.md/design.md/tasks.md).

Execute ONLY Task 2 ("Fix duplicate EventManager instance") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task.

Same rules as always: touch only the named files, no unrelated refactors, no invented
architecture, run the task's exact verification step and report the real output, stop after this
one task and report files changed + verification output + any spec mismatches found.
```

## Task 3 — Create PlayerFaction.tres

```
Same reading order (agents.md, docs/05_CURRENT_SYSTEMS.md, milestone-m3-stabilization
requirements.md/design.md/tasks.md).

Execute ONLY Task 3 ("Create PlayerFaction.tres") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task.

Same rules: minimal file scope, no unrelated changes, no invented architecture, run and report
the real verification output, stop after this task.
```

## Task 4 — Wire PlayerFaction.tres into FactionManager

```
Same reading order as always. Execute ONLY Task 4 ("Wire PlayerFaction.tres into FactionManager")
from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. This task depends
on Task 3 already being done — if resources/factions/PlayerFaction.tres does not exist yet, stop
and report that instead of improvising a fix.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 5 — Fix GhostShipStats.tres property names

```
Same reading order as always. Execute ONLY Task 5 ("Fix GhostShipStats.tres property names")
from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. Before editing,
actually read the full @export property list in scripts/world/ShipStats.gd — do not guess
property names.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 6 — Rewrite SaveManager.gd documentation header

```
Same reading order as always. Execute ONLY Task 6 ("Rewrite SaveManager.gd documentation header")
from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. Change only the
header comment block — do not touch any code below it, even if you notice something you think
should be fixed. If you notice something else that looks wrong, report it at the end instead of
fixing it.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 7 — Delete dead code (ScenePaths, UIConstants)

```
Same reading order as always. Execute ONLY Task 7 ("Delete dead code — ScenePaths and
UIConstants") from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task.
Before deleting anything, actually run a full-repo search for "ScenePaths" and "UIConstants" and
paste the results in your report — do not delete based on assumption.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 8 — Delete orphaned resources

```
Same reading order as always. Execute ONLY Task 8 ("Delete orphaned resources") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. Before deleting
anything, actually run a full-repo search for "resources/world/ShipStats.tres" and
"resources/world/IslandData.tres" and paste the results in your report.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## 🛑 CHECKPOINT after Task 8 — bring to Claude Code before continuing

```
Review the milestone-m3-stabilization work completed so far (Tasks 1-8) in the Godot project at
d:\Pirate-game. Read .kiro/specs/milestone-m3-stabilization/tasks.md Task 9's checkpoint
criteria. Actually run: `godot --headless --check-only` (use the Godot_v4.3-stable_win64_console.exe
in the project root) and the full GUT suite. Boot the game and manually verify: Boot -> MainMenu
-> World, sail to an island, dock, colonize it, undock, with no new console errors compared to
before this milestone. Report pass/fail on each check, and fix anything broken before this
milestone continues to Task 10.
```

## Task 10 — Add gamepad input bindings

```
Same reading order as always. Execute ONLY Task 10 ("Add gamepad input bindings") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 11 — Add camera collision to CameraRig

```
Same reading order as always. Execute ONLY Task 11 ("Add camera collision to CameraRig") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task.

Same rules: minimal scope, no invented architecture. This task's verification requires actually
running the game and observing behavior near an island, not just confirming the code compiles —
do this and describe what you observed. Stop after this task.
```

## Task 12 — Resolve ORBIT/LOOK camera mode stubs

```
Same reading order as always. Execute ONLY Task 12 ("Resolve ORBIT/LOOK camera mode stubs") from
.kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. Per design.md, prefer
collapsing the unused modes with a clear comment over implementing new camera logic, unless
implementing them is genuinely trivial — if it looks non-trivial, stop and report that instead
of building new camera-mode behavior.

Same rules: minimal scope, run and report the real verification output, stop after this task.
```

## Task 13 — Align ocean shader uniforms with OceanController

```
Same reading order as always. Execute ONLY Task 13 ("Align ocean shader uniforms with
OceanController") from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other
task. Read resources/shaders/water.gdshader's uniform declarations AND
scripts/world/OceanController.gd's set_shader_parameter calls side by side before changing
anything, and report which names you found mismatched.

Same rules: minimal scope, no invented architecture. Verify visually (run the game, change a
value in OceanSettings.tres, confirm the ocean visibly changes) — do not rely on compilation
success alone. Stop after this task.
```

## Task 14 — Sync WaveGenerator with OceanSettings

```
Same reading order as always. Execute ONLY Task 14 ("Sync WaveGenerator with OceanSettings")
from .kiro/specs/milestone-m3-stabilization/tasks.md. Do not do any other task. This depends on
Task 13 being done first — if the shader uniform names are still mismatched, stop and report
that instead of proceeding.

Same rules: minimal scope, no invented architecture. Verify visually (run the game, observe
whether the player ship's pitch/roll now tracks the rendered wave surface) — do not rely on
compilation success alone. Stop after this task.
```

## 🛑 CHECKPOINT after Task 14 — bring to Claude Code before continuing

```
Review the milestone-m3-stabilization work completed in Tasks 10-14 in the Godot project at
d:\Pirate-game. Read .kiro/specs/milestone-m3-stabilization/tasks.md Task 15's checkpoint
criteria. Actually boot the game and manually verify: camera no longer clips through islands
near shore, ship motion visually matches the ocean surface, gamepad bindings exist in Project
Settings > Input Map (test with a controller if one is available). Report pass/fail on each,
fix anything broken before this milestone continues to Task 16.
```

## Task 16 — Implement test_ship_properties.gd

```
Same reading order as always, plus also read
.kiro/specs/milestone-m2-playable-world/design.md section 6 (Correctness Properties) before
starting. Execute ONLY Task 16 ("Implement test_ship_properties.gd") from
.kiro/specs/milestone-m3-stabilization/tasks.md — implement Properties 4, 5, 6, 7, 9 exactly as
specified there, following the GUT test pattern already used in tests/test_settings_manager.gd.
Do not invent new properties or change the ones already specified.

Same rules: minimal scope. Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
-gexit` and report the real pass/fail output. Stop after this task.
```

## Task 17 — Implement test_camera_properties.gd

```
Same reading order as always, plus .kiro/specs/milestone-m2-playable-world/design.md section 6.
Execute ONLY Task 17 ("Implement test_camera_properties.gd") from
.kiro/specs/milestone-m3-stabilization/tasks.md — implement Properties 1, 2, 3 exactly as
specified there.

Same rules: minimal scope. Run the GUT suite command and report the real pass/fail output. Stop
after this task.
```

## Task 18 — Implement test_docking_properties.gd

```
Same reading order as always, plus .kiro/specs/milestone-m2-playable-world/design.md section 6.
Execute ONLY Task 18 ("Implement test_docking_properties.gd") from
.kiro/specs/milestone-m3-stabilization/tasks.md — implement Properties 10, 11, 12, 13 exactly as
specified there.

Same rules: minimal scope. Run the GUT suite command and report the real pass/fail output. Stop
after this task.
```

## Task 19 — Implement test_input_properties.gd

```
Same reading order as always, plus .kiro/specs/milestone-m2-playable-world/design.md section 6.
Execute ONLY Task 19 ("Implement test_input_properties.gd") from
.kiro/specs/milestone-m3-stabilization/tasks.md — implement Properties 8, 14, 15, 23, 24, 25
exactly as specified there.

Same rules: minimal scope. Run the GUT suite command and report the real pass/fail output. Stop
after this task.
```

## Task 20 — Implement test_ocean_properties.gd

```
Same reading order as always, plus .kiro/specs/milestone-m2-playable-world/design.md section 6.
Execute ONLY Task 20 ("Implement test_ocean_properties.gd") from
.kiro/specs/milestone-m3-stabilization/tasks.md — implement Properties 19, 20, 21, 22 exactly as
specified there.

Same rules: minimal scope. Run the GUT suite command and report the real pass/fail output. Stop
after this task.
```

## 🛑 FINAL CHECKPOINT — Task 21, full M3 verification

```
Perform the full milestone-m3-stabilization closeout described in Task 21 of
.kiro/specs/milestone-m3-stabilization/tasks.md, in the Godot project at d:\Pirate-game. Run the
full GUT suite and `godot --headless --check-only`, both must be clean. Manually play through:
Boot -> MainMenu -> World -> sail -> dock -> colonize -> undock -> combat with one enemy ship ->
ship destroyed -> loot drop -> death/respawn. Update docs/05_CURRENT_SYSTEMS.md's defect table
(D1-D11 resolved, D12 remains open) with what was actually fixed. Confirm every modified .gd
file has an accurate documentation header. Report a full pass/fail summary. Do not mark this
milestone complete unless every check genuinely passes — if something is broken, fix it and
re-verify rather than reporting a partial pass as done.
```

---

# Milestone M4 — Empire Escalation

**Do not start these until milestone-m3-stabilization's final checkpoint above has genuinely
passed.** M4 is built directly on top of the colonize/capture flow that M3 fixes.

## Task 1 — Add is_empire field to FactionData

```
You are working in the Godot 4.3 project at d:\Pirate-game ("Pirate Empire").

Read, in this order: agents.md, docs/05_CURRENT_SYSTEMS.md,
.kiro/specs/milestone-m4-empire-escalation/requirements.md,
.kiro/specs/milestone-m4-empire-escalation/design.md,
.kiro/specs/milestone-m4-empire-escalation/tasks.md.

Execute ONLY Task 1 ("Add is_empire field to FactionData") from that tasks.md. Do not do any
other task.

Rules: touch only the files that task names. Do not refactor or "clean up" anything else. Do not
invent architecture not already in design.md. Run the exact verification step written in the
task and report its real output. Stop after this one task and report: files changed,
verification output, anything that didn't match the spec.
```

## Task 2 — Create SpanishEmpire faction

```
Same reading order as always (agents.md, docs/05_CURRENT_SYSTEMS.md, then
milestone-m4-empire-escalation requirements.md/design.md/tasks.md). Execute ONLY Task 2 ("Create
SpanishEmpire faction") from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Do not do any
other task.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 3 — Create RegionData resource class

```
Same reading order as always. Execute ONLY Task 3 ("Create RegionData resource class") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Use the exact field list from design.md
section 2/3 — do not add fields not specified there.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 4 — Create the 3 RegionData instances

```
Same reading order as always. Execute ONLY Task 4 ("Create the 3 RegionData instances") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. This depends on Task 3 already existing —
if scripts/world/RegionData.gd doesn't exist yet, stop and report that. Before assigning
island_ids, actually look up the real island ids from the existing IslandData .tres files listed
in docs/05_CURRENT_SYSTEMS.md section 3 — do not guess them.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 5 — Author a second Region 3 island

```
Same reading order as always. Execute ONLY Task 5 ("Author a second Region 3 island") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Follow the exact schema of the existing
VolcanoIsland.tres and the placement pattern already used for other islands in
scenes/world/World.tscn.

Same rules: minimal scope, no invented architecture. Verify by actually booting the game and
confirming the new island renders — do not rely on the scene file compiling alone. Stop after
this task.
```

## Task 6 — Create EmpireManager autoload — notoriety core

```
Same reading order as always. Execute ONLY Task 6 ("Create EmpireManager autoload — notoriety
core") from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Use the exact signal/field
signatures from design.md section 3 — do not add methods or signals not specified there yet
(later tasks add the rest incrementally).

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 7 — Wire notoriety gains to combat and colonization

```
Same reading order as always. Execute ONLY Task 7 ("Wire notoriety gains to combat and
colonization") from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Find the actual death
handling in scripts/world/ShipCombat.gd (or wherever the faction of the destroyed ship is
already known) rather than guessing where to hook in — report which exact function you hooked
into.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 8 — Add idle notoriety decay

```
Same reading order as always. Execute ONLY Task 8 ("Add idle notoriety decay") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md.

Same rules: minimal scope, no invented architecture. For verification, temporarily use a short
test interval as the task suggests, confirm the behavior, then revert to the real default before
reporting done — state clearly in your report that you reverted the debug value. Stop after this
task.
```

## Task 9 — Region loading and activation checking

```
Same reading order as always. Execute ONLY Task 9 ("Region loading and activation checking")
from .kiro/specs/milestone-m4-empire-escalation/tasks.md. This depends on Tasks 4 and 6 already
being done — if the region resources or EmpireManager don't exist yet in the state this task
expects, stop and report that instead of improvising.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 10 — Gate Island.gd defender spawning and capture on region activation

```
Same reading order as always. Execute ONLY Task 10 ("Gate Island.gd defender spawning and
capture on region activation") from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Read
the existing defender-spawn logic and capture_island() in scripts/world/Island.gd fully before
adding the guard clause — the goal is one small guard added to existing logic, not a rewrite of
Island.gd.

Same rules: minimal scope, no invented architecture. Verify by actually booting the game and
observing a dormant-region island's behavior before and after crossing the threshold, not by
code inspection alone. Stop after this task.
```

## 🛑 CHECKPOINT after Task 10 — bring to Claude Code before continuing

```
Review the milestone-m4-empire-escalation work completed so far (Tasks 1-10) in the Godot
project at d:\Pirate-game. Read .kiro/specs/milestone-m4-empire-escalation/tasks.md Task 11's
checkpoint criteria. Actually boot the game from a fresh save and verify: Region 1 is fully
active and playable, Region 2 and Region 3 islands have no defenders and cannot be colonized.
Manually raise notoriety (via debug calls or by grinding kills/colonization) past each region's
threshold in turn and confirm each region activates exactly once, in the correct order. Report
pass/fail, fix anything broken before continuing to Task 12.
```

## Task 12 — Empire spawn scaling

```
Same reading order as always. Execute ONLY Task 12 ("Empire spawn scaling") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Read design.md section 5 and section 6
(Property M4-5) carefully — the multiplier must be applied at spawn/instantiation time to that
specific ship instance's runtime stats, and must NOT mutate the shared ShipStats resource used by
other ships of the same tier. If you find that avoiding shared-resource mutation requires
duplicating the resource (e.g. ShipStats.duplicate()) at spawn time, do that — do not take a
shortcut that mutates the shared resource, even temporarily.

Same rules: minimal scope. Write the unit test the task describes and report its real pass/fail
output. Stop after this task.
```

## Task 13 — Confirm non-empire spawns are unaffected

```
Same reading order as always. Execute ONLY Task 13 ("Confirm non-empire spawns are unaffected")
from .kiro/specs/milestone-m4-empire-escalation/tasks.md — this is a verification/test-writing
task on top of Task 12's work, not new spawn logic.

Same rules: minimal scope, run and report the real verification output, stop after this task.
```

## 🛑 CHECKPOINT after Task 13 — bring to Claude Code before continuing

```
Review the milestone-m4-empire-escalation work completed in Tasks 12-13 in the Godot project at
d:\Pirate-game. Read .kiro/specs/milestone-m4-empire-escalation/tasks.md Task 14's checkpoint
criteria. With notoriety high enough for Region 3 to be active, fight an empire ship there vs.
one in Region 1 (or compare printed/logged stat values if a live side-by-side isn't practical)
and confirm a real, measurable difference matching the +25%/+60% targets in requirements.md
Requirement 5.2. Confirm non-empire faction ships show zero difference across regions. Report
pass/fail, fix anything broken before continuing to Task 15.
```

## Task 15 — Home island tracking and defense score

```
Same reading order as always. Execute ONLY Task 15 ("Home island tracking and defense score")
from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Use the exact formula in design.md
section 5 for the defense score — do not invent different weightings.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 16 — Attack score and raid probability check

```
Same reading order as always. Execute ONLY Task 16 ("Attack score and raid probability check")
from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Use the exact formula in design.md
section 5. For verification, temporarily lower the interval and raise the probability floor as
the task suggests, confirm raids attempt at roughly the expected rate, then revert the debug
values and state clearly in your report that you reverted them.

Same rules: minimal scope, no invented architecture, stop after this task.
```

## Task 17 — Raid resolution

```
Same reading order as always. Execute ONLY Task 17 ("Raid resolution") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Use the exact RaidReport shape and formula
from design.md sections 5 and 6 (Properties M4-7, M4-8, M4-9) — write the unit tests the task
describes covering both the repelled and not-repelled cases.

Same rules: minimal scope, no invented architecture. Report the real test pass/fail output. Stop
after this task.
```

## Task 18 — Defend Home fleet assignment

```
Same reading order as always. Execute ONLY Task 18 ("Defend Home fleet assignment") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Read the existing Fleet tab UI in
scripts/ui/IslandMenu.gd before adding to it — add one small control, do not restructure the
existing tab.

Same rules: minimal scope, no invented architecture, run and report the real verification
output, stop after this task.
```

## Task 19 — RaidReportScreen UI

```
Same reading order as always. Execute ONLY Task 19 ("RaidReportScreen UI") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Follow DeathScreen's existing
CanvasLayer -> Control (FULL_RECT) structure and scripting pattern as the template — read
scripts/ui/DeathScreen.gd and its scene first.

Same rules: minimal scope, no invented architecture. Verify by actually triggering a raid via
the debug values from Task 16 and observing the screen appear and dismiss correctly in a live
run. Stop after this task.
```

## Task 20 — HUD notoriety display

```
Same reading order as always. Execute ONLY Task 20 ("HUD notoriety display") from
.kiro/specs/milestone-m4-empire-escalation/tasks.md. Read the existing scripts/ui/WorldHUD.gd
fully before adding to it — add new elements, do not restructure the existing HUD layout.

Same rules: minimal scope, no invented architecture. Verify visually in a live run, not by code
inspection alone. Stop after this task.
```

## Task 21 — Persistence — save/load all new state

```
Same reading order as always. Execute ONLY Task 21 ("Persistence — save/load all new state")
from .kiro/specs/milestone-m4-empire-escalation/tasks.md. Read the existing save/load structure
in scripts/managers/SaveManager.gd fully before adding to it — extend the existing JSON
structure, do not introduce a second save mechanism.

Same rules: minimal scope, no invented architecture. Verify by setting all new values to
non-default, saving, reloading, and confirming an exact round-trip — report the actual before/
after values you tested with. Stop after this task.
```

## 🛑 FINAL CHECKPOINT — Task 22, full M4 verification

```
Perform the full milestone-m4-empire-escalation closeout described in Task 22 of
.kiro/specs/milestone-m4-empire-escalation/tasks.md, in the Godot project at d:\Pirate-game. Run
the full GUT suite (all M1/M2/M3/M4 tests) and `godot --headless --check-only`, both must be
clean. From a fresh save, play through: Region 1 active/playable immediately, gain notoriety via
kills and colonization, watch Region 2 then Region 3 activate in order, confirm empire ships in
higher regions are visibly tougher, trigger and observe a raid and the RaidReportScreen, save and
reload and confirm every new value persisted correctly. Add a new "Empire Escalation (M4)"
section to docs/05_CURRENT_SYSTEMS.md summarizing EmpireManager, RegionData, and the raid system,
so this milestone's systems are documented for whatever comes next. Confirm every new/modified
.gd file has an accurate documentation header. Report a full pass/fail summary. Do not mark this
milestone complete unless every check genuinely passes.
```

---

# Reusable template (for any future milestone not yet covered above)

When a new `.kiro/specs/milestone-XX/tasks.md` is written, generate its prompts using this exact
shape — do not deviate:

```
Same reading order as always: agents.md, docs/05_CURRENT_SYSTEMS.md, then
.kiro/specs/milestone-XX/requirements.md, design.md, tasks.md.

Execute ONLY Task N ("<exact task title>") from that tasks.md. Do not do any other task.

Same rules: touch only the named files, no unrelated refactors, no invented architecture beyond
what design.md already specifies, run the exact verification step and report the real output
(never claim success without running it), stop after this one task and report files changed +
verification output + anything that didn't match the spec's assumptions.
```

For checkpoint tasks, use this shape instead (addressed to Claude Code / a human reviewer, not
Gemini):

```
Review the milestone-XX work completed in Tasks A-B in the Godot project at d:\Pirate-game. Read
tasks.md's checkpoint task criteria. Actually run the verification steps (headless check, GUT
suite, manual play pass) rather than trusting Gemini's self-report. Fix anything broken before
the milestone continues to the next task.
```
