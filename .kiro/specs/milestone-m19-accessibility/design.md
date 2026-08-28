# Design Document: Milestone M19 — Accessibility & Inclusive Play

## 1. Why this design shape

**Palettes belong in themes, not in scripts.** The M9 presentation pass established themed
screens; this milestone makes the theme the single source of colour truth. Any colour still
hardcoded in a `.gd` file is unreachable by a palette swap, which is why Task 2 is a sweep rather
than a feature.

**Redundancy is authored once, per state, not per screen.** The faction-relation colour appears in
several screens. The icon that makes it non-colour-dependent is added to the data that describes
the relation, so every consumer inherits it. Adding it screen-by-screen guarantees one gets missed.

**Reduced motion is a camera setting.** Requirement 3.3 forbids touching gameplay values, and this
is not pedantry: `docs/05_CURRENT_SYSTEMS.md` D11 was a wave-sync defect between the GPU wave
shader and CPU buoyancy sampling. Damping the *simulation* to reduce motion would re-open exactly
that class of bug. Damp `CameraRig`'s reaction instead; the ship still rides the same waves.

**Tests are the deliverable as much as the features are.** Requirement 7.2 covers every existing
screen, not just new ones. Without that, this milestone decays over the next four.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/managers/AccessibilityManager.gd` | **New.** Autoload. Palette, text scale, reduced motion, one-hand, caption settings. Applies on change. |
| `resources/ui/palette_*.tres` | **New.** Default, Deuteranopia, Protanopia, Tritanopia. |
| `resources/ui/theme_*.tres` | **Changed.** Colours sourced from the active palette. |
| `scripts/ui/SettingsMenu.gd` + scene | **Changed.** New Accessibility section. |
| `scripts/ui/CaptionLayer.gd` + scene | **New.** Global caption surface with scrim. |
| `scripts/world/CameraRig.gd` | **Changed.** Reduced-motion damping of sway and pitch reaction. |
| `scripts/managers/SettingsManager.gd` | **Changed.** Persist the new options at account level. |
| Every `scenes/ui/*.tscn` | **Changed.** Touch targets, reflow containers, non-colour redundancy, one-hand anchors. |
| `resources/factions/*.tres`, resource/ammo/notoriety data | **Changed.** Gain an icon or label field for non-colour signalling. |
| `tests/test_accessibility_contrast.gd`, `test_accessibility_layout.gd`, `test_accessibility_redundancy.gd`, `test_reduced_motion.gd` | **New.** Flat under `tests/`. |

## 3. Palettes

`AccessibilityManager` holds the active palette and pushes it into the theme on change
(Requirement 1.6, immediate application). Palettes are `Resource` files — the `@export`s on the
palette script are the schema, per the D3/D14 silent-failure rule.

```gdscript
class_name PaletteData extends Resource
@export var faction_hostile: Color
@export var faction_neutral: Color
@export var faction_allied: Color
@export var resource_colors: Dictionary
@export var notoriety_bands: Array[Color]
@export var damage_states: Array[Color]
@export var region_locked: Color
# ... one entry per semantic role, never a raw named colour
```

**Roles, not colours.** The palette names *what a colour means*, never what it looks like. A
palette entry called `danger_red` is useless to a protanope; `faction_hostile` swaps correctly.

**Hazard: `KenneyMaterialApplier`.** It already handles tinting and theme override (D23/D24) and
is a second place colour is decided. Confirm during Task 2 whether any of its tints carry
*meaning* (as opposed to being decorative material colour). Decorative tints stay put; meaningful
ones move into the palette.

## 4. Non-colour redundancy

The `docs/18_ACCESSIBILITY.md` §2 table, with the concrete integration point for each:

| State | Add | Where |
|---|---|---|
| Faction relations | Icon + word (Hostile / Neutral / Allied) | `FactionData` gains an icon field; every consumer reads it |
| Resource bar | Distinct icon **silhouettes**, not tinted copies of one shape | Resource icon set |
| Notoriety band | Label + discrete tick position | `WorldHUD` notoriety widget |
| Ship damage state | HUD readout + silhouette change | `ShipVisuals` already changes smoke and list; add the readout |
| Region gating | Lock icon + text requirement | World map UI (M10) |
| Ammunition type | Distinct icon shape | Combat HUD |

**Silhouette, not tint, is the requirement for the resource bar.** Five icons of the same shape in
five colours is precisely the failure this milestone exists to fix, and it is an easy thing to
ship by accident.

## 5. Text scale and reflow

`AccessibilityManager` sets a global scale that the theme's font sizes derive from. The work is
not the scaling — it is the reflow.

**Every panel must size from anchors and containers, never fixed pixels.** V17 (`IslandMenu`'s
hardcoded 600×400) is the known instance; Task 8's sweep finds the rest. A panel with a fixed
`custom_minimum_size` and a fixed font clips at 200% and the clipping is invisible at 100%, which
is why `test_accessibility_layout.gd` renders at 200% rather than trusting inspection.

Requirement 2.5 (no text baked into textures) also serves M12 localization — a texture with
English text cannot be translated either.

## 6. Reduced motion

```gdscript
# CameraRig — presentation only
if AccessibilityManager.reduced_motion:
    sway_amplitude   *= REDUCED_SWAY_FACTOR
    pitch_follow_gain *= REDUCED_PITCH_FACTOR
    shake_amplitude   = 0.0
```

**What must NOT change:** wave amplitude in the simulation, buoyancy sampling, ship handling, or
any value the physics reads. `test_reduced_motion.gd` asserts that ship position and velocity over
a fixed input sequence are byte-identical with reduced motion on and off. That test is the
guarantee Requirement 3.3 makes real.

The 3 Hz flash limit (Requirement 3.4) applies in **all** modes, not only reduced motion — it is a
photosensitivity safety floor, not a preference. Audit particle effects, the raid alarm, and any
damage-flash for it.

## 7. Captions

A global `CaptionLayer`, so captions do not need re-implementing per screen. Two sources:

- **Dialogue** — routed from the existing dialogue panel.
- **Non-speech events** (Requirement 4.2) — connected to existing signals: cannon fire (with
  direction), boarding started, raid alarm, building complete. No new event plumbing; these
  already emit.

The scrim matters. White text over a bright ocean is unreadable, and this game's background is
literally moving water.

Requirement 4.3 — playable with sound off — should be asserted by a test that enumerates
information channels and confirms none is audio-only. In practice the game is already close; the
directional cannon-fire cue is the likely gap.

## 8. One-handed mode

An alternate anchor set moving primary actions into the lower third. Implemented as a layout
variant on existing scenes, not as duplicate scenes — duplicating every screen would double the
maintenance surface and is the kind of thing `AGENTS.md` forbids.

Not every screen needs a variant. Screens whose actions already sit low are compliant as-is; Task
14 identifies which actually need work rather than mechanically re-anchoring all thirteen.

## 9. Test strategy

Requirement 7.2 is the important half: these run against **every** screen.

| Test | Asserts | Checklist item |
|---|---|---|
| `test_accessibility_contrast.gd` | Every theme colour pair meets 4.5:1 / 3:1, in both themes × all four palettes | 1 |
| `test_accessibility_redundancy.gd` | Every state in the §4 table has a non-colour signal present | 2 |
| `test_accessibility_layout.gd` | No fixed-pixel panel sizing; 48dp targets with 8dp separation; no clipping or overlap when rendered at 200% | 4, 5 |
| `test_reduced_motion.gd` | Ship physics byte-identical with reduced motion on and off | 10 + Req 3.3 |

Extends `tests/test_world_hud_layout.gd`'s existing approach rather than inventing a new one.

## 10. What cannot be verified headlessly

Per `CLAUDE.md`, stated rather than glossed:

**Testable in GUT:** contrast ratios, redundancy presence, layout and touch-target geometry at all
text scales, reduced-motion physics equivalence, gamepad navigability of menus.

**Requires a headful pass:** whether the ocean scrim actually makes captions readable, whether a
palette genuinely helps a colourblind player (ideally tested with a simulator, better with a real
person), one-handed reach on a physical large phone, and the 3 Hz flash audit. Checklist items 6,
7, 10 and 11 are in this category — Requirement 7.3 requires reporting them as unverified rather
than claiming them.
