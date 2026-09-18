# Implementation Plan — M13 Ship It

> **Re-verify scope before starting.** Confirm no earlier milestone's own device-profiling or
> export work already covered part of this scope (M10's Requirement 1 and M12's Requirement 8 both
> touch adjacent ground — LOD performance target and Android notification permissions
> respectively).
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Plus a real Android device for this milestone's core work — see Wave 2.

---

## Wave 1 — Engine version and export pipeline

- [x] 1. Investigate whether the project genuinely depends on any 4.3-specific behavior; resolve
       `project.godot`'s declared version to match reality (almost certainly 4.7), or document
       why not.
  - _Requirements: 1.1, 1.2_
  - **2026-08-29:** Already resolved before this milestone started, by
    `docs/20_PLATFORM_MATRIX.md` §2 (2026-08-27) — stay on 4.3. This task's own original guess
    (4.7) predates that decision. Confirmed still accurate; no code change.
- [x] 2. Install Android export templates matching the resolved version.
  - _Requirements: 2.1_
  - **2026-08-29:** 4.3-stable Android templates installed, matching the installed engine exactly.
- [x] 3. Configure `export_presets.cfg` (package id, version, icon, permissions).
  - _Requirements: 2.2_
  - **2026-08-29:** Configured (`com.sakshamjain03.pirateempire`). Icon is a placeholder pending
    real art; INTERNET permission added for M15's Supabase calls.
- [x] 4. Generate/configure a release signing keystore; confirm it's excluded from version control.
  - _Requirements: 2.3_
  - **2026-08-29:** Debug + release keystores generated via `keytool`, stored outside the repo;
    `.gitignore` extended with `*.jks`/`*.keystore`.
- [x] 5. Produce a successful `.apk`/`.aab` export from current project state.
  - _Requirements: 2.4_
  - **2026-08-29: blocked.** Consistent blank `"due to configuration errors:"` failure from the
    engine itself, extensively bisected — see `docs/RELEASE_CHECKLIST.md` step 4 for the full
    reproduction record. Not resolved this pass.
  - **2026-09-15: resolved.** Root cause found via web research into the exact blank-message
    symptom: Godot's Android export validation
    (`EditorExportPlatformAndroid::has_valid_project_configuration`) marks the export invalid with
    no error string appended when `ResourceImporterTextureSettings::should_import_etc2_astc()`
    returns `false` — which happens whenever
    `rendering/textures/vram_compression/import_etc2_astc` is unset in `project.godot`. This
    project's `[rendering]` section never set that key. Added
    `textures/vram_compression/import_etc2_astc=true` (`project.godot`) — the blank error is gone.
    `--export-debug "Android" builds/pirate_empire_debug.apk` now produces a real, valid 86.8MB
    signed APK (verified: `file` identifies it as a genuine Android package, `unzip -l` lists 1551
    real entries — `classes.dex`, `lib/arm64-v8a/libgodot_android.so`, exported game resources,
    manifest). `--export-release "Android" builds/pirate_empire.aab` then hit a second, unrelated,
    and this time genuinely informative error (`"Invalid filename! Android APK requires the *.apk
    extension"`) — `export_presets.cfg`'s `gradle_build/export_format` was `0` (APK), not `1`
    (AAB), while the release checklist asks for a `.aab`. Fixed (`export_format=1`); the release
    export then succeeded cleanly (exit 0), producing a real signed 34.8MB
    `builds/pirate_empire.aab` (verified: valid bundle structure — `BundleConfig.pb`,
    `base/dex/classes.dex`, `base/lib/arm64-v8a/libgodot_android.so`,
    `META-INF/PIRATE_E.{SF,RSA}` matching the `pirate_empire_release` signing alias).
  - **2026-09-19: now also run on a real device** — see Task 6 below; that was Wave 2, blocked at
    the time this note was written, unblocked later the same pass once a device became available.

## Wave 2 — Device verification (requires real hardware)

- [x] 6. Install and run the Wave 1 export on at least one real Android device.
  - _Requirements: 3.1_
  - **Blocked on Task 5** — no installable build exists yet.
  - **2026-09-19: unblocked and done.** User connected a real device (Samsung Galaxy A35 5G,
    `SM-A356E`, Android 16/API 36, 1080×2340 physical, Mali GPU) via USB with debugging enabled.
    Installed via `adb install` — both the debug APK and, after fixing `export_presets.cfg`'s
    `gradle_build/export_format` (see Task 5), a proper release APK (signed with the release
    keystore, distinct install after uninstalling the debug-signed one — `adb` correctly refused to
    upgrade across mismatched signatures, as expected). Launched via
    `adb shell monkey -p com.sakshamjain03.pirateempire -c android.intent.category.LAUNCHER 1`;
    confirmed via `adb shell pidof` and `logcat` (no `FATAL`/`AndroidRuntime` crash) that it stays
    running, and via `adb shell screencap` that it renders the real main menu and real gameplay
    (HUD, ship, WardrobeButton from M16, resource bar) correctly — not a black screen or crash.
- [x] 7. Measure frame rate in open-ocean sailing, a populated island view, and active combat;
       log findings, flag anything significantly below 60fps with a recommendation.
  - _Requirements: 3.2, 3.3_
  - **Blocked on Task 6.**
  - **2026-09-19: done — and this is a real, flagged finding, not a clean pass.** Godot's own
    debug FPS counter (visible in both debug and release builds) was read directly off device
    screenshots, sampled repeatedly to rule out a one-frame fluke:
    - Debug build, open ocean, idle: 20 FPS (50.0ms), then 21 FPS (47.6ms) — stable.
    - Release build, open ocean: 24 FPS → 27 FPS → 21 FPS → 25 FPS across several samples 5-8s
      apart (release is somewhat better than debug but not dramatically so).
    - Release build, near a populated island (dock, palm trees, chest, another ship) and mid-combat
      (a target locked, starboard cannon reloading): 21 FPS, twice.
    - Release build, close-up populated island view after the Task 9 fix (heavier geometry in
      frame): **18 FPS (55.6ms)** — the lowest reading of the whole pass.
    **All readings are well below the 60fps target**, on a real but only mid-range 2024 device
    (Exynos 1380 / Mali-G68, not a flagship) — across every one of the three required scenarios,
    not just one. **Recommendation, not yet actioned (out of this pass's scope — this needs
    profiling time, not a guess-and-check fix):** `gfxinfo` couldn't help (Godot's Vulkan rendering
    bypasses the Android View pipeline it instruments — "Total frames rendered: 0" even while the
    game visibly ran at ~20fps), so the next session should connect Godot's own built-in profiler
    (`--remote-debug`) against the device to find what's actually expensive, starting from two
    concrete leads found during this pass rather than guessed blind: (1) no
    `rendering/renderer/rendering_method.mobile` override exists anywhere in `project.godot` —
    worth confirming in-editor whether Android is actually getting the Mobile renderer or silently
    inheriting Forward+; (2) `OceanController` has **no LOD system** (the one long-accepted GUT gap,
    `test_property_21_lod_distance_transitions` — see `docs/05_CURRENT_SYSTEMS.md`), and every
    sampled scene had a large, fully-detailed ocean surface in frame, which is a plausible primary
    cost on mobile GPU regardless of which renderer is active. This is now the single most
    important open question for M13 device-readiness — not a cosmetic finding.
- [x] 8. Verify every `MobileControls.tscn` action (movement, firing, docking/interact, ability,
       special broadside, pause/menu) functions correctly on-device.
  - _Requirements: 4.1_
  - **2026-08-29: code fixed, device verification still pending.** The scene was stale — only 5 of
    the 8 actions this task lists were wired at all, and the two fire buttons drove M8's deprecated
    manual-fire path. Added `BtnBackward`/`BtnDock`/`BtnPause`/`BtnCaptainAbility`/
    `BtnSpecialBroadside`. GUT-clean; actual on-device functionality unverified pending Task 6.
  - **2026-09-19: device-verified — and it caught a real defect, now fixed.** Movement (`^`/`<`/`>`)
    confirmed via `adb shell input swipe` (press-and-hold): the ship's speed and position visibly
    changed across screenshots, exactly as expected. `FIRE PORT`/`FIRE STAR` render and their
    reload-state labels update live (observed `"TARGET · RELOADING 50%"` during a real encounter).
    **But `BtnDock`/`BtnPause`/`BtnCaptainAbility`/`BtnSpecialBroadside` were completely invisible
    and unreachable** — see Task 9, same root cause, fixed there.
- [x] 9. Confirm touch target sizes are usable on the real screen; resize anything found too
       small, fix within this milestone.
  - _Requirements: 4.2, 4.3_
  - **Blocked on Task 6.**
  - **2026-09-19: real defect found and fixed, not just sized.** A real-device screenshot showed
    the DOCK/PAUSE/ABILITY/BROADSIDE buttons apparently missing entirely; a cropped/enlarged close
    read of the exact expected region showed their text faintly bleeding through *underneath*
    `WorldHUD`'s `CannonsContainer` (Port/Starboard Cannons status panels) — both are anchored to
    the same bottom-center point, `CannonsContainer` is declared later in `WorldHUD.tscn`'s child
    order so it draws on top, and it fully occupied the same screen rect as `MobileControls`'
    `Actions` cluster. Every existing GUT layout test checked `WorldHUD`'s own panels against each
    other (`test_world_hud_layout.gd`) but nothing ever checked `MobileControls` against `WorldHUD`
    — a real gap in test coverage, not just in the scene. **Fixed** by moving `Actions`
    (`scenes/ui/MobileControls.tscn`) into the horizontal gap right of the movement d-pad instead of
    stacking it against `CannonsContainer` vertically (`CannonsContainer`'s actual rendered height
    turned out to exceed its authored minimum — 184px real vs. 100px nominal at one tested viewport
    size — making a vertical-clearance fix fragile; the horizontal gap is a stable ~500px regardless
    of that content-driven growth). A second, smaller overlap this first fix introduced — against
    `HealthBarContainer`'s right edge (x=352) clipping the leading "A" off `ABILITY` — was caught by
    the same real-device screenshot pass, not assumed away, and fixed by widening the gap further.
    New regression test `tests/test_mobile_controls_layout.gd` (property-based, two viewport sizes,
    16 assertions) locks in both non-overlap constraints. Re-exported, reinstalled, and
    re-screenshotted on the same real device to confirm all four buttons now render fully legible
    and clear of both blockers — not just that the test passes headlessly. Touch target *sizes*
    themselves (95×60/119×60px buttons) were not separately flagged as too small at this device's
    density (450dpi) — the overlap was the real defect, not sizing.

### Wave 2.5 — Mobile UX overhaul (2026-09-19, PROPOSED — not started, pending your review)

**Why this exists.** Task 9 already committed to "resize anything found too small, fix within
this milestone." Once the Task 9 overlap bug was fixed, a full pass across every real screen on
the Galaxy A35 (main menu, settings, both settings tabs, the pause menu, map, captain's log,
wardrobe, in-world HUD) showed the touch-target problem is much broader than one overlap — this
game currently reads as a PC build with mobile controls bolted on, not a mobile-first UI. Numbered
`9a`-`9g` rather than folded into existing tasks so nothing here silently expands Task 9's own
already-closed scope. **Nothing below has been implemented yet.**

- [ ] 9a. **Fix screen scaling — the game does not fill the screen, and won't fit every phone.**
  - **Root cause found:** `project.godot`'s `[display]` section sets
    `window/stretch/aspect="keep"` against a `1920x1080` (16:9) design canvas. On the Galaxy A35's
    actual landscape resolution (`2340x1080`, ≈19.5:9), "keep" preserves the 16:9 ratio and
    pillarboxes the extra width — confirmed visually: solid black bars on both sides in every
    screenshot from this pass. Modern phones range roughly 18:9 to 20:9 (and tablets differ again),
    so this isn't specific to one device.
  - **Task:** change to a stretch/aspect strategy that fills real device screens without
    distortion or wasted bars — most likely `window/stretch/aspect="expand"` (shows more world at
    wider ratios, common for this genre) — and re-verify every anchor-based panel still lays out
    correctly once the visible canvas is no longer a fixed 16:9.
  - **Verify:** GUT's existing multi-viewport-size layout tests (`test_world_hud_layout.gd`,
    `test_wardrobe_layout.gd`, `test_mobile_controls_layout.gd`) still pass; a real-device
    screenshot shows no black bars; add at least one more tested viewport size representing a
    narrower phone (e.g. `1600x720`, ≈18:9) so both ends of the real range are covered, not just
    the A35's own ratio.

- [ ] 9b. **Every mobile touch target is below Android's own 48dp minimum — resize project-wide.**
  - **Measured this pass** (button size in `project.godot`'s design pixels; this device's density
    is 450dpi, so 48dp ≈ 135 design px at this device's effective ~1:1 canvas-to-physical mapping —
    note the mapping ratio itself changes once 9a changes the stretch mode, so re-measure after):

    | Element | File | Current size | ≈dp (this device) | 48dp target |
    |---|---|---|---|---|
    | `BtnDock`/`BtnPause`/`BtnCaptainAbility`/`BtnSpecialBroadside` | `MobileControls.tscn` | 95×60 / 119×60 | **21dp tall** | ~135×135 |
    | `BtnForward`/`BtnBackward`/`BtnFirePort`/`BtnFireStar` | `MobileControls.tscn` | 100×80 | 28dp tall | ~135×135 |
    | `BtnLeft`/`BtnRight` | `MobileControls.tscn` | 80×80 | 28dp | ~135×135 |
    | `LOG`/`MAP`/`CODEX`/`NEW`/`WARDROBE` | `WorldHUD.gd` (built in code) | 70×32 | **11dp tall — the worst offender in the game** | ~135×135 (or wider, shorter label buttons ≥48dp tall) |
    | Main menu buttons | `MainMenu.tscn` | 240×44 | 16dp tall | keep width, ≥135 tall |
    | Settings tab buttons (General/Controls/Account) | `SettingsMenu.gd` | not yet measured — visually tiny relative to the screen | — | measure and fix alongside 9c |

    A flat "50-70% bigger" (your ask) gets the current worst offenders (60px/70×32px) to roughly
    100-119px — still short of the real 48dp/~135px line. Recommend targeting the actual 48dp
    guideline directly rather than an arbitrary percentage, since that's the number the rest of
    this project's own tests already enforce elsewhere (`test_wardrobe_layout.gd`'s 48×48dp
    minimum-touch-target assertions) — MobileControls and the WorldHUD button row were apparently
    never held to that same bar.
  - **Verify:** extend `tests/test_mobile_controls_layout.gd` (and a new
    `tests/test_world_hud_button_sizes.gd` if one doesn't already cover this) with the same
    48×48dp-equivalent minimum-size property test `test_wardrobe_layout.gd` already uses, applied
    to every button named above — so this can't silently regress again.

- [ ] 9c. **Settings menu exposes PC-only controls that are meaningless — or actively confusing —
       on a phone.**
  - **Found this pass, General tab:** a `Fullscreen` toggle and a `Resolution: 1920x1080` dropdown
    (an Android app has no window to resize) and a `VSync` toggle.
  - **Found this pass, Controls tab:** this is a full desktop keybinding remapper — `Sensitivity`/
    `Dead Zone` sliders (gamepad-specific), empty rebind boxes for every ship/camera action meant
    to capture a *keyboard key press*, `Camera Zoom In`/`Camera Zoom Out` showing `UNBOUND` (a
    mouse-wheel binding), and `Pause: ESCAPE`. None of this can be interacted with meaningfully via
    touch, and none of it reflects anything the player can actually do on a phone.
  - **Task:** hide or replace the PC-specific settings (Fullscreen/Resolution/VSync, the entire
    keybind remapper, mouse-wheel zoom bindings) behind an `OS.has_feature("pc")` check — matching
    the same convention `MobileControls.gd` already uses for the reverse case — and design what
    actually belongs on mobile instead (e.g. haptics toggle, touch control opacity/layout, graphics
    quality — `Graphics Quality: Medium` already exists and is reasonable to keep).
  - **Verify:** on-device, confirm no PC-only control is reachable; a new GUT test asserts the
    settings tree contains no `Fullscreen`/`Resolution`/keybind-capture nodes when
    `OS.has_feature("pc")` is false (mirroring how `MobileControls.gd`'s own mobile-only branch
    could be tested, if it isn't already).

- [ ] 9d. **Navigation/action buttons have no icon art — plain text on a generic button.**
  - **Confirmed this pass:** `assets/ui_icons/` has resource icons (gold/wood/iron/rum/health/
    notoriety/cannon) and generic 9-slice button backgrounds, but genuinely no arrow, anchor,
    pause, dock, or ability icon exists anywhere in the repo. `MobileControls.tscn`'s buttons are
    plain `text = "^"` / `"<"` / `">"` / `"DOCK"` etc. on the same background every other button
    uses — this is very likely what read as "old" navigation art, since there's no art there at
    all, just text.
  - **Task:** source real icons (follow M15.5's own precedent — "sourced CC0 UI assets" — for a
    consistent license-clean pipeline) for: forward/back/turn-left/turn-right, dock, pause,
    captain ability, special broadside, fire-port/fire-starboard. Apply them as `TextureRect`/icon
    children the same way `CannonsContainer`'s existing cannon-ready icon already does, not as a
    from-scratch button system.
  - **Verify:** real-device screenshot comparison, before/after; confirm no licensing file is
    missing (this repo already carries `LICENSE_ui-pack.txt`/`LICENSE_board-game-icons.txt` for
    its existing CC0 icons — any new pack needs the same).

- [ ] 9e. **"How do I move forward" is genuinely unclear — not a functional bug, a clarity one.**
  - **Checked this pass:** there is no separate "raise sail" mechanic in `ShipMovement.gd` —
    `ship_forward` directly drives the ship, and it *does* work (confirmed via
    `adb shell input swipe` press-and-hold in Task 6/8's device pass, ship speed/position visibly
    changed). The actual gap is that `BtnForward` is a bare `"^"` caret with no ship/sail iconography
    or first-run hint, so a new player has no reason to associate it with sailing.
  - **Task:** once 9d sources real icon art, make the forward control unambiguous (a sail/forward
    icon, not a generic chevron) and consider whether `TutorialManager`'s existing tutorial flow
    already covers movement on mobile — if not, that's the actual fix, not new mechanics.
  - **Verify:** confirm via `TutorialManager`'s content whether a first-session mobile-movement
    hint already exists; if not, add one and confirm it doesn't fire on desktop (per M17's own
    established "never show mobile-only prompts on the wrong platform" convention).

- [ ] 9f. **Map and Captain's Log are small fixed popups that waste most of the screen —
       inconsistent with Wardrobe's own better pattern.**
  - **Confirmed this pass:** both `WorldMapScreen` and `CaptainsLog` render as a small, centered,
    fixed-size box (roughly a quarter of the screen) with mostly-empty content around it — this is
    exactly the D17 fixed-pixel-panel anti-pattern `docs/05_CURRENT_SYSTEMS.md`'s M16 section
    already names, and that M16 deliberately built `WardrobeScreen` *against* (anchored 5%-95% of
    the viewport, confirmed by direct screenshot comparison this pass — Wardrobe genuinely does
    fill the screen; Map/Log don't).
  - **Task:** rebuild `WorldMapScreen`/`CaptainsLog` panel sizing on the same anchor-based
    convention `WardrobeScreen` already proves out, rather than inventing a new approach.
  - **Verify:** the same anchor-based-sizing property test `test_wardrobe_layout.gd` already uses
    (render at two very different viewport sizes, confirm the panel's actual rendered size differs)
    applied to both screens.

- [ ] 9g. **Verify the above across a real support matrix, not just the one device on hand.**
  - This environment only has one physical device (Galaxy A35, 2340×1080, 450dpi). Real phones
    span roughly 18:9 to 20:9 and a wide density range; tablets differ again.
  - **Task:** at minimum, extend every layout GUT test above to assert at 3-4 simulated
    viewport/aspect combinations spanning that real range (not just 1920×1080 and one phone ratio,
    which is what `test_world_hud_layout.gd`/`test_wardrobe_layout.gd` currently do) — GUT can't
    substitute for a second real device, but it can stop a fix that only happens to work on the
    one device this pass had access to.
  - **Verify:** explicitly list, per `CLAUDE.md`'s standing rule, which sizes were headless-tested
    versus real-device-tested — do not imply multi-device coverage from a single real device.

**Aside, found but out of this list's scope — a real functional bug, not a UX one:** the Wardrobe
screen's Hull tab rendered a completely empty item grid on-device during this pass, despite
`docs/05_CURRENT_SYSTEMS.md`'s M16 section recording 10 cosmetics across 5 slots (3 hull). Worth
its own investigation — not folded in here since it's a data/loading defect, not a sizing/scaling
one.

## Wave 3 — Store readiness

- [x] 10. Prepare store listing copy (title, short/long description) drawing from
        `docs/00_VISION.md`'s existing positioning.
  - _Requirements: 5.1_
  - **2026-08-29:** `docs/STORE_LISTING.md`.
- [ ] 11. Capture fresh store screenshots reflecting the current (post-M9–M12) build — via
        `CaptureHarness` or the Wave 2 device — not stale earlier-milestone captures.
  - _Requirements: 5.1, 5.2_
  - **2026-08-29: deprioritized behind the Task 5 export blocker** — no point capturing "current"
    screenshots from a build that can't yet be produced/installed.
  - **2026-09-19: export blocker cleared (Task 5/6), but this task is still genuinely open —
    not done as a side effect.** The screenshots taken during this pass's device-verification work
    (`adb shell screencap`) are real gameplay on the real device, but they're verification captures,
    not curated store assets: Godot's debug FPS counter is visible in the corner even in the release
    build (worth checking whether that's intended to ship at all, separately from this task), the
    on-screen touch controls are in shot, and no attempt was made to pick flattering angles/moments.
    Deliberately left open rather than quietly reusing a verification screenshot as a "real" store
    asset.
- [x] 12. Check whether `.kiro/specs/milestone-m15-backend-cloud-services/` has landed
        (`docs/05_CURRENT_SYSTEMS.md`); publish the privacy-policy + account-deletion-request page
        via GitHub Pages, content sourced accordingly (`design.md`'s Requirement 7 section).
  - _Requirements: 7.1, 7.2, 7.3_
  - **2026-08-29:** M15's Supabase auth/cloud-save code has actually landed on `origin/main`
    (though M15 hasn't written its own doc section yet — see `docs/05_CURRENT_SYSTEMS.md`'s M13
    note). Content sourced directly from that real code. `index.html`/`privacy.html`/`terms.html`
    pushed to `origin/gh-pages`. **User still needs to enable Pages in repo Settings** — no `gh`
    CLI available to do this via API.
- [ ] 13. Enter the page URL into the Play Console store listing and Data Safety section; fill out
        the Data Safety questionnaire accurately.
  - _Requirements: 7.4, 7.5_
  - **2026-08-29: not done — no Play Console account access in this environment.** Documented as
    an exact manual step in `docs/RELEASE_CHECKLIST.md` step 8.

## Wave 4 — Release checklist and checkpoint

- [x] 14. Write `docs/RELEASE_CHECKLIST.md` (GUT green, fresh capture reviewed, version bump,
        export, signing, device smoke test, store listing update, **privacy-policy/Data-Safety
        re-check if a data-collection-affecting milestone landed since the last release**).
  - _Requirements: 6.1, 7.6_
  - **2026-08-29:** Written, 8 steps.
- [x] 15. Execute this milestone's own release against the new checklist as its first real use;
        note any gap found in the checklist itself.
  - _Requirements: 6.2_
  - **2026-08-29:** Executed — found real gaps (steps 4 and 6), recorded in the checklist's own
    "First real use" section rather than glossed over.
- [ ] 16. **Checkpoint — M13 complete**
  - **2026-08-29: NOT PASSED — explicitly not claimed complete.** GUT is green (411/411) and
    documentation is current, but Requirements 2.4, 3, 4 (device-verified), and 7.4/7.5 remain
    genuinely open per the notes above. Re-run via `checkpoint-reviewer` once the export blocker is
    resolved and device access is used.
  - **2026-09-15: still NOT PASSED, but Requirement 2.4 is now resolved** — Task 5 above. GUT
    re-confirmed green (483/483, current baseline; up from 411 via M14/M15.5/M16 having landed
    since). A real signed `.apk` and `.aab` now export cleanly. **Genuinely still open, and none
    of these are things this environment can complete on its own:** Requirement 3 (device frame-
    rate profiling), Requirement 4 (on-device touch verification — the code fix from Task 8 has
    never actually run on a screen), Requirement 5 (real store screenshots/app icon — still a flat
    placeholder), Requirement 7.4/7.5 (Play Console Data Safety questionnaire — needs a Play
    Console account). All four need a physical Android device and/or Play Console access handed to
    a session, not solved by more code. Do not re-run `checkpoint-reviewer` to claim this checkpoint
    passed until at least Wave 2's device work has actually happened.
  - **2026-09-19: Wave 2's device work has now happened — still NOT PASSED, and this pass found a
    real reason it shouldn't be, not just leftover paperwork.** Tasks 6/8/9 are device-verified for
    real (a Samsung Galaxy A35 5G connected over USB): the build installs, launches, and is fully
    playable, and a real defect found on-screen (four mobile-control buttons completely hidden
    under `WorldHUD`'s cannon panels) was fixed and re-verified on the same device, with a new
    regression test (`tests/test_mobile_controls_layout.gd`) locking it in. GUT re-confirmed green
    at 484/484 (483 baseline + 1 new test). **But Task 7's frame-rate measurement — the other half
    of Requirement 3/4 this checkpoint explicitly asks for — came back genuinely bad, not
    acceptable:** 18-27fps across open ocean, a populated island, and mid-combat, against a 60fps
    target, on a real (if mid-range) 2024 device. This checkpoint's own second bullet below requires
    "acceptable frame rate," and this is not that. **This checkpoint stays NOT PASSED — now
    primarily blocked on the Task 7 performance finding**, not on device access, plus the
    still-open Requirement 5 (real screenshots/icon, Task 11) and 7.4/7.5 (Play Console, Task 13,
    still needs an account this environment doesn't have). Do not re-run `checkpoint-reviewer` to
    claim this passed until either the frame rate is profiled and brought within reason, or a
    deliberate, written decision is made to ship anyway and accept the risk — silently lowering the
    bar is not that decision.
  - GUT suite passes with no regressions.
  - A signed build has run on a real device with acceptable frame rate and fully functional touch
    controls — logged as genuinely verified, not assumed. If no device was available, this is
    logged as a blocking constraint, not silently skipped.
  - Store listing assets reflect the actual current build.
  - Privacy policy page is live at a real URL and accurately reflects current data collection —
    re-confirm this specifically if M15 landed partway through this milestone's own work.
  - Independently re-verify against actual code changes and a real GUT run before marking done,
    per `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8.

- [x] 16.5. **Platform split — catalogue every Android-only and PC-only bug/fix/enhancement, and
       start maintaining both as real, clearly-supported platforms.** Catalogue (A, B) written
       2026-09-19; policy question resolved and section C's concrete actions done 2026-09-19 (see
       note at the end of section C). The 9a-9h Android-only items this task catalogues are still
       open — tracked under Wave 2.5 (Tasks 9a-9g) and 9h, not re-tracked here.
  - **Why this task exists, and a real policy conflict it surfaces.**
    `docs/20_PLATFORM_MATRIX.md` §1 currently states: *"Windows (desktop): 🛠 Development only —
    How the project is built and tested. Not a shipping target, not store-listed."* You've now
    asked to maintain PC as a real, clearly-supported second platform rather than a dev-only
    environment. **This is a deliberate change from that documented decision, not a silent
    override** — recorded here per this project's own repeated rule that a scope/sequencing
    decision like this belongs to you, not to an implementing session's own judgment. If this is
    confirmed, `docs/20_PLATFORM_MATRIX.md` §1 needs its own update alongside the work below (flip
    Windows from 🛠 to a real support tier, decide whether it's store-listed anywhere — e.g.
    itch.io/Steam — or just a direct-download build).

  - ### A. Android-only — bugs, fixes, enhancements

    Everything in **Wave 2.5 above (Tasks 9a-9g)** is Android-only scope and belongs in this list —
    not repeated here in full, cross-referenced instead:
    - 9a. Screen doesn't fill the phone (`window/stretch/aspect="keep"` pillarboxing) — needs
      multi-aspect-ratio support, not just a fix for one device.
    - 9b. Every mobile touch target measured below Android's 48dp minimum (concrete sizes/targets
      already tabulated in 9b).
    - 9c. Settings menu exposes PC-only controls (Fullscreen/Resolution/VSync, full keybind
      remapper) that are meaningless on touch.
    - 9d. No icon art for navigation/action buttons — plain text on a generic button background.
    - 9e. Forward/movement control ("sail") gives no visual hint it means "move forward."
    - 9f. Map/Captain's Log are small fixed popups wasting most of the screen, inconsistent with
      Wardrobe's own better anchor-based pattern.
    - 9g. Verify across a real support matrix (multiple aspect ratios/densities), not just the one
      device on hand.

    **New this pass, found on a fresh on-device run (not in Wave 2.5 above):**
    - **9h. `libgodot_android.so` is not 16KB memory-page-size compatible.** A real Android OS-level
      dialog ("Android app compatibility") reported: *"This app isn't 16 KB-compatible. APK and ELF
      alignment checks failed"* against `lib/arm64-v8a/libgodot_android.so`. The dialog itself only
      shows for a debuggable/testing build — a signed release build won't show it to players — but
      the underlying ELF alignment characteristic is real and unrelated to debug-vs-release. Google
      Play has been rolling out 16KB-page-size compliance requirements for native libraries on
      newer Android devices/API levels; this is worth confirming against Play Console's own current
      submission requirements before M13 actually ships, not assumed harmless. **This is not fixable
      in game code** — it's a characteristic of the Godot 4.3 engine's own precompiled Android
      native libraries. Ties directly into `docs/20_PLATFORM_MATRIX.md` §2's engine-version
      decision (currently "stay on 4.3 through M13 launch, revisit after M13 ships, before M20") —
      a newer Godot 4.x may already ship 16KB-aligned binaries, which would make this one of the
      concrete reasons *for* that eventual upgrade, not just iOS. **Verify:** check current Play
      Console pre-launch report / submission requirements for this exact warning; confirm whether
      it's a hard submission blocker or an advisory at this project's actual target API level.

  - ### B. PC-only — bugs, fixes, enhancements

    Researched this pass by actually running the game windowed on this dev machine (not assumed) —
    PC is in noticeably better shape than Android, since it's this project's native development
    target, but real gaps found:
    - **16.5-B1. The desktop window has the exact same `window/stretch/aspect="keep"` pillarboxing
      problem as Android, just less visually obvious on a near-16:9 monitor.** On this dev
      machine's own window, a thin black bar was visible even at the tested window size — on an
      ultrawide monitor or a non-16:9 window, this would pillarbox exactly like Android does.
      Whatever stretch/aspect fix 9a picks for Android should be verified on PC too, at multiple
      window/monitor aspect ratios, not treated as an Android-only fix.
    - **16.5-B2. The debug FPS counter is visible in-game on PC too** (same overlay noted on
      Android in Task 11's notes) — confirm whether this is meant to be a permanent debug-only
      overlay gated on `OS.is_debug_build()`/a settings toggle, since it currently just always
      renders.
    - **16.5-B3. Settings' PC-relevant controls (Fullscreen/Resolution/VSync, the full keybinding
      remapper) work correctly and are appropriately shown here** — explicitly confirmed via a real
      windowed run, not assumed. These are the ones 9c needs to *hide on Android* — they should
      stay exactly as they are on PC.
    - **16.5-B4. Pause (`Esc`) → Resume/Settings/Quit to Menu works correctly and is
      well-proportioned on PC** — same menu Android's Task 16.5-A audit found via the (now-fixed)
      mobile Pause button; on PC it was never broken, confirmed via a real keypress.
    - **16.5-B5. Mobile touch controls correctly stay hidden on PC** — `MobileControls.gd`'s
      existing `OS.has_feature("pc")` check confirmed working as intended in a live windowed run;
      called out explicitly so 9a-9g's Android changes don't accidentally regress this.
    - **Not yet checked, flagged as open rather than assumed fine:** multi-monitor/high-DPI display
      behavior, ultrawide aspect ratios beyond what this pass's single monitor could test, and
      gamepad support on PC (the Controls tab's `Sensitivity`/`Dead Zone` sliders imply gamepad
      support exists, but this pass only tested keyboard/mouse).

  - ### C. Maintaining both platforms going forward

    - **Reuse the one pattern already in the codebase**, don't invent a second one:
      `MobileControls.gd:31` already gates its entire behavior on `OS.has_feature("pc")`. Every
      platform-conditional fix above (9c hiding PC-only settings on Android, this list's PC section
      confirming what should stay PC-only) should use that exact same feature-check convention —
      per `AGENTS.md`'s "never duplicate systems," one shared codebase with platform branches, not
      a fork.
    - **Test both, not just Android.** This pass's PC findings only exist because the game was
      actually run windowed on this dev machine — add that as a standing step (not just an
      Android-device step) to `docs/RELEASE_CHECKLIST.md`'s device-smoke-test section, so a future
      release checks both platforms, not just whichever one happens to have a checklist step
      already.
    - **Extend the GUT layout tests platform-blind where possible.** `test_mobile_controls_layout.gd`
      and friends already instantiate scenes at multiple viewport sizes headlessly — that pattern
      doesn't require real hardware and should be the first line of defense for both platforms, with
      real-device/real-PC passes reserved for what genuinely can't be checked headlessly (per
      `CLAUDE.md`'s standing verifiability rule).
    - **Update `docs/20_PLATFORM_MATRIX.md` §1** once this task's scope is agreed, so the matrix
      reflects the real decision rather than the pre-existing "dev only" stance this task
      deliberately revisits.

    **Done, 2026-09-19.** You confirmed the policy change ("let's start maintaining 2 versions ...
    clear support for both"). `docs/20_PLATFORM_MATRIX.md` §1's Windows row now reads "✅ Supported
    (secondary)" instead of "🛠 Development only," with a note that it's actively maintained/tested
    but **not yet store-listed anywhere** — itch.io/Steam/direct-download is a distribution
    decision I did not make for you, flagged as still open in that same row.
    `docs/RELEASE_CHECKLIST.md` step 6 got a new "6b. PC smoke test" sibling to the existing Android
    device-smoke-test step, pre-filled with this pass's own PC findings (16.5-B1 through B5) as its
    first real run. The other two items in this list — reusing `OS.has_feature("pc")` instead of a
    second system, and extending GUT layout tests platform-blind — aren't one-time artifacts; they're
    standing practice that Wave 2.5's actual implementation work (9a-9g) needs to follow, not
    something to check off here in isolation.

## Notes

- Wave 2 is the one wave in this entire multi-milestone roadmap that cannot be completed without
  physical hardware — every other milestone's work can proceed in a pure development environment.
  If hardware access is a genuine blocker when this milestone starts, say so explicitly rather than
  reporting completion without it.
