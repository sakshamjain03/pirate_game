# Requirements Document

## Introduction

Milestone M13 (originally "M12 — Ship It") is the milestone where Pirate Empire becomes an
installable Android build on a store, rather than a project that only runs from the Godot editor
or a local `.cmd` launcher. Every prior milestone has built toward this without ever actually
crossing it: export templates have never been installed on the dev machine, the game has never
run on a real Android device, touch controls (`MobileControls.tscn`) exist but have never been
verified outside the editor, and `project.godot` still declares Godot 4.3 while every fix in this
project's history has been validated against the 4.7.1 binary actually installed. This is the
milestone where all of that gets resolved or the plan is wrong.

Full context: `docs/15_MASTER_PLAN.md`'s M13 entry, `docs/14_SYSTEM_INVENTORY.md` §5, and the
engine-version risk already flagged in `docs/15_MASTER_PLAN.md` §5's risk register.

---

## Requirements

### Requirement 1 — Resolve the engine version question

**User Story:** As a maintainer, I want to know definitively which Godot version this project
targets, so export configuration and any remaining rendering work isn't guessing against a
declared version nobody has actually run the game on.

#### Acceptance Criteria

1. `project.godot`'s `config/features` (currently `"4.3"`) SHALL be reconciled with the 4.7.1
   binary every fix in this project's history has actually been validated against — either
   updated to declare 4.7, or a documented decision that 4.3 compatibility is genuinely required
   (e.g. for a specific export target) and the project SHALL be re-verified to actually run
   correctly under a real 4.3 binary if so.
2. Whichever version is chosen SHALL be the version export templates (Requirement 2) are installed
   for — a mismatch here would silently reintroduce this exact risk at export time.

### Requirement 2 — Android export pipeline

**User Story:** As a maintainer, I want a working, repeatable Android export process, so shipping
an update isn't a from-scratch investigation every time.

#### Acceptance Criteria

1. Godot's Android export templates SHALL be installed on the build machine (confirmed absent
   today — no `export_templates` directory, no `export_presets.cfg`).
2. An `export_presets.cfg` SHALL be configured for Android, including package identifier, version
   code/name, icon, and permissions (at minimum whatever Requirement 3 of
   `.kiro/specs/milestone-m12-playtest-instrumentation/` push-notification work requires, if that
   milestone landed first).
3. A signing keystore SHALL be generated/configured for release builds, following Android's
   standard signing process, with the keystore itself **not** committed to the repository
   (`.gitignore` updated if needed) — only the export configuration referencing it.
4. A successful `.apk`/`.aab` export SHALL be produced from the current project state.

### Requirement 3 — Device performance profiling

**User Story:** As a maintainer, I want to know the game actually runs acceptably on real
hardware, since every performance-relevant decision so far (Ocean LOD's target, buoyancy tick
cost, UI redraw frequency) has been made without ever measuring on a device.

#### Acceptance Criteria

1. The exported build SHALL be run on at least one real Android device (target: "mid-range," per
   `docs/15_MASTER_PLAN.md`'s existing M10/M13 framing of the performance bar).
2. Frame rate SHALL be measured in at minimum: open ocean sailing, a populated island view, and an
   active combat encounter — the three scenes most likely to stress rendering/physics
   respectively.
3. Any frame rate significantly below the project's implicit 60fps target (per
   `docs/15_MASTER_PLAN.md`'s M10 exit criterion, "holds 60 fps on a mid-range Android device")
   SHALL be logged as a finding, with a recommendation for which milestone should address it if
   not fixable within this one.

### Requirement 4 — Touch control verification

**User Story:** As a mobile player, I want the touch controls to actually work, since
`MobileControls.tscn` has existed since M2 but has never been verified outside the editor.

#### Acceptance Criteria

1. Every action `MobileControls.tscn` exposes (movement, firing, docking/interact, ability,
   special broadside, pause/menu access) SHALL be verified functional on the Requirement 3 device.
2. Touch target sizes SHALL be confirmed usable on a real screen (not just visually present in the
   editor) — resize any control found too small to reliably tap during this verification pass.
3. Any control found non-functional or unusably small SHALL be fixed within this milestone, not
   deferred — this is the first and only point in the roadmap where real touch-device
   verification happens.

### Requirement 5 — Store listing and release assets

**User Story:** As a prospective player browsing a store, I want a listing that actually
represents the game, so the decision to install it is informed.

#### Acceptance Criteria

1. A store listing SHALL be prepared: title, short/long description, icon (the existing
   `icon.svg`/`icon.svg.import` per D38, or a store-resolution-appropriate export of it),
   screenshots (captured from the Requirement 3 device or the existing `CaptureHarness` pipeline
   at store-appropriate resolution), and a short description consistent with
   `docs/00_VISION.md`'s core fantasy framing ("build the greatest pirate civilization ever
   known"), not a generic template description.
2. Screenshots SHALL represent actual current gameplay (post-M9 through M12), not stale/outdated
   captures from earlier milestones — recapture fresh if this milestone runs meaningfully after
   M9's presentation fixes.

### Requirement 6 — Release checklist

**User Story:** As a maintainer, I want a repeatable checklist for future releases, so shipping an
update isn't reconstructed from memory every time.

#### Acceptance Criteria

1. A release checklist SHALL be documented (`docs/RELEASE_CHECKLIST.md` or equivalent) covering:
   GUT suite green, fresh headful capture reviewed, version bump, export, signing, device smoke
   test, store listing update if changed.
2. This milestone's own release SHALL be executed against that checklist as its first real use,
   surfacing any gaps in the checklist itself before it's relied on for a future update.

### Requirement 7 — Privacy policy and Play Console data compliance

**User Story:** As a prospective player, I want to know what data the app collects and how to get
it removed, and as a maintainer I want the store listing to actually be submittable — Google Play
Console requires a privacy policy URL for essentially every app, and additionally requires an
account-deletion path for any app supporting account creation.

#### Acceptance Criteria

1. A hosted privacy policy page SHALL exist at a stable URL — **GitHub Pages from this repo is the
   recommended host** (free, no new infrastructure, this project is already on GitHub) — before
   this milestone's store submission.
2. **If `.kiro/specs/milestone-m15-backend-cloud-services/` has landed by the time this task
   starts**, the policy's data-collection section SHALL be written directly from that spec's
   Requirement 9.2 enumeration (email address, gameplay save data) — not independently guessed.
   **If M15 has not landed yet**, the policy SHALL accurately describe only what actually exists
   at this milestone's own ship time (at minimum, M12's analytics — confirm whether that
   requirement's design keeps analytics identity-anonymous, which affects what must be disclosed),
   and SHALL be revisited and expanded as an M15 task (already noted in that spec's own Wave 7)
   once accounts/cloud save actually ship — this requirement is never satisfied by a policy that
   describes a future state as if it were already true.
3. The same hosted page SHALL include an account-deletion request section (a documented
   support-contact process, per `.kiro/specs/milestone-m15-backend-cloud-services/` Requirement
   8.5) — present even if M15 hasn't landed yet, since the page only needs to be accurate about
   current capability (e.g. "this app does not currently support accounts" is a perfectly valid,
   accurate statement until M15 changes that).
4. The privacy policy URL SHALL be entered into both the Play Console store listing and (once
   applicable) Supabase's own project settings.
5. The Play Console Data Safety form SHALL be filled out accurately against what the app actually
   collects at submission time — re-verified, not copied from a template.
6. This requirement's page content SHALL be re-reviewed and updated any time a future milestone
   changes what data the app collects — noted here as the durable home for that obligation, so it
   isn't rediscovered from scratch at the next audit.

---

## Non-Goals

- iOS export — `docs/02_TECH_STACK.md` names it "future," not v1 scope.
- CI/CD automation of the export pipeline — valuable but not required to ship the first build;
  flag as a recommended follow-up if not done here, don't silently assume it exists.
- Any new gameplay content or systems — this milestone is exclusively about getting the existing,
  content-complete-by-M12 game onto a device and a store.
