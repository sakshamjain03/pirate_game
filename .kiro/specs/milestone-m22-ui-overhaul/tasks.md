# Implementation Plan: Milestone M22 — UI Visual Overhaul

## Overview

Started ahead of M17's open tasks and the unstarted M18–M21 scaffolds, at explicit user direction
(2026-09-25). See requirements.md "Sequencing note". No dependency on those milestones.

Before Task 1, read `docs/05_CURRENT_SYSTEMS.md`'s M15.5 section (the pipeline this milestone
rebuilds), this spec's `design.md` (§3 scale model and §11 hazards in particular), and open the
v0.3 design HTML in a browser.

**Session sizing:** one phase ≈ one session (Phases 4–6 may take two). Every phase ends in a
Checkpoint task. Per Rule 8, the next phase does not start until that checkpoint has been
independently re-verified.

**Checkpoint procedure (every phase):**
1. Full GUT suite (`godot-verify` skill). Pass count ≥ baseline, no new failures.
2. Headful `UIScreenSweep` (and `UIKitSheet` from Phase 2 on) into `screenshots/m22/phaseN/`,
   **viewed**, and compared against the matching v0.3 screen.
3. `checkpoint-reviewer` agent. Then a scoped `git add` of this phase's files, a real commit
   message, and a push.
4. List explicitly what couldn't be verified (touch feel, haptics, device fps, notch safe area).

## Tasks

### Phase 0 — Spec + baseline

- [x] 0.1 Scaffold this spec (requirements/design/tasks) from the approved plan.
  - **Verify:** all three files exist with real content; the token table in design.md §4 matches
    v0.3's `const sw` swatch list.
  - _Requirements: 10_
- [x] 0.2 Record the GUT baseline (count/pass/fail) at the top of this file's Notes.
  - **Verify:** the number comes from a real run's output in this session, not from docs.
  - _Requirements: 10.2_
- [x] 0.3 Promote `FontOverflowAudit` → `UIScreenSweep` (script + scene rename, header rewritten as
        permanent, `--profile=phone|tablet|desktop`).
  - **Verify:** `<godot> --path . scenes/debug/UIScreenSweep.tscn --capture-dir=<abs>/screenshots/m22/before/phone --profile=phone`
    writes one PNG per screen and exits 0; repeat for desktop.
  - _Requirements: 10.1_
- [x] 0.4 Screen inventory: add a table to design.md (scene → script → `theme_override_*` count →
        `add_theme_*` count → phase that owns it).
  - **Verify:** the table covers all 23 `scenes/ui/*.tscn`, and its totals match `grep -c`.
  - _Requirements: 6, 7, 8_
- [x] 0.5 **Checkpoint — Phase 0.** (checkpoint-reviewer PASS 2026-09-25: re-ran GUT 631/629/2, same 2 failures)

### Phase 1 — Foundation: tokens, fonts, display

- [x] 1.1 `UIPalette.gd` + `resources/ui/palette_default.tres` + `UITokens.gd` (design §4, §5 sizes).
  - **Verify:** new `tests/test_ui_tokens.gd` (10 tests) asserts the palette loads, all 12 swatches
    + rarity keys exist, and sizes equal design px × 2. All passing.
  - _Requirements: 1.1, 1.2_
- [x] 1.2 Add Germania One + Baloo 2 (and OFL texts) to `assets/fonts/`, then `--headless --import`.
  - **Verify:** `ResourceLoader.load()` of both returns `Font` (asserted in test_ui_tokens). `.import`
    files + `.godot/imported` fontdata confirmed generated.
  - _Requirements: 2.1_
- [x] 1.3 `project.godot` display: 1688×780, `canvas_items`/`expand`, handheld orientation sensor
        landscape.
  - **Verify:** `grep -n "viewport_width=1688\|viewport_height=780\|orientation" project.godot` — confirmed.
  - _Requirements: 3.1_
- [x] 1.4 Re-derive scale constants in `PirateThemeBuilder` per design §3 table (MOBILE/TABLET
        CONTROL_SCALE→1.0/1.0, FONT_SCALE→1.0/1.1, MIN_TOUCH_TARGET→96×96 both). Updated
        `test_pirate_theme_builder_mobile_scaling` (2 assertions replaced — see design.md §3) and
        `test_touch_target_audit` (hardcoded `72.0` → `PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET`
        reference).
  - **Verify:** both tests pass with the new numbers as intended (test_touch_target_audit's own
    audit test still shows exactly the 2 pre-existing MainMenu/SettingsMenu failures, unchanged
    from baseline — tracked for Phase 4, not regressed further).
  - _Requirements: 3.3_
- [x] 1.5 Fixed `MobileLayoutManager.safe_area()`'s screen-px vs canvas-px mismatch (maps the native
        safe rect through `viewport.get_final_transform().affine_inverse()`) and re-based
        `REFERENCE_LANDSCAPE` to 1688×780. Also made `is_mobile()` honour
        `PirateThemeBuilder.force_mobile_scaling_for_test` (design §8's "known harness gap") — and,
        found while verifying the sweep, `MobileControls._uses_mobile_layout()` had the identical gap
        independently and needed the same fix (design §8). `SafeAreaMargin.gd` created (not yet wired
        into any screen — Phase 4+ does that).
  - **Verify:** new `tests/test_safe_area_units.gd` (5 tests, using an embedded `Window` with real
    `content_scale_*` to reproduce the actual physical/canvas split) — 80 phys-px inset → 57.8 canvas
    px, matching the spec's own worked example almost exactly; `SafeAreaMargin` margins = max(96,
    inset) in both directions verified. All passing.
  - _Requirements: 3.2_
- [x] 1.6 `SettingsManager` HUD-layout migration (design §9): scale stored positions by 780/1080 and
        stamp `hud_layout_version = 2`.
  - **Verify:** new `tests/test_hud_layout_migration.gd` (5 tests) — v1 config (no version key)
    rescales positions and leaves `scale_mult` untouched; a v2 config loads unchanged; empty
    overrides migrate without error; `save_settings()` always stamps the current version. All passing.
  - _Requirements: 7.3_
- [x] 1.7 Wired Germania One into Button/CheckButton/CheckBox/OptionButton/TabContainer/TabBar's font
        slots (was Cinzel) and Baloo 2 (a `FontVariation` at weight 600) into the default/Label/body
        slot when `ui_font == 0` (was Cinzel default) — using the existing styleboxes, no kit yet.
        Fixed `MockSettingsManager` in `test_settings_menu.gd` (missing `ui_font`, a pre-existing
        non-failing SCRIPT ERROR source per the Phase 0 baseline notes).
  - **Verify:** GUT passes (`test_ui_tokens.gd`'s `test_build_uses_germania_for_the_button_font` /
    `test_build_uses_baloo2_for_the_default_body_font_when_ui_font_is_default`); sweep confirms the
    new fonts render on every screen.
  - _Requirements: 2.3, 2.4_
- [x] 1.8 Fixed what the sweep showed broken:
  - MainMenu's title/subtitle overlapped ButtonPanel (Germania/Baloo2's taller line-height vs.
    Cinzel's, against ButtonPanel's independently-hardcoded offsets — CLAUDE.md's own named fragile
    pattern) — nudged ButtonPanel down as a documented stop-gap; Phase 4 owns the real shared-container
    fix. Also found `UIScreenSweep`'s own `_settle()` frame-wait couldn't outlast MainMenu's real-time
    title fade-in tween (pre-existing since Phase 0, unrelated to any M22 change, confirmed against
    the `before/` baseline capture) — added `_wait_seconds()` for real-time waits.
  - The base-resolution/scale-constant change also surfaced a second, WIDER regression: ~12 button
    call sites across CaptainsLog/CreditsScreen/DeathScreen/IslandMenu/PauseMenu/
    PurchaseSupportScreen/RaidReportScreen/StoreScreen/TutorialDialogue/WardrobeScreen/
    WhatsNewScreen/WorldMapScreen relied on `scaled_size()`'s old 1.5× multiplier turning a "48"
    literal into exactly the old 72px floor — fixed at the root with a new
    `PirateThemeBuilder.scaled_button_size()` (design §8b), not 12 one-off patches.
  - The right-hand HUD column clipping off-screen on phone (WorldHUD) was confirmed present in the
    Phase-0 `before/` baseline too — a pre-existing defect, not caused by Phase 1; left for Phase 5,
    which owns WorldHUD.
  - **Verify:** phone + desktop sweep re-captured and viewed (`screenshots/m22/phase1/`) after every
    fix above; no off-screen or overlapping control found on MainMenu, PauseMenu, CaptainsLog,
    IslandMenu, WorldHUD, Settings, or Credits. Full GUT suite: 652 tests, 650 passing — the same 2
    pre-existing, tracked failures as the Phase 0 baseline, no new ones.
  - _Requirements: 3.4_
- [x] 1.9 **Checkpoint — Phase 1.** checkpoint-reviewer PASSed all 10 substantive criteria on its
        first independent pass; flagged one open question (`test_ocean_properties`'s
        `test_property_19_wave_animation_continuity` failing in its own run, 650/652/3 vs. the
        expected 650/652/2). Resolved with direct evidence, not asserted: that test draws
        unseeded `randf_range()` 25x against Godot's global per-process RNG
        (`tests/test_ocean_properties.gd:12-38`); `git log` on it and
        `scripts/world/WaveGenerator.gd`/`OceanSettings.gd` shows zero M22 commits; isolated
        re-runs were 5/5 passing; 3 further fresh full-suite runs after the reviewer's were all
        652/650/2 (the expected baseline). Pre-existing, out-of-scope test-hygiene defect, not a
        Phase 1 regression — see Notes for the write-up. Phase 1 files committed and pushed
        (scoped commit, Phase 2 work in the same tree left unstaged).

### Phase 2 — Texture kit

- [ ] 2.1 `tools/ui_kit/gen_kit.py` skeleton + panels: parchment 9-slice, wood frame + rope +
        studs, wood plaque 3-slice.
  - **Verify:** `python tools/ui_kit/gen_kit.py` is deterministic: two runs → byte-identical SVGs.
  - _Requirements: 4.1, 4.2_
- [ ] 2.2 Buttons: Primary (coral), Brass, Wood-round × idle/pressed/disabled with baked lip.
  - **Verify:** `UIKitSheet` screenshot shows 9 button states; pressed body sits 4 design px lower.
  - _Requirements: 4.1_
- [ ] 2.3 Controls: toggle on/off + knob, rope slider track/fill/knob, segmented well/pill, tab
        idle/active, dropdown sheet, scrollbar.
  - **Verify:** UIKitSheet screenshot next to v0.3 "Settings controls" for side-by-side review.
  - _Requirements: 4.1_
- [ ] 2.4 Misc: resource pill, 5 rarity gem borders, cooldown ring mask, glow sprite.
  - **Verify:** UIKitSheet screenshot.
  - _Requirements: 4.1_
- [ ] 2.5 Icons: **correction, see design.md §5a** — `claude design outputs/` has no new art (every
        file there except `higgins.png` is a byte-identical duplicate of an existing, correctly-placed
        asset; verified by hashing the whole folder against `assets/`). Nothing to move. Generate
        the two genuinely-missing resource icons (research, cannonball) per the v0.3 icon spec, add
        them to `UIIcons._PATHS`.
  - **Verify:** test iterates `UIIcons` keys, and every one loads a `Texture2D`.
  - _Requirements: 4.3_
- [ ] 2.6 `scenes/debug/UIKitSheet.tscn` laying out every piece (+ a sweep entry).
  - **Verify:** headful capture exists and has been viewed.
  - _Requirements: 4.4_
- [ ] 2.7 **Checkpoint — Phase 2.**

### Phase 3 — Theme rebuild

- [ ] 3.1 `build()`: panels (`ParchmentPanel`, `WoodFramePanel`, `PlaquePanel`; default
        Panel/PanelContainer = wood frame) from kit `StyleBoxTexture`s.
  - **Verify:** UIKitSheet "live controls" row shows each variation.
  - _Requirements: 5.5_
- [ ] 3.2 Buttons + variations (`PrimaryButton`, default brass, `WoodRoundButton`), label type
        variations, font shadow/outline (design §5, §7).
  - **Verify:** new `tests/test_theme_variations.gd` asserts each variation exists with the
    expected base type and font sizes.
  - _Requirements: 2.2, 2.3, 5.1_
- [ ] 3.3 `ButtonJuice` → modulate press (60/120ms); `PrimaryGlow.gd` + `mark_primary()`.
  - **Verify:** test simulates `button_down`/`button_up` and checks `self_modulate` reaches 0.88 and
    returns to 1. `mark_primary` twice → one glow child.
  - _Requirements: 5.2, 5.3_
- [ ] 3.4 HSlider (rope), CheckButton (toggle), CheckBox, OptionButton/PopupMenu (parchment),
        TabContainer/TabBar, ProgressBar, ScrollBar, LineEdit, TooltipPanel,
        AcceptDialog/ConfirmationDialog (`Window` `embedded_border`/`panel`). Delete the
        now-unused `_make_*_icon` image generators.
  - **Verify:** UIKitSheet live-controls row screenshot; slider track clearly visible.
  - _Requirements: 5.4_
- [ ] 3.5 Route every `PirateThemeBuilder.COLOR_*` use through the palette
        (`grep -rn "PirateThemeBuilder.COLOR_" scripts`).
  - **Verify:** that grep returns only the compatibility accessors themselves.
  - _Requirements: 1.3_
- [ ] 3.6 **Checkpoint — Phase 3** (sweep shows every screen already restyled by the theme alone).

### Phase 4 — Menus & modals

- [ ] 4.1 MainMenu: logo plaque, one Primary (Continue/New Game), brass secondaries, round gear.
  - **Verify:** phone + desktop sweep shots of MainMenu vs. v0.3.
  - _Requirements: 6.1, 6.3_
- [ ] 4.2 PauseMenu restyle (Resume = Primary).
  - **Verify:** sweep shot.
  - _Requirements: 6.1, 6.3_
- [ ] 4.3 SettingsMenu: confirm the slider root cause (design §9), constrain the content width,
        apply the rope-slider row anatomy with value readouts, container-laid Back. Same kit for the
        Controls/Account tabs. Restyle only: no new options.
  - **Verify:** sweep shots of all 3 tabs; every slider shows a track, knob and value; no
    horizontal scrollbar.
  - _Requirements: 6.2_
- [ ] 4.4 ChoiceDialog + crash-recovery notice (`CrashReporter`'s dialog) on the parchment modal.
  - **Verify:** sweep triggers both dialogs and captures them.
  - _Requirements: 6.1_
- [ ] 4.5 CreditsScreen, AgeGate, ConsentPanel.
  - **Verify:** sweep shots.
  - _Requirements: 6.1_
- [ ] 4.6 Strip now-redundant `theme_override_*`/`add_theme_*` in these screens; update the design.md
        inventory counts.
  - **Verify:** counts for Phase-4 screens reduced; GUT passes.
  - _Requirements: 1.3_
- [ ] 4.7 New `tests/test_primary_button_rule.gd`: instantiate each Phase-4 screen and assert
        ≤1 visible `PrimaryButton`.
  - **Verify:** test passes. (Extended to more screens in Phases 5–6.)
  - _Requirements: 6.3_
- [ ] 4.8 **Checkpoint — Phase 4.**

### Phase 5 — HUD & mobile controls

- [ ] 5.1 WorldHUD resource pills (kit pill + icon + `HudNumLabel`), notoriety chip, production
        timer chip.
  - **Verify:** `test_world_hud_layout` passes (expectations updated only where intended); sweep shot.
  - _Requirements: 7.1_
- [ ] 5.2 Speed/sail plaque + hull ProgressBar restyle (keep the tween + low-hp pulse).
  - **Verify:** sweep shot at full hull and at <25% hull (harness sets health).
  - _Requirements: 7.1_
- [ ] 5.3 MobileControls → `WoodRoundButton` + icons; Set Sail = `mark_primary`.
  - **Verify:** sweep with forced mobile shows the controls; touch-target audit passes.
  - _Requirements: 7.2, 7.3_
- [ ] 5.4 Ability/broadside cooldown as a clockwise `TextureProgressBar` sweep (visual only, reading
        the existing cooldown values).
  - **Verify:** test sets a cooldown fraction → progress value matches; `git diff` of combat
    scripts is empty.
  - _Requirements: 7.2, 7.4_
- [ ] 5.5 Log/Map/Codex/New/Wardrobe drawer → round icon-button rail.
  - **Verify:** sweep shot; each button still opens its screen (existing tests / manual sweep).
  - _Requirements: 7.1_
- [ ] 5.6 Regression pass: HudCustomizeOverlay drag/resize, left-handed mirror, tilt-to-steer UI.
  - **Verify:** existing tests pass; sweep shot with left-handed on and a custom layout applied.
  - _Requirements: 7.3_
- [ ] 5.7 **Checkpoint — Phase 5.**

### Phase 6 — Content screens (6a then 6b)

- [ ] 6.1 (6a) IslandMenu → v0.3 screen 02 composition (right-docked detail panel, parchment cost
        chips, one Primary Upgrade/Build).
  - **Verify:** `test_island_menu_layout` passes; sweep shot vs. v0.3 02.
  - _Requirements: 8.1, 8.2_
- [ ] 6.2 (6a) Captain drawer/roster → screen 03 card style. Rarity gems only if the data already
        has rarity (check `CaptainData` first).
  - **Verify:** sweep shot; `git diff resources/` shows no schema change.
  - _Requirements: 8.1, 8.3_
- [ ] 6.3 (6a) WorldMapScreen → screen 01 right-docked panel (keep 90fd46f's ring-label fix).
  - **Verify:** sweep shot.
  - _Requirements: 8.1, 8.2_
- [ ] 6.4 (6a) TutorialDialogue → screen 06 toast (Higgins portrait, brass Next).
  - **Verify:** sweep shot.
  - _Requirements: 8.1_
- [ ] 6.5 (6a) **Checkpoint — Phase 6a.**
- [ ] 6.6 (6b) CaptainsLog, CodexScreen, WhatsNewScreen.
  - **Verify:** their layout tests pass; sweep shots.
  - _Requirements: 8.1_
- [ ] 6.7 (6b) WardrobeScreen, StoreScreen, PurchaseSupportScreen, RewardedBonusOffer.
  - **Verify:** sweep shots.
  - _Requirements: 8.1_
- [ ] 6.8 (6b) RaidReportScreen, DeathScreen (keep the distinct alarm/somber palette via tokens),
        UpgradeChoiceScreen.
  - **Verify:** sweep shots.
  - _Requirements: 8.1_
- [ ] 6.9 (6b) EnemyHealthBarWidget, FloatingDamage (Baloo 800 numbers + ink outline).
  - **Verify:** CombatCaptureHarness shot.
  - _Requirements: 8.1_
- [ ] 6.10 (6b) Extend `test_primary_button_rule` to every screen; update the inventory counts.
  - **Verify:** test passes.
  - _Requirements: 6.3, 1.3_
- [ ] 6.11 (6b) **Checkpoint — Phase 6b.**

### Phase 7 — Motion foundation

- [ ] 7.1 `UIMotion.gd` helpers + `reduced_motion()` hook (design §10).
  - **Verify:** `tests/test_ui_motion.gd`: each helper returns a valid Tween, and with reduced motion
    forced on, durations collapse to 0.
  - _Requirements: 9.1, 9.4_
- [ ] 7.2 `CelebrationQueue.gd` tier rules.
  - **Verify:** test: two Large plays → the second waits until the first CTA `pressed`; Small plays
    immediately during a Large.
  - _Requirements: 9.2_
- [ ] 7.3 Apply Small-tier juice: resource pill shine + number tick on change, pop-in on
        modal open, tutorial typewriter.
  - **Verify:** sweep sequence shots mid-animation.
  - _Requirements: 9.1_
- [ ] 7.4 **Checkpoint — Phase 7.**

### Phase 8 — Gameplay moments

- [ ] 8.1 Grep and record the real signals for each moment (design §10). Add any missing signal on
        its owning system.
  - **Verify:** the table in design.md §10 is updated with file:line for each signal.
  - _Requirements: 9.3_
- [ ] 8.2 Medium: enemy sunk stamp + flotsam; loot pickup; ship upgrade refit.
  - **Verify:** CombatCaptureHarness shots mid-moment.
  - _Requirements: 9.2, 9.3_
- [ ] 8.3 Medium: notoriety escalation banner at band crossings; defeat (somber, one clear way
        forward) on DeathScreen.
  - **Verify:** capture shots.
  - _Requirements: 9.2, 9.3_
- [ ] 8.4 Large: battle victory (RaidReport), island tier up; coin burst `GPUParticles2D`
        (14, 0.8s), rotating rays.
  - **Verify:** capture shots; queue test covers the victory + tier-up overlap.
  - _Requirements: 9.2, 9.3_
- [ ] 8.5 Captain reveal (rarity-scaled intensity only if data exists, else a single tier).
  - **Verify:** capture shot.
  - _Requirements: 9.2, 8.3_
- [ ] 8.6 **Checkpoint — Phase 8.**

### Phase 9 — Polish, audit, docs

- [ ] 9.1 Full sweep at phone 19.5:9, 16:9, tablet 4:3 and desktop, then fix overflow/clipping.
  - **Verify:** all shots viewed; list any accepted exceptions in Notes.
  - _Requirements: 3.4_
- [ ] 9.2 Retire unused assets (Kenney button PNGs, Cinzel if unreferenced), after grepping for
        references.
  - **Verify:** grep shows 0 references before deletion; GUT passes.
  - _Requirements: 1.3_
- [ ] 9.3 Docs: `docs/05_CURRENT_SYSTEMS.md` M22 section; `docs/03_ART_DIRECTION.md` → v0.3 tokens;
        fix the stale "one accepted failing test" note in CLAUDE.md if still wrong; `sync-systems-doc`.
  - **Verify:** `sync-systems-doc` reports no undocumented M22 files.
  - _Requirements: 10.3_
- [ ] 9.4 **Final checkpoint — M22.**

## Notes

- **GUT baseline (real run 2026-09-25, Godot 4.3 `.godot-tools/`, pre-M22 tree): 96 scripts,
  631 tests, 629 passing, 2 failing, 3745 asserts.** Both docs are stale (`05_CURRENT_SYSTEMS.md`
  says 467/467; CLAUDE.md names the LOD test, which now passes). The 2 pre-existing failures:
  1. `test_ad_gating::test_ready_state_actually_allows_an_ad_request` — "expected an ad load call
     for the surface". Ad-SDK gating, unrelated to M22. Leave it for M17, but it must not change.
  2. `test_touch_target_audit::test_property_all_screens_meet_touch_target_minimums` — MainMenu's
     6 buttons are 320×64 and SettingsMenu's ReplayTutorial (0,68) / Back (176,62) fall under the
     72 floor. **This is an M22 defect to fix** (Phase 1.4 raises the floor to 96; Phase 4 sizes
     these buttons), not a test to loosen. It must pass by the Phase 4 checkpoint.
  - Also pre-existing and non-failing: `test_settings_menu`'s `MockSettingsManager` has no
    `ui_font` property, so it throws SCRIPT ERRORs at `SettingsMenu.gd:450`. Fix the mock in
    Phase 1.7, which touches `ui_font`.
  - **Found during Phase 1 checkpoint review, unrelated to M22:**
    `test_ocean_properties::test_property_19_wave_animation_continuity` failed exactly once
    across 6 total full-suite runs this milestone (5 by the implementing session, 1 by
    checkpoint-reviewer) — every other run (including 5/5 when re-run in isolation immediately
    after) passed. Root cause: the test itself draws `randf_range()` 25x with no fixed seed
    (`tests/test_ocean_properties.gd:17-25`) against Godot's global RNG, which is seeded from
    system entropy fresh per process — a real, pre-existing test-hygiene defect (probabilistic,
    order/seed-dependent), not a regression: no file this milestone touches is anywhere near
    `scripts/world/WaveGenerator.gd`/`OceanSettings.gd`, and `git log` on both confirms no
    M22 commit exists for either. Logged here rather than silently reconciled (this project's own
    stated lesson, docs/16_MILESTONE_HISTORY.md's M15.5 "419 vs 434" entry) — worth a real fix
    (seed the RNG or use a local `RandomNumberGenerator`) as a small separate task outside M22,
    not blocking this checkpoint.
- **Highest-risk task:** 1.3/1.4/1.8, the base-resolution change. It moves every screen at once.
  Keep it in its own commit so it can be bisected.
- **Parallelizable:** within Phase 2, tasks 2.1–2.5 are independent. Within Phase 6, screens are
  independent once Phase 3 has landed.
- Settings is **restyle only**. The v0.3 five-page settings layout is look-reference, not scope.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["0.1", "0.2", "0.3", "0.4", "0.5"] },
    { "id": 1, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9"] },
    { "id": 2, "tasks": ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7"] },
    { "id": 3, "tasks": ["3.1", "3.2", "3.3", "3.4", "3.5", "3.6"] },
    { "id": 4, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6", "4.7", "4.8"] },
    { "id": 5, "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7"] },
    { "id": 6, "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "6.10", "6.11"] },
    { "id": 7, "tasks": ["7.1", "7.2", "7.3", "7.4"] },
    { "id": 8, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6"] },
    { "id": 9, "tasks": ["9.1", "9.2", "9.3", "9.4"] }
  ]
}
```
