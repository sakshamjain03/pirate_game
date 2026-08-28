# Requirements Document

## Introduction

Milestone M15.5 is an unplanned visual-polish pass, the same role `milestone-m7.5-stabilization`
played between M7 and M8: an out-of-sequence insertion between the now-complete M15
(Backend & Cloud Services) and the already-scaffolded M16 (Cosmetics & Entitlements), not a
renumbering of the M16–M21 roadmap in `docs/15_MASTER_PLAN.md`.

The gap this closes: every screen in the game (`WorldHUD` and all ten menu screens) renders
through `PirateThemeBuilder.gd`, a single centrally-applied theme — this part already works well
and needs no rework (`docs/05_CURRENT_SYSTEMS.md`'s Presentation section confirms it, last
touched by M9's presentation pass). But that theme's actual visual output is flat 2010-era
`StyleBoxFlat` boxes (small radius, hard shadow, thin border) and plain emoji-prefixed `Label`
text for every resource/stat readout — no icon art, no gradient, no press feedback. The player's
own framing: it reads as dated next to contemporary mobile games (Clash Royale/Coin Master were
the named reference points), and this is the screen surface seen in 100% of play sessions. This
milestone modernizes *how* the existing theme renders, not *what* it shows — `docs/03_ART_DIRECTION.md`'s
"Minimal, Large buttons, Readable fonts, High contrast" standard is kept, not replaced.

**What already exists and needs no work here:** the single-theme-applied-everywhere architecture
(`PirateThemeBuilder.build()`, called from `WorldHUD.gd`, `MainMenu.gd`, `IslandMenu.gd`,
`PauseMenu.gd`, `SettingsMenu.gd`, `DeathScreen.gd`, and five other screens); the signal-driven
update points that already exist for every value this pass re-skins (`ResourceManager.resources_changed`
→ `WorldHUD._on_resources_changed()`, `ShipController.ship_health_changed` → `WorldHUD._on_health_changed()`,
`EmpireManager.notoriety_changed` → `WorldHUD._on_notoriety_changed()`); the reusable
themed-modal precedent (`scripts/ui/ChoiceDialog.gd`, M15's own new-screen pattern).

**What does not exist and this milestone builds:** any icon/texture asset for UI at all (every
resource/stat is currently emoji-in-a-Label); a gradient or soft-shadow "card" visual language;
any button/bar press or fill animation; a shared component for that animation.

## Glossary

- **UI texture pack** — a single, coherently-styled, CC0-licensed set of pre-rendered 9-slice
  panel/button/bar PNGs plus matching icon glyphs, sourced from a public asset site (e.g.
  Kenney.nl). Chosen because Godot's `StyleBoxFlat` cannot fill with a gradient, and
  `GradientTexture2D` cannot have rounded alpha-blended corners without a custom shader — a
  pre-rendered texture is the low-risk way to get a rounded, gradient-shaded "premium" panel
  without introducing shader code this project would then have to maintain.
- **Icon chip** — a small rounded `PanelContainer` holding an icon `TextureRect` beside a count
  `Label`, replacing a bare emoji-prefixed `Label` (e.g. `"💰 1250"` becomes a gold-coin icon next
  to `"1250"` on a rounded gradient-textured background).
- **Juice** — the informal but precise term (used the same way throughout game-feel literature)
  for the small animated feedback — a button's press/hover scale tween, a bar's fill/pulse
  animation — that makes an interaction read as responsive rather than static, independent of the
  underlying art quality.

## Requirements

### Requirement 1: Sourced UI texture/icon asset set

**User Story:** As a player, I want the resource counters, panels, and buttons to use real icon
and panel art instead of emoji-in-a-box, so the game reads as professionally produced.

#### Acceptance Criteria

1. A single coherent, CC0-licensed (or equivalently unrestricted) UI texture pack SHALL be
   sourced, covering: rounded 9-slice panel and button textures, a bar/fill texture, and icon
   glyphs for gold/wood/iron/rum, ship health, notoriety, and at least anchor/compass.
2. The pack's assets SHALL live under `assets/ui_icons/`, not `assets/icons/` (already used by
   M13's Android app-icon files — a name collision would make both purposes ambiguous).
3. The pack's license file SHALL be kept alongside the assets in `assets/ui_icons/`, and the
   license terms SHALL be confirmed to permit redistribution inside a shipped game before any
   asset is wired into a scene.
4. `scripts/ui/UIIcons.gd` SHALL provide a single lookup point (by resource/stat key) for every
   icon texture path this milestone introduces — no scene or script SHALL hardcode an
   `assets/ui_icons/...` path directly, mirroring how `PirateThemeBuilder` is already the one
   place theme values live.

### Requirement 2: Modernized central theme

**User Story:** As a player, I want every panel, button, and bar in the game to share one
current-feeling visual language, so the UI reads as one polished product rather than a patchwork.

#### Acceptance Criteria

1. `PirateThemeBuilder.build()` SHALL produce `Button`, `Panel`/`PanelContainer`, and
   `ProgressBar` styles built from the Requirement 1 texture pack (`StyleBoxTexture`, 9-slice
   margins) rather than the current flat `StyleBoxFlat` boxes, while keeping the same theme types
   and property names it already sets (`normal`/`hover`/`pressed`/`focus` for `Button`; `panel`
   for `Panel`/`PanelContainer`; `background`/`fill` for `ProgressBar`) so every screen that
   already calls `PirateThemeBuilder.build()` picks up the new look with no per-screen code
   change.
2. The existing font choices (PirataOne, Cinzel/Cinzel-Bold) and the pirate-rooted gold/navy
   identity SHALL be kept — this is a rendering-technique change, not a rebrand.
3. Any element for which no texture-pack asset fits (a one-off dynamically-colored state, e.g.
   the red "cap reached" resource tint) SHALL fall back to an enhanced `StyleBoxFlat` (larger
   corner radius, `shadow_size`/`shadow_color`, `anti_aliasing = true`) rather than the current
   small-radius/hard-shadow box — never a silent revert to the old flat look.
4. `docs/03_ART_DIRECTION.md` SHALL be updated to describe the new rendering technique while
   keeping its existing "Minimal, Large buttons, Readable fonts, High contrast" standard intact.

### Requirement 3: WorldHUD icon-chip resource counters and restyled bars

**User Story:** As a player sailing the world, I want the resource counters, health bar, and
cannon-cooldown readouts to look like a modern mobile game's HUD, since this is the screen I see
for nearly all of play.

#### Acceptance Criteria

1. `WorldHUD.tscn`'s `%GoldLabel`/`%WoodLabel`/`%IronLabel`/`%RumLabel` (currently plain
   emoji-prefixed `Label`s) SHALL each become an icon chip (icon `TextureRect` + count `Label` on
   a Requirement 2 panel style), with the same node's existing `unique_name_in_owner` preserved so
   `WorldHUD.gd`'s `_on_resources_changed()` continues to update it with no signal-wiring change.
2. `%HealthBar` SHALL use the Requirement 2 bar style (texture-based background/fill) and SHALL
   animate its `value` change (a short tween on `_on_health_changed()`) rather than snapping
   instantly, while `set_health()`'s existing text-label update behavior is preserved.
3. The health bar SHALL visibly pulse (e.g. a looping modulate/scale tween) when current health
   drops below 25% of maximum, stopping once health rises back above that threshold.
4. Port/starboard cannon-cooldown panels (`CannonsContainer`) and the notoriety readout
   (`_create_notoriety_label()`) SHALL be restyled with the same panel/icon language — no new
   visual language introduced that doesn't also appear elsewhere in the HUD.
5. None of the above changes the actual gameplay values displayed or the signals/functions that
   feed them — `WorldHUD.gd`'s public methods (`set_health`, `set_cannon_cooldown`,
   `announce_event`, etc.) keep their existing signatures.

### Requirement 4: Button and bar "juice"

**User Story:** As a player, I want buttons and bars to visibly respond to my input, so the UI
feels alive rather than static.

#### Acceptance Criteria

1. A new reusable `scripts/ui/ButtonJuice.gd` SHALL provide a press/hover scale-and-brightness
   tween attachable to any `Button` without per-button boilerplate, following the same
   composition precedent as `ChoiceDialog.gd` (a small standalone script, not a new base class
   every button must inherit from — `AGENTS.md`'s composition-over-inheritance rule).
2. Every `Button` across every screen touched by Requirement 5 SHALL use `ButtonJuice.gd`.
3. The press/hover animation SHALL complete within 150ms so it never reads as input lag.

### Requirement 5: Apply the modernized theme across every remaining screen

**User Story:** As a player, I want every menu (not just the HUD) to share the new look, so
navigating between screens doesn't feel like crossing between two different games.

#### Acceptance Criteria

1. Every screen currently duplicating its own inline `StyleBoxFlat`-based panel background
   (`IslandMenu.tscn`, `PauseMenu.tscn`, `DeathScreen.tscn`, `CaptainsLog.tscn`,
   `RaidReportScreen.tscn`, `TutorialDialogue.tscn`) SHALL instead use the Requirement 2
   centralized panel style — removing the per-scene duplicated `StyleBoxFlat_*Bg`-style
   sub-resource where the centralized style now covers the same need.
2. `MainMenu.tscn`, `SettingsMenu.tscn`, `CodexScreen.tscn`, `WorldMapScreen.tscn`,
   `UpgradeChoiceScreen.tscn`, and `MobileControls.tscn` SHALL visibly reflect the new theme
   (verified by launching each screen, not inferred from the theme change alone, since several of
   these build UI elements dynamically in code rather than purely through the shared `Theme`).
3. No screen's existing functional behavior (button actions, tab switching, data displayed,
   `tr()`-wrapped strings) SHALL change — this is a rendering-only pass.

### Requirement 6: Documentation

**User Story:** As a maintainer, I want this pass's outcome recorded the same way every prior
milestone's has been, so a future session doesn't have to rediscover it.

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md`'s Presentation section SHALL gain an entry describing the new
   texture-based theme, the icon-chip pattern, and `ButtonJuice.gd`, with the updated GUT
   baseline.
2. `docs/03_ART_DIRECTION.md` SHALL be updated per Requirement 2.4.
3. `docs/15_MASTER_PLAN.md` SHALL gain an "M15.5" entry inserted between the M15 and M16 sections,
   explicitly framed as an unplanned insertion (matching M7.5's own framing) that does not
   renumber M16–M21.

## Out of Scope

- Any change to gameplay values, economy numbers, signal wiring, or save data — this is a
  rendering-only milestone.
- Real captain portrait artwork (tracked separately, `docs/05_CURRENT_SYSTEMS.md` — 0 of 27
  delivered as of M11) — out of scope here; portraits use a different sourcing problem (specific
  named characters) than generic UI icons.
- Colorblind-safe palettes / non-color state redundancy — that is M19 (Accessibility &
  Inclusive Play)'s explicit scope; this pass should not accidentally regress contrast, but does
  not attempt the accessibility audit itself.
- Cosmetic items, entitlements, or any monetization surface — that is M16's explicit scope; this
  milestone ships no purchasable content and has no dependency on M16 having landed.
- Music/SFX for button presses — `AudioManager` exists but has no configured audio backend
  (`docs/05_CURRENT_SYSTEMS.md` known gap); adding sound here would be new scope this milestone
  doesn't own.
- A custom shader-based gradient/rounding pipeline — deliberately avoided in favor of sourced
  texture assets (see Glossary); revisit only if a future milestone has a specific need a texture
  pack can't satisfy.
