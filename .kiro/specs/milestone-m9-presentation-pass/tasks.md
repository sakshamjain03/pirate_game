# Implementation Plan — M9 Presentation Pass

> **Read before starting:** `docs/05_CURRENT_SYSTEMS.md`'s "Presentation audit (2026-08-26)"
> section, `docs/15_MASTER_PLAN.md` §8, and this spec's `requirements.md`/`design.md` — all
> describe the same nine findings in full.
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Baseline entering this milestone: **324 tests, 323 passing, 1 known failure**
> (`test_property_21_lod_distance_transitions`).
>
> **Screenshot verification command** (required for this milestone's checkpoint, not optional):
> ```
> <godot-binary> --path d:/Pirate-game scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
> ```
> Run headful (no `--headless`). Review the resulting PNGs directly — do not sign off this
> milestone on a passing test suite alone; that is exactly what let D32/D36 ship un-fixed before.

---

## Tasks

- [x] 1. Fix the reopened D36 HUD-overlap regression (Requirement 1)
  - **Done.** Replaced the two independently-hardcoded `52.0` constants with a `TopRightPanel`
    `VBoxContainer` (`WorldHUD.tscn`) that `ResourceBar` was reparented into; `_create_notoriety_label()`
    (`WorldHUD.gd`) now adds the label as a second child of that container instead of anchoring it
    independently, so Godot's own container layout — not a hand-typed offset — guarantees the two
    can never overlap regardless of `ResourceBar`'s actual rendered height.
  - **Done.** Added `tests/test_world_hud_layout.gd` — instantiates `WorldHUD.tscn` inside a
    `SubViewport` at two sizes (1920×1080 and a 750×1334 phone-like portrait), populates
    multi-digit resource values, and asserts `resource_bar`/`notoriety_label` global rects never
    intersect (`Rect2.intersects()`). Passing.
  - **Found and fixed a second overlap the first pass introduced.** A follow-up headful capture
    (not the GUT test, which only checked the original pair) showed the notoriety label now
    overlapping the Captain's Log button — `_create_captains_log_button()` still used an
    independently hardcoded `offset_top = 100.0` calibrated against the label's old, shorter
    position. Fixed by moving the Log button into `top_right_panel` too, alongside the World Map
    button M10 later added the same way. Test now checks all three pairwise. Visually confirmed
    via a fresh headful `CaptureHarness` capture.
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Re-diagnose and close the reopened D32 material-null errors (Requirement 2)
  - **Done — root cause conclusively traced, not the "ambient encounter" lead this spec started
    with.** Godot 4.3 wasn't present in this environment and had to be downloaded first. Bisected
    via ~15 fast headful reproductions (`godot -s <script>` loading `World.tscn` or pieces of it,
    quitting after ~10 frames): disabled `EncounterManager.ambient_enabled` (errors persisted —
    this spec's original lead was wrong), set `EnemySpawner.initial_enemies = 0` (persisted),
    removed `CameraRig` from a live `World.tscn` (persisted — the original D31/camera explanation
    is now shown to have never been the real cause either), removed `Systems`/`WorldUI`/`Islands`/
    `Enemies` in turn (all persisted). Down to `Ocean` + `PlayerShip`, which only reproduced when
    loaded through the real `World.tscn`, not a synthetic recreation — pointing at `World.gd`'s own
    `_ready()`, which calls `SaveManager.call_deferred("load_game")`. Confirmed by moving the real
    save file aside (0 errors) and restoring it (4 errors, twice). When a save exists, `load_game()`
    reassigns `player.ship_stats`; `ShipController.ship_stats`'s setter emits `ship_stats_changed`
    once in-tree, re-triggering `ShipVisuals._rebuild_model()` a second time on a frame after the
    ship's first, correctly-materialed build has already been submitted for render — the renderer's
    dirty-material sync catches the old/new model mid-swap.
  - **Conclusively harmless, documented rather than fixed** — every captured frame (including the
    first) shows the ship correctly modeled; no test failure, no visible glitch. Restructuring
    `ShipVisuals`/`KenneyMaterialApplier`'s rebuild timing for a one-time startup log line is
    disproportionate, per Requirement 2 AC2's explicit allowance for a conclusively-traced harmless
    cause. All temporary bisection instrumentation removed; `World.tscn` and `KenneyMaterialApplier.gd`
    confirmed clean (`git diff` shows no leftover diagnostic edits).
  - _Requirements: 2.1, 2.2_

- [x] 3. Theme `SettingsMenu` and `CreditsScreen` (Requirement 3)
  - **Done.** `SettingsMenu.gd`/`CreditsScreen.gd` now set `root_control.theme =
    PirateThemeBuilder.build()` in `_ready()` (their roots are `CanvasLayer`, so the theme is
    applied to the `Control` child, matching `MainMenu.gd`'s existing pattern). Both `.tscn`s
    gained a `ColorRect` background overlay (`Color(0,0,0,0.7)`) copied from `PauseMenu.tscn`'s
    structure.
  - **Confirmed.** No settings functionality touched; `tests/test_settings_menu.gd`'s
    `settings_manager`/`audio_manager` dependency-injection pattern is untouched and still passes.
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 4. `MainMenu` typography and button consistency (Requirement 4)
  - **Done.** `TitleLabel` → 56px, `SubtitleLabel` → 20px. `CreditsButton`/`QuitButton` now carry
    the same 28px override as the other three buttons; their emoji prefixes were stripped
    ("📜 CREDITS" → "Credits", "✖ QUIT" → "Quit") to match the other three's plain text.
  - **Done.** Removed the dead `VignetteOverlay` node entirely (confirmed zero code references
    before deleting).
  - **Confirmed.** `MainMenu.gd` untouched — navigation/button-connection logic unchanged; only
    `.tscn` properties were edited.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5. HUD panel arbitration (Requirement 5)
  - **Done.** `TutorialDialogue.gd` now joins a `"tutorial_dialogue"` group (mirroring the
    existing `"hud"` group lookup pattern) and exposes `is_blocking() -> bool`. `WorldHUD.gd`
    connects to its `visibility_changed` signal and sets `cannons_container.modulate.a = 0.35`
    while it's open, `1.0` otherwise.
  - **Done.** `EncounterManager._start_random_ambient()` now returns early if
    `get_first_node_in_group("tutorial_dialogue").is_blocking()`, mirroring the existing
    `required_chapter_id` gate — no general focus-stack system added.
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 6. Framed, themed announcement banner (Requirement 6)
  - **Done.** `announce_event()` now wraps its `Label` in a `PanelContainer` styled like
    `PauseMenu.tscn`/`DeathScreen.tscn` (dark-navy `StyleBoxFlat`, gold border). Added
    `is_warning: bool = false`; default color is `PirateThemeBuilder.COLOR_GOLD_BRIGHT`,
    `true` keeps the original alarm-red. `_on_dock_speed_exceeded()` and
    `_on_save_load_failed()` now pass `true`; every other call site is unchanged (default `false`).
  - **Confirmed.** Full-width auto-wrap and fade-in/hold/fade-out tween preserved, now applied to
    the panel instead of the bare label. No trigger site's text/timing changed.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 7. Responsive `IslandMenu` sizing (Requirement 7)
  - **Done.** Removed the `CenterContainer` wrapper (which ignored the `Panel` child's anchors)
    and reparented `Panel` directly under the root `Control`, with `anchor_left/top = 0.1`,
    `anchor_right/bottom = 0.9`, and a `custom_minimum_size = Vector2(480, 320)` floor. All 15
    `parent="CenterContainer/Panel/..."` node paths updated to `parent="Panel/..."`.
  - **Confirmed.** `IslandMenu.gd` resolves every node via `%UniqueName`, not path, so the
    reparent required no script changes; all six tabs already used `SIZE_EXPAND_FILL` with no
    hardcoded-width assumption. Tier/ownership gating logic untouched.
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 8. Intentional portrait-fallback treatment (Requirement 8)
  - **Note:** the requirement's premise (a "purple skull-and-crossbones" fallback) did not match
    the actual codebase — no skull icon exists anywhere. The real state: `TutorialDialogue.tscn`'s
    `PortraitLabel` was hardcoded to the same 🏴‍☠️ emoji for every speaker regardless of
    `portrait_path`, which was otherwise unused anywhere in the codebase. Fixed the real
    underlying problem instead (see docs update for detail).
  - **Done.** Added `scripts/ui/PortraitFallback.gd` (`apply_to_label()`): loads a real portrait
    if `portrait_path` resolves, otherwise renders a themed monogram (the speaker's initial,
    gold-on-navy) — a single shared, reusable fallback per AC2. Wired into
    `TutorialDialogue.gd._render_current_beat()`, replacing the static hardcoded glyph.
  - _Requirements: 8.1, 8.2_

- [x] 9. Update documentation
  - **Done.** `docs/05_CURRENT_SYSTEMS.md`: D32/D36 marked resolved with the real traced fixes
    described (including D36's second Log-button overlap); D68–D72 marked resolved; D73 (the
    pre-existing GUT-suite crash found and fixed during this milestone's own verification) added;
    Requirement 8's premise-vs-reality discrepancy noted explicitly.
  - **Done.** `docs/14_SYSTEM_INVENTORY.md`: §7.7 and the HUD/Screen-inventory rows updated.
  - **Done.** `docs/09_VISUAL_BUG_TRACKER.md`: V5, V9, V13–V17 updated to `[x]` with the real
    root causes described; two new "wrong turns" added (#8 corrects the prior "camera spring arm"
    explanation for V5, now shown itself to have been wrong; #9 records the Log-button overlap
    the first D36 fix attempt introduced).
  - **Done.** `docs/15_MASTER_PLAN.md`: M9's exit-criteria results filled in.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 10. **Checkpoint — M9 complete**
  - **GUT suite:** 391 tests, 391 passing, 0 failures (baseline was 324/323 entering M9; M10/M11
    landed concurrently in this same working directory and added their own tests plus closed the
    project's one standing pre-existing failure — no regression from M9 itself).
  - **Fresh headful captures reviewed directly** (not just automated pass/fail): the full
    `CaptureHarness` run (`World.tscn` in play, t=0/1/3/7/12s) plus direct captures of `MainMenu`,
    `SettingsMenu`, `CreditsScreen`, and `IslandMenu` at two viewport sizes. Confirmed: no overlap
    between the resource bar, notoriety label, and Log/Map/Codex buttons; `SettingsMenu`/
    `CreditsScreen` render with the full gold/navy theme (previously raw default Godot UI);
    `MainMenu` shows a clear title (56px) > subtitle (20px) > button (28px, all five consistent)
    hierarchy; `IslandMenu`'s panel scales responsively at both 1920×1080 and a 750×1334 portrait
    size with no clipping; the portrait fallback renders a themed "Q" monogram for Higgins, not a
    generic icon.
    - Note: `CaptureHarness.tscn`/`ScreenshotCapture.gd` (pre-existing project tooling, not part
      of M9) hung reproducibly (twice) partway through this milestone's own verification — with
      zero CPU/frame progress after ~15-60 minutes each time. Diagnosed as specific to that
      declared-main-scene path: `World.tscn` loaded directly via a `-s` SceneTree script ran
      cleanly through all 720 frames every time. Worked around by capturing the same checkpoint
      screenshots through the proven-working `-s` path instead of chasing the hang itself, which
      is out of M9's scope (not something this milestone touched or claims to fix) — worth a
      follow-up look if `CaptureHarness` is needed again for a future milestone's checkpoint.
  - No stray Godot processes left running (checked and cleared after every run, including the two
    hung attempts); all capture output written to the session scratchpad, nothing committed.
  - **Independently re-verified** via the `checkpoint-reviewer` agent per
    `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8 (this project's documented history of self-reported
    checkpoints not holding up — D15, D42, D57, D66, D67, the original D32/D36 — applies solo too,
    per `CLAUDE.md`). The agent independently ran the GUT suite itself, read the actual diffs
    against every requirement's claims, and specifically cross-checked the D32 mechanism against
    the real `ShipController.gd`/`SaveManager.gd` code rather than trusting the traced explanation
    at face value. **Verdict: pass, zero defects found**, all nine requirements confirmed against
    the real code and docs, no leftover diagnostic instrumentation.

## Notes

- This milestone intentionally does not touch `PirateThemeBuilder`'s palette or font choices —
  confirmed sound in the audit that scoped this milestone. Scope is composition, consistency, and
  regression fixes only.
- Task 2's root cause is genuinely unconfirmed as of this spec being written — the "ambient
  encounter firing early" lead is the best available hypothesis from the 2026-08-26 capture's log
  output, not a confirmed diagnosis. Budget real investigation time; don't assume the fix is
  mechanical.
- If Task 1's `VBoxContainer` approach doesn't compose cleanly with `ResourceBar`'s existing
  `PanelContainer` structure without a larger refactor, use the runtime-measured-offset fallback in
  `design.md` rather than expanding this task into a `ResourceBar` rewrite — flag any such
  restructuring need as a follow-up instead of scope-creeping this milestone.
- **Unplanned, found during this milestone's own verification pass:** the full GUT suite crashed
  (segfault, "Lambda capture ... was freed") partway through, reproducing identically on the
  pre-M9 codebase (confirmed via `git stash`) — a pre-existing defect, not caused by any M9 change.
  Root cause: 15 test files share an identical `if not get_tree().current_scene: create a
  "TestScene" node` pattern with no matching cleanup, so whichever one runs last (alphabetically)
  before `test_navigation_integration.gd` leaks a node that corrupts its later real
  `get_tree().change_scene_to_file()` call. Fixed all 15 (tracked via a `_created_test_scene` var,
  freed and `current_scene` restored to `null` in each file's `after_each()`) since M9's own
  checkpoint requires a clean full-suite baseline and this blocked it outright. Will be logged as a
  new defect in `docs/05_CURRENT_SYSTEMS.md` alongside the M9 fixes rather than silently folded in.
