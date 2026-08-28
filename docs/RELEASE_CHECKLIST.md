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

## 7. Store listing update (if changed)

If gameplay, UI, or the icon changed since the last release, refresh `docs/STORE_LISTING.md`'s
screenshots and description before updating the Play Console listing.

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
- Screenshots for `docs/STORE_LISTING.md` are not yet captured, for the same reason as Step 6 —
  gated on having something real to screenshot.
