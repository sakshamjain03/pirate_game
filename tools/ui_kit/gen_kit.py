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

_BTN_FACE_H = 64          # design 32 — the visible button face height
_LIP_IDLE = dpx(6)        # design 6 -> canvas 12 (UITokens.LIP_IDLE)
_LIP_PRESSED = dpx(2)     # design 2 -> canvas 4 (UITokens.LIP_PRESSED)
_PRESS_DROP = dpx(4)      # design 4 -> canvas 8 (UITokens.PRESS_OFFSET_Y)
_BORDER = dpx(3)          # design 3 -> canvas 6 (UITokens.BORDER_WIDTH)
# Shared rectangular-button canvas: wide enough for a real label, and
# EXACTLY face + idle lip tall (== press drop + face + pressed lip) — no
# transparent padding below. The 9-slice stretches the whole canvas over
# the Button's rect, so any empty band here became an empty band at the
# bottom of every button, pushing the face up while the label stayed
# centred on the full rect — every label rendered half off its face (M22
# Phase 4 sweep, visible on every brass/primary button).
_BTN_W, _BTN_H = 240, _BTN_FACE_H + _LIP_IDLE
assert _BTN_H == _PRESS_DROP + _BTN_FACE_H + _LIP_PRESSED


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
        # Face centred on the canvas (M22 Phase 5): the canvas is stretched
        # over the whole Button rect, so a face sitting high in it (the
        # original diam/2 + 3 = 43% down) put every centred icon/label low and
        # onto the lip at any button size. The transparent band above is the
        # price of symmetric content margins that work at every size.
        face_y = (_PRESS_DROP if pressed else 0) + canvas_h / 2
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
    # Was dpx(31)/dpx(15) — half the spec, so the rendered toggle was a
    # 31x15-design sliver (M22 Phase 4 Settings sweep).
    w, h = dpx(62), dpx(30)
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
    track_h = dpx(14)     # was dpx(7) — half the spec (M22 Phase 4 sweep)
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

    knob_d = dpx(26)      # was dpx(13) — half the spec
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


def gen_dropdown_arrow() -> tuple[str, str]:
    """M22 Phase 4.3 — OptionButton's "arrow" icon. The engine default is a
    tiny light-grey chevron that vanishes on the brass button face; this is
    an ink chevron sized for a 32-canvas-px label (design 10x6 -> 20x12,
    plus stroke room)."""
    w, h = dpx(12), dpx(8)
    sw = dpx(1.5)
    pts = f"{sw:g},{sw:g} {w / 2:g},{h - sw:g} {w - sw:g},{sw:g}"
    body = (f'<polyline points="{pts}" fill="none" stroke="{PALETTE["ink"]}" '
            f'stroke-width="{sw * 1.4:g}" stroke-linecap="round" stroke-linejoin="round"/>')
    return svg_doc(w, h, body), f"dropdown_arrow: {w:g}x{h:g}"


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
    # design 30 tall (v0.3 HUD pills) -> 60 canvas; was dpx(18), sized before
    # any screen used it — too short for a 36px HudNum + 48px icon row.
    w, h = 160, dpx(30)
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


def gen_icon_gear() -> tuple[str, str]:
    """M22 Phase 4.1 — MainMenu's round Settings button glyph, not a resource
    icon (kept in the same icons_dir/UIIcons registry regardless — UIIcons
    is "every UI icon this project uses", not resources-only). A body disc +
    N radial teeth reads as "gear" at the small sizes a round nav button
    uses; the centre "hole" is a solid ink dot rather than true alpha
    transparency (simpler, and reads the same at this size — same pragmatic
    choice as cooldown_ring_mask's plain stroke ring)."""
    w = h = dpx(24)
    cx = cy = w / 2
    r_outer = w / 2 - dpx(2)
    r_body = r_outer * 0.68
    r_hole = r_outer * 0.28
    teeth = 8
    tooth_w = r_outer * 0.30
    tooth_h = r_outer * 0.38
    body = [circle(cx, cy, r_body, fill=PALETTE["brass_light"])]
    for i in range(teeth):
        angle = (2 * math.pi / teeth) * i
        tx = cx + math.cos(angle) * r_body
        ty = cy + math.sin(angle) * r_body
        deg = math.degrees(angle)
        body.append(
            f'<rect x="{tx - tooth_w / 2:g}" y="{ty - tooth_h / 2:g}" width="{tooth_w:g}" height="{tooth_h:g}" '
            f'fill="{PALETTE["brass_light"]}" transform="rotate({deg:g} {tx:g} {ty:g})"/>'
        )
    body.append(circle(cx, cy, r_body, fill="none", stroke=PALETTE["ink"], stroke_width=dpx(1.0)))
    body.append(circle(cx, cy, r_hole, fill=PALETTE["ink"]))
    svg = svg_doc(w, h, "\n".join(body))
    return svg, f"gear icon: {w:g}x{h:g}"


# --------------------------------------------------------------------------
# M22 Phase 5 — painted resource icons (replacing the Kenney white glyphs the
# HUD tinted per resource) and flat glyphs for the round HUD utility rail.
# Same 24-design-px canvas + upper-left light / darkest-tone outline as
# research/cannonball above (icon spec).
# --------------------------------------------------------------------------

def gen_icon_gold() -> tuple[str, str]:
    """A struck gold coin: gradient disc, inner rim ring, a stamped cross."""
    w = h = dpx(24)
    cx = cy = w / 2
    r = w / 2 - dpx(1)
    body = _resource_icon_base(cx, cy, r, "#FFF1B8", PALETTE["horizon_gold"], "#9A6A1E")
    body.append(circle(cx, cy, r * 0.68, fill="none", stroke="#9A6A1E", stroke_width=dpx(1.0), opacity=0.8))
    arm = r * 0.34
    body.append(path(f"M {cx:g} {cy - arm:g} L {cx:g} {cy + arm:g} M {cx - arm:g} {cy:g} L {cx + arm:g} {cy:g}",
                     stroke="#9A6A1E", stroke_width=dpx(1.2)))
    return svg_doc(w, h, "\n".join(body)), f"gold icon: {w:g}x{h:g}"


def gen_icon_wood() -> tuple[str, str]:
    """A sawn log end: bark ring + pale heartwood with growth rings."""
    w = h = dpx(24)
    cx = cy = w / 2
    r = w / 2 - dpx(1)
    body = [circle(cx, cy, r, fill=PALETTE["driftwood"])]
    body.append(circle(cx, cy, r * 0.8, fill="#D9A866"))
    for k in (0.58, 0.38, 0.18):
        body.append(circle(cx + r * 0.04, cy + r * 0.03, r * k, fill="none", stroke="#9C6A36", stroke_width=dpx(0.8)))
    body.append(circle(cx, cy, r - dpx(0.75), fill="none", stroke=PALETTE["wood_dark"], stroke_width=dpx(1.25)))
    body.append(circle(cx - r * 0.35, cy - r * 0.35, r * 0.12, fill="#FFFFFF", opacity=0.45))
    return svg_doc(w, h, "\n".join(body)), f"wood icon: {w:g}x{h:g}"


def gen_icon_iron() -> tuple[str, str]:
    """A cast ingot: lit top face + darker front face, cool grey-blue."""
    w = h = dpx(24)
    m = dpx(2)
    top = f"M {m + dpx(4):g} {dpx(7):g} L {w - m - dpx(4):g} {dpx(7):g} L {w - m:g} {dpx(12):g} L {m:g} {dpx(12):g} Z"
    front = f"M {m:g} {dpx(12):g} L {w - m:g} {dpx(12):g} L {w - m:g} {dpx(18):g} L {m:g} {dpx(18):g} Z"
    body = [path(front, fill="#5E6B78"), path(top, fill="#B9C6D2")]
    body.append(path(f"M {m:g} {dpx(12):g} L {m + dpx(4):g} {dpx(7):g} L {w - m - dpx(4):g} {dpx(7):g} "
                     f"L {w - m:g} {dpx(12):g} L {w - m:g} {dpx(18):g} L {m:g} {dpx(18):g} Z",
                     stroke="#2A323B", stroke_width=dpx(1.25)))
    body.append(rect(m + dpx(5), dpx(8), dpx(6), dpx(1.2), fill="#FFFFFF", opacity=0.55))
    return svg_doc(w, h, "\n".join(body)), f"iron icon: {w:g}x{h:g}"


def gen_icon_rum() -> tuple[str, str]:
    """A rum barrel: bulged staves + two brass hoops."""
    w = h = dpx(24)
    x0, x1, y0, y1 = dpx(5), w - dpx(5), dpx(3), h - dpx(3)
    bulge = dpx(2.5)
    d = (f"M {x0:g} {y0:g} Q {x0 - bulge:g} {h / 2:g} {x0:g} {y1:g} L {x1:g} {y1:g} "
         f"Q {x1 + bulge:g} {h / 2:g} {x1:g} {y0:g} Z")
    body = [defs(linear_gradient("rum_staves", [(0, "#B87A45", 1), (1, "#6D452A", 1)], x1=0, y1=0, x2=1, y2=0))]
    body.append(path(d, fill="url(#rum_staves)"))
    for yy in (dpx(7.5), h - dpx(7.5)):
        body.append(rect(x0 - bulge * 0.6, yy - dpx(1), (x1 - x0) + bulge * 1.2, dpx(2), fill=PALETTE["brass"]))
    body.append(path(d, stroke=PALETTE["wood_dark"], stroke_width=dpx(1.25)))
    body.append(rect(x0 + dpx(2), y0 + dpx(2), dpx(1.5), dpx(5), fill="#FFFFFF", opacity=0.4))
    return svg_doc(w, h, "\n".join(body)), f"rum icon: {w:g}x{h:g}"


_GLYPH = PALETTE["text_on_dark"]
_GLYPH_SW = dpx(1.8)


def gen_icon_log() -> tuple[str, str]:
    """Captain's Log — a rolled scroll with written lines."""
    w = h = dpx(24)
    body = [rect(dpx(5), dpx(4), dpx(14), dpx(16), rx=dpx(1.5), fill="none", stroke=_GLYPH, stroke_width=_GLYPH_SW)]
    for i in range(3):
        y = dpx(9) + i * dpx(3.5)
        body.append(path(f"M {dpx(8):g} {y:g} L {dpx(16):g} {y:g}", stroke=_GLYPH, stroke_width=dpx(1.3)))
    body.append(rect(dpx(3), dpx(3), dpx(18), dpx(3), rx=dpx(1.5), fill=_GLYPH))
    return svg_doc(w, h, "\n".join(body)), f"log icon: {w:g}x{h:g}"


def gen_icon_map() -> tuple[str, str]:
    """World Map — a three-panel folded chart with an X."""
    w = h = dpx(24)
    d = (f"M {dpx(3):g} {dpx(6):g} L {dpx(9):g} {dpx(4):g} L {dpx(15):g} {dpx(6):g} L {dpx(21):g} {dpx(4):g} "
         f"L {dpx(21):g} {dpx(18):g} L {dpx(15):g} {dpx(20):g} L {dpx(9):g} {dpx(18):g} L {dpx(3):g} {dpx(20):g} Z")
    body = [path(d, stroke=_GLYPH, stroke_width=_GLYPH_SW)]
    body.append(path(f"M {dpx(9):g} {dpx(4):g} L {dpx(9):g} {dpx(18):g} M {dpx(15):g} {dpx(6):g} L {dpx(15):g} {dpx(20):g}",
                     stroke=_GLYPH, stroke_width=dpx(1.2)))
    body.append(path(f"M {dpx(16.5):g} {dpx(9.5):g} L {dpx(19.5):g} {dpx(12.5):g} M {dpx(19.5):g} {dpx(9.5):g} L {dpx(16.5):g} {dpx(12.5):g}",
                     stroke=PALETTE["coral_bloom"], stroke_width=dpx(1.6)))
    return svg_doc(w, h, "\n".join(body)), f"map icon: {w:g}x{h:g}"


def gen_icon_codex() -> tuple[str, str]:
    """Codex — an open book."""
    w = h = dpx(24)
    left = f"M {dpx(12):g} {dpx(7):g} Q {dpx(8):g} {dpx(5):g} {dpx(3):g} {dpx(6):g} L {dpx(3):g} {dpx(19):g} Q {dpx(8):g} {dpx(18):g} {dpx(12):g} {dpx(20):g} Z"
    right = f"M {dpx(12):g} {dpx(7):g} Q {dpx(16):g} {dpx(5):g} {dpx(21):g} {dpx(6):g} L {dpx(21):g} {dpx(19):g} Q {dpx(16):g} {dpx(18):g} {dpx(12):g} {dpx(20):g} Z"
    body = [path(left, stroke=_GLYPH, stroke_width=_GLYPH_SW), path(right, stroke=_GLYPH, stroke_width=_GLYPH_SW)]
    return svg_doc(w, h, "\n".join(body)), f"codex icon: {w:g}x{h:g}"


def gen_icon_new() -> tuple[str, str]:
    """What's New — a five-point star burst."""
    w = h = dpx(24)
    cx = cy = w / 2
    pts = []
    for i in range(10):
        rr = (w / 2 - dpx(2)) if i % 2 == 0 else (w / 2 - dpx(2)) * 0.45
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(f"{cx + math.cos(a) * rr:g},{cy + math.sin(a) * rr:g}")
    body = [f'<polygon points="{" ".join(pts)}" fill="{_GLYPH}" stroke="{PALETTE["ink"]}" stroke-width="{dpx(0.8):g}"/>']
    return svg_doc(w, h, "\n".join(body)), f"new icon: {w:g}x{h:g}"


def gen_icon_wardrobe() -> tuple[str, str]:
    """Wardrobe — a pirate tricorn hat."""
    w = h = dpx(24)
    crown = f"M {dpx(6):g} {dpx(13):g} Q {dpx(12):g} {dpx(2):g} {dpx(18):g} {dpx(13):g} Z"
    brim = f"M {dpx(1.5):g} {dpx(11):g} Q {dpx(12):g} {dpx(20):g} {dpx(22.5):g} {dpx(11):g} Q {dpx(12):g} {dpx(15):g} {dpx(1.5):g} {dpx(11):g} Z"
    body = [path(crown, fill=_GLYPH), path(brim, fill=_GLYPH, stroke=PALETTE["ink"], stroke_width=dpx(0.8))]
    body.append(circle(dpx(12), dpx(9), dpx(1.3), fill=PALETTE["ink"]))
    return svg_doc(w, h, "\n".join(body)), f"wardrobe icon: {w:g}x{h:g}"


def gen_cooldown_disc() -> tuple[str, str]:
    """M22 Phase 5.4 — the fill texture for a round button's clockwise
    cooldown sweep (TextureProgressBar FILL_CLOCKWISE). Solid white so the
    node's tint_progress decides the colour; sized to the wood-round face
    (58 design px)."""
    d = dpx(58)
    return svg_doc(d, d, circle(d / 2, d / 2, d / 2, fill="#FFFFFF")), f"cooldown_disc: {d:g}x{d:g}"


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
    svg, meta = gen_dropdown_arrow(); emit("dropdown_arrow", svg, meta)
    for stem, svg, meta in gen_scrollbar():
        emit(stem, svg, meta)

    svg, meta = gen_resource_pill(); emit("resource_pill", svg, meta)
    for name in RARITY:
        svg, meta = gen_rarity_gem(name); emit(f"rarity_gem_{name}", svg, meta)
    svg, meta = gen_cooldown_ring_mask(); emit("cooldown_ring_mask", svg, meta)
    svg, meta = gen_cooldown_disc(); emit("cooldown_disc", svg, meta)
    svg, meta = gen_glow_sprite(); emit("glow_sprite", svg, meta)

    icons_dir.mkdir(parents=True, exist_ok=True)
    svg, meta = gen_icon_research()
    _write(icons_dir / "research.svg", svg)
    manifest.append(meta)
    svg, meta = gen_icon_cannonball()
    _write(icons_dir / "cannonball.svg", svg)
    manifest.append(meta)
    svg, meta = gen_icon_gear()
    _write(icons_dir / "gear.svg", svg)
    manifest.append(meta)
    for stem, fn in (("gold", gen_icon_gold), ("wood", gen_icon_wood), ("iron", gen_icon_iron),
                     ("rum", gen_icon_rum), ("log", gen_icon_log), ("map", gen_icon_map),
                     ("codex", gen_icon_codex), ("new", gen_icon_new), ("wardrobe", gen_icon_wardrobe)):
        svg, meta = fn()
        _write(icons_dir / f"{stem}.svg", svg)
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
