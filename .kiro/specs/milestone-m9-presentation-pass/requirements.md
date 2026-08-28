# Requirements Document

## Introduction

Milestone M9 is a presentation and UI/UX pass, inserted ahead of the previously-planned "M9 — The
Legible World" (renumbered M10) after a 2026-08-26 audit that, for the first time, actually ran
the game (`scenes/debug/CaptureHarness.tscn`, headful, zero input) and looked at the rendered
output rather than reading code or trusting a prior "Resolved" status. Two defects this project's
own ground-truth doc already recorded as fixed — D32 (4× `Parameter "material" is null` at
startup) and D36 (HUD layout: the notoriety label overlapping the resource bar) — reproduced on a
completely fresh run. Five further UI/UX problems were found the same way, none previously
tracked. Full narrative and evidence: `docs/15_MASTER_PLAN.md` §8,
`docs/05_CURRENT_SYSTEMS.md`'s "Presentation audit (2026-08-26)" section,
`docs/09_VISUAL_BUG_TRACKER.md` V5/V9/V13–V17.

This milestone exists because M1–M8 (plus M7.5) built a functionally complete, well-tested game
(324 tests, 323 passing) whose UI has never been reviewed by a human looking at rendered output —
only by code review and fixed-timestamp automated screenshots. The result is a HUD that visibly
overlaps its own text, two unthemed screens sitting next to eight themed ones, and a main-menu
title with no font-size styling — all on the very first and most-repeated screens a player sees.
None of these are systems bugs; all of them are the first impression of an otherwise complete
game. This milestone is deliberately scoped to composition/consistency/regression fixes only — the
underlying visual language (`PirateThemeBuilder`'s gold/navy palette, `Cinzel`/`PirataOne` fonts)
is sound and is explicitly not being redesigned here.

---

## Requirements

### Requirement 1 — Fix the reopened D36 HUD-overlap regression for real

**User Story:** As a player, I want the top-right HUD (resources, notoriety, next escalation) to
be readable at a glance, so I can track my empire's state without squinting through overlapping
text.

#### Acceptance Criteria

1. `WorldHUD._create_notoriety_label()` SHALL position the notoriety/next-escalation label using a
   layout that cannot silently drift out of alignment with the `ResourceBar` panel — e.g. anchoring
   directly beneath the `ResourceBar` node's actual rect (by node reference or group), not a
   hardcoded pixel offset assumed to match `ResourceBar`'s own hardcoded offsets.
2. Under a fresh `CaptureHarness` run with a populated resource bar (gold/wood/iron/rum all
   non-zero, multi-digit) and non-zero notoriety, no character of the notoriety/escalation label
   SHALL overlap any character of the resource bar.
3. The fix SHALL hold across at least two different viewport sizes/aspect ratios exercised by the
   test in Requirement 7 — the original D36 "fix" held at design time but silently broke, and this
   requirement exists specifically so that class of regression cannot recur unnoticed.
4. `docs/05_CURRENT_SYSTEMS.md`'s D36 entry, `docs/14_SYSTEM_INVENTORY.md` §7.7, and
   `docs/09_VISUAL_BUG_TRACKER.md` V9 SHALL be updated from "reopened" back to resolved, with the
   new fix described and a fresh validating capture referenced.

### Requirement 2 — Re-diagnose and close the reopened D32 material-null errors

**User Story:** As a developer, I want the game to start with zero renderer errors, so that error
logs stay meaningful and a future error isn't lost in noise from a known-but-unfixed one.

#### Acceptance Criteria

1. The 4 `Parameter "material" is null` errors (`material_casts_shadows`,
   `material_is_animated`, `material_get_instance_shader_parameters`,
   `material_update_dependency`) SHALL be re-diagnosed from scratch — the previous D31-based
   explanation (camera spring arm colliding with its own followed ship) is confirmed not to fully
   explain them, since the D31 fix is still in place and the errors still occur.
2. A fresh `CaptureHarness` run SHALL report 0 such errors after the fix, or the errors SHALL be
   conclusively identified as harmless/expected and documented as such with the actual source
   traced (not merely re-guessed).
3. `docs/05_CURRENT_SYSTEMS.md`'s D32 entry and `docs/09_VISUAL_BUG_TRACKER.md` V5 SHALL be
   updated to reflect the real root cause and resolution.

### Requirement 3 — Theme `SettingsMenu` and `CreditsScreen` to match every other screen

**User Story:** As a player, I want every menu in the game to look like the same game, so that
checking Settings doesn't feel like I've been dropped into an unfinished placeholder.

#### Acceptance Criteria

1. `SettingsMenu.gd` and `CreditsScreen.gd` SHALL apply `PirateThemeBuilder.build()` the same way
   every other screen in `scenes/ui/` already does (`MainMenu`, `IslandMenu`, `DeathScreen`,
   `PauseMenu`, `CaptainsLog`, `RaidReportScreen`, `TutorialDialogue`, `UpgradeChoiceScreen`,
   `WorldHUD`).
2. `SettingsMenu.tscn` SHALL gain a background panel consistent with the rest of the game's UI
   (matching the dark-navy/gold panel style `PirateThemeBuilder` and other screens' `.tscn` files
   already use) — it currently has none, rendering as a transparent overlay over whatever scene is
   behind it.
3. `SettingsMenu`'s `TabContainer` and its child controls (sliders, checkboxes, rebind buttons)
   SHALL visibly pick up the themed font/color/panel styling after the fix — verified by reading
   the applied theme's resolved values, not just confirming the `theme =` assignment exists.
4. This SHALL NOT change any settings functionality (rebinding, sensitivity, audio/display
   options) — purely a visual/theme change.

### Requirement 4 — `MainMenu` typographic hierarchy and button consistency

**User Story:** As a player, I want the main menu — the very first thing I see — to look
deliberately designed, so my first impression of the game is "finished," not "placeholder."

#### Acceptance Criteria

1. `MainMenu.tscn`'s `TitleLabel` ("PIRATE EMPIRE") SHALL render at a font size clearly larger than
   body/button text (the theme's current button size is 28px; the title SHALL be visibly larger
   than that, not left at the 15px default-body size it currently inherits).
2. `SubtitleLabel` ("Rule the Seas. Build an Empire.") SHALL render at a size between the title and
   body text, establishing a clear three-tier hierarchy (title > subtitle > buttons/body).
3. All five buttons in `Control/ButtonPanel/VBoxContainer` (`ContinueButton`, `NewGameButton`,
   `SettingsButton`, `CreditsButton`, `QuitButton`) SHALL share the same font-size override — today
   three are 28px and two (`CreditsButton`, `QuitButton`) are unset. Either all five carry an emoji
   prefix or none do — today only `CreditsButton`/`QuitButton` do.
4. `VignetteOverlay` (`Control/VignetteOverlay`, authored at `Color(0, 0, 0, 0)` and never
   referenced by `MainMenu.gd`) SHALL either be removed, or wired to an actual runtime effect
   (e.g. a subtle vignette tween on scene entry) — it SHALL NOT remain authored-but-inert.
5. This SHALL NOT change `MainMenu`'s navigation behavior (Continue/New Game/Settings/Credits/Quit
   routing) — purely a visual/typography change.

### Requirement 5 — Arbitrate concurrent HUD panels (tutorial dialogue vs. combat HUD vs. announcements)

**User Story:** As a player, I want the game to show me one coherent thing at a time when several
events happen at once, so a tutorial moment doesn't get visually contaminated by an unrelated
combat panel bleeding through underneath it.

#### Acceptance Criteria

1. When `TutorialDialogue` is visible, `WorldHUD` SHALL either hide or visibly de-emphasize
   (e.g. dim/fade) the `CannonsContainer` combat panel beneath it, rather than letting both render
   at full opacity simultaneously.
2. An ambient encounter starting while `TutorialDialogue` is open SHALL NOT begin firing cannons
   with no on-screen acknowledgment — at minimum, this SHALL be prevented from occurring during a
   chapter's opening dialogue beat (the exact scenario reproduced in the 2026-08-26 audit), by
   gating ambient encounter starts while a blocking dialogue/tutorial panel has focus, or by
   pausing ambient spawn timers while such a panel is open.
3. This requirement does not mandate a general-purpose UI stack/focus-manager system — a minimal,
   explicit priority rule (tutorial dialogue > combat HUD visibility; ambient encounters gated
   while tutorial/campaign dialogue is open) is sufficient and preferred, per `AGENTS.md`'s
   "no unnecessary complexity."

### Requirement 6 — Framed, themed announcement banner

**User Story:** As a player, I want system announcements (e.g. "while you were away") to look like
part of the game's designed UI, so a genuinely nice moment (my empire kept running) doesn't read
as a debug print interrupting the view.

#### Acceptance Criteria

1. `WorldHUD.announce_event()` SHALL render its message inside a themed, bordered panel (consistent
   with `PirateThemeBuilder`'s existing panel style — dark-navy background, gold border) rather
   than as bare, unframed `Label` text directly over the 3D viewport.
2. The banner SHALL remain full-width-safe and auto-wrapping for long messages (preserving the
   existing fix for the message running off-screen) and SHALL continue to fade in/out, not pop.
3. The banner's color/size SHALL read as a deliberate design choice appropriate to the message's
   tone (e.g. neutral/gold for informational messages) rather than the current alarm-red for every
   message regardless of content, unless a message is genuinely a warning.
4. This SHALL NOT change which events trigger an announcement or their text content — purely
   presentation.

### Requirement 7 — Responsive `IslandMenu` sizing

**User Story:** As a player on a mobile device, I want the island management screen (buildings,
shipyard, tavern, fleet, research, trade) to use my actual screen space sensibly, so it isn't a
tiny fixed box floating in the middle of a much larger or differently-shaped screen.

#### Acceptance Criteria

1. `IslandMenu.tscn`'s main `Panel` SHALL replace its hardcoded `custom_minimum_size =
   Vector2(600, 400)` with responsive anchoring (e.g. a percentage-of-viewport or
   min/max-clamped size) that scales sensibly across at least two different viewport
   sizes/aspect ratios.
2. All six tabs (Buildings, Shipyard, Tavern, Fleet, Research, Trade) SHALL remain fully usable
   (no clipped content, no unreachable scroll region) at both a desktop-like viewport (e.g.
   1920×1080, the project's declared default) and a phone-like portrait or narrow-landscape
   viewport.
3. This SHALL NOT change any gated-by-tier/gated-by-ownership logic already governing tab/button
   availability — purely a sizing/layout change.

### Requirement 8 — Intentional portrait-fallback treatment

**User Story:** As a player meeting a named character (captain, Higgins, a faction leader) before
real portrait art exists, I want the placeholder to look like a deliberate design choice, so it
doesn't read as a missing/broken asset.

#### Acceptance Criteria

1. Dialogue and roster UI currently showing a generic purple skull-and-crossbones icon for any
   character with no `portrait_path` asset on disk SHALL instead show a treatment that reads as
   intentional — e.g. a stylised flag/monogram/silhouette consistent with `PirateThemeBuilder`'s
   palette — reusable for any of the 27 named characters (20 captains + 7 named cast) until real
   portraits land in M11.
2. The fallback SHALL be a single shared resource/scene, not duplicated per call site, so M11's
   real-portrait work only needs to add actual art files without touching the fallback logic.

### Requirement 9 — Documentation

**User Story:** As a maintainer, I want this pass's findings and fixes recorded the same way every
prior defect has been, so the ground-truth docs stay accurate for the next audit.

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md`'s "Presentation audit (2026-08-26)" section SHALL be updated:
   D32/D36 marked re-resolved with their real fixes described; D68–D72 marked resolved with their
   fixes described.
2. `docs/14_SYSTEM_INVENTORY.md` §7.7 and the relevant status rows (HUD, Settings/Credits theming,
   MainMenu, IslandMenu sizing) SHALL be updated to ✅.
3. `docs/09_VISUAL_BUG_TRACKER.md` V5, V9, V13–V17 SHALL be updated from open/reopened to
   `[x]` fixed and confirmed, each with a fresh validating capture referenced.
4. `docs/15_MASTER_PLAN.md`'s M9 entry SHALL have its exit-criteria results filled in.

---

## Non-Goals

- Redesigning `PirateThemeBuilder`'s palette, fonts, or overall visual language — confirmed sound
  in the 2026-08-26 audit; this milestone fixes composition/consistency/regressions, not the
  underlying design.
- Building a general-purpose UI focus-stack/z-order manager — Requirement 5's HUD arbitration is
  scoped to the specific reproduced conflict (tutorial dialogue vs. combat HUD vs. ambient
  encounters), not a rearchitecture of how every future screen will coordinate.
- Real portrait art (27 files) — Requirement 8 only covers the fallback treatment; sourcing/
  authoring real portraits is M11 scope.
- Any of the M10–M14 roadmap items in `docs/15_MASTER_PLAN.md` — reviewed during this pass's
  scoping and confirmed accurately scoped; nothing here needed a new bucket beyond what §8 of that
  document already added.
- Mobile device testing (touch target sizing, thermal/battery) — still M13 scope; Requirement 7's
  "phone-like viewport" acceptance criterion is a desktop-simulated aspect-ratio check, not a
  real-device verification pass.
