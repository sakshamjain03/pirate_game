# Design Document: Milestone M22 — UI Visual Overhaul

Visual source of truth: `claude design outputs/Pirate Empire UI System v0.3.html` (bundled) /
`…/Pirate Empire UI System.zip → Pirate Empire UI System v0.3.dc.html` (readable source — strip
`data:` URIs before grepping). Sections: *Screens* 01–06, *Settings* 07a–e, *Gameplay Moments*
08–15, *Component Sheet* (tokens, buttons, frames, icons, type, controls, celebration scale,
Godot build notes). Open it in a browser next to every screen being restyled.

## 1. Why this design shape

**Change the existing theme pipeline in place; add no parallel UI system** (AGENTS.md "never
duplicate systems"). Everything already routes through one choke point — ~30 screens call
`PirateThemeBuilder.build()`, all buttons get `apply_button_juice()`, all icons come from
`UIIcons.get_icon()`. M15.5 proved that choke point works: its button reskin reached every screen
with zero per-screen edits. M22 does the same, in three layers:

1. **Tokens** (`UIPalette` resource + `UITokens.gd`) — the only place a UI colour/size/timing lives.
2. **Kit** (generated SVG textures) + **theme** (`PirateThemeBuilder.build()` rebuilt on the kit,
   with named type variations) — makes most screens look new without touching them.
3. **Per-screen passes** — remove `theme_override_*`/`add_theme_*` one-offs (186 + 186 today),
   assign type variations, fix layout to the landscape v0.3 composition.

Layer 2 changes the most pixels for the least risk, so it lands first and is verified on a
kit-sheet scene before any real screen is touched.

## 2. New/changed files

| File | Change |
|------|--------|
| `resources/ui/palette_default.tres` + `scripts/ui/UIPalette.gd` | **New.** `Resource` with `@export` colour tokens (§4). |
| `scripts/ui/UITokens.gd` | **New.** Const type scale / radii / motion timings in Godot px; `palette()` accessor. |
| `assets/fonts/GermaniaOne-Regular.ttf`, `Baloo2[wght].ttf`, `OFL-*.txt` | **New.** |
| `tools/ui_kit/gen_kit.py` | **New.** Deterministic (seeded) SVG generator for the kit (§6). |
| `assets/ui/kit/*.svg` (+ Godot `.import`) | **New.** Generated kit textures. |
| `assets/ui/icons/research.svg`, `assets/ui/icons/cannonball.svg` | **New.** The only two icons genuinely missing from `UIIcons` (§6a). |
| `scripts/ui/PirateThemeBuilder.gd` | **Rebuilt** `build()` on kit + variations; scale model re-derived (§3); `mark_primary()`. |
| `scripts/ui/ButtonJuice.gd` | Scale tween → modulate press (§7). |
| `scripts/ui/PrimaryGlow.gd` | **New.** Behind-parent looping glow (§7). |
| `scripts/ui/SafeAreaMargin.gd` | **New.** `MarginContainer` applying 48dp sides + display safe area. |
| `scripts/ui/UIIcons.gd` | New keys (research, cannonball, action_*, nav_*, fire_*, gear…). |
| `scripts/ui/UIMotion.gd`, `scripts/ui/CelebrationQueue.gd` | **New** (Phase 7). |
| `scripts/debug/FontOverflowAudit.gd` → `scripts/debug/UIScreenSweep.gd` (+ scene) | Promoted to permanent; `--profile=phone|tablet|desktop` (§8). |
| `scenes/debug/UIKitSheet.tscn` | **New.** Renders every kit piece + variation. |
| `project.godot` | Base 1688×780, handheld orientation sensor landscape. |
| `scripts/managers/SettingsManager.gd` | `ui_font` Default → Baloo 2 (value 0 unchanged); HUD-layout migration (§9). |
| `scenes/ui/*.tscn`, `scripts/ui/*.gd` | Per-screen passes (Phases 4–6). |

## 3. Scale model (the most consequential change)

**Units.** v0.3 is authored at 1× on an 844×390 landscape phone — i.e. design px ≈ dp (a
2340×1080 phone at ~2.77 density is 845×390 dp). New Godot base is 1688×780, so
**canvas px = design px × 2** and every number in `UITokens` is design px × 2.

**Why today's UI is tiny.** Base 1920×1080 on a 2340×1080 phone is 1 canvas px ≈ 1 physical px.
`MOBILE_MIN_TOUCH_TARGET = 72` canvas px is 72 phys px ≈ **26 dp** (48 dp needed), and 15 px
body × `MOBILE_FONT_SCALE` 1.45 ≈ 22 phys px ≈ **8 dp** text. The scale multipliers were
compensating for a base resolution that doesn't match phone dp.

**New model.** With the 780-high base, `canvas_items` + `expand` gives phone ≈1.385 phys px per
canvas px, so design sizes land at their intended dp with **no multiplier**:

| Constant | Old | New | Why |
|---|---|---|---|
| `MOBILE_CONTROL_SCALE` / `MOBILE_FONT_SCALE` | 1.5 / 1.45 | 1.0 / 1.0 | base now matches dp |
| `TABLET_CONTROL_SCALE` / `TABLET_FONT_SCALE` | 1.15 / 1.6 | 1.0 / 1.1 | tablet: slightly larger text only |
| `MOBILE_MIN_TOUCH_TARGET` | 72×72 | 96×96 | 48 dp × 2 |
| `TABLET_MIN_TOUCH_TARGET` | 56×56 | 96×96 | a finger isn't bigger on a tablet |

Keep `control_scale()`/`font_scale()`/`scaled_*`/`apply_mobile_control_scaling()` as the API (call
sites stay valid; values become ~identity). Desktop uses the same layout scaled by the stretch mode;
if desktop looks oversized, tune a desktop factor in `control_scale()` in Phase 9, not per screen.

**Latent unit bug surfaced by this change:** `MobileLayoutManager.safe_area()` intersects
`DisplayServer.get_display_safe_area()` (physical **screen** px) with
`viewport.get_visible_rect()` (**canvas** px). Today these agree only by coincidence (1080-high
base on a 1080-high phone → 1:1). At a 780-high base they differ by ~1.385×, so the safe area,
`mobile_scale()` (`REFERENCE_LANDSCAPE = 2340×1080`, also physical) and `mobile_dialog_size()`
all go wrong. Fix it in `safe_area()` itself: map the native rect through
`viewport.get_final_transform().affine_inverse()` (screen → canvas) before intersecting. Re-base
`REFERENCE_LANDSCAPE` to the canvas base 1688×780. `SafeAreaMargin` **consumes**
`MobileLayoutManager.safe_area()` and does not re-implement it.

**Hazard:** every hardcoded pixel literal in scripts (e.g. `SettingsMenu.gd:229-236` sets
`custom_minimum_size`, `back_button.position` from `viewport_size`) was tuned for 1080-high
canvas. After Phase 1 the full screen sweep (§8) must be run and viewed; anything broken is fixed
in container layout (CLAUDE.md fragile area), not by retuning literals.

## 4. Palette resource

```gdscript
# scripts/ui/UIPalette.gd
class_name UIPalette extends Resource
@export var ocean_deep := Color("#0A2C33")
@export var sunset_teal := Color("#1F6F76")
@export var shallows := Color("#3A9A97")
@export var horizon_gold := Color("#F4C96E")
@export var driftwood := Color("#6D452A")
@export var wood_dark := Color("#2E1A0C")
@export var brass := Color("#C29444")
@export var brass_light := Color("#F7DE98")
@export var parchment := Color("#ECD6A4")
@export var ink := Color("#3A2616")
@export var coral := Color("#F0602A")        # Primary CTA + Legendary ONLY
@export var coral_bloom := Color("#FFD6AE")
@export var brick := Color("#A8392B")        # destructive; never coral
@export var text_on_dark := Color("#F7DFA6")
@export var text_on_parchment := Color("#3A2616")
@export var hp_good := Color("#3FBF8F")
@export var hp_low := Color("#D6453A")
@export var rarity := {"common": Color("#EDE6D6"), "uncommon": Color("#3FBF8F"),
	"rare": Color("#2F6FD6"), "epic": Color("#7B3FC4"), "legendary": Color("#FF8A3D")}
```

`UITokens.palette()` loads and caches `res://resources/ui/palette_default.tres`, and **push_errors**
if the file is missing, falling back to `UIPalette.new()`. M19 later swaps which `.tres` is loaded.
`PirateThemeBuilder.COLOR_*` become `static var` getters or are replaced at call sites. They are
`const` today, so dependent code (`SettingsMenu.gd:227` uses `COLOR_GOLD_BRIGHT`) must be migrated
in the same task. `grep -rn "PirateThemeBuilder.COLOR_" scripts` gives the full list.

## 5. Typography

- Germania One (static TTF) → `display_font`. Baloo 2 is a variable font, so build
  `FontVariation`s with `variation_opentype = {"wght": 600/700/800}` → `body_font` (600),
  `num_font` (800).
- Label variations (sizes in canvas px = design × 2): `DisplayLabel` 88 · `TitleLabel` 56 ·
  `HudNumLabel` 36 · `BodyLabel` 32 · `ChipLabel` 24. Default `Label` = BodyLabel.
  Display/Title/Button use `display_font` with `shadow_offset_y = 4` (2 design px) in `ink`, plus
  `outline_size` 4 in `ink` so text survives busy art.
- `SettingsManager.ui_font`: value 0 now means Baloo 2 (was Cinzel). It only swaps the **body**
  font, as today. Display font is always Germania One. Update the Settings option label text to
  match, and keep values 1/2. Cinzel files stay until Phase 9's unused-asset cleanup.
- Source the fonts from `github.com/google/fonts` (`ofl/germaniaone/`, `ofl/baloo2/`), both OFL 1.1.

## 5a. Correction (found starting Phase 2): `claude design outputs/` has no new art

The original plan assumed `claude design outputs/` held delivered v0.3-styled icon/button art
to move into the project. Verified false by hashing every file there against the whole `assets/`
tree: **every file except `higgins.png` (a captain portrait, out of scope — requirements.md Out of
Scope) is a byte-identical duplicate** of an asset already correctly placed under
`assets/icons/controls/`, `assets/icons/cosmetics/`, `assets/branding/`, `assets/ui_icons/` or
`assets/portraits/` — including the button/resource PNGs, which are the *current* (pre-M22, being
replaced) art, not new v0.3 art. The folder is reference/context material bundled alongside the
v0.3 HTML doc, not an asset delivery. **No file-moving happens in Phase 2.** The `action_*`/`nav_*`/
`fire_*` control icons are already wired (as direct `ext_resource`s in `MobileControls.tscn` and a
small local dict in `MobileControls.gd`) — left as-is; routing them through `UIIcons` too is a
nice-to-have, not required, and not done here to avoid an unnecessary risk-free-looking-but-
actually-two-integration-paths refactor mid-milestone. The only real gap against the v0.3 icon
list (gold, rum, wood, iron, research, cannonball) is the last two — `UIIcons` gets exactly those
two new keys (§6a), nothing else moves.

## 6. Texture kit pipeline

Godot 4.3 imports SVG natively (ThorVG). ThorVG supports paths, linear/radial gradients, opacity
and clip paths, but **not SVG filters** (`feTurbulence`, blur). So texture detail is made of
geometry:
- Parchment grain: a few hundred seeded short, low-alpha strokes. Burnt edge: radial/linear
  gradients to `ink` at 30–50% alpha. Deckle: irregular seeded outline path.
- Wood: plank rectangles with seeded grain curves in driftwood/wood_dark. Brass studs: radial
  gradient circles with a specular dot at 30%/30%.
- Buttons: body + 3 design-px dark-ink border + solid lip slab (6 idle / 2 pressed) baked in. The
  **pressed** SVG draws the body 4 design px lower, so the press offset is purely the state swap.

`tools/ui_kit/gen_kit.py` (stdlib only, fixed seed) writes every SVG. Commit both the generator
and its output, so the art can be edited either way. Import: SVG units = design px, import
`svg/scale = 2.0` → texture px = canvas px, so `StyleBoxTexture.texture_margin_*` equals the
canvas-px 9-slice margin (parchment 80, rope frame 24, plaque ends 64; button 36/28). After adding
files, run `<godot> --headless --import` once so `.import` files and `.godot/imported` exist
before GUT runs.

## 7. Buttons, press, glow

- Variations via `theme.set_type_variation("PrimaryButton", "Button")` and the same for
  `WoodRoundButton`. Default `Button` = brass. `OptionButton` reuses brass.
- `pressed` stylebox = pressed texture, with `content_margin_top` +8 and `content_margin_bottom` −8
  vs. normal, so the label drops 4 design px with the body. `hover` = normal texture at a lighter
  `modulate_color`. `focus` = a brass-light 4px outline StyleBoxFlat (keyboard/gamepad only).
- `ButtonJuice`: replace the 0.94/1.03 **scale** tween with `self_modulate` 1 → 0.88 over 60ms on
  `button_down`, back over 120ms with `TRANS_BACK` (slight overshoot) on `button_up`. Keep the node
  and its `apply_button_juice` sweep and haptic hookup unchanged.
- `PrimaryGlow extends TextureRect`: `show_behind_parent = true` (draws beneath its parent button
  with no sibling reshuffle), anchored ~12 design px outside the button, glow sprite, tween loop
  opacity .45↔1 / scale .96↔1.07, 2.2s sine; `pivot_offset` = centre.
- `PirateThemeBuilder.mark_primary(btn: Button)` sets the variation and adds one glow (idempotent).
  A GUT test sweeps each instantiated screen scene: at most one visible `PrimaryButton`.
- Cooldowns (Phase 5): `TextureProgressBar` with `fill_mode = FILL_CLOCKWISE` over the round
  button, using the ring-mask texture, instead of `disabled` grey-out.

## 8. Screen sweep (verification tool)

`FontOverflowAudit.gd`'s header says "TEMPORARY… delete once confirmed". M22 instead **promotes**
it to `scripts/debug/UIScreenSweep.gd` / `scenes/debug/UIScreenSweep.tscn`, because it is the
only thing that closes M15.5's "only MainMenu and PauseMenu were seen live" gap. It adds
`--profile=phone` (window 2340×1080, `force_mobile_scaling_for_test`), `tablet` (2048×1536) and
`desktop` (1920×1080). Output goes to `screenshots/m22/<phase>/<profile>/NN_<screen>.png`. It must
run headful. Screens it can't reach get added as each phase touches them.

**Known harness gap (found in the Phase 0 baseline run):** `--profile=phone` forces
`PirateThemeBuilder` scaling, but `MobileLayoutManager.is_mobile()` still reads
`OS.has_feature("pc")`. So on desktop the safe-area and dialog-sizing path and `MobileControls`
(which hides itself on PC) behave as desktop while fonts and controls scale as phone. The
baseline phone shots show the right-hand HUD column clipped and no touch controls, which the
real device (`screenshots/mobile/device_test/16_in_game.png`) does not. Phase 1.5 makes
`MobileLayoutManager.is_mobile()` honour the same test-force flag (one flag, read in both
places), so phone-profile sweeps match the device before any restyle is judged against them.

## 8a. MainMenu touch-target root cause (found in Phase 1.4)

`MainMenu.gd._apply_theme()` calls `PirateThemeBuilder.apply_button_juice(root_control)` (which
clamps every button to `MOBILE_MIN_TOUCH_TARGET`) and then unconditionally calls
`_apply_button_sizing()`, which overwrites `custom_minimum_size = MOBILE_BUTTON_MIN_SIZE` —
a local `Vector2(320, 64)` constant from M13, tuned under the old 1080-canvas/1080-phys
coincidence — on all six buttons, **undoing** the juice clamp (this runs unconditionally, not only
on mobile). That is why `test_touch_target_audit` already failed pre-M22 at the old 72px floor,
and will keep failing at the new 96px floor until Phase 4 either deletes `MOBILE_BUTTON_MIN_SIZE`
in favour of the (now-correct) `apply_button_juice()` clamp, or replaces it with the v0.3 button
composition (logo plaque + one Primary + brass secondaries) sized to meet the floor honestly.
`SettingsMenu.gd`'s `ReplayTutorialButton`/`BackButton` likely have an equivalent explicit
`custom_minimum_size` set after theming — check the same pattern there in Phase 4.

## 8b. `scaled_button_size()` — a second, wider instance of the same bug

Raising `MOBILE_MIN_TOUCH_TARGET` (Phase 1.4) exposed the same defect as §8a in
**eleven more** call sites across CaptainsLog, CreditsScreen, DeathScreen, IslandMenu,
PauseMenu, PurchaseSupportScreen, RaidReportScreen, StoreScreen, TutorialDialogue,
WardrobeScreen, WhatsNewScreen and WorldMapScreen: each screen's own post-theme
"resize for mobile" block calls `PirateThemeBuilder.scaled_size(...)` on a button
*after* `apply_button_juice()` already clamped it once, and nearly every literal
involved is a "48" base height — `48 * 1.5` (the old `MOBILE_CONTROL_SCALE`) is
exactly 72, the old floor, by design, not coincidence. That stopped holding the
moment the constant dropped to identity. Fixed at the root with one new function,
`PirateThemeBuilder.scaled_button_size(pc_size)` — `scaled_size()` plus a floor at
`MOBILE_MIN_TOUCH_TARGET`, mirroring `apply_button_juice()`'s own "one shared
mechanism, not N screens" precedent — swapped in at every confirmed **Button**
call site (panel/scroll_container/portrait_panel/row calls are untouched: they
aren't Buttons and `test_touch_target_audit` doesn't check them). Phases 4/6/etc.
should call `scaled_button_size()` for any new button-sizing code, not
`scaled_size()`.

## 9. Settings & HUD-layout specifics

- **Slider defect root cause (confirm in Phase 4):** the General tab's `GridContainer` content is
  wider than its ScrollContainer. `05_settings_general.png` shows a horizontal scrollbar and a
  right-clipped Replay Tutorial button, so Master (1.0) and SFX (0.9) grabbers sit off-screen and
  only Music (0.6) shows. Separately, the groove (`COLOR_SHADOW_DARK` fill with an
  `int(1.5)` = 1px border) is near-invisible on the navy panel. The fix is to constrain the
  content width (`SIZE_EXPAND_FILL` inside a width-bounded container, and disable horizontal
  scroll) **and** give the rope track real contrast. Confirm with the sweep, not by reasoning.
- Rows follow the v0.3 07a row anatomy: label (+ optional sub-caption) left, control right, value
  in Baloo 800 at the far right. Replace `back_button.position` absolute math with container layout.
- **HUD layout migration:** `HudCustomizeOverlay` stores per-control `position` deltas in unscaled
  canvas px (`HudCustomizeOverlay.gd:185-190`). Those were authored against the 1080-high base.
  `SettingsManager` load: if `hud_layout_version` is absent or < 2, multiply every stored
  `position` by 780/1080, keep `size` scale entries as ratios, set version 2, and `print` the
  migration. Scaling beats resetting: never silently discard player data (CLAUDE.md fragile area).

## 10. Motion & celebrations (Phases 7–8)

- `UIMotion` static helpers return the `Tween`, so callers can chain: `pop_in(c)` 450ms scale .6→1.06→1,
  `shine(c)` 400ms, `tick_number(label, from, to)`, `stamp(c)` (rotate −8°, scale 2.2→.92→1),
  `float_up(c)`, `typewrite(label, cps := 30)`. Each checks `UIMotion.reduced_motion()`, which
  returns `bool(SettingsManager.get("reduce_motion"))` if that property exists, else `false`. That
  is the single hook M19 wires later. Enforce no flashing above 3 Hz.
- `CelebrationQueue` (plain `Node`, owned by `WorldHUD`, not an autoload): `play(tier, scene)`.
  Small plays immediately. Medium plays over the live scene. Large enqueues while one is active
  and dequeues on the prior CTA's `pressed`.
- **Signals must be verified at Phase 8 start** (grep; don't trust this list): `ShipCombat.died`
  (sunk stamp), `EmpireManager.notoriety_changed` (escalation at band crossings), raid resolution
  → `RaidReportScreen` (victory), player death → `DeathScreen` (defeat), island tier / building
  upgrade signal on `Island.gd`, ship upgrade purchase in `IslandMenu`, loot pickup. If a moment has
  no signal, add a signal on the owning system; never call UI from gameplay code.

## 11. Known hazards

- **Layout tests** (`test_world_hud_layout`, `test_island_menu_layout`, `test_captains_log_layout`,
  `test_whats_new_screen_layout`, `test_mobile_dialog_sizing`, `test_touch_target_audit`,
  `test_pirate_theme_builder_mobile_scaling`) encode today's pixel sizes/scale constants. Update
  expectations only where this spec changes them, name each in the commit, and never loosen an
  assertion just to pass.
- **`apply_mobile_control_scaling` compounding:** safe once per rebuild only (its own header). With
  scale → 1.0 it becomes near-no-op, but keep the guard.
- **Font overflow** from wider glyphs (precedent `d88e0c6`): the sweep after every phase catches it.
- **MobileControls is a CanvasLayer** that applies the theme in its own `_ready()` (M15.5 Req 5).
  Theme propagation doesn't cross the layer, so check it separately.
- **Concurrent sessions:** stage only this phase's files; never `git add -A`.
- **Not verifiable here:** on-device touch feel, haptics, real-device fps with the textures and
  particles, and safe-area on notched hardware. Say so at every checkpoint.

## 12. Screen inventory (baseline 2026-09-25)

Override counts to burn down. `tscn` = `theme_override_*` lines in `scenes/ui/<name>.tscn`;
`gd` = `add_theme_*` calls in `scripts/ui/<name>.gd`. Totals: **186 / 186**. Re-count with the
same greps after each phase and update the "now" columns.

| Screen | tscn | gd | Phase | tscn now | gd now |
|---|---:|---:|---|---:|---:|
| MainMenu | 10 | 0 | 4 | | |
| PauseMenu | 10 | 2 | 4 | | |
| SettingsMenu | 0 | 37 | 4 | | |
| CreditsScreen | 0 | 0 | 4 | | |
| AgeGate | 8 | 0 | 4 | | |
| ConsentPanel | 8 | 0 | 4 | | |
| ChoiceDialog (code-only) | – | 6 | 4 | | |
| WorldHUD | 39 | 32 | 5 | | |
| MobileControls | 0 | 8 | 5 | | |
| HudCustomizeOverlay (code-only) | – | 3 | 5 | | |
| IslandMenu | 14 | 51 | 6a | | |
| WorldMapScreen | 8 | 1 | 6a | | |
| TutorialDialogue | 15 | 5 | 6a | | |
| CaptainsLog | 6 | 6 | 6b | | |
| CodexScreen | 0 | 6 | 6b | | |
| WhatsNewScreen | 7 | 4 | 6b | | |
| WardrobeScreen | 10 | 2 | 6b | | |
| StoreScreen | 7 | 2 | 6b | | |
| PurchaseSupportScreen | 7 | 1 | 6b | | |
| RewardedBonusOffer | 7 | 0 | 6b | | |
| RaidReportScreen | 11 | 5 | 6b | | |
| DeathScreen | 11 | 3 | 6b | | |
| UpgradeChoiceScreen | 0 | 9 | 6b | | |
| EnemyHealthBarWidget | 8 | 0 | 6b | | |
| FloatingDamage | 0 | 0 | 6b | | |
| PortraitFallback (code-only) | – | 2 | 6a | | |
| PirateThemeBuilder (code-only) | – | 1 | 3 | | |

Captain drawer lives inside WorldHUD (not its own scene); it's restyled in 6a alongside the roster.
