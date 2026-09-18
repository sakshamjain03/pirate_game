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

## Notes

- Wave 2 is the one wave in this entire multi-milestone roadmap that cannot be completed without
  physical hardware — every other milestone's work can proceed in a pure development environment.
  If hardware access is a genuine blocker when this milestone starts, say so explicitly rather than
  reporting completion without it.
