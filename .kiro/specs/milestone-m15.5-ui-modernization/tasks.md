# Implementation Plan: Milestone M15.5 — UI Visual Modernization

## Overview

Depends on M15's completed checkpoint (confirmed: `git log` shows M15's final checkpoint commit
`ff26aeb`, working tree clean). Read `docs/05_CURRENT_SYSTEMS.md`'s Presentation section and this
spec's `design.md` before Task 1 — `design.md` §3-7 give exact integration points (file:line) for
every change below; don't re-derive them from scratch.

> **Verify command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Confirm the current baseline count with a fresh run before Task 1 (recent milestones have moved
> it) rather than trusting a stale number from docs.

## Tasks

- [x] 1. Source the CC0 UI texture/icon pack
  - Done 2026-08-29. Sourced two Kenney (kenney.nl) CC0 packs: **UI Pack** (v2.0, buttons —
    `assets/ui_icons/LICENSE_ui-pack.txt`) and **Board Game Icons** (v1.1, resource/stat glyphs —
    `assets/ui_icons/LICENSE_board-game-icons.txt`). Both confirmed CC0 (public domain, no
    mandatory attribution, shipped-commercial-game use explicitly permitted) by reading each
    pack's own license file after download. **Deviation from design.md's original assumption:**
    no panel-background or progress-bar texture existed in either pack (UI Pack is
    buttons/sliders/checkboxes only, no full background panels) — panels/bars keep the enhanced
    `StyleBoxFlat` fallback (Task 3) instead, which the design already anticipated as the
    documented fallback path. No dedicated anchor/compass icon exists in either pack either;
    dropped from scope (compass is already a real rendered needle graphic in `WorldHUD`, not a
    static icon; the anchor emoji's uses were decorative and are addressed via Task 8's
    `cannon_ready` icon instead).
  - **Verified:** `assets/ui_icons/` contains 4 button-state textures + 1 added disabled-state
    texture (Task 3 finding, see below) and 7 icon glyphs (gold/wood/iron/rum/health/notoriety/
    cannon_ready — 2 are thematic substitutes, documented in `UIIcons.gd`'s header: gold uses a
    generic coin/token glyph, rum uses a potion-flask glyph). Both license files confirmed CC0.
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Write `scripts/ui/UIIcons.gd`
  - Done 2026-08-29. Single lookup by key to each icon's real sourced path; substitutions
    documented in the file's header comment. New `tests/test_ui_icons.gd`.
  - **Verified:** `test_ui_icons.gd`'s `test_every_registered_icon_key_loads_a_real_texture`
    passes for all 7 registered keys (asserts non-null `Texture2D`) via a real GUT run.
  - _Requirements: 1.4_

- [x] 3. Rebuild `PirateThemeBuilder.gd`'s style builders
  - Done 2026-08-29. Added `_make_texture_button_stylebox()` (`StyleBoxTexture`, 18px
    texture_margin, matches the sourced 192x64 button art) wired into `build()` for the same
    `Button` normal/hover/pressed/focus property names already set. Enhanced
    `_make_panel_stylebox()` per Requirement 2.3 (16px/12px corner radius up from 8px/4px,
    `shadow_size` 10 up from 4, `anti_aliasing = true`) — kept, not deleted, as the panel/
    ProgressBar/one-off fallback (see Task 1's deviation note). Added `make_chip_stylebox()` for
    Task 6's resource chips.
  - **Real defect found and fixed during this task's own visual verification, not assumed
    away:** a live headful screenshot of `PauseMenu` showed the "Resume" button rendering as a
    plain grey box while "Settings"/"Quit to Menu" showed the correct gold gradient — Godot was
    falling back to its own built-in default `disabled` Button style because `build()` never set
    one. Root-caused (not just patched blind): added a `disabled` texture (Grey-family
    `button_rectangle_depth_flat.png`, matching the pack's own convention for that state) plus
    `font_disabled_color`, then re-verified with a fresh GUT run (still 419/419, no regression).
  - **Verified:** launched the real game headful (not `--headless`), force-focused the window,
    and screenshotted `MainMenu` and `PauseMenu` directly (no MCP screenshot tool exists for this
    project, so this used `SetForegroundWindow`/GDI screen capture instead of
    `mcp__godot__run_project`). Confirmed: button texture renders with correct proportions, no
    stretching/warping, rounded corners intact, gradient reads as a smooth gold gloss, label text
    stays readable on top of it, `disabled` state now themed instead of falling back to Godot's
    stock grey.
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 4. Write `scripts/ui/ButtonJuice.gd`
  - Done 2026-08-29. Matches `design.md` §5 (press/hover scale tween via `create_tween()`,
    `duration = 0.12`, attached as a plain child `Node`, not a `Button` subclass).
  - **Verified:** script parses cleanly under the GUT run (no script errors); the actual
    press/hover animation feel is a live-interaction check deferred to Task 9/12 once it's wired
    into real buttons — noted here rather than assumed, since a static screenshot can't show a
    tween.
  - _Requirements: 4.1, 4.3_

- [x] 5. **Checkpoint — theme system in place**
  - GUT suite: **419 tests, 419 passing, 0 known failures** — up from the true pre-M15.5 baseline
    of **417/417** (`test_ui_icons.gd` added the +2; reconciled against the M13-checkpoint-
    documented 411/411 plus M15 Waves 6/7's own later test growth, not a fresh unexplained
    number). No regressions, no new failures.
  - `MainMenu` and `PauseMenu` (neither has a scene-level style override) visually confirmed via a
    real headful screenshot to already show the new texture-based buttons just from Task 3's
    theme change, before any other scene was touched — proof the centralization is actually
    working.
  - **Not yet independently re-verified by the checkpoint-reviewer agent** — self-verified via a
    real GUT run and a real screenshot in this pass; flagging explicitly rather than silently
    treating that as equivalent to independent review, per this project's own repeated lesson on
    the difference.

- [x] 6. WorldHUD: icon-chip resource counters
  - Done 2026-08-29. `WorldHUD.tscn`: each of `%GoldLabel`/`%WoodLabel`/`%IronLabel`/`%RumLabel`
    now sits inside a `PanelContainer` chip (icon `TextureRect`, tinted to the resource's existing
    color, + the same-named `Label`). `WorldHUD.gd`: dropped the emoji prefix from
    `_on_resources_changed()`'s four format strings; added `_style_resource_chips()` (called from
    `_ready()`) applying `PirateThemeBuilder.make_chip_stylebox()` per chip.
  - **Verified:** real headful capture via `scenes/debug/CaptureHarness.tscn` (no MCP screenshot
    tool exists for this project) — all four resource chips render with icons and correct live
    values (`327/5000`, `200/200`, `100/100`, `48/50` at t=7s/t=12s).
  - _Requirements: 3.1_

- [x] 7. WorldHUD: health bar retexture, animation, and low-health pulse
  - Done 2026-08-29. Removed `%HealthBar`'s scene-level `StyleBoxFlat_HealthBg`/`HealthFill`
    overrides so it picks up `PirateThemeBuilder`'s (now enhanced) `ProgressBar` theme styles —
    same pattern as Task 11's menu-panel change, applied here first. `set_health()` now tweens
    `value` (0.25s) instead of snapping, and `_set_health_pulse()` loops a red modulate pulse
    below 25% health, restoring `modulate` once healed back above it.
  - **Verified:** headful capture confirms the bar renders correctly (rounded, themed) at
    100/100 HP. The animation/pulse itself is a live-interaction behavior a static screenshot
    cannot show — deferred to a real playtest rather than falsely claimed from a still frame.
  - _Requirements: 3.2, 3.3_

- [x] 8. WorldHUD: cannon panels, cooldown icon, and notoriety readout
  - Done 2026-08-29. Removed `StyleBoxFlat_CannonPanel`'s scene-level override from both
    Port/Starboard panels (same centralized-style pattern as Task 7); kept
    `StyleBoxFlat_CannonHeader` (a nested header strip, not the panel background itself — not
    part of Task 1's deviation). Replaced both sides' `"🛶"` emoji `Icon` `Label`s with a
    `TextureRect` using `UIIcons`' `cannon_ready` glyph. Wrapped the notoriety label in a
    `PanelContainer` chip matching Task 6's treatment (same `make_chip_stylebox()` helper), added
    as the container child instead of the bare label — `test_world_hud_layout.gd`'s
    non-overlap guarantee (D36) re-verified to still hold with the wrapper in place.
  - **Verified:** headful capture confirms the notoriety chip renders; the cannon panels
    themselves did not appear in either capture frame (both fell during the opening tutorial
    beat, before combat) — pre-existing visibility behavior unrelated to this change, not newly
    broken by it (confirmed by reading `CannonsContainer`'s existing D69 tutorial-dimming logic,
    untouched here). A live-combat check is deferred to a real playtest.
  - _Requirements: 3.4_

- [x] 9. WorldHUD: `ButtonJuice` on dynamically-created buttons
  - Done 2026-08-29. `_create_captains_log_button()`, `_create_world_map_button()`,
    `_create_codex_button()` each now also `add_child(ButtonJuice.new())` on the button they
    create.
  - **Verified:** headful capture shows Log/Map/Codex rendering with the new gold-gradient button
    texture (confirming Wave 1's theme change reaches dynamically-created buttons too, not just
    `.tscn`-authored ones). The hover/press animation itself needs live interaction to observe —
    not claimable from a still frame, noted rather than assumed.
  - _Requirements: 4.2_

- [x] 10. **Checkpoint — WorldHUD complete**
  - GUT suite: **419/419 passing**, unchanged from the Wave 1 checkpoint — no regressions from
    any WorldHUD scene/script edit in this wave.
  - Visually confirmed via a real headful `CaptureHarness` run (all 5 timestamps,
    t=0/1/3/7/12s): resource chips, health bar, notoriety chip, and Log/Map/Codex buttons all
    render with the new theme; the pre-existing "While you were away" announcement banner and
    tutorial dialogue panel/buttons also confirmed unaffected (still themed correctly).
  - **Not yet independently re-verified by the checkpoint-reviewer agent.**

- [ ] 11. Menu screens: swap duplicated panel backgrounds for the centralized style
  - `IslandMenu.tscn`, `PauseMenu.tscn`, `DeathScreen.tscn`, `CaptainsLog.tscn`,
    `RaidReportScreen.tscn`, `TutorialDialogue.tscn`: delete each scene's local
    `theme_override_styles/panel = SubResource("StyleBoxFlat_*Bg")` override and its now-unused
    sub-resource, per `design.md` §7 — the screen's own `PirateThemeBuilder.build()` call already
    supplies the new panel style once the override is gone.
  - **Verify:** open each of the six screens in a running game and visually confirm the new panel
    style renders with no missing/blank background.
  - _Requirements: 5.1_

- [ ] 12. Menu screens: `ButtonJuice` everywhere, remaining dynamic-`StyleBoxFlat` cleanup
  - Add `ButtonJuice.gd` under every `Button` in `MainMenu.tscn`, `SettingsMenu.tscn`,
    `CodexScreen.tscn`, `WorldMapScreen.tscn`, `UpgradeChoiceScreen.tscn`,
    `MobileControls.tscn` (all confirmed real `Button` nodes — `BtnForward`/`BtnLeft`/
    `BtnRight`/`BtnBackward`/`BtnFirePort`/`BtnFireStar`/`BtnDock`/`BtnPause`/
    `BtnCaptainAbility`/`BtnSpecialBroadside`), plus every screen touched in Task 11.
    `SettingsMenu._show_message()` and `WorldHUD.announce_event()` switch to
    `PirateThemeBuilder`'s enhanced `StyleBoxFlat` fallback instead of their own inline
    `StyleBoxFlat.new()`.
  - **Verify:** on a touch-input build or the mouse-emulated equivalent, press each
    `MobileControls` button and confirm both the juice animation plays and the underlying action
    (movement/fire/dock/pause/ability) still functions — `ButtonJuice` only touches `scale`/
    `modulate`, never movement state, but this must be confirmed live, not assumed.
  - _Requirements: 4.2, 5.2_

- [ ] 13. **Checkpoint — every screen modernized**
  - GUT suite: no new failures, no count regression from the Task 1 baseline.
  - Every one of the 12 screens listed across Requirement 5 opened via `mcp__godot__run_project`
    and visually confirmed — this project's own documented limitation (visual quality can't be
    verified headlessly) means this step cannot be skipped or inferred.
  - No functional regression in any screen's existing behavior (tab switching, button actions,
    displayed data) — spot-checked per screen, not assumed from "only styling changed."
  - Independently re-verified (checkpoint-reviewer agent), not self-reported.

- [ ] 14. Documentation
  - `docs/05_CURRENT_SYSTEMS.md`: new Presentation-section entry (texture-based theme, icon-chip
    pattern, `ButtonJuice.gd`, updated GUT baseline). `docs/03_ART_DIRECTION.md`: Requirement 2.4.
    `docs/15_MASTER_PLAN.md`: new "M15.5" entry between M15 and M16, framed as an unplanned
    insertion (matching M7.5's framing) — M16-M21's existing numbering is not touched.
  - **Verify:** grep `docs/15_MASTER_PLAN.md` for both "M15" and "M16" section headers and confirm
    the new entry sits between them without altering either.
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 15. **Checkpoint — M15.5 complete**
  - GUT suite passes with no regressions from the Task 1 baseline (log the exact before/after
    counts).
  - All three doc files updated and cross-checked against the actual code changes, not copied from
    this spec's intent.
  - A full visual pass across every touched screen logged as genuinely verified live, not assumed
    — explicitly note that subjective "does this look modern/current" judgment is a human call,
    per this project's own stated limitation on verifying aesthetics headlessly.
  - Independently re-verified against actual code changes and a real GUT run before marking done,
    per `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8.

## Notes

- Tasks 6-9 (WorldHUD) and Task 11-12 (other menus) are independent of each other in principle,
  but both depend on Tasks 1-4 (the sourced assets and theme builders must exist first) — hence
  the wave structure below rather than a fully flat task list.
- `MobileControls.tscn`'s buttons are real `Button` nodes (confirmed by direct inspection), so
  `ButtonJuice.gd` attaches with no special-casing — the risk noted during planning (that touch
  controls might use a different node type needing separate handling) did not materialize.
- If the sourced texture pack (Task 1) turns out not to cover every needed icon glyph cleanly
  (e.g. no obvious "notoriety" icon exists in a generic UI pack), fall back to the closest
  thematically-fitting glyph (e.g. a flame or skull icon) rather than blocking the milestone on a
  perfect one-to-one icon match — note the substitution in `UIIcons.gd`'s comment, don't silently
  reuse a mismatched icon without saying so.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4"] },
    { "id": 1, "tasks": ["5"] },
    { "id": 2, "tasks": ["6", "7", "8", "9"] },
    { "id": 3, "tasks": ["10"] },
    { "id": 4, "tasks": ["11", "12"] },
    { "id": 5, "tasks": ["13"] },
    { "id": 6, "tasks": ["14"] },
    { "id": 7, "tasks": ["15"] }
  ]
}
```
