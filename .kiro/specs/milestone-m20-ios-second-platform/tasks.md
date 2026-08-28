# Implementation Plan: Milestone M20 — iOS & Second Platform

## Overview

Depends on **M13** (Android export pipeline, `export_presets.cfg`, listing text), **M17** (the
`IStoreBackend` seam and the consent state machine), and **M19** (accessibility features worth
declaring). **M15 is a soft dependency** — without it, entitlements do not cross platforms, and
Requirement 5.3 requires saying so to the player rather than leaving it to be discovered.

**Hard logistical blocker: iOS builds require macOS.** This project develops on Windows. Confirm a
Mac or a macOS CI runner is available before Task 3, not at Task 3. Raising this late costs the
milestone.

Read `docs/20_PLATFORM_MATRIX.md` before Task 1 — it is the platform record and outranks this
spec where they differ.

Scaffolded 2026-08-27 as a forward-planning artifact alongside M16–M21; Rule 8 still governs.

## Tasks

### Wave 0 — The engine question

- [ ] 1. Re-evaluate the engine version per `docs/20_PLATFORM_MATRIX.md` §2 — decide upgrade or
        stay, and record the decision and reasoning either way.
  - **Verify:** the decision is written into `docs/20_PLATFORM_MATRIX.md` §2 with its reasoning,
    not left in a session.
  - _Requirements: 1.1, 1.4_

- [ ] 2. **If and only if upgrading:** perform the upgrade as its own isolated change.
  - **Verify:** full GUT suite at or above the then-current baseline, **plus** a headful pass on
    the ocean, ship damage visuals, and toon shading. The suite alone does not prove the ocean
    still looks right (D11, D50). Report the visual pass as a real observation.
  - _Requirements: 1.2, 1.3_

- [ ] 3. **Checkpoint — engine settled**
  - Suite at or above baseline; decision recorded; if upgraded, visual pass reported honestly.
  - Confirm macOS build capability is actually available before proceeding.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

### Wave 1 — Export and run

- [ ] 4. Add the iOS export preset and produce a signed, installable build.
  - **Verify:** the build installs and launches on a physical iPhone.
  - _Requirements: 2.1_

- [ ] 5. Verify the build on iPhone and iPad at the minimum OS target, including touch controls on
        a physical device rather than a simulator.
  - **Verify:** complete a full session on each form factor. Simulator-only results do not satisfy
    this and must not be reported as if they did.
  - _Requirements: 2.2, 2.3_

- [ ] 6. Confirm M19's accessibility features are present and functional on iOS.
  - **Verify:** walk `docs/18_ACCESSIBILITY.md` §6's twelve points on the device.
  - _Requirements: 5.4_

### Wave 2 — StoreKit through the seam

- [ ] 7. Implement `scripts/core/StoreBackendIOS.gd` against `IStoreBackend`, and add the iOS
        branch to `StoreManager`'s backend selection.
  - **Verify:** grep confirms no file outside `StoreBackendIOS.gd` references StoreKit.
  - _Requirements: 3.1, 3.2_

- [ ] 8. Handle Ask-to-Buy / deferred purchases. If the interface needs a `purchase_deferred`
        signal, add it and update the Play and stub implementations **in the same change**.
  - **Verify:** trigger Ask-to-Buy with a sandbox family account; confirm the app does not hang in
    `PENDING` and recovers when approval arrives.
  - _Requirements: 3.3_

- [ ] 9. Parametrize `tests/test_store_backend.gd` across all backends, with unavailable backends
        **reported as skipped**, never silently passed.
  - **Verify:** the run output names which backends ran and which were skipped.
  - _Requirements: 3.4_

- [ ] 10. Configure the mirrored SKU set and per-market price tiers in App Store Connect; verify
         purchase, restore, and refund revocation on device.
  - **Verify:** all three flows exercised with a sandbox account; behaviour matches Play.
  - _Requirements: 3.4, 3.5, 3.6_

- [ ] 11. Implement cross-platform entitlements where an M15 account exists; where it does not,
         state the per-store limitation plainly on the purchase-support screen.
  - **Verify:** with an account, a supporter entitlement earned on Android appears on iOS. Without
    one, the limitation is visible to the player in plain language.
  - _Requirements: 5.2, 5.3_

- [ ] 12. **Checkpoint — billing parity**
  - Full GUT suite at or above baseline.
  - Confirm the seam held: exactly one billing interface, two implementations, no parallel path.
  - Confirm every conformance test ran or was explicitly reported as skipped.
  - Use the `checkpoint-reviewer` agent.

### Wave 3 — ATT and ads

- [ ] 13. Fold ATT into M17's existing consent state machine as one additional state — **not** a
         parallel iOS permission flow.
  - **Verify:** `test_ad_gating.gd`, extended with ATT states, asserts no SDK call, ad request, or
    identifier read occurs outside `READY_*`.
  - _Requirements: 4.1, 4.2, 4.4_

- [ ] 14. Implement the declined-ATT path — non-personalized ads, full playability, no nagging.
  - **Verify:** decline ATT on device; confirm play continues and no re-prompt appears.
  - _Requirements: 4.3_

### Wave 4 — Store presence

- [ ] 15. Build the screenshot pipeline on `ScreenshotHarness` — deterministic setup, every
         required resolution from one run, re-runnable per locale. Confirm the harness's current
         state in `docs/05_CURRENT_SYSTEMS.md` first (D5 history).
  - **Verify:** two consecutive runs produce identical images; one run emits every store size.
  - _Requirements: 6.2_

- [ ] 16. Produce the ~30-second trailer, leading with the **empire-building** fantasy rather than
         only ship combat.
  - **Verify:** the cut shows islands, fleets, and economy — not just cannons.
  - _Requirements: 6.1_

- [ ] 17. Produce feature graphics, icon variants per store spec, and the press kit (description,
         key art, logo, fact sheet, contact).
  - **Verify:** each asset meets its store's published spec.
  - _Requirements: 6.3, 6.4_

- [ ] 18. Localize listing copy for the top target markets and declare the M19 accessibility
         features in both listings.
  - **Verify:** each listing renders correctly in its locale and names the accessibility features.
  - _Requirements: 6.5, 6.6_

### Wave 5 — Review, documentation, final checkpoint

- [ ] 19. Complete App Privacy nutrition labels, derived from M17's data enumeration rather than
         restated from assumption, plus the export-compliance declaration.
  - **Verify:** each declared item traces to a real code path, and each real collection point
    appears in the declaration.
  - _Requirements: 2.4, 2.5_

- [ ] 20. Submit for App Review and resolve findings.
  - **Verify:** approved, or every rejection reason addressed and recorded.
  - _Requirements: 2.4_

- [ ] 21. Update `docs/05_CURRENT_SYSTEMS.md` (M20 section), `docs/20_PLATFORM_MATRIX.md` (iOS
         shipped, engine decision, **every parity deviation**), `docs/14_SYSTEM_INVENTORY.md`
         (iOS and ASO rows), and `docs/17_MONETIZATION.md` (iOS SKUs and real prices).
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M20 system.
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 22. **Checkpoint — M20 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Confirm one billing interface with two implementations and no duplicated storefront logic.
  - Confirm the ad permission machine is one machine, with ATT as a state rather than a second flow.
  - List every parity deviation found, and confirm each is recorded rather than merely known.
  - State explicitly which checks were device-verified on iOS and which were not — a Windows
    headless run proves nothing about this milestone.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **This milestone is a verdict on M17's interface design.** If Task 7 turns into a large,
  awkward job, that is the seam failing, and the correct response is to fix the seam and update
  both implementations — not to let iOS grow its own billing path. That divergence would be
  permanent and would double every future billing change.
- **Task 8 (Ask-to-Buy) is the most likely genuine interface extension.** A child's purchase can
  sit pending family approval for days. A state machine that assumes purchases resolve promptly
  will hang, and it will hang specifically for families — the users least able to debug it.
- **The macOS requirement is a hard blocker, not a preference.** Confirm it before Wave 1.
- Wave 4 (store presence) has no dependency on Waves 1–3 and can run in parallel or earlier. The
  screenshot pipeline in particular is useful to Android immediately.
- Waves 1–3 all require physical Apple hardware. Budget for that rather than assuming simulator
  coverage is sufficient — Task 5 explicitly rejects simulator-only results.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3"] },
    { "id": 1, "tasks": ["4", "5", "6"] },
    { "id": 2, "tasks": ["7", "8", "9", "10", "11", "12"] },
    { "id": 3, "tasks": ["13", "14"] },
    { "id": 4, "tasks": ["15", "16", "17", "18"] },
    { "id": 5, "tasks": ["19", "20", "21", "22"] }
  ]
}
```
