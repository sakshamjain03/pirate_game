---
name: godot-verify
description: The correct way to build/test-verify this Godot 4.3 project (d:\Pirate-game) — run the GUT test suite, never `--check-only`, and how to find the (gitignored) engine binary. Use whenever asked to run tests, verify a fix, check the project compiles, or confirm nothing regressed after a change.
---

# Godot Verify

The single correct way to verify this project builds/tests cleanly. Read this before running any
Godot CLI command — this project has one documented trap that wastes real time if you don't know
about it (see `docs/07_AI_AGENT_WORKFLOW.md` Rule 7).

## The trap: never use `--check-only`

`godot --headless --path . --check-only` does **not** reliably exit on its own in this project on
Godot 4.3. `project.godot` sets `run/main_scene="res://scenes/core/Boot.tscn"`, so instead of just
checking scripts and quitting, the engine boots into real gameplay (Boot → MainMenu) and then
idles forever. Waiting on it or polling it produces a false "hang," and killing it manually leaves
orphaned processes that then interfere with the *next* run.

## The correct command

Run the GUT test suite instead — it calls `-gexit` and reliably terminates, and since GUT cannot
run tests from a script that fails to compile, a clean GUT run already proves every test script
(and everything it imports) parses correctly. That covers what `--check-only` was being used for,
without the hang.

1. Locate the engine binary — it's gitignored (`Godot_v*.exe` in `.gitignore`, installed
   separately, not vendored), so it won't always be at a fixed path:
   - Check the project root for `Godot_v*.exe` (Windows) first.
   - Otherwise check `where godot` / `where godot4` on PATH.
   - If neither is found, ask the user where their Godot 4.3 binary lives rather than guessing.
2. Full suite:
   ```
   <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
   ```
3. Single file (much faster — use this when verifying one specific fix, not a whole milestone):
   ```
   <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit
   ```

## Before starting a run

Check for stray leftover Godot processes from a previous attempt before launching a new one — a
prior run that was manually killed (often because it hit the `--check-only` trap above and looked
"hung") can leave a process alive that then produces confusing double output or file locks. On
Windows: `Get-Process | Where-Object {$_.ProcessName -like "*Godot*"}` (PowerShell) or
`tasklist | grep -i godot` (bash).

Launch with proper background execution and wait for the actual completion signal (`-gexit`
terminates the process on its own) — do not poll with sleep loops, and do not assume a run "hung"
without first checking whether an old leftover process is actually the problem.

## Reading the output

GUT prints a final summary line with pass/fail counts. As of the last full run recorded in
`docs/05_CURRENT_SYSTEMS.md` (§2, D8/D12), the suite has exactly one pre-existing, known-and-
accepted failure: `test_property_21_lod_distance_transitions` — it correctly detects that no LOD
system exists in `OceanController` (a real, tracked gap, not a test bug or a regression). Treat
that single failure as expected baseline; any *other* failure is a real regression. If the total
test count changes from what's recorded in `05_CURRENT_SYSTEMS.md`, flag that too — new tests
should be a deliberate addition, not a silent shift.

## Manual/visual verification

Some behaviors genuinely can't be verified headlessly (camera feel, gamepad input, visual shader
changes, timed offline-return prompts) — this project has repeated precedent for saying so
explicitly rather than guessing (M3 Task 14, M4 Task 22, M5 Task 4/10 checkpoints all did this).
If no display is available in your environment, say exactly that instead of claiming a visual
check passed.
