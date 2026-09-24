# Requirements Document

## Introduction

M15.5 modernized *how* the theme rendered (Kenney 9-slice button PNGs, rounded `StyleBoxFlat`
panels, `ButtonJuice` scale tweens), and the 2026-09-24 pass swapped the body font to Cinzel. A
2026-09-25 on-device capture sweep (`screenshots/mobile/device_test/`, 2340×1080 phone) shows the
result still reads as flat and dated: every surface is the same dark-navy box with a thin gold
rule, all text is small Cinzel small-caps, Settings rows are mostly empty space, the General-tab
volume sliders render **no track at all** (one stray grabber is the only visible part), the
crash-recovery notice is an unstyled grey Godot `AcceptDialog`, and HUD buttons are
text-on-navy squares with no hierarchy between primary and secondary actions.

This milestone replaces the visual language across every UI surface with the one specified in
`claude design outputs/Pirate Empire UI System v0.3.html` (unbundled source:
`…/Pirate Empire UI System.zip → Pirate Empire UI System v0.3.dc.html`) — "epic world, funny
furniture": warm wood/brass/parchment chrome, chunky lipped buttons with a single coral primary
per screen, Germania One headers over Baloo 2 body/numbers, landscape layout authored on a
1688×780 base, and the gameplay "celebration moments" (sunk, loot, victory, tier-up, escalation).

**Already met, no further work:** a single runtime theme exists (`PirateThemeBuilder.build()`,
applied by every screen); a single icon registry (`UIIcons`); a reusable modal (`ChoiceDialog`);
recursive button feedback (`apply_button_juice`); a player-selectable UI font
(`SettingsManager.ui_font`); a headful per-screen screenshot walker
(`scripts/debug/FontOverflowAudit.gd`). M22 changes these in place; it adds no parallel system.

**Sequencing note (Rule 8):** M17 has open tasks and M18–M21 are unstarted forward-planning
scaffolds. M22 is started ahead of them at the user's explicit direction (2026-09-25), the same
"unplanned insertion" role M7.5 and M15.5 played. It does not touch billing (M17), retention
(M18), or any M19 accessibility *option*; it must not make M19 harder (see Req 1.3, 2.4).

## Glossary

- **Design px** — a length in the v0.3 doc, authored at 1× on an 844×390 phone. Godot base is
  1688×780, so **Godot px = design px × 2** everywhere in this milestone.
- **Palette** — the `UIPalette` resource holding every UI colour token; the only place a UI
  colour is defined.
- **Kit** — the generated texture set under `assets/ui/kit/` (frames, buttons, controls, gems).
- **Primary** — the single coral call-to-action on a screen (at most one visible at a time).
- **Brass** — the default secondary button; never glows.
- **Wood round** — circular 56–58 design-px button for nav, HUD abilities and icon actions.
- **Lip** — the solid 6 design-px shadow slab under a button that collapses to 2 on press.
- **Celebration tier** — Small (in place, ≤1s, never blocks input), Medium (overlay, 1.5–2.5s,
  input live), Large (full takeover, 3s+, waits for its CTA).
- **Screen sweep** — the headful capture walker (promoted from `FontOverflowAudit`) that
  screenshots every UI surface in phone, tablet and desktop scaling.

## Requirements

### Requirement 1: Design tokens

**User Story:** As a maintainer, I want every UI colour, size and timing defined once, so that the
look is consistent and a future palette (M19) is a resource swap, not a code hunt.

#### Acceptance Criteria

1. THE system SHALL define UI colours (the 12 v0.3 swatches, brick-red destructive, the 5-step
   rarity ramp, text-on-dark/text-on-parchment) in a `UIPalette` resource
   (`resources/ui/palette_default.tres`), not as script constants.
2. THE system SHALL define the type scale, radii, lip/press and motion timings in one script
   (`scripts/ui/UITokens.gd`), expressed in Godot px (design px × 2).
3. WHEN M22 completes, no script under `scripts/ui/` SHALL construct a `Color(...)` literal for a
   themed element; existing `PirateThemeBuilder.COLOR_*` constants SHALL resolve through the palette.
4. Coral SHALL be used only for the Primary button and Legendary rarity.

### Requirement 2: Typography

**User Story:** As a phone player, I want text that is big, bold and readable over busy art.

#### Acceptance Criteria

1. THE system SHALL ship Germania One (headers, CTA labels) and Baloo 2 (body, all numerals) under
   `assets/fonts/` with their OFL licence files.
2. Header/CTA text SHALL render with a 2 design-px ink drop shadow.
3. THE theme SHALL expose label type variations `DisplayLabel` (44), `TitleLabel` (28),
   `HudNumLabel` (18), `BodyLabel` (16), `ChipLabel` (12) in design px; body text SHALL be ≥16.
4. `SettingsManager.ui_font` SHALL keep working; its Default option SHALL map to Baloo 2 and
   existing saved values SHALL load without error.
5. No text SHALL be baked into any kit texture.

### Requirement 3: Display & safe area

#### Acceptance Criteria

1. `project.godot` SHALL set base 1688×780, stretch `canvas_items`, aspect `expand`, and
   `display/window/handheld/orientation` to sensor landscape.
2. Every full-screen UI SHALL keep interactive controls ≥48 design px from both side edges and
   inside `DisplayServer.get_display_safe_area()`.
3. Phone/tablet scale factors in `PirateThemeBuilder` SHALL be re-derived for the new base so a
   phone renders design px at ≈1:1 and touch targets stay ≥48×48 dp.
4. All screens SHALL render without clipped or overlapping text at 19.5:9, 16:9 and 4:3.

### Requirement 4: Texture kit

#### Acceptance Criteria

1. THE system SHALL provide SVG-sourced textures for: parchment page (9-slice), wood frame with
   rope and brass studs (9-slice), wood title plaque (3-slice), Primary/Brass/Wood-round button
   bodies in idle/pressed/disabled, toggle track on/off + knob, rope slider track/fill/knob,
   segmented well + pill, tab idle/active, dropdown sheet, resource pill, 5 rarity gem borders,
   cooldown ring mask, glow sprite.
2. Panels SHALL never render as a flat single-colour fill.
3. Resource icons (gold, rum, wood, iron, research, cannonball) SHALL follow the v0.3 icon spec and
   be served only through `UIIcons`.
4. A debug scene SHALL render every kit piece for visual verification.

### Requirement 5: Theme components

#### Acceptance Criteria

1. THE theme SHALL provide button variations `PrimaryButton`, `BrassButton` (the default `Button`
   look) and `WoodRoundButton`, with v0.3 idle/pressed/disabled states.
2. WHEN a button is pressed THE system SHALL move its content down 4 design px, shrink the lip
   6→2 and darken to 88% brightness, 60ms in / 120ms out.
3. A Primary button SHALL carry a looping glow (opacity .45→1, scale .96→1.07, 2.2s); no other
   button SHALL glow.
4. THE theme SHALL style HSlider (visible track, fill and knob — fixes the invisible-track defect),
   CheckButton (toggle), OptionButton/PopupMenu (parchment sheet), TabContainer/TabBar (active tab
   parchment), ProgressBar, ScrollBar, LineEdit, TooltipPanel, and AcceptDialog/ConfirmationDialog.
5. Panel variations `ParchmentPanel`, `WoodFramePanel`, `PlaquePanel` SHALL exist.

### Requirement 6: Menus & modals

#### Acceptance Criteria

1. MainMenu, PauseMenu, SettingsMenu, CreditsScreen, AgeGate, ConsentPanel, ChoiceDialog and the
   crash-recovery notice SHALL use the new kit and type variations.
2. SettingsMenu SHALL keep its existing General/Controls/Account tabs, options and behaviour
   (restyle only); every slider SHALL show a track and a numeric value.
3. Each of these screens SHALL have at most one Primary button.

### Requirement 7: HUD & mobile controls

#### Acceptance Criteria

1. WorldHUD resource counters, speed/sail readout, hull bar, notoriety and production timer SHALL
   use the kit (resource pills, plaque, chip).
2. MobileControls SHALL use Wood-round buttons with icon art; Set Sail SHALL be the HUD's only
   Primary; ability cooldowns SHALL render as a conic sweep, not a grey-out.
3. HUD customization (`HudCustomizeOverlay`), left-handed mirroring and the touch-target audit
   SHALL keep working unchanged.
4. No ship, combat or input logic SHALL change.

### Requirement 8: Content screens

#### Acceptance Criteria

1. IslandMenu, captain drawer/roster, CaptainsLog, WorldMapScreen, CodexScreen, WhatsNewScreen,
   WardrobeScreen, StoreScreen, RaidReportScreen, DeathScreen, TutorialDialogue,
   UpgradeChoiceScreen, RewardedBonusOffer, PurchaseSupportScreen, EnemyHealthBarWidget and
   FloatingDamage SHALL use the kit.
2. Detail panels SHALL dock to the right edge in landscape, per v0.3 screens 01–03.
3. Rarity gem borders SHALL appear only where the data already carries a rarity; M22 SHALL NOT add
   a rarity field or system.

### Requirement 9: Motion & celebration moments

#### Acceptance Criteria

1. `scripts/ui/UIMotion.gd` SHALL provide pop-in, shine sweep, number tick-up, stamp, float-up and
   typewriter helpers with v0.3 timings.
2. A celebration queue SHALL enforce the Small/Medium/Large tiers; two Large moments SHALL never
   overlap — the second waits for the first's CTA.
3. Moments SHALL be triggered only from existing signals (e.g. `ShipCombat.died`,
   `EmpireManager.notoriety_changed`), never a new direct call path into gameplay code.
4. UIMotion SHALL read a single reduced-motion query point (default off) so M19 can wire its
   toggle without touching call sites; nothing SHALL flash above 3 Hz.

### Requirement 10: Verification & docs

#### Acceptance Criteria

1. THE screen sweep SHALL capture every surface in Req 6–8 at phone, tablet and desktop scaling.
2. Every phase checkpoint SHALL include a GUT run with no new failures and a viewed screen sweep.
3. `docs/05_CURRENT_SYSTEMS.md` and `docs/03_ART_DIRECTION.md` SHALL describe the M22 system at close.

## Out of Scope

- New settings options or Settings restructure into the v0.3 five pages (user decision: restyle
  only). The v0.3 Audio/Graphics/Accessibility/Notifications pages are reference for *look* only.
- M19 accessibility features (palette variants, text scaling, reduced-motion *toggle*, dyslexia
  font) — M22 only leaves the hooks (Req 1.1, 9.4).
- A captain/loot rarity system — v0.3 marks it "not in the game yet"; data work belongs elsewhere.
- Painted illustration slots (islands, ships, captain portraits, chest, parrot) — v0.3 leaves
  them as "ART" slots; M22 keeps existing art and `PortraitFallback`.
- Any gameplay, balance, ship-physics, combat or input change.
- Store/billing flows beyond reskinning existing screens.
