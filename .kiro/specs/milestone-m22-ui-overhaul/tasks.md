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

- [x] 2.1 `tools/ui_kit/gen_kit.py` skeleton + panels: parchment 9-slice, wood frame + rope +
        studs, wood plaque 3-slice.
  - **Verify:** `python tools/ui_kit/gen_kit.py` is deterministic: two runs → byte-identical SVGs.
    Confirmed via `diff -rq` on two separate `--out-dir` runs — **first attempt was NOT
    deterministic** (a button gradient id used Python's built-in `hash()` on a tuple, which is
    salted per-process unless `PYTHONHASHSEED` is fixed); fixed by using a plain descriptive id
    string instead of a hash. Re-verified deterministic after the fix, and again after a later
    parchment-highlight tweak.
  - _Requirements: 4.1, 4.2_
- [x] 2.2 Buttons: Primary (coral), Brass, Wood-round × idle/pressed/disabled with baked lip.
  - **Verify:** `UIKitSheet` screenshot shows all 9 button states. Rectangular (Primary/Brass)
    idle/pressed clearly differ (taller vs. shorter lip, body dropped `dpx(4)`=8px). The wood-round
    button's first attempt used a same-radius circle offset a few px for its "lip", which is
    correct for the rectangular buttons' rect-slab lip but produced only a razor-thin, barely-
    visible sliver on a circle — caught by actually looking at the capture, not assumed from the
    code; fixed with a proper stadium-shaped slab.
  - _Requirements: 4.1_
- [x] 2.3 Controls: toggle on/off + knob, rope slider track/fill/knob, segmented well/pill, tab
        idle/active, dropdown sheet, scrollbar.
  - **Verify:** UIKitSheet screenshot reviewed against the v0.3 doc's "Settings controls" section —
    toggle on (teal+brass knob right) vs. off (dark wood+cream knob left), rope slider's dark
    groove vs. gold fill vs. brass knob, segmented pill vs. well, tab active (parchment) vs. idle
    (dark), all visually distinct.
  - _Requirements: 4.1_
- [x] 2.4 Misc: resource pill, 5 rarity gem borders, cooldown ring mask, glow sprite.
  - **Verify:** UIKitSheet screenshot — all 5 rarity gems distinct (common/uncommon/rare plain
    rings, epic/legendary with a visible outer glow), cooldown ring mask a clean white ring,
    glow sprite a soft coral radial blob.
  - _Requirements: 4.1_
- [x] 2.5 Icons: **correction, see design.md §5a** — `claude design outputs/` has no new art (every
        file there except `higgins.png` is a byte-identical duplicate of an existing, correctly-placed
        asset; verified by hashing the whole folder against `assets/`). Nothing to move. Generated
        the two genuinely-missing resource icons (research, cannonball) per the v0.3 icon spec,
        added to `UIIcons._PATHS`. Also found: a `tests/test_ui_icons.gd` already existed from
        M15.5 covering the original 7 keys — merged into it (extended `_EXPECTED_KEYS`, added one
        new size-sanity test) rather than the accidental blind overwrite this session first made
        (caught before committing; no coverage was actually lost, since the replacement happened to
        be a strict superset, but the discipline violation — not reading before overwriting an
        existing file — is worth naming here rather than quietly fixing).
  - **Verify:** `tests/test_ui_icons.gd` iterates all 9 `UIIcons` keys (old 7 + new 2), every one
    loads a `Texture2D`; 3/3 passing.
  - _Requirements: 4.3_
- [x] 2.6 `scenes/debug/UIKitSheet.tscn` laying out every piece (+ a sweep entry).
  - **Verify:** headful capture exists (`screenshots/m22/phase2/`) and has been viewed, both
    standalone and via `UIScreenSweep --profile=desktop`'s new `13_ui_kit_sheet` entry (a
    `self_capture` export was needed on `UIKitSheet` so an embedded instance doesn't also see the
    shared `--capture-dir=` arg and quit the whole sweep early — confirmed the full sweep runs to
    completion, all 16 shots, with it wired in).
  - _Requirements: 4.4_
- [x] 2.7 **Checkpoint — Phase 2.** checkpoint-reviewer independently re-verified all 6 criteria
        (determinism via its own `diff -rq` on two fresh runs, all 34 files rasterizing through
        Godot's real importer, `UIIcons`/test extension, the sweep integration end-to-end with its
        own headful run, a fresh GUT suite at 653/651/2 — same 2 tracked failures, no regression —
        and scope). PASS. Committed and pushed.

### Phase 3 — Theme rebuild

- [x] 3.1 `build()`: panels (`ParchmentPanel`, `WoodFramePanel`, `PlaquePanel`; default
        Panel/PanelContainer = wood frame) from kit `StyleBoxTexture`s.
  - **Verify:** UIKitSheet "live controls" row (new) shows all three panel variations + the
    default Panel/PanelContainer, each a real `StyleBoxTexture` — reviewed on
    `screenshots/m22/phase3/desktop/ui_kit_sheet.png`. Also visible automatically on every real
    screen the sweep touches (WorldHUD chips/dialogue, IslandMenu, PauseMenu, TutorialDialogue) —
    design.md §1's "layer 2 changes the most pixels for the least risk" claim confirmed directly.
  - _Requirements: 5.5_
- [x] 3.2 Buttons + variations (`PrimaryButton`, default brass, `WoodRoundButton`), label type
        variations, font shadow/outline (design §5, §7).
  - **Verify:** `tests/test_theme_variations.gd` (6 tests) — panel/button variation base types,
    default-Button-is-brass-not-primary, label type-scale sizes match `UITokens`,
    Display/Title use Germania with shadow+outline, HudNum/Chip use the 800-weight Baloo2
    variation. All passing.
  - _Requirements: 2.2, 2.3, 5.1_
- [x] 3.3 `ButtonJuice` → modulate press (60/120ms); `PrimaryGlow.gd` + `mark_primary()`.
  - **Verify:** `tests/test_button_juice_and_glow.gd` (2 tests, deliberately split from
    test_theme_variations.gd — its real-time press-timing assertion doesn't want that file's
    heavy per-test theme-rebuild `before_each` ahead of it). `button_down`/`button_up` simulated via
    direct `emit_signal` (see Notes — a lambda-callable quirk found along the way);
    `self_modulate` reaches 0.88 and returns to 1. `mark_primary` called twice → exactly one
    `PrimaryGlow` child. Both passing.
  - _Requirements: 5.2, 5.3_
- [x] 3.4 HSlider (rope), CheckButton (toggle), CheckBox, OptionButton/PopupMenu (parchment),
        TabContainer/TabBar, ProgressBar, ScrollBar, LineEdit, TooltipPanel,
        AcceptDialog/ConfirmationDialog (`Window` `embedded_border`/`panel`). Deleted the
        now-unused `_make_toggle_icon`/`_make_slider_grabber_icon` generators (kit textures
        replace them); `_make_checkbox_icon` kept (no kit asset for CheckBox) and recoloured onto
        the palette.
  - **Verify:** `screenshots/m22/phase3/desktop/11_settings_tab0.png` — the pre-M22 "invisible
    slider" defect (tasks.md Notes, M18) is fixed: all three sliders show a gold fill, dark
    groove, and brass knob. Required a real, non-obvious second fix beyond the kit texture itself
    (design.md §11a — Slider's stylebox content-margin doubles as groove thickness, not padding).
    Dropdown/tabs/checkboxes/toggles all reviewed on the same capture and on
    `ui_kit_sheet.png`'s live-controls row.
  - **Correction (Phase 4):** three things this item claimed were wrong, and the Phase 4 sweep
    caught all three. (a) Toggles were never the kit art: the icons were set under Godot 3's
    `on`/`off` names, which Godot 4 ignores. (b) AcceptDialog theming never reached the crash
    notice, because a `Window` under a CanvasLayer can't inherit the theme. (c) ScrollBars were 0px
    wide. All three are fixed in Phase 4 (design.md §11b).
  - _Requirements: 5.4_
- [x] 3.5 Route every `PirateThemeBuilder.COLOR_*` use through the palette
        (`grep -rn "PirateThemeBuilder.COLOR_" scripts`).
  - **Verify:** `grep -rn "PirateThemeBuilder.COLOR_" scripts` returns zero real matches (one
    unrelated comment in `tools/gen_app_icons.gd` naming the old const for cross-reference). No
    compatibility accessors were needed — every one of the 27 call sites across `ChoiceDialog.gd`,
    `PortraitFallback.gd`, `SettingsMenu.gd` (11), `WorldMapScreen.gd` (9), `WorldHUD.gd` (2) was
    migrated directly to `UITokens.palette().<field>`, and the old `COLOR_*`/`_make_toggle_icon`
    style consts were deleted from `PirateThemeBuilder.gd` outright rather than kept as a second,
    parallel colour system (AGENTS.md "never duplicate systems").
  - _Requirements: 1.3_
- [x] 3.6 **Checkpoint — Phase 3.** Full sweep (phone + desktop, all 16 shots each,
        `screenshots/m22/phase3/{phone,desktop}/`) viewed: MainMenu, WorldHUD, IslandMenu,
        PauseMenu, Settings (all 3 tabs), Credits all already restyled by the theme alone — wood
        frame panels, brass/coral buttons, working sliders, no text clipping. GUT full suite
        710/714 passing (see Notes for the 4 non-blocking failures and their disposition). Two
        real defects found and fixed via the live-controls capture, not assumed from code (design
        §11a): a confirmed upstream Godot 4.3 button-text-clipping engine bug (worked around
        centrally), and Slider's content-margin-as-groove-thickness behaviour.
        `checkpoint-reviewer` independently re-verified all of the above (its own fresh GUT run,
        its own headful sweep, its own `git show 74af27e --stat` scope check, its own grep for
        Phase 3.5's palette migration) — PASS. Committed (`74af27e`) and pushed.

### Phase 4 — Menus & modals

- [x] 4.1 MainMenu: logo plaque, one Primary (Continue/New Game), brass secondaries, round gear.
  - **Verify:** phone + desktop sweep shots of MainMenu vs. v0.3.
    `screenshots/m22/phase4/{phone,desktop}/10_main_menu.png` were viewed. They show the emblem +
    Germania title plaque, coral New Game (Continue when a save exists) with glow, brass
    Store/Credits/Quit on a wood frame, and the round wood gear (new `gear.svg` kit icon). The sizes
    come from `scaled_button_size()`. Found along the way (design.md §11b): **every** brass/coral
    button's label sat half off its face. It's fixed at the kit source, and the fix applies to
    every screen.
  - _Requirements: 6.1, 6.3_
- [x] 4.2 PauseMenu restyle (Resume = Primary).
  - **Verify:** sweep shot. `07_pause_menu.png` (both profiles) shows a WoodFramePanel, coral
    Resume and brass Settings/Quit to Menu, with labels centred on their faces.
  - _Requirements: 6.1, 6.3_
- [x] 4.3 SettingsMenu: confirm the slider root cause (design §9), constrain the content width,
        apply the rope-slider row anatomy with value readouts, container-laid Back. Same kit for the
        Controls/Account tabs. Restyle only: no new options.
  - **Verify:** sweep shots of all 3 tabs; every slider shows a track, knob and value; no
    horizontal scrollbar. `11_settings_tab{0,1,2}.png` (phone + desktop) were viewed. Pages are
    now parchment with ink text (`build_parchment_page_theme()`), with the rope track, knob and
    "%" readout clear of the knob. Toggles are the real kit art (the Godot 3 icon-name bug, §11b),
    dropdowns show the new ink chevron, Controls-row labels no longer run into their dropdown, the
    phone has no horizontal scrollbar and no clipped readouts, and phone text uses token sizes.
    Covered by `test_settings_menu*.gd`, and `test_theme_variations.gd` gained toggle/RichText tests.
  - _Requirements: 6.2_
- [x] 4.4 ChoiceDialog + crash-recovery notice (`CrashReporter`'s dialog) on the parchment modal.
  - **Verify:** sweep triggers both dialogs and captures them. `UIScreenSweep._run_modals()` →
    `14_crash_notice.png`/`15_choice_dialog.png` show a centred parchment, ink title/body and brass
    buttons (no Primary: a destructive choice must never be coral). The crash notice now uses
    ChoiceDialog; the old AcceptDialog could never inherit the theme (§11b).
  - _Requirements: 6.1_
- [x] 4.5 CreditsScreen, AgeGate, ConsentPanel.
  - **Verify:** sweep shots. `12_credits.png`: Credits is rebuilt as one CenterContainer
    (parchment + ink title + `InkRichTextLabel`, then Back) on the MainMenu background art. Its
    `[b]`/`[i]` headings now render, which needed the has_font/default_font fix in §11b.
    `16_age_gate.png`/`17_consent_panel.png` are parchment modals that fit on phone.
  - _Requirements: 6.1_
- [x] 4.6 Strip now-redundant `theme_override_*`/`add_theme_*` in these screens; update the design.md
        inventory counts.
  - **Verify:** counts for Phase-4 screens reduced; GUT passes. design.md §12: `tscn`/`gd` counts
    went from 36/45 to 19/10 across the 7 Phase-4 surfaces. Everything left in the scenes is
    container spacing, which is layout rather than styling. The Settings section card and toast
    moved onto theme variations (`InkInsetPanel`, `WoodFramePanel`).
  - _Requirements: 1.3_
- [x] 4.7 New `tests/test_primary_button_rule.gd`: instantiate each Phase-4 screen and assert
        ≤1 visible `PrimaryButton`.
  - **Verify:** test passes. (Extended to more screens in Phases 5–6.) 3 tests pass: exactly one
    Primary on MainMenu/PauseMenu (so it can't pass vacuously); at most one on
    Settings/Credits/AgeGate/Consent; none in ChoiceDialog.
  - _Requirements: 6.3_
- [x] 4.8 **Checkpoint — Phase 4.** Full sweeps (`screenshots/m22/phase4/{phone,desktop}/`, now
        including the 4 new modal shots) were viewed. GUT full suite: 724/725. The sole failure is
        the already-documented `test_store_screen` overlap (deferred to 6b). The previously flaky
        `test_ad_gating` and the long-standing LOD test both pass this run. Nine real defects were
        found by looking and fixed (design.md §11b), including two that affected every screen:
        button labels sat off-face, and toggles were the engine default.
        `checkpoint-reviewer` independently re-verified: its own GUT run and headful sweep on both
        profiles, the §12 counts re-grepped, the container-layout rule, and no ship/combat files
        touched. Result: PASS.

### Phase 5 — HUD & mobile controls

- [x] 5.1 WorldHUD resource pills (kit pill + icon + `HudNumLabel`), notoriety chip, production
        timer chip.
  - **Verify:** `test_world_hud_layout` passes (expectations updated only where intended); sweep shot.
  - **Done:** five floating `ResourcePill`s (the kit pill regenerated at the design's 30-design-px
    height). Each has a painted icon (new generated gold/wood/iron/rum SVGs replace the tinted Kenney
    glyphs), a `HudNumLabel` amount and a dim `/cap` ChipLabel suffix; Research is the fifth pill
    (it was a "🧪 N" suffix on the economy text). Notoriety and "Next Production" are pill chips,
    with every translation key unchanged. Viewed: `screenshots/m22/phase5/{desktop,phone}/00*_*.png`.
    The phone overflow noted below was the stale 1.45× `hud_scale` plus a width cap measured
    against the pre-layout rect. Both are fixed (design.md §11c).
  - **Known going in (seen in both the Phase 3 and Phase 4 phone sweeps, `00_world_hud.png`):**
    the resource-pill bar and the right-hand Log/Map/Codex rail run off the right edge at
    2340×1080. The rail overlaps the Set Sail/Ability/Broadside cluster, and the notoriety chip is
    clipped. This isn't a Phase 4 regression, since the Phase 4 kit fix only made the labels
    readable; the layout itself is 5.1/5.3/5.4's job.
  - _Requirements: 7.1_
- [x] 5.2 Speed/sail plaque + hull ProgressBar restyle (keep the tween + low-hp pulse).
  - **Verify:** sweep shot at full hull and at <25% hull (harness sets health). `00b` (full) and
    `00c_world_hud_low_hull` (18/100) show the `PlaquePanel` speed/sail plaque (content inset
    widened to clear its brass studs) and the new `HullBar` (dark pill track + rounded hp-green
    fill). The tween and low-hp pulse are unchanged and visible. The compass now sits inside the
    plaque (it had been buried under the resource bar all along).
  - _Requirements: 7.1_
- [x] 5.3 MobileControls → `WoodRoundButton` + icons; Set Sail = `mark_primary`.
  - **Verify:** sweep with forced mobile shows the controls; touch-target audit passes. Steering,
    sail, ability, broadside, fire and pause are round wood buttons at the art's own aspect
    (`round_button_size()`). The context action is coral Primary only as "Set Sail"; it goes back to
    brass for Dock/Board/Anchor via the new `unmark_primary()`. `test_touch_target_audit` and
    `test_mobile_controls_layout` pass; the latter gained a context-action Primary test and an
    opener/context-action overlap check.
  - _Requirements: 7.2, 7.3_
- [x] 5.4 Ability/broadside cooldown as a clockwise `TextureProgressBar` sweep (visual only, reading
        the existing cooldown values).
  - **Verify:** test sets a cooldown fraction → progress value matches; `git diff` of combat
    scripts is empty. `test_cooldown_sweep_shows_the_remaining_fraction` passes: 25% ready → 0.75
    sweep, ready → 0, FILL_CLOCKWISE, and mouse-ignore so it never eats a tap. `00c` shows both
    sweeps mid-way. The HUD only reads `get_cooldown_fraction()`/`get_special_cooldown_fraction()`
    and no Phase 5 change touches `scripts/combat/` or `ShipCombat.gd`/`ShipController.gd`.
    `scripts/combat/EnemySpawner.gd`'s working-tree diff belongs to a concurrent session (it
    predates Phase 5) and is not part of this phase's commit.
  - _Requirements: 7.2, 7.4_
- [x] 5.5 Log/Map/Codex/New/Wardrobe drawer → round icon-button rail.
  - **Verify:** sweep shot; each button still opens its screen (existing tests / manual sweep).
    Desktop: one container-owned row of round wood icon buttons with captions (five new generated
    glyphs). Phone: an icon-only round opener plus a wood-frame drawer with the same five buttons in
    a row (`00d_mobile_drawer`). Every `*_button` reference and pressed handler is kept. The sweep
    itself still opens each screen through the HUD (`01`–`05`), and `test_world_hud_layout` and
    `test_captains_log`/`test_whats_new_screen` pass.
  - _Requirements: 7.1_
- [x] 5.6 Regression pass: HudCustomizeOverlay drag/resize, left-handed mirror, tilt-to-steer UI.
  - **Verify:** existing tests pass; sweep shot with left-handed on and a custom layout applied.
    `00e_left_handed` and `00f_custom_layout` (actions ×1.15 and moved, resource panel ×0.9) were
    viewed with nothing colliding. HudCustomizeOverlay still targets only TopBar, TopRightPanel and
    the three MobileControls clusters, all with unchanged paths. `test_hud_layout_migration` and the
    tilt-steering test pass. **Known, pre-existing (M13 design):** a saved override is clamped to the
    viewport, not to other controls, so a player *can* drag one cluster onto another. Seen with a
    harness-only override; the default layouts never overlap.
  - _Requirements: 7.3_
- [x] 5.7 **Checkpoint — Phase 5.** The v0.3 HUD Overlay mock was rendered headlessly and compared
        against real phone + desktop sweeps (`screenshots/m22/phase5/`, including the new
        `00b`–`00g` HUD states). GUT full suite 726/727; the sole failure is the documented
        `test_store_screen` overlap (6b). Test count +2. The design.md §11c findings include the stale
        1.45× phone scale, a phone sweep that had never shown the phone HUD, and the compass buried
        under the resource bar. `checkpoint-reviewer` independently re-verified with its own GUT
        run and headful sweeps on both profiles; it also confirmed the ship/combat diff is empty,
        re-grepped the §12 counts and judged the test-expectation changes: PASS.

### Phase 6 — Content screens (6a then 6b)

- [x] 6.1 (6a) IslandMenu → v0.3 screen 02 composition (right-docked detail panel, parchment cost
        chips, one Primary Upgrade/Build).
  - **Verify:** `test_island_menu_layout` passes; sweep shot vs. v0.3 02. Done:
    - tab pages are a parchment page with ink text (`build_parchment_page_theme()`, as in Settings);
    - every row is an `InkInsetPanel` card and cost text became icon `CostChip`s;
    - the title uses `TitleLabel`, and Colonize is the one coral Primary;
    - wrapped descriptions stop the modal changing width tab to tab, and empty tabs say so.

    All six tabs are restyled by one `_restyle_page()` pass rather than by re-authoring each row
    builder, because a concurrent session is editing this file. The sweep now captures an owned
    island (`06_island_owned_tab0..5`). Owned-island tab gating was also broken in real play (see
    the separate fix `2abf6e7`).
  - **Follow-up, approved by the user 2026-09-27:** the full v0.3 tile board plus right-docked
    detail panel.
    - Construction, Shipyard, Tavern and Research are boards of selectable `BoardTile`s. Each tile
      shows an icon or portrait, a name and a status such as "Lv 1 · Build", "Locked", "Hired" or
      "Crew Full".
    - The selected entry's full card is docked on the right. Its one enabled action is the Primary,
      unless Colonize is showing.
    - The header shows v0.3's island-tier pips.
    - The board re-parents the builders' own row nodes, so every button, closure and handler is
      unchanged.
    - The selection survives the refresh on every economy tick. That is covered by the new
      `tests/test_island_menu_board.gd` (5 tests), which caught a real bug: the rebuilt flow was
      auto-renamed while the stale one was still queued.
    - Fleet and Trade stay card lists by design (design.md §11d).
  - _Requirements: 8.1, 8.2_
- [x] 6.2 (6a) Captain drawer/roster → screen 03 card style. Rarity gems only if the data already
        has rarity (check `CaptainData` first).
  - **Verify:** sweep shot; `git diff resources/` shows no schema change. Tavern captain rows are
    roster cards: a 96px portrait in a `PortraitFrame`, the name, the ability line and SPD/TRN/DMG/HP
    stat chips (`06_island_owned_tab2`). `CaptainData` has **no rarity field**, so there are no gems
    and a plain frame, per the spec. No `resources/` or schema change from this phase (the only
    `resources/world/*.tres` diffs belong to a concurrent session).
  - _Requirements: 8.1, 8.3_
- [x] 6.3 (6a) WorldMapScreen → screen 01 right-docked panel (keep 90fd46f's ring-label fix).
  - **Verify:** sweep shot.
    - Landscape wood frame: the map is on the left as a teal sea disc under brass rings, and a
      parchment dossier with View Log/Close is on the right.
    - Map text uses the theme font with an ink outline (it was the engine fallback font at 12px).
    - 90fd46f's ring-label bearings are unchanged. Island labels now step aside when they would
      overprint a neighbour.
    - The sweep adds `02_world_map_discovered`, which discovers every island in memory only and
      selects one; `test_world_map_screen_layout`'s PC-size expectation changed deliberately.
  - _Requirements: 8.1, 8.2_
- [x] 6.4 (6a) TutorialDialogue → screen 06 toast (Higgins portrait, brass Next).
  - **Verify:** sweep shot (`08_tutorial_dialogue`):
    - A parchment card with the Higgins portrait, an ink name, "N of M", progress dots, wrapped
      body text, a text-link Skip and a brass Next.
    - The portrait had **never** shown: 27 beats author `portrait_path`, but the Label-only fallback
      returns early whenever art exists. It now uses the texture-rect contract.
    - The card grows from its content (the fixed box overflowed below the screen). On phone it fits
      the measured band between the thumb clusters.
  - _Requirements: 8.1_
- [x] 6.5 (6a) **Checkpoint — Phase 6a.** `checkpoint-reviewer` independently re-verified: its own
        GUT run (729/730), its own headful sweeps with zero ERROR lines, all 6a shots viewed, the
        building-id and VFX-lambda fixes checked for behaviour preservation (test_ship_combat
        unmodified, no fragile ship code touched), and the concurrent session's IslandMenu/Island hunks
        confirmed as independent of this work: PASS. Pre-review status: GUT 729/730 (only the documented
        StoreScreen failure) and 0 script errors in both sweeps (the lambda-capture error at World
        teardown is fixed, design.md §11d).
- [x] 6.6 (6b) CaptainsLog, CodexScreen, WhatsNewScreen.
  - **Verify:** their layout tests pass; sweep shots (`01_captains_log`, `03_codex`, `05_whats_new`,
    both profiles).
    - All three use one shared "journal page": a wood frame, a Germania `TitleLabel`, a parchment
      page, ink text and one brass Close. The page comes from the new
      `PirateThemeBuilder.dress_parchment_page()`, which also gives HSeparators an ink rule and
      RichText ink colour. Codex entries are `InkInsetPanel` cards.
    - Section headings use a new `UITokens.FONT_SECTION` (44), smaller than the frame title.
    - Wrapped body text had double-spaced lines (Baloo 2's tall ascent). The fix is
      `UITokens.BODY_LINE_SPACING` on InkBodyLabel and ChipLabel.
    - `test_captains_log_layout`/`test_whats_new_screen_layout` changed their PC sizes on purpose,
      from 480x560 to 880x640: at the old size the page left a text column about 300px wide. Both
      files say so. The behaviour tests (Labels directly under Content) are unchanged.
  - _Requirements: 8.1_
- [x] 6.7 (6b) WardrobeScreen, StoreScreen, PurchaseSupportScreen, RewardedBonusOffer.
  - **Verify:** sweep shots (`04_wardrobe`, `18_store`, `19_purchase_support`, `20_rewarded_offer`;
    the last three are new sweep entries, drawn from their render methods so that no analytics, ad
    or purchase state is touched).
    - **Wardrobe**
      - Slot buttons are a new `RailTab` variation (the Settings tab-rail art), opening onto a
        parchment page.
      - Cosmetics are v0.3 board tiles in an HFlowContainer. Before, a fixed 2-column grid of wide
        brass bars cropped at the page edge. Each tile shows Owned / Not Owned / **Equipped**,
        through a new read-only `ShipVisuals.get_equipped_cosmetic()`.
      - Tiles are not device-scaled: a scaled 330px tile didn't fit the phone page and cropped its
        status line (phone sweep). The "Tap a design…" detail line moved into the button row for the
        same vertical budget.
      - Equip is the one Primary. `PrimaryGlow` now hides while its button is disabled, with a new
        test in `test_button_juice_and_glow`.
      - The tile builder moved out of IslandMenu into a shared
        `PirateThemeBuilder.make_board_tile()`; both screens call it, so there is no second copy.
    - **Store, support and rewarded offer:** the same frame and page. Buy, Watch Ad and No Thanks are
      all brass, on purpose: a coral glowing buy button or ad button is the pressure the AGENTS.md
      never-list forbids. The new test group `SCREENS_THAT_MUST_NOT_HAVE_A_PRIMARY` pins this.
    - **The StoreScreen "overlap" failure (Notes, Phase 3) is fixed, and its diagnosis was wrong.**
      The failure was not Close's hardcoded 44px height. The test compared Close against `content`,
      the scrolled VBox, whose rect is its full 1040px height and mostly clipped. It now checks the
      ScrollContainer's visible rect and asserts clipping (`test_store_screen.gd` explains this).
  - _Requirements: 8.1_
- [x] 6.8 (6b) RaidReportScreen, DeathScreen (keep the distinct alarm/somber palette via tokens),
        UpgradeChoiceScreen.
  - **Verify:** sweep shots (`21_raid_repelled`, `21_raid_hit`, `22_death`, `23_upgrade_choice`,
    all new sweep entries).
    - **Raid report and Death:** a frame, a `DisplayLabel` title and a parchment page. The raid title
      is `hp_good` when the raid is repelled and `hp_low` when the island is hit; the Death title is
      `hp_low`. These token colours replace the hand-picked `Color(1,0.3,0.3)` values.
    - Defeat has one brass way forward and deliberately **no** coral glow, which would read as
      celebration.
    - `test_death_and_raid_report_layout` changed 500x300 to 760x400 on purpose. The Death penalty
      string is now wrapped in `tr()`.
    - **UpgradeChoice:** a frame, "Choose One", and the upgrades as `BoardTile` cards (glyph, ink
      name, effect line) on parchment, replacing the flat navy StyleBoxFlat.
  - _Requirements: 8.1_
- [x] 6.9 (6b) EnemyHealthBarWidget, FloatingDamage (Baloo 800 numbers + ink outline).
  - **Verify:** CombatCaptureHarness shot, plus a probe capture of spawned damage numbers. Changes:
    - **Enemy bar:** an ink-outlined name chip over a new `EnemyHullBar` (the hull pill with an
      `hp_low` red fill, so it can't be mistaken for the player's green hull).
    - **Damage numbers:** Baloo 800 in `hp_low`, with an ink outline, `fixed_size` and
      `no_depth_test`. At world scale they were a few pixels tall at combat range.

    **Two real bugs, found only by looking at the captures:**
    1. **Every damage number drifted toward the world origin.** Both spawners (ShipCombat and
       ShipCollisionHandler) `add_child()` first and set `global_position` afterwards, but
       FloatingDamage computed an absolute float-up target in `_ready()`. It now tweens relative to
       its start position. The fix is in FloatingDamage only; the protected combat files are
       untouched.
    2. **No Baloo "600/800" weight had ever rendered.** Godot 4.3 silently ignores a String
       `"wght"` key in `FontVariation.variation_opentype`, and the integer OpenType tag is
       required. Every HUD number, chip and body text had been Baloo 400 since Phase 1.
       `test_theme_variations` pinned the broken String key. It now asserts the tag and, as a
       behavioural check, that the 800 face shapes wider than 400.

    Also fixed, a 6a regression: TutorialDialogue's card became 4,558px tall in the combat
    capture. The wrapped label reported its height at ~0 width, and nothing re-ran the fit
    afterwards. It now also refits on the Panel's `minimum_size_changed`.
  - _Requirements: 8.1_
- [x] 6.10 (6b) Extend `test_primary_button_rule` to every screen; update the inventory counts.
  - **Verify:** test passes (4/4). Coverage:
    - Wardrobe has exactly one Primary.
    - The Log, Codex, What's New, Map, Tutorial, Support, Raid and UpgradeChoice screens have at
      most one.
    - Store, RewardedBonusOffer and Death must have none.
    - IslandMenu is covered by `test_island_menu_board` and the HUD by `test_mobile_controls_layout`,
      since both need a live world.

    design.md §12 counts are updated. Also fixed from the 6b sweep: a neutral island opened
    IslandMenu on a hidden Construction page, blank, with no tab lit. TabContainer only re-points a
    hidden current tab while visible. The fix is `_select_first_visible_tab()`, with a new test that
    fails without it (verified).
  - _Requirements: 6.3, 1.3_
- [x] 6.11 (6b) **Checkpoint — Phase 6b.** `checkpoint-reviewer` independently re-verified:
        - its own GUT run: **738/738**;
        - its own phone and desktop sweeps, plus CombatCaptureHarness, with zero ERROR lines;
        - the 6b shots, viewed;
        - the font-tag, FloatingDamage and first-visible-tab fixes;
        - the primary-rule coverage, and that the layout-size changes are deliberate;
        - that no fragile ship code was touched.

        Result: PASS. Not verifiable here: touch feel, haptics, on-device fps and notch safe area.

### Phase 6c — v0.3 fidelity pass (user request 2026-09-27)

Requested after 6b: "the colour combination of the original plan is better … pretty animation and
slight movements … text, colours, everything more proportionate … learn from the images and the
html". This pass matches the kit, typography and motion to the v0.3 doc's own CSS. Every value is
lifted from `Pirate Empire UI System v0.3.html` (design.md §13) rather than eyeballed, and the
Phase 7 motion foundation is folded in, since the user asked for the movement now.

- [x] 6c.1 Extract the v0.3 material/type/motion values from the HTML (inline styles, `@keyframes`,
        component JS) and record them in design.md §13.
- [x] 6c.2 Regenerate the kit to those values (`tools/ui_kit/gen_kit.py`):
        - **Wood frame:** v0.3 plank bands (period 17), a warm top sheen and a dark foot, radius 18
          with a 3px `#2e1a0c` border, and round brass studs. The rope edge and triangle corners
          are gone, and the centre is exactly two plank periods, so the theme tiles it
          (`AXIS_STRETCH_MODE_TILE_FIT`).
        - **Parchment:** clean `#ecd6a4` paper with the `#fdf1d2` top-left glow and a warm inset
          edge. The deckle and dirt are gone, and the grain was dropped because the stretched page
          turned hairlines into bands.
        - **Rope-parchment:** a new tutorial-toast card.
        - **Buttons:**
          - brass, with the 4-stop gradient, `#4a300f` border, `#5a3a12` lip and top light;
          - coral, with the ellipse radial `#ffd6ae → #b83a14`, `#6a260c` lip and bottom shade;
          - greyed disabled faces;
          - plank round buttons.
        - **Controls:**
          - the toggle is `#5a4632` off and `#2a9a96 → #17616a` on, with a brass knob;
          - the slider has a dark track, a teal `#8fe0d6 → #17616a` fill and a brass knob;
          - the resource pill is a dark `#3d2616 → #1f1209` gradient with a brass border and gloss.
        - **Icons:** the v0.3 coin, ringed log end, steel ingot, barrel, research scroll and a
          notoriety skull.
- [x] 6c.3 Typography and colour tokens (`UIPalette`: title `#fff1d0`/`#1a0e06`, soft body text
        `#e6d4b0`, HUD numbers `#fff4d6`, ink-soft `#8a6a3a`, brass text `#3a2410`, coral text
        `#fff8ec`/`#7a2a0a`, teal fill, and the modal dim `rgba(6,14,18,.62)`):
        - brass buttons, tabs, toggles and dropdowns are Baloo 800, and Germania is kept for titles
          and the coral CTA;
        - titles lose the outline and keep the hard drop;
        - new `InkSubLabel`, `PillNumLabel`, `HudCard` and `BountyCard` variations;
        - every modal backdrop is the teal-black dim via `dress_modal_dim()`.
- [x] 6c.4 HUD to v0.3 screen 04:
        - notoriety becomes a `HudCard` with a Germania title, the value, "Next escalation" in the
          coral accent, and the new `NotorietyBar` (gradient fill, threshold ticks, and a skull
          that shakes near the next escalation);
        - the cannon readouts and the production chip become translucent `HudCard`s;
        - the phone objective card becomes a parchment `BountyCard`;
        - pill numbers are grouped ("5,000");
        - the plaque studs no longer sit under the speed text;
        - the phone utility opener sits beside the notoriety card.
- [x] 6c.5 Motion ("slight animations and simple transitions"), all through `UIMotion` and all
        collapsing to still states under `reduced_motion()`:
        - **Modals:** every modal enters with `modal_enter()` (dim fade 0.18s plus a 450ms pop).
        - **Tutorial:** the toast pops in and types at 30 cps; the first Next tap reveals the line.
        - **Resource pills:** numbers tick and a gain shines the pill.
        - **Tiles and tabs:** the selected board tile lifts, and tab pages fade in.
        - **IslandMenu:** the tier track is numbered v0.3 nodes, and the current node breathes a
          glow.
        - **Notoriety:** the skull shakes near a threshold.
        - **Sweep:** the new `30_motion_modal_pop`, `31_motion_pill_shine_tick` and
          `32_motion_typewriter` shots capture motion mid-animation. Every other shot runs with
          motion collapsed, so it shows the settled state.
- [x] 6c.6 Tests updated on purpose (each commented): `test_theme_variations` (the title outline
        is 0 now, with the v0.3 colours asserted) and `test_ui_tokens` (brass is Baloo 800 and the
        Primary is Germania). The layout regression the phone opener caused was fixed, not the test.
- [x] 6c.7 **Checkpoint — Phase 6c** (with 7.1–7.3). `checkpoint-reviewer` independently re-verified:
        - its own GUT run: **748/748** (4245 asserts);
        - its own phone and desktop sweeps with zero ERROR lines, with the §13 values checked in
          the 00b/11/06/08 shots and the three motion shots;
        - `gen_kit.py` producing byte-identical output across two runs;
        - that the test changes are deliberate and non-loosening (`test_world_hud_layout` untouched);
        - that reduced motion is gated in the sweep, and that the CelebrationQueue fix is sound;
        - that no fragile ship code was touched.

        Result: PASS. Not verifiable here: touch feel, haptics, on-device fps with the textures and
        notch safe area.

### Phase 7 — Motion foundation

- [x] 7.1 `UIMotion.gd` helpers + `reduced_motion()` hook (design §10).
  - **Verify:** `tests/test_ui_motion.gd` (7 tests):
    - each helper returns a valid Tween;
    - pop_in starts at 0.6 and settles at 1 about its centre;
    - tick reaches its target and typewrite reveals the whole line;
    - shine is a single pulse that returns to white (below 3 Hz);
    - with reduced motion forced on, every helper jumps to its final state;
    - the query defaults to off while `SettingsManager` has no `reduce_motion`, since M19 adds it.
    Helpers: `pop_in`, `shine`, `tick_number` (+`group_digits`), `stamp`, `float_up`, `typewrite`,
    `modal_enter`, `idle_glow`, `tile_lift`, `fade_tabs`.
  - _Requirements: 9.1, 9.4_
- [x] 7.2 `CelebrationQueue.gd` tier rules.
  - **Verify:** `tests/test_celebration_queue.gd` (3 tests): two Large plays → the second waits until
    the first CTA `pressed`; Small and Medium play immediately during a Large; and a Large that
    leaves the tree without its CTA still releases the queue. That last test found a real bug:
    starting the next moment from the finished moment's own `tree_exiting` was refused by the
    host, and the start is now deferred.
  - _Requirements: 9.2_
- [x] 7.3 Apply Small-tier juice: resource pill shine + number tick on change, pop-in on
        modal open, tutorial typewriter.
  - **Verify:** sweep sequence shots mid-animation (`30_`/`31_`/`32_motion_*`, both profiles), done
    as part of 6c.5.
  - _Requirements: 9.1_
- [x] 7.4 **Checkpoint — Phase 7.** Covered by 6c.7 above (7.1–7.3 shipped inside the 6c pass).

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
  - **Found during Phase 3 (real GUT-suite run, this milestone's tree): 710/714 passing.** Beyond
    the 2 baseline failures above (still present, unchanged):
    1. `test_store_screen::test_property_no_overlap_between_content_and_close_button` — **new,
       real, and intentionally left failing** — see design.md §11a. **Resolved in 6.7, and the
       diagnosis below was wrong:** the rect compared was the clipped scroll content, not what is
       drawn (see 6.7). `StoreScreen.tscn`'s
       `CloseButton` has a hardcoded pre-M22 `custom_minimum_size.y = 44`; Germania One's own
       line-height at the new `FONT_BODY` makes the button's real content-driven minimum ~104px.
       Same class of "legacy hardcoded size vs. deliberately bigger theme" collision as
       `test_touch_target_audit` above, for a screen Phase 6 (task 6.7) already owns restyling —
       left failing and documented, not patched around or loosened.
    2. A **flaky, unrelated-to-M22 combat/purchase test** failed once per full-suite run, but
       *which one* varied run to run: this session's own runs saw
       `test_purchase_flow::test_bundle_purchase_grants_every_entitlement_atomically` fail once
       (8/8 passing in isolation immediately after); the independent `checkpoint-reviewer` pass
       saw `test_combat_loop_end_to_end::test_the_whole_v1_combat_loop_runs_through_the_real_scenes`
       fail instead, with `test_purchase_flow` passing clean. Neither file this milestone touches
       is anywhere near `StoreManager.gd`/`EntitlementManager.gd` or `scripts/world/`/`scripts/combat/`.
       `git status` throughout showed `scripts/world/{ShipCombat,ShipController,
       ShipCollisionHandler,EnemyAI,Cannonball,ShipMovement,ShipDamage,ShipStats}.gd` and several
       `resources/combat/*` files all modified/untracked under an unrelated in-progress
       `.kiro/specs/milestone-m23-naval-dynamics/` — a concurrent session's own active work
       (CLAUDE.md "Concurrent sessions git safety"). The failure moving between combat-adjacent
       tests run-to-run, never anything `scripts/ui/*`, is itself evidence this is state/timing
       noise from that concurrent work landing mid-run, not a Phase 3 regression. Not investigated
       further and not staged/committed by this phase (scoped `git add` of M22 files only).
    - Also observed, transient and non-reproducing: one phone-profile `UIScreenSweep` run and one
      headful capture each hit a momentary script-compile error while the same concurrent session
      was mid-save on `SettingsManager.gd`; both re-ran clean seconds later. Noted for the same
      reason as above, not a real defect.
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
