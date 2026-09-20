# RELEASE_CHECKLIST.md

> Version: 1.0
> Status: Living Document — first written and first used during
> `.kiro/specs/milestone-m13-ship-it/` (Requirement 6). Update this file if a release surfaces a
> gap in it — that's the whole point of "first real use."

This is the repeatable process for shipping a Pirate Empire update, so it doesn't get
reconstructed from memory every time. It applies the same "verify, don't self-report" discipline
`docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8 already require for checkpoints, to a release event
specifically.

## 1. GUT suite green

Run the standing verification command and record the **actual** totals — never paste a
remembered/stale number (`docs/07_AI_AGENT_WORKFLOW.md`'s baseline-discipline section):

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Compare against the previous release's recorded totals in `docs/05_CURRENT_SYSTEMS.md`. Any new
failure, or any drop in total test count, blocks the release until resolved or explicitly
justified (the one standing exception is `test_property_21_lod_distance_transitions`, tracked
separately, not a release blocker).

## 2. Fresh headful capture reviewed

A passing GUT suite does not catch visual/layout/feel regressions — proven repeatedly (D23–D28,
D31–D38, D64/D65, D32/D36). Run:

```
<godot-binary> --path <project-root> scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
```

headful, zero input, and actually look at the resulting screenshots before proceeding.

## 3. Version bump

Update `project.godot`'s `config/version` and `export_presets.cfg`'s `version/code`
(monotonically increasing integer) / `version/name` (matches `config/version`) together — a
mismatch here is exactly the kind of drift Requirement 1/2 of the M13 spec exists to prevent
recurring.

## 4. Export

Produce a release AAB/APK from the current, GUT-green, capture-reviewed state:

```
<godot-binary> --headless --export-release "Android" builds/pirate_empire.aab
```

**Known issue as of 2026-08-29 (M13):** this command currently fails on this project/environment
with `ERROR: Cannot export project with preset "Android" due to configuration errors:` followed by
**no further detail**. Extensively investigated, both empirically and by reading Godot 4.3-stable's
own source (`platform/android/export/export_plugin.cpp`,
`editor/export/editor_export_platform.cpp`, `editor/editor_node.cpp`):

- Reproduced consistently across gradle and non-gradle builds, headless and headful invocation,
  multiple package-name values, JKS and PKCS12 keystore formats, with and without custom launcher
  icons, `advanced_options` true/false, after a full `.godot` cache rescan, and both after manually
  copying the Android build template AND after installing it via Godot's own official
  `--install-android-build-template` CLI flag.
- The one empirical trigger: the blank error appears as soon as `package/unique_name` is
  explicitly set to *any* value; leaving it unset produces a normal, specific message instead
  ("project name does not meet the requirement...").
- Read the actual validation source: `editor_node.cpp`'s `_fs_changed()` prints
  `vformat("...due to configuration errors:\n%s", preset_name, config_error)`, where
  `config_error` is populated by `EditorExportPlatform::can_export()`, which itself concatenates
  `has_valid_export_configuration()`'s error (SDK/JDK/keystore/template checks — every branch that
  sets `valid=false` also appends a real, non-empty message; this project's actual config passes
  every one of those checks on inspection) with `has_valid_project_configuration()`'s error (a loop
  over every export option's `get_export_option_warning()` — also only produces real messages,
  including the package-name check itself). Neither function's code, read directly, explains an
  empty `config_error` reaching the printed message. This is either a genuine defect specific to
  this build (`Godot v4.3.stable.official.77dcf97d8`) in code not yet located, or something
  environment-specific (e.g. a translation-catalog issue affecting `TTR()`) outside what static
  reading of the source can diagnose.
- **`--export-pack "Android" builds/pirate_empire.pck` succeeds** — produces a real ~12MB `.pck`
  with no validation error at all. This proves the failure is specific to the *full app-assembly*
  validation path (`has_valid_export_configuration`'s Android/Gradle branch), not resource packing.
  A manual APK assembly (place the `.pck` into `android/build/assets/`, run `gradlew.bat
  assembleDebug` directly) was considered but not completed — Godot's Gradle-build asset wiring,
  manifest patching (permissions, version, icon), and per-architecture `.so` placement are done
  internally by the same export code that's failing, with no documented manual equivalent; fully
  reverse-engineering that by hand is a much larger undertaking than this milestone's remaining
  scope justifies.

**Next step for whoever picks this up:** try a different Godot 4.3.x point release or a fresh
4.3-stable download (rule out a corrupted/patched local binary), drive the export through the
actual editor GUI where the dialog may render text the CLI path is dropping, or search/file a
Godot engine issue for this exact blank-message symptom with the source trace above as a starting
point.

**Resolved 2026-09-15.** Web research turned up the exact symptom (a *blank* "due to configuration
errors:" message on Android export) already diagnosed in a public Godot 4.2.2 project
([ryanpf/CampRoguelite#2](https://github.com/ryanpf/CampRoguelite/pull/2)):
`EditorExportPlatformAndroid::has_valid_project_configuration()` sets the export invalid with no
error string appended when `ResourceImporterTextureSettings::should_import_etc2_astc()` returns
`false`, which happens whenever `rendering/textures/vram_compression/import_etc2_astc` is unset.
This project's `project.godot` had a `[rendering]` section but never set that key — matching the
bug precondition exactly, on a different Godot version than the original report (4.3.stable vs.
4.2.2), so this was tested as a lead, not assumed. Adding
`textures/vram_compression/import_etc2_astc=true` made the blank message disappear entirely.

`--export-debug "Android" builds/pirate_empire_debug.apk` then produced a real, valid signed APK
(86.8MB, 1551 files, confirmed via `file`/`unzip -l` — `classes.dex`,
`lib/arm64-v8a/libgodot_android.so`, exported game resources, manifest all present).
`--export-release "Android" builds/pirate_empire.aab` surfaced one further, genuinely informative
error (`export_presets.cfg`'s `gradle_build/export_format` was `0`/APK while the target filename
was `.aab`) — fixed by setting `export_format=1`, after which the release export succeeded cleanly
and produced a real signed 34.8MB `.aab` (verified bundle structure: `BundleConfig.pb`,
`base/dex/classes.dex`, `base/lib/arm64-v8a/libgodot_android.so`, a `META-INF/PIRATE_E.{SF,RSA}`
signature matching the `pirate_empire_release` keystore alias).

**Still not verified — this fix only produces the artifact, it does not install or run it:** the
APK/AAB have not been installed on a real device. Steps 6 (device smoke test) and everything in
M13 Wave 2 (frame rate, touch controls) remain genuinely open and need physical hardware.

## 5. Signing

Release builds sign with the keystore at
`C:\Users\saksham\AppData\Roaming\Godot\keystores\pirate_empire_release.jks` (alias
`pirate_empire_release`) — **never commit this file or its password.** Credentials are recorded in
`C:\Users\saksham\AppData\Roaming\Godot\keystores\RELEASE_KEYSTORE_INFO.txt`, itself outside the
repo. Losing both the file and its backup permanently blocks future updates under
`com.sakshamjain03.pirateempire` (short of Play App Signing's key-upgrade path) — back both up to a
password manager and a second location before relying on this for a real store submission.

## 6. Device smoke test

Install the exported build on a real Android device and confirm: the app launches, touch controls
respond (every `MobileControls` action — movement, dock/interact, pause, captain ability, special
broadside), and frame rate holds up in open ocean, a populated island, and active combat. This step
requires physical hardware — see `.kiro/specs/milestone-m13-ship-it/` Requirements 3/4 for the full
verification bar. **Never skip this and mark a release done anyway** — "we could not verify this"
is an honest, acceptable outcome; "we assumed it would be fine" is not.

**First real run, 2026-09-19 (Samsung Galaxy A35 5G, Android 16).** App launch and every
`MobileControls` action now confirmed working — but only after fixing a real defect this step
exists to catch: `BtnDock`/`BtnPause`/`BtnCaptainAbility`/`BtnSpecialBroadside` were completely
hidden under `WorldHUD`'s cannon-status panels (see `docs/05_CURRENT_SYSTEMS.md`'s M13 device
section and `.kiro/specs/milestone-m13-ship-it/tasks.md` Task 9). **Frame rate did not hold up** —
18-27fps measured across all three required scenarios, against the 60fps target. Do not treat this
step as passed on a future release until that's been profiled and addressed or explicitly
risk-accepted in writing.

### 6b. PC smoke test (added 2026-09-19 — `docs/20_PLATFORM_MATRIX.md` §1 now lists Windows as a
real supported platform, not just the dev/build environment)

Launch the game windowed on a real desktop (not just assumed fine because it's also where the game
is developed) and confirm: main menu, Settings (both General and Controls tabs), Pause
(`Esc` → Resume/Settings/Quit to Menu), and that `MobileControls` correctly stays hidden
(`OS.has_feature("pc")`, `MobileControls.gd:31`). This is a cheap step — no export/install/keystore
involved, just running the built project or a packaged executable directly — so there's no excuse
to skip it the way hardware access can excuse skipping step 6's Android pass.

**First real PC-specific pass, 2026-09-19** (see `.kiro/specs/milestone-m13-ship-it/tasks.md` Task
16.5-B1 through B5 for the full findings): main menu, Settings' PC-relevant controls
(Fullscreen/Resolution/VSync, full keybind remapper), Pause menu, and mobile-controls-hidden all
confirmed working correctly. Two gaps shared with Android, not PC-only: the same
`window/stretch/aspect="keep"` pillarboxing (barely visible on a near-16:9 monitor, would be worse
on ultrawide) and the debug FPS counter rendering in-game. **Not yet checked, flagged open rather
than assumed fine:** multi-monitor/high-DPI behavior, ultrawide aspect ratios, and gamepad support
(the Controls tab's Sensitivity/Dead Zone sliders imply it exists, but only keyboard/mouse was
exercised this pass).

## 7. Store listing update (if changed)

If gameplay, UI, or the icon changed since the last release, refresh the store listing copy below
(Appendix A) — screenshots and description — before updating the Play Console listing.

## 8. Privacy policy / Data Safety re-check

**Re-check this every release, not just the first one.** If any milestone since the last release
changed what the app collects or transmits (a new account feature, a new analytics event, a new
third-party SDK), update the hosted privacy policy
(`https://sakshamjain03.github.io/pirate_game/privacy.html`, sourced from the `gh-pages` branch)
**before** re-submitting, and re-fill the Play Console Data Safety form to match — Google Play
requires Data Safety to stay accurate as data practices change, it is not a one-time form. See
`.kiro/specs/milestone-m15-backend-cloud-services/` Requirement 9.2 for the canonical
data-collection enumeration this page must stay consistent with.

---

## First real use — gaps this checklist's own first run found (2026-08-29)

- Step 4 (Export) hit a genuine, well-investigated engine-level blocker (see above) — this
  checklist item cannot currently be completed as written; it needs either an engine-side fix, a
  different Godot point release, or a GUI-driven export to get past it.
- Step 6 (device smoke test) could not run this pass as a direct consequence — no working exported
  build exists yet to install.
- The launcher icon (`assets/icons/*.png`, referenced from `export_presets.cfg`) is currently a
  flat placeholder color, not real branded art rasterized from `icon.svg` — deprioritized behind
  getting the export pipeline itself working at all. A real icon pass is a named follow-up, not
  silently forgotten.
- Screenshots for Appendix A below are not yet captured, for the same reason as Step 6 — gated on
  having something real to screenshot.

---

## Appendix A — Store listing copy

> Folded in from `docs/STORE_LISTING.md` during the 2026-09-20 docs consolidation pass (release
> assets and the checklist that governs them belong together). Satisfies
> `.kiro/specs/milestone-m13-ship-it/` Requirement 5. Copy is drawn directly from
> `docs/00_VISION.md` §1–§4's existing, already-approved positioning — not freshly invented for the
> store listing.

**Title:** Pirate Empire

**Short description** (≤80 characters, Play Console limit — 79 used):
> Build the greatest pirate empire ever known. Sail, raid, and rule the seas.

**Full description:**

**Can you become a legendary pirate? Pirate Empire asks something bigger: can you build the
greatest pirate civilization in history?**

You are not role-playing a pirate. You are building history.

Start with a single ship and an unclaimed island. Grow it into an empire.

**BUILD** — Develop your islands, construct trade buildings, upgrade your infrastructure, and
unlock new technology. Every level of every building reads as visible investment — a thriving port
looks different from a struggling outpost, from a distance.

**EXPLORE** — Sail an ocean with real geography: three regions, each riskier and richer than the
last. Discover new islands, find hidden treasure, and uncover what's waiting past the fog.

**CONQUER** — Naval combat that rewards positioning and skill, not tap speed. Line up your
broadsides, fire your special volley at the right moment, and use your captain's unique ability to
turn a fight. Capture islands, defeat rival factions, and take down the two legendary warships that
patrol the deep water.

**COMMAND YOUR CAPTAINS** — Recruit and level up a roster of 20 distinct captains, each with their
own home, allegiance, and a combat ability that's genuinely theirs — not just a bigger number on
the same fight.

**LIVE A STORY** — A five-chapter campaign carries you from an unknown sailor to a name the seas
remember, with dialogue, objectives, and stakes that build as your empire grows.

Every session should leave something meaningfully different behind — a fleet that came home, an
island that finished upgrading, a captain who leveled up. Return tomorrow and find your empire kept
moving without you.

Pirate Empire is free to play, in full. Every island, ship, captain, and chapter is reachable
without spending anything.

**Category:** Games → Strategy

**Content rating:** To be completed via Play Console's IARC content-rating questionnaire at
submission time — not guessed here.

**Icon:** `icon.svg` (D38) — a store-resolution (512×512) rasterized PNG export is required by Play
Console and is a follow-up task; the in-app launcher icon currently ships as an unbranded
solid-color placeholder pending real icon art (see Step 4 above and the M13 checkpoint notes for
why this wasn't finished in that pass — it was gated behind the Android export pipeline itself
working, which hit a blocking engine issue since resolved).

**Screenshots:** Not yet captured — gated behind a working exported/running build (Requirement 3's
device pass, or a fresh `CaptureHarness` run) so they reflect actual current gameplay, not stale
pre-M9 captures.

**Privacy policy URL:** https://sakshamjain03.github.io/pirate_game/privacy.html (published — see
`.kiro/specs/milestone-m13-ship-it/` Requirement 7; user must enable GitHub Pages in repo settings
for this URL to resolve, per the checkpoint notes).
