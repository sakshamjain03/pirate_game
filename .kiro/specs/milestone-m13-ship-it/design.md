# Design Document — M13 Ship It

## Sequencing

Requirement 1 (engine version) SHOULD resolve before Requirement 2 (export templates) — installing
templates for the wrong declared version wastes the download/setup. Requirements 3/4 (device
profiling, touch verification) naturally happen together once Requirement 2 produces a real
installable build — one device session covers both. Requirements 5/6 (store listing, release
checklist) are documentation/asset work that can start in parallel with the device work and
finalize once Requirement 3/4's findings are in (screenshots should reflect a build that's already
been device-verified, not a pre-fix one).

## Requirement 1 — Engine version

This is a decision, not a mechanical task — investigate first. Check whether anything in the
project actually depends on 4.3-specific behavior (unlikely, given every fix in this project's
history since the visual pass has been validated against 4.7.1 specifically, and no 4.3-only API
usage has been flagged anywhere in `docs/05_CURRENT_SYSTEMS.md`). The likely correct outcome:
update `project.godot`'s `config/features` to declare 4.7, since that's what's actually been
running and tested this whole time — the declared-4.3 value looks like a stale artifact from
project creation, not a deliberate compatibility target. If investigation finds a real reason 4.3
was intentional (e.g. a specific export template availability concern), document that reasoning
explicitly rather than silently keeping the mismatch.

## Requirement 2 — Android export pipeline

Standard Godot export flow, no project-specific novelty expected: install export templates
matching the Requirement 1 version via the Godot editor's own template manager or manual download,
configure `export_presets.cfg` (package id — pick something matching `docs/00_VISION.md`'s
branding, e.g. `com.<studio>.pirateempire`, version code/name synced with whatever version
identifier this project uses, `icon.svg` per D38), generate a keystore via `keytool` (standard
Android tooling), reference it in the export preset without committing the keystore file itself.
Verify `.gitignore` already excludes typical keystore/export-template patterns; add if missing.

## Requirement 3 — Device performance profiling

Godot's built-in performance monitor (`Performance` singleton, or the editor's remote debugger
when connected to a device build) is the standard tool — no custom profiling harness needed. The
three target scenes (open ocean, populated island, active combat) map directly to the three
systems most likely to be expensive: `WaveGenerator`/ocean LOD (M10), `Island`'s building-visual
instancing plus any new building models from M10/M11, and `ShipCombat`/`EnemyAI`/particle effects
respectively. If Ocean LOD (M10) under-delivered on mobile framerate, this is where that would
surface — cross-reference against M10's own device-profiling gap (M10's Requirement 1 explicitly
notes real device testing remains M13 scope).

## Requirement 4 — Touch control verification

`MobileControls.tscn` already exists and maps to the same `InputManager` actions keyboard/gamepad
use (per `docs/05_CURRENT_SYSTEMS.md`'s architecture notes) — verification is confirming the
existing mapping actually reaches the player on a touchscreen, not building new input handling.
Any touch-target resize should follow `docs/03_ART_DIRECTION.md`'s existing UI principle ("large
buttons... minimal chrome") rather than introducing a new sizing convention.

## Requirement 5 — Store listing and release assets

Reuse `scenes/debug/CaptureHarness.tscn` (or the Requirement 3 device's own screenshot capability)
for store screenshots rather than building a separate marketing-capture tool — the existing harness
already produces clean, consistent captures at meaningful gameplay moments. Description copy
should draw directly from `docs/00_VISION.md`'s own framing (already-written, already-approved
positioning) rather than being freshly invented for the store listing.

## Requirement 6 — Release checklist

Documentation-only. Cross-reference `docs/07_AI_AGENT_WORKFLOW.md`'s existing checkpoint-review
discipline (Rules 4/7/8) — the release checklist is that same "verify, don't self-report"
discipline applied to a release event specifically, not a new philosophy.

## Requirement 7 — Privacy policy and data compliance

A single static page (plain HTML or Markdown rendered by GitHub Pages — no framework, no build
step, matching this project's general "no unnecessary dependencies" bias) with two sections:
privacy policy and account-deletion request. Publish via GitHub Pages from this same repository
(a `docs/` or `gh-pages`-branch static site is GitHub Pages' standard pattern — pick whichever the
existing repo's GitHub remote/Pages configuration supports; if Pages isn't already enabled on the
repo, enabling it is a one-time repo-settings task, not new infrastructure to provision
elsewhere).

**Content sourcing, order matters:** check whether
`.kiro/specs/milestone-m15-backend-cloud-services/` has actually landed in
`docs/05_CURRENT_SYSTEMS.md` before writing this page's data-collection section. If it has,
quote its Requirement 9.2 enumeration directly. If it hasn't, write the page against what's
genuinely true right now — most likely just M12's analytics (confirm that milestone's design kept
analytics device-scoped/anonymous rather than identity-linked; if so, the honest page may say
"this app does not collect personally-identifying information" and "this app does not currently
support user accounts," both fully accurate statements that don't need to anticipate M15). Either
way, the account-deletion section states current reality — before M15, "not applicable, no
accounts exist"; after, the real support-contact process.

**Play Console side:** enter the page URL in the Data Safety section and the store listing's
privacy policy field; fill out the Data Safety questionnaire against the same accurate
enumeration, not a template. This is a Play Console UI task at submission time, not a code change
— no corresponding Godot work exists for this requirement at all.

**If M15 ships after M13:** the page needs a follow-up edit (already tracked as
`.kiro/specs/milestone-m15-backend-cloud-services/`'s own Wave 7 documentation task) and the Data
Safety form needs re-submitting to reflect the new data collection — Google Play requires the
Data Safety section to stay accurate as an app's data practices change, this isn't a one-time
form.

---

## Verification

This milestone's own verification *is* its content — Requirements 3/4 require a real device, which
no prior milestone in this project has ever had access to. If a real Android device genuinely isn't
available when this milestone starts, that SHALL be logged as a blocking constraint, not
worked around by skipping Requirements 3/4 and marking the milestone complete anyway — per this
project's repeated, explicit lesson about self-reported completion not holding up
(`docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8; `docs/05_CURRENT_SYSTEMS.md`'s entire D-number
history). "We could not verify this" is an acceptable, honest checkpoint outcome; "we assumed it
would be fine" is not.
