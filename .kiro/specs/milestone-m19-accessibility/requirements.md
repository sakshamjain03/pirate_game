# Requirements Document

## Introduction

Milestone M19 makes the game playable by people it currently excludes.

A gap audit on 2026-08-27 found accessibility had **zero coverage anywhere** — not in
`docs/14_SYSTEM_INVENTORY.md`, not in any spec from M9 through M15. That is a real hole on two
counts: it shuts players out, and accessibility is a Google Play quality-listing factor that
affects store placement.

**Sequencing note, stated up front.** This milestone is numbered M19, but it is cheapest to build
*before* the UI multiplies, and its presence improves the M13 store listing. **If the M13 launch
date has any slack at all, this work should be pulled forward ahead of it.** Retrofitting
accessibility across a UI layer that has grown through four more milestones costs several times
what building it in costs. The number is a planning artifact; the argument for doing it early is
not.

**What already exists and needs no work here.** `SettingsManager` owns settings persistence and
input rebinding (D57/M7), and gamepad bindings exist (D10). The M9 presentation pass established
a theme, responsive sizing (the V17 fix to `IslandMenu`'s hardcoded 600×400 panel is the
precedent every screen follows), and panel arbitration. `AudioManager` owns the bus structure.
M11 authors the SFX and music this milestone captions. `tests/test_world_hud_layout.gd` is the
existing pattern for layout assertions.

**What this milestone builds.** Colourblind palettes, non-colour redundancy for every colour-coded
state, text scaling with reflow, captions, a reduced-motion mode, one-handed layout, and touch
target compliance — plus the automated tests that stop all of it silently regressing.

Full context: `docs/18_ACCESSIBILITY.md` is the standard of record and **takes precedence over
this document** where they differ. Its §6 twelve-point checklist is the acceptance bar.

---

## Glossary

- **Colour-alone violation** — any state distinguishable only by hue. Banned throughout.
- **Reduced motion** — a rendering and camera setting that damps camera reaction, removes shake,
  and shortens transitions. It **never** changes a gameplay value.
- **Text scale** — a global multiplier (100/125/150/200%) applied to all UI text.
- **Touch target** — an interactive region. Minimum 48×48 dp with 8 dp separation.
- **Caption** — on-screen text for a meaningful audio event, speech or otherwise.
- **The checklist** — `docs/18_ACCESSIBILITY.md` §6's twelve points, which every screen must pass.

---

## Requirements

### Requirement 1: Colour

**User Story:** As a colourblind player, I want to tell game states apart.

#### Acceptance Criteria

1. THE system SHALL provide Deuteranopia, Protanopia, and Tritanopia palette variants alongside
   Default, selectable in settings.
2. Palettes SHALL live in theme resources and SHALL NOT be hardcoded in scripts.
3. No information SHALL be conveyed by colour alone — every colour-coded state SHALL also carry a
   shape, icon, label, or pattern.
4. THE system SHALL add the non-colour signal to each row of `docs/18_ACCESSIBILITY.md` §2's
   table: faction relations, resource bar, notoriety band, ship damage state, region gating, and
   ammunition type.
5. All text SHALL meet 4.5:1 contrast against its background, or 3:1 for large text, in **both**
   themes and **all four** palettes.
6. Changing palette SHALL apply immediately without a restart.

### Requirement 2: Text

**User Story:** As a player with low vision, I want to read the game.

#### Acceptance Criteria

1. THE system SHALL provide text scaling at 100%, 125%, 150%, and 200%.
2. Every panel SHALL reflow or scroll at 200% SHALL NOT clip, truncate, or overlap.
3. Body text SHALL be at least 16sp equivalent at 100%.
4. THE system SHALL provide a dyslexia-friendly font option.
5. No critical information SHALL be baked into a texture as text.
6. Text scale SHALL apply immediately without a restart.

### Requirement 3: Motion

#### Acceptance Criteria

1. THE system SHALL provide a reduced-motion toggle.
2. Reduced motion SHALL damp camera sway and buoyancy-driven camera pitch, remove screen shake,
   and shorten or remove UI transitions.
3. Reduced motion SHALL NOT change any gameplay value — wave physics affecting the ship remains;
   only the camera's reaction and presentation are damped.
4. Nothing SHALL flash above 3 Hz anywhere in the game, in any mode.

### Requirement 4: Audio and captions

#### Acceptance Criteria

1. THE system SHALL caption all dialogue, on by default, with adjustable size and a background
   scrim legible over the ocean.
2. THE system SHALL caption meaningful non-speech audio — cannon fire and its direction, incoming
   boarding, raid alarm, building complete.
3. THE game SHALL be fully playable with sound off, with no information available only through
   audio.
4. THE system SHALL provide independent Music, SFX, and Voice volume sliders.

### Requirement 5: Input and reach

#### Acceptance Criteria

1. THE system SHALL provide a one-handed mode placing every primary action within the lower third
   of the screen.
2. THE system SHALL provide a hold-versus-tap option for every action currently requiring a
   sustained hold.
3. Every touch target SHALL be at least 48×48 dp with at least 8 dp separation from adjacent
   targets.
4. No action SHALL require a multi-touch gesture without a single-touch alternative.
5. Every menu SHALL be fully navigable by gamepad and by keyboard.

### Requirement 6: Settings surface

#### Acceptance Criteria

1. All accessibility options SHALL live in one dedicated Accessibility section of `SettingsMenu`,
   not scattered across other tabs.
2. Every option SHALL persist through `SettingsManager` and apply immediately without a restart.
3. Accessibility settings SHALL be account-scoped, not save-scoped — a new campaign SHALL NOT
   reset them.

### Requirement 7: Enforcement

**User Story:** As a maintainer, I want accessibility not to silently regress.

#### Acceptance Criteria

1. THE system SHALL provide automated tests for the mechanically-checkable checklist items:
   contrast, colour-alone, touch target size, text reflow at 200%, and gamepad navigability.
2. THE tests SHALL cover every existing UI screen, not only new ones.
3. Checklist items requiring visual judgement SHALL be verified in a headful pass and SHALL be
   reported as unverified if that pass did not happen — never claimed on the strength of a
   headless run.

### Requirement 8: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M19 section.
2. `docs/14_SYSTEM_INVENTORY.md` accessibility rows SHALL move off ❌.
3. `docs/18_ACCESSIBILITY.md` SHALL be reconciled against what shipped, and SHALL record which
   checklist items are enforced by test versus by review.
4. `docs/20_PLATFORM_MATRIX.md` SHALL note the accessibility features declared in store listings.

---

## Out of Scope

- **Screen-reader narration of the 3D world.** Explicitly out of scope in
  `docs/18_ACCESSIBILITY.md` §1 — the cost is disproportionate for a game of this shape.
- **Full WCAG AA certification.** The target is substantive accessibility for the barriers this
  game actually creates, not a compliance badge.
- **Voice acting or voice control.** No voice content exists.
- **Localization.** M12 owns strings. This milestone must not break M12's work, and Requirement
  2.5 (no text in textures) actively helps it.
- **New UI screens.** M19 makes existing screens accessible; it does not add surfaces.
- **Difficulty options or assist modes.** A legitimate accessibility topic, but a gameplay
  balance decision that belongs with `docs/04_GAME_LOOP.md`, not here.
- **Changing wave or buoyancy physics.** Reduced motion is a camera and presentation setting only
  (Requirement 3.3) — altering the simulation would change gameplay and risks the D11 wave-sync
  defect class.
