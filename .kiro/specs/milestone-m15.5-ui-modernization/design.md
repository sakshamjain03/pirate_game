# Design Document: Milestone M15.5 — UI Visual Modernization

## 1. Why this design shape

Extend `PirateThemeBuilder.gd` — the single theme object every screen already applies
(`WorldHUD.gd:104-107`, `MainMenu.gd:29-30`, `IslandMenu.gd:57`, `PauseMenu.gd:21`,
`SettingsMenu.gd:68`, `DeathScreen.gd:20`, five more) — rather than inventing a second theme
system or a per-screen styling convention. This is the direct application of `AGENTS.md`'s "never
duplicate systems": the centralization already exists and already works (M9's presentation pass
specifically fixed the two screens that weren't calling it). The only thing wrong with it today is
what it *builds* — flat `StyleBoxFlat` boxes instead of textured/gradient ones — not how it's
wired in.

**Key technical constraint driving the whole design:** Godot 4.3's `StyleBoxFlat.bg_color` is a
single solid `Color` — there is no gradient-fill property on it. `GradientTexture2D` can produce
a real gradient, but wrapping it in a `StyleBoxTexture` for a *rounded* panel requires the source
texture to already have rounded, anti-aliased alpha corners — `GradientTexture2D` only ever
renders a plain rectangle. Getting both "rounded corners" and "gradient fill" at once therefore
means either (a) writing and maintaining a custom `canvas_item` shader with a rounded-rect SDF, or
(b) sourcing pre-rendered 9-slice texture art that already has both baked in. This design takes
(b): it is zero new shader-maintenance surface, matches how every commercial mobile-game UI kit
(including free ones) is actually distributed, and directly satisfies the "sourced icon art"
requirement at the same time — one asset pack serves both needs.

## 2. New/changed files

| File | Change |
|------|--------|
| `assets/ui_icons/` | New. Sourced CC0 UI texture pack: 9-slice panel/button/bar PNGs, resource/stat icon glyphs, `LICENSE.txt`. |
| `scripts/ui/UIIcons.gd` | New. `const`/static lookup from key (`"gold"`, `"wood"`, `"iron"`, `"rum"`, `"health"`, `"notoriety"`, `"anchor"`, `"compass"`) to `res://assets/ui_icons/...` texture path. |
| `scripts/ui/ButtonJuice.gd` | New. Reusable press/hover tween component (script, not inheritance — see §5). |
| `scripts/ui/PirateThemeBuilder.gd` | Modified. New palette constants; `Button`/`Panel`/`PanelContainer`/`ProgressBar` styles built as `StyleBoxTexture` from the sourced pack; `StyleBoxFlat` fallback helper kept (enhanced) for one-off dynamic states. |
| `scenes/ui/WorldHUD.tscn`, `scripts/ui/WorldHUD.gd` | Modified. Icon-chip resource counters, restyled/animated health bar, restyled cannon/notoriety panels. No signal or public-method changes. |
| `scenes/ui/{IslandMenu,PauseMenu,DeathScreen,CaptainsLog,RaidReportScreen,TutorialDialogue}.tscn` | Modified. Remove duplicated inline `StyleBoxFlat_*Bg` sub-resource; use the centralized theme panel style. Buttons gain `ButtonJuice.gd`. |
| `scenes/ui/{MainMenu,SettingsMenu,CodexScreen,WorldMapScreen,UpgradeChoiceScreen,MobileControls}.tscn` | Modified. Buttons gain `ButtonJuice.gd`; any dynamically-built `StyleBoxFlat` (e.g. `SettingsMenu._show_message()`'s toast) uses the enhanced fallback helper. |
| `docs/05_CURRENT_SYSTEMS.md`, `docs/03_ART_DIRECTION.md`, `docs/15_MASTER_PLAN.md` | Doc sync per Requirement 6. |

## 3. Asset sourcing (Requirement 1)

Selection criteria, checked in order, before any pack is downloaded:
1. **License** — CC0 or a license that explicitly permits use in a shipped commercial game
   without per-asset attribution (Kenney.nl's entire catalog is CC0; this is the primary
   candidate source). Reject anything requiring attribution-in-product or non-commercial-only
   terms.
2. **Coverage** — must include (or be paired with a same-author companion pack that includes)
   both UI chrome (9-slice panels/buttons/bar) and enough generic icon glyphs to cover
   gold/wood/iron/rum/health/notoriety/anchor/compass — reskinned generically (a coin, a log,
   an ore chunk, a bottle, a heart, a skull-or-flame, an anchor, a compass rose) rather than
   needing pirate-specific art; the pirate identity stays in the font/palette/copy, not the icon
   set.
3. **Style** — flat/clean rendering (soft shading, rounded corners, subtle gradient), explicitly
   not a heavy carved-wood/bevel skeuomorphic style — matches the "sleek and current" direction
   over the initially-discussed "Clash of Clans chunky" reference.

Mechanism: downloaded via `Bash`/`PowerShell` (`curl`/`Invoke-WebRequest`) directly from the
source site during Task 1, unzipped into `assets/ui_icons/`, with the pack's license file kept
alongside it unmodified. `UIIcons.gd` is written against whatever the actual downloaded filenames
turn out to be — this design intentionally does not hardcode filenames that don't exist yet.

## 4. `PirateThemeBuilder.gd` — texture-based styles

Current shape (`_make_panel_stylebox()`, called for every `Button`/`Panel`/`ProgressBar` state)
returns a flat `StyleBoxFlat`. New shape adds a parallel builder consuming the sourced pack:

```gdscript
static func _make_texture_stylebox(texture_path: String, margin: int = 16) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = ResourceLoader.load(texture_path)
    sb.texture_margin_left   = margin
    sb.texture_margin_right  = margin
    sb.texture_margin_top    = margin
    sb.texture_margin_bottom = margin
    sb.content_margin_left   = 12.0
    sb.content_margin_right  = 12.0
    sb.content_margin_top    = 6.0
    sb.content_margin_bottom = 6.0
    return sb
```

`build()` keeps setting the exact same theme type/property pairs it already sets today
(`theme.set_stylebox("normal", "Button", ...)`, `"panel"` for `Panel`/`PanelContainer`,
`"background"`/`"fill"` for `ProgressBar`) — only the StyleBox *implementation* passed in changes,
so no calling screen needs to change how it requests the theme. `_make_panel_stylebox()` (the
existing `StyleBoxFlat` builder) is kept, not deleted, and enhanced per Requirement 2.3
(`corner_radius_*` raised, `shadow_size`/`shadow_color` added, `anti_aliasing = true`) as the
documented fallback for dynamically-built one-off elements that reference
`PirateThemeBuilder`'s helpers directly (`WorldHUD.announce_event()`,
`SettingsMenu._show_message()`) rather than going through the `Theme` object.

## 5. `ButtonJuice.gd` — composition, not inheritance

```gdscript
class_name ButtonJuice extends Node

## Attach as a child of any Button. Connects to that Button's own signals;
## does not require the Button to be a custom subclass.
@export var press_scale: float = 0.94
@export var hover_scale: float = 1.03
@export var duration: float = 0.12

var _button: Button

func _ready() -> void:
    _button = get_parent() as Button
    if not _button:
        push_warning("ButtonJuice must be a child of a Button")
        return
    _button.pivot_offset = _button.size / 2.0
    _button.button_down.connect(func(): _tween_to(press_scale))
    _button.button_up.connect(func(): _tween_to(hover_scale if _button.is_hovered() else 1.0))
    _button.mouse_entered.connect(func(): _tween_to(hover_scale))
    _button.mouse_exited.connect(func(): _tween_to(1.0))

func _tween_to(target_scale: float) -> void:
    var tween := _button.create_tween()
    tween.tween_property(_button, "scale", Vector2(target_scale, target_scale), duration)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

Attached as a plain child `Node` under each `Button` in the `.tscn` files (matching how
`MobileControls.tscn`/other scenes already compose behavior via sibling/child nodes rather than
custom `Button` subclasses) — satisfies Requirement 4.1's composition constraint and Requirement
4.3's 150ms ceiling (`duration = 0.12`).

## 6. WorldHUD icon chips (Requirement 3)

`WorldHUD.tscn`'s current resource row (`TopRightPanel/ResourceBar/HBox/GoldLabel` etc., a bare
`Label`) becomes, per resource:

```
GoldChip (PanelContainer, theme_override_styles/panel = the new texture stylebox)
└── HBox (HBoxContainer)
    ├── Icon (TextureRect, texture = UIIcons.get_icon("gold"))
    └── GoldLabel (Label, unique_name_in_owner = true — SAME name, same %-reference)
```

`GoldLabel` keeps its `unique_name_in_owner` and node name, so
`WorldHUD.gd:26` (`@onready var gold_label : Label = %GoldLabel`) and
`_on_resources_changed()` (`WorldHUD.gd:383-396`) need **zero changes** — only the label's own
text format changes, from `"💰 %s / %s"` to `"%s / %s"` (the icon now carries what the emoji did).
Same pattern for wood/iron/rum. `_tint_label()` (the red cap-reached override, `WorldHUD.gd:376`)
is untouched — it sets a font color override on the same `Label`, independent of the surrounding
chip.

Health bar: `%HealthBar`'s `theme_override_styles/background`/`fill` point at the new texture
styles (same property names, `WorldHUD.tscn:105-106`). `set_health()` (`WorldHUD.gd:490-497`)
gains a tween instead of a direct `value` assignment:

```gdscript
func set_health(current: float, maximum: float) -> void:
    if health_bar:
        health_bar.max_value = maximum
        var tween := create_tween()
        tween.tween_property(health_bar, "value", current, 0.25)
        var low_health := maximum > 0.0 and current / maximum < 0.25
        _set_health_pulse(low_health)
    if health_left:
        health_left.text = tr("%d / %d HP") % [int(current), int(maximum)]
    if health_right:
        health_right.text = "%d / %d" % [int(current), int(maximum)]

func _set_health_pulse(active: bool) -> void:
    if active == _health_pulse_active:
        return
    _health_pulse_active = active
    if active:
        _health_pulse_tween = create_tween().set_loops()
        _health_pulse_tween.tween_property(health_bar, "modulate", Color(1.3, 0.5, 0.5), 0.4)
        _health_pulse_tween.tween_property(health_bar, "modulate", Color(1, 1, 1), 0.4)
    elif _health_pulse_tween:
        _health_pulse_tween.kill()
        health_bar.modulate = Color(1, 1, 1)
```

(`_health_pulse_active: bool` and `_health_pulse_tween: Tween` are new `WorldHUD.gd` member
vars.) `set_health()`'s signature and every caller (`_on_health_changed()`) are unchanged —
satisfies Requirement 3.5. Cannon panels (`StyleBoxFlat_CannonPanel`/`CannonHeader`) and the
notoriety label's container get the same texture-panel treatment as the resource chips; the port
cooldown "🛶" emoji `Icon` label (`WorldHUD.tscn:189-193`) is replaced with a `TextureRect` from
`UIIcons`, same pattern as the resource icons.

## 7. Menu screens (Requirement 5)

Every screen in the `StyleBoxFlat_*Bg`-duplication group (confirmed identical pattern to
`PauseMenu.tscn`'s `StyleBoxFlat_MenuBg`, lines 5-15) gets that one sub-resource swapped for a
reference to the theme's own panel style — since these screens already call
`PirateThemeBuilder.build()` and apply it to their root (`PauseMenu.gd:21` etc.), the simplest
correct change is to delete the scene's local override
(`theme_override_styles/panel = SubResource("StyleBoxFlat_MenuBg")`) entirely and let the now-
textured `Theme`'s own `"panel"` style apply, exactly as `Panel`/`PanelContainer` nodes without an
override already do elsewhere. This is strictly fewer lines per scene, not a new mechanism.

Screens that build UI dynamically in code (`SettingsMenu._show_message()`,
`WorldHUD.announce_event()`) call `PirateThemeBuilder`'s enhanced `StyleBoxFlat` fallback
(§4) instead of hand-rolling their own `StyleBoxFlat` inline — removing two more of the
duplicated definitions the codebase currently has.

## 8. Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
This is a rendering-only milestone: the GUT suite is expected to stay at its current baseline
(no new failures, no count regression) since no signal, save-data, or gameplay-value path changes.
It cannot verify the actual visual result — per this project's own documented limitation, each
touched screen must also be opened via `mcp__godot__run_project` (or the `run` skill) and visually
confirmed against Requirement 2/3's stated look, with that confirmation recorded in `tasks.md`
rather than inferred from a passing test suite.
