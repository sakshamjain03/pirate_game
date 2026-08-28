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
**no further detail** — reproduced consistently across gradle and non-gradle builds, headless and
headful invocation, multiple package-name values, JKS and PKCS12 keystore formats, with and
without custom launcher icons, after a full `.godot` cache rescan, and after installing the Android
Gradle build template. The one common factor: it reproduces as soon as `package/unique_name` is
explicitly set to *any* value in `export_presets.cfg` — leaving it unset produces a normal,
specific validation message instead ("project name does not meet the requirement..."), which
strongly suggests an engine-side bug in this exact build (`Godot v4.3.stable.official.77dcf97d8`)
rather than a project misconfiguration. Everything else in the pipeline (SDK, JDK, keystores,
Gradle build template, export templates) is confirmed correctly installed and configured — see
`export_presets.cfg` and the keystores at
`C:\Users\saksham\AppData\Roaming\Godot\keystores\`. **Next step for whoever picks this up:**
either test against a different Godot 4.3.x point release, try driving the export through the
actual editor GUI (where the validation dialog may render the real message the CLI is swallowing),
or file/search a Godot engine issue for this exact blank-message symptom.

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
