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

- [ ] 1. Investigate whether the project genuinely depends on any 4.3-specific behavior; resolve
       `project.godot`'s declared version to match reality (almost certainly 4.7), or document
       why not.
  - _Requirements: 1.1, 1.2_
- [ ] 2. Install Android export templates matching the resolved version.
  - _Requirements: 2.1_
- [ ] 3. Configure `export_presets.cfg` (package id, version, icon, permissions).
  - _Requirements: 2.2_
- [ ] 4. Generate/configure a release signing keystore; confirm it's excluded from version control.
  - _Requirements: 2.3_
- [ ] 5. Produce a successful `.apk`/`.aab` export from current project state.
  - _Requirements: 2.4_

## Wave 2 — Device verification (requires real hardware)

- [ ] 6. Install and run the Wave 1 export on at least one real Android device.
  - _Requirements: 3.1_
- [ ] 7. Measure frame rate in open-ocean sailing, a populated island view, and active combat;
       log findings, flag anything significantly below 60fps with a recommendation.
  - _Requirements: 3.2, 3.3_
- [ ] 8. Verify every `MobileControls.tscn` action (movement, firing, docking/interact, ability,
       special broadside, pause/menu) functions correctly on-device.
  - _Requirements: 4.1_
- [ ] 9. Confirm touch target sizes are usable on the real screen; resize anything found too
       small, fix within this milestone.
  - _Requirements: 4.2, 4.3_

## Wave 3 — Store readiness

- [ ] 10. Prepare store listing copy (title, short/long description) drawing from
        `docs/00_VISION.md`'s existing positioning.
  - _Requirements: 5.1_
- [ ] 11. Capture fresh store screenshots reflecting the current (post-M9–M12) build — via
        `CaptureHarness` or the Wave 2 device — not stale earlier-milestone captures.
  - _Requirements: 5.1, 5.2_
- [ ] 12. Check whether `.kiro/specs/milestone-m15-backend-cloud-services/` has landed
        (`docs/05_CURRENT_SYSTEMS.md`); publish the privacy-policy + account-deletion-request page
        via GitHub Pages, content sourced accordingly (`design.md`'s Requirement 7 section).
  - _Requirements: 7.1, 7.2, 7.3_
- [ ] 13. Enter the page URL into the Play Console store listing and Data Safety section; fill out
        the Data Safety questionnaire accurately.
  - _Requirements: 7.4, 7.5_

## Wave 4 — Release checklist and checkpoint

- [ ] 14. Write `docs/RELEASE_CHECKLIST.md` (GUT green, fresh capture reviewed, version bump,
        export, signing, device smoke test, store listing update, **privacy-policy/Data-Safety
        re-check if a data-collection-affecting milestone landed since the last release**).
  - _Requirements: 6.1, 7.6_
- [ ] 15. Execute this milestone's own release against the new checklist as its first real use;
        note any gap found in the checklist itself.
  - _Requirements: 6.2_
- [ ] 16. **Checkpoint — M13 complete**
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
