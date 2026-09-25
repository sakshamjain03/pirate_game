#!/usr/bin/env python3
"""tools/ui_kit/gen_kit.py — M22 UI texture kit generator.

Generates every SVG in the v0.3 ("Pirate Empire UI System") texture kit:
panels, buttons, controls, and a handful of misc pieces (see design.md §6).
stdlib only (no PIL/cairosvg/etc. — this only ever *writes* SVG text; Godot's
own ThorVG importer does the rasterizing at build/run time).

Determinism (tasks.md 2.1's own verify step: two runs must produce
byte-identical output): every seeded/"random" texture detail (parchment
grain, wood grain) uses a *local* `random.Random(<fixed string seed>)`
instance, never the global `random` module, so generation order can never
matter and re-running this script always reproduces the exact same bytes.

Units: authored directly in CANVAS px (design px x2 — see
.kiro/specs/milestone-m22-ui-overhaul/design.md §3), not "design px + a 2x
import scale". This sidesteps having to hand-author or verify a Godot
`.import` scale override for 30+ files; every SVG's own width/height/viewBox
IS the real texture pixel size Godot will rasterize, with the default
(1.0) import scale. A `DESIGN` alias is provided purely for readability at
each call site (so a reviewer can cross-reference the v0.3 doc's own
design-px numbers directly) — see `dpx()`.

Usage:
    python tools/ui_kit/gen_kit.py [--out-dir assets/ui/kit] [--icons-dir assets/ui/icons]

Run again any time the art needs tweaking — this script IS the source of
truth; both it and its output are committed (design.md §6), so the art can
be edited either way (by re-running this with tweaked parameters, or by
hand-editing a generated .svg directly — a future re-run will simply
overwrite hand edits, so prefer changing this script).
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

# --------------------------------------------------------------------------
# Palette — MUST stay in sync with scripts/ui/UIPalette.gd (the runtime's
# own single source of truth for these colours). Duplicated here because
# this is a build-time Python tool with no access to a .tres/.gd file at
# generation time; a mismatch would only affect generated art, never
# gameplay/theme correctness (PirateThemeBuilder always reads UIPalette).
# --------------------------------------------------------------------------
PALETTE = {
    "ocean_deep": "#0A2C33",
    "sunset_teal": "#1F6F76",
    "shallows": "#3A9A97",
    "horizon_gold": "#F4C96E",
    "driftwood": "#6D452A",
    "wood_dark": "#2E1A0C",
    "brass": "#C29444",
    "brass_light": "#F7DE98",
    "parchment": "#ECD6A4",
    "ink": "#3A2616",
    "coral": "#F0602A",
    "coral_bloom": "#FFD6AE",
    "brick": "#A8392B",
    "text_on_dark": "#F7DFA6",
    "text_on_parchment": "#3A2616",
    "hp_good": "#3FBF8F",
    "hp_low": "#D6453A",
}

RARITY = {
    "common": {"col": "#EDE6D6", "hi": "#FFFAF0", "dk": "#A89D86", "glow": 0},
    "uncommon": {"col": "#3FBF8F", "hi": "#9FF0CC", "dk": "#1D7A58", "glow": 0},
    "rare": {"col": "#2F6FD6", "hi": "#8FB8FF", "dk": "#173F8A", "glow": 0},
    "epic": {"col": "#7B3FC4", "hi": "#C49BFF", "dk": "#45207A", "glow": 14},
    "legendary": {"col": "#FF8A3D", "hi": "#FFE39A", "dk": "#C2501A", "glow": 22},
}

# canvas px = design px x2 (design.md §3) — this converts a design-px number
# from the v0.3 doc straight to the canvas px this script actually emits, so
# every call site can read like "dpx(40)" and be cross-referenced directly
# against the doc instead of a pre-multiplied magic number.
def dpx(design_px: float) -> float:
    return design_px * 2.0


# --------------------------------------------------------------------------
# Tiny SVG string-building helpers. Deliberately not a DOM/ElementTree
# builder — raw f-string templates are shorter and easier to eyeball-diff
# for this kind of generative-graphics script, and ThorVG (Godot 4.3's SVG
# renderer) only needs a small, well-understood subset of SVG (paths,
# rects, circles, linear/radial gradients, opacity, groups) — no filters.
# --------------------------------------------------------------------------

def svg_doc(width: float, height: float, body: str, *, view_box: str | None = None) -> str:
    vb = view_box or f"0 0 {width:g} {height:g}"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:g}" height="{height:g}" '
        f'viewBox="{vb}">\n{body}\n</svg>\n'
    )


def rect(x, y, w, h, *, rx=0, fill="none", stroke=None, stroke_width=0, opacity=None) -> str:
    attrs = f'x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}"'
    if rx:
        attrs += f' rx="{rx:g}"'
    attrs += f' fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{stroke_width:g}"'
    if opacity is not None:
        attrs += f' opacity="{opacity:g}"'
    return f"<rect {attrs}/>"


def circle(cx, cy, r, *, fill="none", stroke=None, stroke_width=0, opacity=None) -> str:
    attrs = f'cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{stroke_width:g}"'
    if opacity is not None:
        attrs += f' opacity="{opacity:g}"'
    return f"<circle {attrs}/>"


def line(x1, y1, x2, y2, *, stroke, stroke_width, opacity=None, cap="round") -> str:
    attrs = (
        f'x1="{x1:g}" y1="{y1:g}" x2="{x2:g}" y2="{y2:g}" '
        f'stroke="{stroke}" stroke-width="{stroke_width:g}" stroke-linecap="{cap}"'
    )
    if opacity is not None:
        attrs += f' opacity="{opacity:g}"'
    return f"<line {attrs}/>"


def path(d, *, fill="none", stroke=None, stroke_width=0, opacity=None, fill_rule=None) -> str:
    attrs = f'd="{d}" fill="{fill}"'
    if fill_rule:
        attrs += f' fill-rule="{fill_rule}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{stroke_width:g}"'
    if opacity is not None:
        attrs += f' opacity="{opacity:g}"'
    return f"<path {attrs}/>"


def linear_gradient(gid, stops, *, x1=0, y1=0, x2=0, y2=1) -> str:
    body = "".join(
        f'<stop offset="{o:g}" stop-color="{c}" stop-opacity="{a:g}"/>' for o, c, a in stops
    )
    return f'<linearGradient id="{gid}" x1="{x1:g}" y1="{y1:g}" x2="{x2:g}" y2="{y2:g}">{body}</linearGradient>'


def radial_gradient(gid, stops, *, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None) -> str:
    focal = f' fx="{fx:g}" fy="{fy:g}"' if fx is not None else ""
    body = "".join(
        f'<stop offset="{o:g}" stop-color="{c}" stop-opacity="{a:g}"/>' for o, c, a in stops
    )
    return f'<radialGradient id="{gid}" cx="{cx:g}" cy="{cy:g}" r="{r:g}"{focal}>{body}</radialGradient>'


def group(body, *, transform=None, opacity=None) -> str:
    attrs = ""
    if transform:
        attrs += f' transform="{transform}"'
    if opacity is not None:
        attrs += f' opacity="{opacity:g}"'
    return f"<g{attrs}>\n{body}\n</g>"


def defs(*items: str) -> str:
    return "<defs>\n" + "\n".join(items) + "\n</defs>"


# --------------------------------------------------------------------------
# Shared texture components
# --------------------------------------------------------------------------

def seeded_grain_strokes(seed: str, w: float, h: float, count: int, colour: str,
                          *, min_len=6, max_len=22, min_op=0.03, max_op=0.10,
                          stroke_w=1.0) -> str:
    """A field of short, low-alpha strokes at random positions/angles — the
    only way to fake "fibre grain"/"wood grain" texture under ThorVG, which
    has no SVG filter support (design.md §6: no feTurbulence/blur)."""
    rng = random.Random(seed)
    out = []
    for _ in range(count):
        x = rng.uniform(0, w)
        y = rng.uniform(0, h)
        length = rng.uniform(min_len, max_len)
        angle = rng.uniform(-14, 14) * math.pi / 180.0
        dx = math.cos(angle) * length / 2.0
        dy = math.sin(angle) * length / 2.0
        op = rng.uniform(min_op, max_op)
        out.append(line(x - dx, y - dy, x + dx, y + dy, stroke=colour, stroke_width=stroke_w, opacity=op))
    return "\n".join(out)


def seeded_wood_planks(seed: str, w: float, h: float, plank_h: float,
                        base: str, dark: str) -> str:
    """Horizontal plank seams + per-plank grain curves."""
    rng = random.Random(seed)
    out = [rect(0, 0, w, h, fill=base)]
    y = 0.0
    while y < h:
        out.append(line(0, y, w, y, stroke=dark, stroke_width=1.4, opacity=0.35))
        # A few long, gently-wavy grain strokes per plank.
        for _ in range(int(w / 40)):
            gx = rng.uniform(0, w)
            gy = y + rng.uniform(4, max(4.0, plank_h - 4))
            glen = rng.uniform(24, 70)
            out.append(line(gx - glen / 2, gy, gx + glen / 2, gy + rng.uniform(-2, 2),
                             stroke=dark, stroke_width=1.2, opacity=rng.uniform(0.08, 0.18)))
        y += plank_h
    return "\n".join(out)


def brass_stud(cx, cy, r) -> str:
    gid = f"stud_{cx:g}_{cy:g}"
    return (
        defs(radial_gradient(gid, [(0, PALETTE["brass_light"], 1), (0.6, PALETTE["brass"], 1),
                                     (1, PALETTE["ink"], 1)], cx=0.35, cy=0.3, r=0.9))
        + circle(cx, cy, r, fill=f"url(#{gid})")
        + circle(cx - r * 0.3, cy - r * 0.3, r * 0.22, fill="#FFFFFF", opacity=0.55)
    )


def rope_tile(x, y, length, thickness, *, vertical=False) -> str:
    """A short run of a rope-stitch pattern — alternating dark/light twist
    segments — used as the frame's rope-stitched edge (design.md's "rope
    4px tile" note, canvas px here)."""
    out = []
    seg = thickness * 1.6
    n = max(1, int(length / seg))
    for i in range(n):
        t = i * seg
        c1, c2 = (PALETTE["driftwood"], PALETTE["wood_dark"]) if i % 2 == 0 else (PALETTE["wood_dark"], PALETTE["driftwood"])
        if vertical:
            out.append(rect(x - thickness / 2, y + t, thickness, seg, rx=thickness / 2, fill=c1))
            out.append(rect(x - thickness / 4, y + t, thickness / 2, seg, rx=thickness / 4, fill=c2, opacity=0.6))
        else:
            out.append(rect(x + t, y - thickness / 2, seg, thickness, rx=thickness / 2, fill=c1))
            out.append(rect(x + t, y - thickness / 4, seg, thickness / 2, rx=thickness / 4, fill=c2, opacity=0.6))
    return "\n".join(out)


# --------------------------------------------------------------------------
# 2.1 — Panels: parchment 9-slice, wood frame + rope + studs, wood plaque
# --------------------------------------------------------------------------

def gen_parchment_panel() -> tuple[str, str]:
    """9-slice margin dpx(40)=80 canvas px (design.md §6). Warm top-left
    highlight, burnt lower-right edge, fibre grain, deckle in the alpha
    channel (an irregular seeded outline — the panel's own edge, not a
    separate stroke, so the alpha itself is uneven)."""
    w, h = 320, 320
    margin = dpx(40)
    body = []
    body.append(defs(
        linear_gradient("bg", [(0, PALETTE["parchment"], 1), (1, "#C9A96E", 1)], x1=0, y1=0, x2=1, y2=1),
        radial_gradient("burn", [(0, PALETTE["ink"], 0), (0.72, PALETTE["ink"], 0), (1, PALETTE["ink"], 0.45)],
                         cx=0.5, cy=0.5, r=0.75),
    ))
    # Deckled (irregular) outline: a seeded wobble around the rect edge.
    rng = random.Random("parchment-deckle")
    deckle_pts = []
    steps = 40
    for i in range(steps + 1):
        t = i / steps
        # Walk the rectangle perimeter, wobbling the inward offset.
        if t < 0.25:
            x = w * (t / 0.25)
            y = 0
        elif t < 0.5:
            x = w
            y = h * ((t - 0.25) / 0.25)
        elif t < 0.75:
            x = w * (1 - (t - 0.5) / 0.25)
            y = h
        else:
            x = 0
            y = h * (1 - (t - 0.75) / 0.25)
        wob = rng.uniform(-3.0, 3.0)
        nx = -1 if x <= 0 else (1 if x >= w else 0)
        ny = -1 if y <= 0 else (1 if y >= h else 0)
        deckle_pts.append((x + nx * wob, y + ny * wob))
    d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in deckle_pts) + " Z"
    body.append(path(d, fill="url(#bg)"))
    body.append(path(d, fill="url(#burn)"))
    # Warm top-left highlight — a soft radial glow, not a flat rect (an
    # earlier flat-rect version left a visible hard-edged seam at its own
    # boundary; caught by rendering this at full size, not judging it from
    # the kit sheet's small thumbnail).
    body.append(defs(radial_gradient("hi", [(0, PALETTE["brass_light"], 0.22), (1, PALETTE["brass_light"], 0)],
                                       cx=0.22, cy=0.2, r=0.65)))
    body.append(rect(0, 0, w, h, fill="url(#hi)"))
    # Fibre grain.
    body.append(seeded_grain_strokes("parchment-grain", w, h, 340, PALETTE["ink"],
                                      min_len=4, max_len=16, min_op=0.03, max_op=0.08, stroke_w=0.9))
    # Deckle edge line itself (subtle ink rim).
    body.append(path(d, fill="none", stroke=PALETTE["ink"], stroke_width=2, opacity=0.5))
    svg = svg_doc(w, h, "\n".join(body))
    meta = f"parchment_panel: {w:g}x{h:g}, 9-slice margin {margin:g}px"
    return svg, meta


def gen_wood_frame() -> tuple[str, str]:
    """9-slice margin dpx(12)=24 canvas px. Wood body, rope-stitched inner
    edge, brass studs at the corners (design.md's "rope 4px tile · studs
    10px @7px inset", here scaled: rope thickness dpx(4)=8, stud radius
    dpx(10)=20, inset dpx(7)=14)."""
    w, h = 240, 240
    margin = dpx(12)
    rope_th = dpx(4)
    stud_r = dpx(10)
    inset = dpx(7)
    body = [seeded_wood_planks("frame-wood", w, h, 28, PALETTE["driftwood"], PALETTE["wood_dark"])]
    # Inner rope border (a rounded rect outline built from 4 straight runs).
    ropes = []
    ropes.append(rope_tile(margin, margin, w - 2 * margin, rope_th))
    ropes.append(rope_tile(margin, h - margin, w - 2 * margin, rope_th))
    ropes.append(rope_tile(margin, margin, h - 2 * margin, rope_th, vertical=True))
    ropes.append(rope_tile(w - margin, margin, h - 2 * margin, rope_th, vertical=True))
    body.append(group("\n".join(ropes)))
    # Corner brass studs.
    for cx, cy in [(inset, inset), (w - inset, inset), (inset, h - inset), (w - inset, h - inset)]:
        body.append(brass_stud(cx, cy, stud_r))
    # Outer dark-ink border.
    body.append(rect(1.5, 1.5, w - 3, h - 3, stroke=PALETTE["ink"], stroke_width=3, fill="none"))
    svg = svg_doc(w, h, "\n".join(body))
    meta = f"wood_frame: {w:g}x{h:g}, 9-slice margin {margin:g}px"
    return svg, meta


def gen_wood_plaque() -> tuple[str, str]:
    """3-slice HORIZONTAL, titles only. Ends dpx(32)=64 canvas px (design.md
    §6's "plaque ends 64")."""
    w, h = 400, 120
    end = dpx(32)
    body = [seeded_wood_planks("plaque-wood", w, h, 40, PALETTE["driftwood"], PALETTE["wood_dark"])]
    # Carved end-caps: a darker inset band at each end, brass rivets.
    for ex in (0, w - end):
        body.append(rect(ex, 0, end, h, fill=PALETTE["wood_dark"], opacity=0.35))
        body.append(brass_stud(ex + end * 0.5, h * 0.25, dpx(4)))
        body.append(brass_stud(ex + end * 0.5, h * 0.75, dpx(4)))
    body.append(rect(1.5, 1.5, w - 3, h - 3, stroke=PALETTE["ink"], stroke_width=3, fill="none"))
    svg = svg_doc(w, h, "\n".join(body))
    meta = f"wood_plaque: {w:g}x{h:g}, 3-slice ends {end:g}px (horizontal)"
    return svg, meta


# --------------------------------------------------------------------------
# 2.2 — Buttons: Primary (coral) / Brass / Wood-round x idle/pressed/disabled
# --------------------------------------------------------------------------

# Shared rectangular-button canvas: wide enough for a real label, tall
# enough to reserve room for the idle lip without the face itself moving.
_BTN_W, _BTN_H = 240, 108
_BTN_FACE_H = 64          # design 32 — the visible button face height
_LIP_IDLE = dpx(6)        # design 6 -> canvas 12 (UITokens.LIP_IDLE)
_LIP_PRESSED = dpx(2)     # design 2 -> canvas 4 (UITokens.LIP_PRESSED)
_PRESS_DROP = dpx(4)      # design 4 -> canvas 8 (UITokens.PRESS_OFFSET_Y)
_BORDER = dpx(3)          # design 3 -> canvas 6 (UITokens.BORDER_WIDTH)


def _button_face(fill_top, fill_bot, radius, *, desaturated=False) -> tuple[str, str]:
    gid = f"face_{fill_top.strip('#')}_{fill_bot.strip('#')}"
    op = 0.45 if desaturated else 1.0
    grad = linear_gradient(gid, [(0, fill_top, 1), (1, fill_bot, 1)], x1=0, y1=0, x2=0, y2=1)
    return grad, op


def _rounded_button_svg(radius: float, top_fill: str, bot_fill: str, *, pressed: bool,
                         disabled: bool = False) -> str:
    face_y = _PRESS_DROP if pressed else 0
    lip_h = _LIP_PRESSED if pressed else _LIP_IDLE
    grad, op = _button_face(top_fill, bot_fill, radius, desaturated=disabled)
    # A plain descriptive id, not a hash of the inputs — Python's built-in
    # hash() is salted per-process (PYTHONHASHSEED) unless explicitly fixed,
    # which would silently break this generator's own determinism guarantee
    # (found by actually diffing two runs, not assumed).
    gid = f"g_{top_fill.strip('#')}_{bot_fill.strip('#')}_{'p' if pressed else 'i'}"
    grad = grad.replace('id="' + grad.split('id="')[1].split('"')[0] + '"', f'id="{gid}"', 1)
    body = [defs(grad)]
    # Lip (solid shadow slab) sits directly under the face, full width.
    body.append(rect(0, face_y + _BTN_FACE_H - radius * 0.4, _BTN_W, lip_h + radius * 0.4,
                      rx=radius * 0.5, fill=PALETTE["ink"], opacity=0.9))
    # Face.
    body.append(rect(0, face_y, _BTN_W, _BTN_FACE_H, rx=radius, fill=f"url(#{gid})", opacity=op))
    body.append(rect(_BORDER / 2, face_y + _BORDER / 2, _BTN_W - _BORDER, _BTN_FACE_H - _BORDER,
                      rx=max(0, radius - _BORDER / 2), fill="none", stroke=PALETTE["ink"],
                      stroke_width=_BORDER, opacity=op))
    # Gloss highlight along the top edge.
    if not disabled:
        body.append(rect(radius, face_y + radius * 0.25, _BTN_W - radius * 2, _BTN_FACE_H * 0.28,
                          rx=radius * 0.4, fill="#FFFFFF", opacity=0.14))
    return svg_doc(_BTN_W, _BTN_H, "\n".join(body))


def gen_buttons() -> list[tuple[str, str, str]]:
    """Returns (filename_stem, svg, meta) for all 9 rectangular states plus
    the 3 wood-round states (below)."""
    out = []
    radius_primary = dpx(18)   # requirements.md: Radius 18 (primary)
    radius_brass = dpx(14)     # Radius 14 (secondary/brass)

    families = {
        "button_primary": (radius_primary, PALETTE["coral_bloom"], PALETTE["coral"]),
        "button_brass": (radius_brass, PALETTE["brass_light"], PALETTE["brass"]),
    }
    for name, (radius, top, bot) in families.items():
        out.append((f"{name}_idle", _rounded_button_svg(radius, top, bot, pressed=False),
                     f"{name}_idle: {_BTN_W:g}x{_BTN_H:g}, radius {radius:g}"))
        out.append((f"{name}_pressed", _rounded_button_svg(radius, top, bot, pressed=True),
                     f"{name}_pressed: {_BTN_W:g}x{_BTN_H:g}, radius {radius:g}, body dropped {_PRESS_DROP:g}px"))
        out.append((f"{name}_disabled", _rounded_button_svg(radius, "#B9AFA0", "#8C8378", pressed=False, disabled=True),
                     f"{name}_disabled: {_BTN_W:g}x{_BTN_H:g}, radius {radius:g}"))

    # Wood-round: nav/abilities, design 56-58px -> canvas ~112-116px. Uses
    # the larger end (58 design px) per requirements.md's own range.
    diam = dpx(58)
    canvas_w = diam + dpx(6)
    canvas_h = diam + _LIP_IDLE + dpx(10)
    for state, pressed, disabled in (("idle", False, False), ("pressed", True, False), ("disabled", False, True)):
        cx = canvas_w / 2
        face_y = (_PRESS_DROP if pressed else 0) + diam / 2 + dpx(3)
        lip_h = _LIP_PRESSED if pressed else _LIP_IDLE
        top, bot = (PALETTE["driftwood"], PALETTE["wood_dark"]) if not disabled else ("#8C8378", "#665F55")
        gid = f"wood_round_{state}"
        body = [defs(radial_gradient(gid, [(0, top, 1), (1, bot, 1)], cx=0.35, cy=0.3, r=0.85))]
        # Lip: a stadium-shaped slab from the circle's vertical centre down
        # to `lip_h` past its bottom edge, drawn UNDER the face circle so
        # only the exposed strip below shows — same idle/pressed geometry
        # trick as the rectangular buttons (a same-radius circle offset by
        # a few px, tried first, only ever shows a razor-thin sliver;
        # caught by actually looking at UIKitSheet's own capture).
        lip_total_h = diam / 2 + lip_h
        body.append(rect(cx - diam / 2, face_y, diam, lip_total_h, rx=diam / 2,
                          fill=PALETTE["ink"], opacity=0.85))
        body.append(circle(cx, face_y, diam / 2, fill=f"url(#{gid})"))
        body.append(circle(cx, face_y, diam / 2 - _BORDER / 2, fill="none", stroke=PALETTE["ink"], stroke_width=_BORDER))
        if not disabled:
            body.append(circle(cx - diam * 0.18, face_y - diam * 0.18, diam * 0.14, fill="#FFFFFF", opacity=0.18))
        svg = svg_doc(canvas_w, canvas_h, "\n".join(body))
        out.append((f"button_wood_round_{state}", svg,
                     f"button_wood_round_{state}: {canvas_w:g}x{canvas_h:g}, diameter {diam:g}"))
    return out


# --------------------------------------------------------------------------
# 2.3 — Controls: toggle, rope slider, segmented, tab, dropdown, scrollbar
# --------------------------------------------------------------------------

def gen_toggle(is_on: bool) -> tuple[str, str]:
    """62x30 design px per requirements.md -> canvas 124x60. On = teal ocean
    fill + brass knob; off = dark wood."""
    w, h = dpx(31), dpx(15)
    r = h / 2
    track = PALETTE["sunset_teal"] if is_on else PALETTE["wood_dark"]
    knob = PALETTE["brass_light"] if is_on else PALETTE["text_on_dark"]
    knob_cx = w - r if is_on else r
    body = [rect(0, 0, w, h, rx=r, fill=track)]
    body.append(rect(1, 1, w - 2, h - 2, rx=r - 1, fill="none", stroke=PALETTE["ink"], stroke_width=2, opacity=0.6))
    body.append(circle(knob_cx, r, r - dpx(1.5), fill=knob))
    body.append(circle(knob_cx, r, r - dpx(1.5), fill="none", stroke=PALETTE["ink"], stroke_width=1.5, opacity=0.5))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"toggle_{'on' if is_on else 'off'}: {w:g}x{h:g}"


def gen_rope_slider() -> list[tuple[str, str, str]]:
    """Track 14px design -> 28 canvas; knob 26 design -> 52 canvas
    (44px design hit-area handled by the Control node in Phase 3, not the
    texture)."""
    out = []
    track_h = dpx(7)
    w = 200
    body = [rect(0, 0, w, track_h, rx=track_h / 2, fill=PALETTE["wood_dark"])]
    body.append(seeded_grain_strokes("rope-slider-track", w, track_h, 30, PALETTE["ink"], min_len=3, max_len=8,
                                      min_op=0.15, max_op=0.3, stroke_w=1.2))
    body.append(rect(0.5, 0.5, w - 1, track_h - 1, rx=track_h / 2 - 0.5, fill="none", stroke=PALETTE["ink"],
                      stroke_width=1.5, opacity=0.7))
    out.append(("rope_slider_track", svg_doc(w, track_h, "\n".join(body)), f"rope_slider_track: {w:g}x{track_h:g}"))

    fill_body = [rect(0, 0, w, track_h, rx=track_h / 2, fill=PALETTE["brass"])]
    fill_body.append(rect(0, 0, w, track_h * 0.45, rx=track_h * 0.3, fill=PALETTE["brass_light"], opacity=0.6))
    out.append(("rope_slider_fill", svg_doc(w, track_h, "\n".join(fill_body)), f"rope_slider_fill: {w:g}x{track_h:g}"))

    knob_d = dpx(13)
    kb = [defs(radial_gradient("knob", [(0, PALETTE["brass_light"], 1), (1, PALETTE["brass"], 1)], cx=0.35, cy=0.3, r=0.9))]
    kb.append(circle(knob_d / 2, knob_d / 2, knob_d / 2, fill="url(#knob)"))
    kb.append(circle(knob_d / 2, knob_d / 2, knob_d / 2 - 1.5, fill="none", stroke=PALETTE["ink"], stroke_width=1.5))
    out.append(("rope_slider_knob", svg_doc(knob_d, knob_d, "\n".join(kb)), f"rope_slider_knob: {knob_d:g}x{knob_d:g}"))
    return out


def gen_segmented() -> list[tuple[str, str, str]]:
    out = []
    w, h = 160, dpx(15)
    well = [rect(0, 0, w, h, rx=h / 2, fill=PALETTE["ink"], opacity=0.55)]
    well.append(rect(1, 1, w - 2, h - 2, rx=h / 2 - 1, fill="none", stroke=PALETTE["brass"], stroke_width=1.5, opacity=0.5))
    out.append(("segmented_well", svg_doc(w, h, "\n".join(well)), f"segmented_well: {w:g}x{h:g}"))

    pill = [defs(linear_gradient("pill", [(0, PALETTE["brass_light"], 1), (1, PALETTE["brass"], 1)], x1=0, y1=0, x2=0, y2=1))]
    pill.append(rect(0, 0, w, h, rx=h / 2, fill="url(#pill)"))
    out.append(("segmented_pill", svg_doc(w, h, "\n".join(pill)), f"segmented_pill: {w:g}x{h:g}"))
    return out


def gen_tabs() -> list[tuple[str, str, str]]:
    out = []
    w, h = 140, dpx(24)
    idle = [rect(0, 0, w, h, rx=dpx(6), fill=PALETTE["ink"], opacity=0.35)]
    idle.append(rect(0, h - 3, w, 3, fill=PALETTE["brass"], opacity=0.4))
    out.append(("tab_idle", svg_doc(w, h, "\n".join(idle)), f"tab_idle: {w:g}x{h:g}"))

    active = [defs(linear_gradient("tabg", [(0, PALETTE["parchment"], 1), (1, "#DFC287", 1)], x1=0, y1=0, x2=0, y2=1))]
    active.append(rect(0, 0, w, h, rx=dpx(6), fill="url(#tabg)"))
    active.append(rect(0, h - 3, w, 3, fill=PALETTE["brass"]))
    out.append(("tab_active", svg_doc(w, h, "\n".join(active)), f"tab_active: {w:g}x{h:g}"))
    return out


def gen_dropdown_sheet() -> tuple[str, str]:
    """A compact parchment sheet for a popup option list — same family as
    the parchment panel but a smaller, simpler variant (no deckle needed at
    typical popup sizes)."""
    w, h = 220, 160
    body = [defs(linear_gradient("dd", [(0, PALETTE["parchment"], 1), (1, "#D2B478", 1)], x1=0, y1=0, x2=1, y2=1))]
    body.append(rect(0, 0, w, h, rx=dpx(6), fill="url(#dd)"))
    body.append(seeded_grain_strokes("dropdown-grain", w, h, 90, PALETTE["ink"], min_len=4, max_len=14,
                                      min_op=0.02, max_op=0.05, stroke_w=0.8))
    body.append(rect(1.5, 1.5, w - 3, h - 3, rx=dpx(6) - 1.5, fill="none", stroke=PALETTE["ink"], stroke_width=3, opacity=0.8))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"dropdown_sheet: {w:g}x{h:g}"


def gen_scrollbar() -> list[tuple[str, str, str]]:
    out = []
    w, h = dpx(4), 200
    track = [rect(0, 0, w, h, rx=w / 2, fill=PALETTE["ink"], opacity=0.35)]
    out.append(("scrollbar_track", svg_doc(w, h, "\n".join(track)), f"scrollbar_track: {w:g}x{h:g}"))

    gw, gh = dpx(4), 60
    grabber = [defs(linear_gradient("sg", [(0, PALETTE["brass_light"], 1), (1, PALETTE["brass"], 1)], x1=0, y1=0, x2=1, y2=0))]
    grabber.append(rect(0, 0, gw, gh, rx=gw / 2, fill="url(#sg)"))
    out.append(("scrollbar_grabber", svg_doc(gw, gh, "\n".join(grabber)), f"scrollbar_grabber: {gw:g}x{gh:g}"))
    return out


# --------------------------------------------------------------------------
# 2.4 — Misc: resource pill, rarity gem borders, cooldown ring mask, glow
# --------------------------------------------------------------------------

def gen_resource_pill() -> tuple[str, str]:
    w, h = 120, dpx(18)
    body = [defs(linear_gradient("rp", [(0, "#152A33", 1), (1, PALETTE["ocean_deep"], 1)], x1=0, y1=0, x2=0, y2=1))]
    body.append(rect(0, 0, w, h, rx=h / 2, fill="url(#rp)"))
    body.append(rect(1, 1, w - 2, h - 2, rx=h / 2 - 1, fill="none", stroke=PALETTE["brass"], stroke_width=2, opacity=0.8))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"resource_pill: {w:g}x{h:g}"


def gen_rarity_gem(name: str) -> tuple[str, str]:
    """3px 160deg gradient (hi -> base -> dark) border; facet split 34/60%;
    specular at upper-left. Epic/Legendary get an outer glow ring baked in
    as a soft radial (the *animated* shimmer sweep is a runtime effect —
    Phase 7/8 — not part of this static texture)."""
    info = RARITY[name]
    glow = info["glow"]
    pad = glow + 6
    w = h = 96 + pad * 2
    cx = cy = w / 2
    r = 40
    body = []
    if glow:
        body.append(defs(radial_gradient(f"glow_{name}", [(0, info["col"], 0.55), (1, info["col"], 0)], r=0.55)))
        body.append(circle(cx, cy, r + glow, fill=f"url(#glow_{name})"))
    body.append(defs(linear_gradient(f"gem_{name}", [(0, info["hi"], 1), (0.34, info["col"], 1), (0.6, info["col"], 1),
                                                       (1, info["dk"], 1)], x1=0.15, y1=0.1, x2=0.85, y2=0.9)))
    body.append(circle(cx, cy, r, fill="none", stroke=f"url(#gem_{name})", stroke_width=dpx(1.5)))
    body.append(circle(cx - r * 0.35, cy - r * 0.35, r * 0.16, fill="#FFFFFF", opacity=0.6))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"rarity_gem_{name}: {w:g}x{h:g}, glow {glow:g}"


def gen_cooldown_ring_mask() -> tuple[str, str]:
    """A plain white ring on transparent — used as a TextureProgressBar
    radial-fill texture over a round button in Phase 5 (design.md §7)."""
    w = h = 128
    cx = cy = w / 2
    body = [circle(cx, cy, w / 2 - 4, fill="none", stroke="#FFFFFF", stroke_width=8)]
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"cooldown_ring_mask: {w:g}x{h:g}"


def gen_glow_sprite() -> tuple[str, str]:
    """Soft radial glow blob — PrimaryGlow.gd (Phase 3) drives its
    opacity/scale via tween; this texture is just the static soft shape."""
    w = h = 160
    cx = cy = w / 2
    body = [defs(radial_gradient("glow", [(0, PALETTE["coral"], 0.55), (0.6, PALETTE["coral"], 0.22), (1, PALETTE["coral"], 0)]))]
    body.append(circle(cx, cy, w / 2, fill="url(#glow)"))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"glow_sprite: {w:g}x{h:g}"


# --------------------------------------------------------------------------
# 2.5 — the only two genuinely-missing resource icons (design.md §5a)
# --------------------------------------------------------------------------

def _resource_icon_base(cx, cy, r, hi, base, dk, *, outline=None) -> list[str]:
    gid = f"ricon_{hi.strip('#')}"
    body = [defs(radial_gradient(gid, [(0, hi, 1), (0.55, base, 1), (1, dk, 1)], cx=0.3, cy=0.3, r=0.9))]
    body.append(circle(cx, cy, r, fill=f"url(#{gid})"))
    if outline is None:
        outline = dk
    body.append(circle(cx, cy, r - dpx(0.75), fill="none", stroke=outline, stroke_width=dpx(1.25)))
    body.append(circle(cx - r * 0.3, cy - r * 0.3, r * 0.16, fill="#FFFFFF", opacity=0.7))
    return body


def gen_icon_research() -> tuple[str, str]:
    """48 design px canonical size (icon spec: outline 2.5px@48). A compass/
    astrolabe-style disc — reads as "research/navigation knowledge"."""
    w = h = dpx(24)
    cx = cy = w / 2
    r = w / 2 - dpx(1)
    body = _resource_icon_base(cx, cy, r, PALETTE["brass_light"], PALETTE["brass"], PALETTE["ink"])
    # A simple 4-point compass star on top.
    star = f"M {cx} {cy-r*0.55} L {cx+r*0.14} {cy-r*0.14} L {cx+r*0.55} {cy} L {cx+r*0.14} {cy+r*0.14} L {cx} {cy+r*0.55} L {cx-r*0.14} {cy+r*0.14} L {cx-r*0.55} {cy} L {cx-r*0.14} {cy-r*0.14} Z"
    body.append(path(star, fill=PALETTE["ink"], opacity=0.85))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"research icon: {w:g}x{h:g}"


def gen_icon_cannonball() -> tuple[str, str]:
    """Dark iron sphere — "never pure black except iron" (icon spec), so
    outline is a very dark warm grey, not #000."""
    w = h = dpx(24)
    cx = cy = w / 2
    r = w / 2 - dpx(1)
    body = _resource_icon_base(cx, cy, r, "#6E6E6E", "#2B2B2B", "#171512", outline="#171512")
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"cannonball icon: {w:g}x{h:g}"


# --------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------

def _write(path_obj: Path, content: str) -> None:
    path_obj.parent.mkdir(parents=True, exist_ok=True)
    # Deterministic across OSes: fixed newline, no trailing-whitespace churn.
    path_obj.write_text(content, encoding="utf-8", newline="\n")


def generate(out_dir: Path, icons_dir: Path) -> list[str]:
    manifest: list[str] = []

    def emit(stem: str, svg: str, meta: str) -> None:
        _write(out_dir / f"{stem}.svg", svg)
        manifest.append(meta)

    svg, meta = gen_parchment_panel(); emit("parchment_panel", svg, meta)
    svg, meta = gen_wood_frame(); emit("wood_frame", svg, meta)
    svg, meta = gen_wood_plaque(); emit("wood_plaque", svg, meta)

    for stem, svg, meta in gen_buttons():
        emit(stem, svg, meta)

    svg, meta = gen_toggle(True); emit("toggle_on", svg, meta)
    svg, meta = gen_toggle(False); emit("toggle_off", svg, meta)
    for stem, svg, meta in gen_rope_slider():
        emit(stem, svg, meta)
    for stem, svg, meta in gen_segmented():
        emit(stem, svg, meta)
    for stem, svg, meta in gen_tabs():
        emit(stem, svg, meta)
    svg, meta = gen_dropdown_sheet(); emit("dropdown_sheet", svg, meta)
    for stem, svg, meta in gen_scrollbar():
        emit(stem, svg, meta)

    svg, meta = gen_resource_pill(); emit("resource_pill", svg, meta)
    for name in RARITY:
        svg, meta = gen_rarity_gem(name); emit(f"rarity_gem_{name}", svg, meta)
    svg, meta = gen_cooldown_ring_mask(); emit("cooldown_ring_mask", svg, meta)
    svg, meta = gen_glow_sprite(); emit("glow_sprite", svg, meta)

    icons_dir.mkdir(parents=True, exist_ok=True)
    svg, meta = gen_icon_research()
    _write(icons_dir / "research.svg", svg)
    manifest.append(meta)
    svg, meta = gen_icon_cannonball()
    _write(icons_dir / "cannonball.svg", svg)
    manifest.append(meta)

    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", default="assets/ui/kit")
    parser.add_argument("--icons-dir", default="assets/ui/icons")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    out_dir = (repo_root / args.out_dir) if not Path(args.out_dir).is_absolute() else Path(args.out_dir)
    icons_dir = (repo_root / args.icons_dir) if not Path(args.icons_dir).is_absolute() else Path(args.icons_dir)

    manifest = generate(out_dir, icons_dir)
    print(f"Generated {len(manifest)} kit files into {out_dir} / {icons_dir}:")
    for line_ in manifest:
        print(" -", line_)


if __name__ == "__main__":
    main()
