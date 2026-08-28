# 18_ACCESSIBILITY.md

> Version: 1.0
> Status: Living Document — accessibility standards and the per-screen conformance checklist
> Owner: Project Lead
> Created: 2026-08-27
>
> **Why this document exists.** A gap audit on 2026-08-27 found that accessibility had **zero
> coverage anywhere in the roadmap** — not in `docs/14_SYSTEM_INVENTORY.md`, not in any
> `.kiro/specs/` milestone from M9 through M15. That is a real hole: it excludes players, and
> accessibility is a Google Play quality-listing factor that affects store placement.
>
> This document defines the standard. Milestone **M19** implements it. Every UI screen built
> from now on — including the M9 presentation pass and everything after — must pass §6.

---

# 1. Scope and posture

This is a **mobile-first, touch-first, single-player strategy game** with a 3D world, a heavy UI
layer (13+ screens), and text-driven narrative. That shape determines what matters:

- **Colour** carries a great deal of meaning here — faction colours, resource icons, notoriety
  bands, damage states, region gating. This is the single highest-value area.
- **Text** is dense (island menus, tech tree, captain rosters, dialogue) and currently fixed-size.
- **Motion** is constant — ocean waves, buoyancy, camera sway. This is a nausea risk.
- **Reach** matters — a large phone held one-handed cannot comfortably reach a top-corner button.

Out of scope, and deliberately so: screen-reader narration of the 3D world, and full WCAG AA
certification. The target is **substantive, testable accessibility for the barriers this game
actually creates**, not a compliance badge.

---

# 2. Colour and contrast

**Standard**

- All text meets a contrast ratio of **at least 4.5:1** against its background; large text
  (18pt+ or 14pt bold) at least **3:1**.
- **No information is ever conveyed by colour alone.** Every colour-coded state also carries a
  shape, an icon, a label, or a pattern.
- Three colourblind-safe palette variants ship as a setting: **Deuteranopia, Protanopia,
  Tritanopia**, alongside Default.

**What this concretely requires in this codebase**

| Element | Current signal | Must also gain |
|---|---|---|
| Faction relations | Colour | An icon or word (Hostile / Neutral / Allied) |
| Resource bar | Coloured icons | Distinct icon silhouettes, not just tint |
| Notoriety band | Colour | A label and a discrete tick position |
| Ship damage state | Red tint / smoke | Damage state readable by silhouette change and a HUD readout |
| Region gating | Colour on world map | A lock icon and a text requirement |
| Ammunition type | Colour | Distinct icon shape |

The existing theming work from M9 is the right place to hang this: palettes belong in the theme
resources, not sprinkled through scripts, consistent with `AGENTS.md` (no hardcoded values).

---

# 3. Text and readability

- **Text scaling** at 100% / 125% / 150% / 200%, as a setting.
- Every panel must **reflow or scroll** at 200% rather than clip. The M9 responsive-sizing work
  (V17, the hardcoded 600×400 `IslandMenu` panel) is the precedent — the same treatment applies
  everywhere.
- Minimum body text size of **16sp equivalent** at 100% scale.
- A **dyslexia-friendly font** option (e.g. an OpenDyslexic-class face) selectable in settings.
- No critical information in text baked into a texture — it cannot scale or localize (this also
  serves the M12 localization work).

---

# 4. Motion, audio and input

**Motion**

- A **reduced-motion** toggle that: damps camera sway and buoyancy-driven camera pitch, reduces
  wave amplitude in the *presentation* layer only, removes screen shake, and shortens or removes
  UI transition animations.
- Reduced motion must **never** change gameplay values — it is a rendering and camera setting.
  Wave physics that affects the ship stays; the camera's reaction to it is what is damped.
- No flashing above **3 Hz** anywhere (photosensitivity).

**Audio**

- **Subtitles and captions for all dialogue**, on by default, with adjustable size and a
  background scrim for legibility over the ocean.
- **Captions for meaningful non-speech audio** — cannon fire direction, incoming boarding, raid
  alarm, building complete. A player with sound off must not lose information.
- Independent Music / SFX / Voice volume sliders (`AudioManager` already has the bus structure;
  M11 authors the content).
- The game must be **fully playable with sound off**. This is already nearly true and should be
  asserted by a test.

**Input and reach**

- **One-handed mode**: a layout variant that moves primary actions into the lower third and
  within thumb reach.
- **Hold-versus-tap** option for any action currently requiring a sustained hold.
- **Minimum touch target of 48×48 dp**, with at least 8 dp between adjacent targets.
- No action may require a multi-touch gesture without a single-touch alternative.
- Full gamepad and keyboard navigation of every menu (input rebinding already exists — D57/M7).

---

# 5. Settings surface

All of the above is exposed in a dedicated **Accessibility** section of `SettingsMenu`, not
scattered across other tabs. Every option persists through `SettingsManager` using its existing
save convention, and applies immediately without a restart.

Accessibility settings are **account-level, not save-level** — the same reasoning as
entitlements in `docs/17_MONETIZATION.md` §4.1. A player who needs large text needs it on a new
game too.

---

# 6. The per-screen conformance checklist

**Every new or modified UI screen must pass all twelve before its task is marked complete.**

1. All text meets 4.5:1 contrast (3:1 for large text) in **both** light and dark themes.
2. No state is distinguishable by colour alone.
3. The screen renders correctly in all three colourblind palettes.
4. The screen reflows or scrolls without clipping at 200% text scale.
5. All touch targets are at least 48×48 dp with 8 dp separation.
6. Every primary action is reachable one-handed in one-handed mode.
7. All dialogue and meaningful non-speech audio is captioned.
8. The screen is fully operable with sound off.
9. The screen is fully navigable by gamepad and by keyboard.
10. Reduced-motion mode removes shake and shortens transitions on this screen.
11. Nothing flashes above 3 Hz.
12. No text is baked into a texture.

Items 1–5 and 9 are mechanically checkable and should become GUT tests in M19 so they cannot
silently regress. Items 6, 7, 10 and 11 require a headful visual pass — and per `CLAUDE.md`,
that **cannot** be verified in the headless environment and must be reported as unverified
rather than claimed.

---

# 7. Sequencing note

M19 is where this is implemented in bulk. But the checklist in §6 applies from the moment this
document exists — retrofitting accessibility across a UI layer that has grown for three more
milestones is dramatically more expensive than building it in.

**If the M13 launch date has any slack, M19 should be pulled forward ahead of M13.** Shipping
the store listing with accessibility features already in place is worth more than shipping them
in an update.
