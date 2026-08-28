# Implementation Plan: Milestone M19 — Accessibility & Inclusive Play

## Overview

Depends on **M9** (theme, responsive sizing, panel arbitration) and **M11** (the SFX this
milestone captions — if M11 has not shipped, build the caption layer and caption what audio
exists, then complete it when M11 lands).

**Sequencing:** this is numbered M19 but is cheapest before the UI grows and improves the M13
store listing. If M13's date has slack, pull this forward. See `requirements.md` Introduction.

Read `docs/18_ACCESSIBILITY.md` in full before Task 1 — it is the standard of record and its §6
twelve-point checklist is the acceptance bar. Then read this spec's `design.md` §6, which explains
why reduced motion must not touch the physics.

Scaffolded 2026-08-27 as a forward-planning artifact alongside M16–M21; Rule 8 still governs.

## Tasks

### Wave 0 — Foundation

- [ ] 1. Create `scripts/managers/AccessibilityManager.gd` (autoload) owning palette, text scale,
        reduced motion, one-hand, and caption settings, persisted account-scoped through
        `SettingsManager`, applying immediately on change.
  - **Verify:** full GUT suite at baseline; change a setting and confirm it applies with no
    restart and survives starting a new game.
  - _Requirements: 6.2, 6.3, 1.6, 2.6_

- [ ] 2. Sweep `scripts/` for hardcoded UI colours and move every **meaning-carrying** one into
        theme/palette resources. Leave decorative material tints in `KenneyMaterialApplier` alone,
        but confirm explicitly which of its tints carry meaning (`design.md` §3).
  - **Verify:** grep for `Color(` in `scripts/ui/`; every remaining hit is justified in writing.
  - _Requirements: 1.2_

- [ ] 3. Author `PaletteData` and the four palettes (Default, Deuteranopia, Protanopia,
        Tritanopia), naming semantic **roles** rather than colours.
  - **Verify:** switching palette changes every faction, resource, notoriety and damage colour
    with no restart.
  - _Requirements: 1.1, 1.2, 1.6_

- [ ] 4. Write `tests/test_accessibility_contrast.gd` — every theme colour pair, both themes,
        all four palettes.
  - **Verify:** the single-file GUT run passes; deliberately darkening one text colour makes it fail.
  - _Requirements: 1.5, 7.1_

### Wave 1 — Non-colour redundancy

- [ ] 5. Add the non-colour signal to the underlying **data** for faction relations, ammunition
        type, and region gating — so every consumer inherits it rather than each screen adding
        its own.
  - **Verify:** the icon/label appears in every screen that shows the state, without per-screen work.
  - _Requirements: 1.3, 1.4_

- [ ] 6. Give each resource a distinct icon **silhouette**, not a tinted copy of one shape.
  - **Verify:** render the resource bar in greyscale; all five remain distinguishable.
  - _Requirements: 1.3, 1.4_

- [ ] 7. Add the notoriety label and tick position, and the ship damage-state HUD readout.
  - **Verify:** in greyscale, both states are readable without colour.
  - _Requirements: 1.3, 1.4_

- [ ] 8. Write `tests/test_accessibility_redundancy.gd` covering every row of `design.md` §4.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 1.3, 7.1, 7.2_

- [ ] 9. **Checkpoint — colour**
  - Full GUT suite at or above baseline.
  - Render every screen in greyscale and confirm no state is indistinguishable — a headful check;
    report it as such.
  - Confirm no meaning-carrying colour remains hardcoded in a script.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

### Wave 2 — Text and layout

- [ ] 10. Implement global text scaling at 100/125/150/200%, applying immediately.
  - **Verify:** change scale in settings; all UI text resizes with no restart.
  - _Requirements: 2.1, 2.3, 2.6_

- [ ] 11. Sweep every `scenes/ui/*.tscn` for fixed-pixel panel sizing and convert to anchors and
         containers — the V17 treatment, applied everywhere.
  - **Verify:** render every screen at 200% scale at 3 aspect ratios; zero clipping, truncation,
    or overlap.
  - _Requirements: 2.2_

- [ ] 12. Add the dyslexia-friendly font option, and audit for text baked into textures, replacing
         any found with real text nodes.
  - **Verify:** the font option applies everywhere; grep the asset list for text-bearing textures.
  - _Requirements: 2.4, 2.5_

- [ ] 13. Bring every touch target to 48×48 dp minimum with 8 dp separation.
  - **Verify:** `test_accessibility_layout.gd` asserts it across every screen.
  - _Requirements: 5.3_

- [ ] 14. Identify which screens actually need a one-handed variant, then add the alternate anchor
         set to those — as a layout variant, never a duplicate scene.
  - **Verify:** in one-handed mode, every primary action sits in the lower third. Report the
    reach check as a headful device observation.
  - _Requirements: 5.1_

- [ ] 15. Add the hold-versus-tap option for every sustained-hold action, and a single-touch
         alternative for every multi-touch gesture.
  - **Verify:** complete a full session using taps only.
  - _Requirements: 5.2, 5.4_

- [ ] 16. Write `tests/test_accessibility_layout.gd` — fixed-pixel sizing, touch targets, and
         200%-scale rendering, across every screen.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 7.1, 7.2_

### Wave 3 — Motion, audio, captions

- [ ] 17. Implement reduced motion in `CameraRig` per `design.md` §6 — sway, pitch reaction, and
         shake only. **The simulation must not be touched** (D11 wave-sync hazard).
  - **Verify:** `test_reduced_motion.gd` asserts ship position and velocity are byte-identical
    over a fixed input sequence with the setting on and off.
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 18. Shorten or remove UI transitions under reduced motion, and audit the whole game for
         anything flashing above 3 Hz in **any** mode — particles, raid alarm, damage flash.
  - **Verify:** headful observation of each candidate effect; report as a visual check.
  - _Requirements: 3.2, 3.4_

- [ ] 19. Build the global `CaptionLayer` with an adjustable-size scrim legible over the ocean,
         routing dialogue captions, on by default.
  - **Verify:** captions readable over bright open water at midday — a headful check.
  - _Requirements: 4.1_

- [ ] 20. Caption meaningful non-speech audio by connecting to existing signals: cannon fire with
         direction, boarding started, raid alarm, building complete.
  - **Verify:** play a full battle muted and confirm no information was audio-only.
  - _Requirements: 4.2, 4.3_

- [ ] 21. Confirm independent Music/SFX/Voice sliders on the existing `AudioManager` buses.
  - **Verify:** each slider affects only its bus.
  - _Requirements: 4.4_

- [ ] 22. Confirm full gamepad and keyboard navigation of every menu, extending the existing
         rebinding work (D57/D10).
  - **Verify:** navigate every screen and complete a purchase-free session using only a gamepad.
  - _Requirements: 5.5_

- [ ] 23. Write `tests/test_reduced_motion.gd`.
  - **Verify:** the single-file GUT run passes; deliberately damping a simulation value makes it fail.
  - _Requirements: 3.3, 7.1_

### Wave 4 — Settings, documentation, final checkpoint

- [ ] 24. Build the dedicated Accessibility section in `SettingsMenu`, containing every option in
         one place — not scattered across tabs. It must itself pass the checklist.
  - **Verify:** every option present, applies immediately, persists across a new game.
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 25. Update `docs/05_CURRENT_SYSTEMS.md` (M19 section), `docs/14_SYSTEM_INVENTORY.md`
         (accessibility rows off ❌), `docs/18_ACCESSIBILITY.md` (reconcile, and record which
         checklist items are test-enforced versus review-enforced), and `docs/20_PLATFORM_MATRIX.md`
         (features declared in store listings).
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M19 system.
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 26. **Checkpoint — M19 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Walk `docs/18_ACCESSIBILITY.md` §6's twelve points against **every** screen, not a sample.
  - Confirm by test that reduced motion leaves ship physics byte-identical.
  - Confirm greyscale renders of every screen keep all states distinguishable.
  - **List explicitly which of the twelve items were verified headfully and which were not.**
    Requirement 7.3 makes this mandatory — a headless run cannot tell you whether a caption is
    readable over water.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **Task 17 is the one most likely to be got wrong in a way that causes a real bug.** The
  intuitive way to reduce motion is to calm the waves. That would desynchronize the GPU wave
  shader from CPU buoyancy sampling — exactly defect D11, already fixed once. Damp the camera's
  reaction, never the simulation. `test_reduced_motion.gd` is the guard, and it should be written
  before the feature, not after.
- **Task 11 is the largest single body of work here** and touches every UI scene. It is also the
  task most likely to surface latent V17-class bugs on screens nobody has resized. Budget for it
  accordingly, and expect the test in Task 16 to fail loudly the first time it runs.
- Wave 1 (colour) and Wave 2 (layout) are independent and can be reordered or interleaved.
  Wave 3's caption work depends on M11's audio existing to be captioned.
- Requirement 7.2 — tests cover **every existing screen**, not only new ones — is what stops this
  milestone decaying over M20 and M21. Do not narrow it to new screens to make the tasks pass.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4"] },
    { "id": 1, "tasks": ["5", "6", "7", "8", "9"] },
    { "id": 2, "tasks": ["10", "11", "12", "13", "14", "15", "16"] },
    { "id": 3, "tasks": ["17", "18", "19", "20", "21", "22", "23"] },
    { "id": 4, "tasks": ["24", "25", "26"] }
  ]
}
```
