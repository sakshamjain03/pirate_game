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
    """v0.3 corner stud: radial-gradient(circle at 35% 30%, #fff3c4 0,
    #e2b75a 35%, #8a6224 75%, #4a3210 100%) + a 1px drop shadow."""
    gid = f"stud_{cx:g}_{cy:g}".replace(".", "_")
    return (
        defs(radial_gradient(gid, [(0, "#FFF3C4", 1), (0.35, "#E2B75A", 1), (0.75, "#8A6224", 1),
                                     (1, "#4A3210", 1)], cx=0.35, cy=0.3, r=0.75))
        + circle(cx, cy + dpx(1), r, fill="#000000", opacity=0.35)
        + circle(cx, cy, r, fill=f"url(#{gid})")
    )


# --------------------------------------------------------------------------
# M22 Phase 6c — v0.3 materials, lifted verbatim from the doc's component CSS
# (design.md §13). Every colour/stop below is the doc's own value; sizes are
# design px x2 via dpx().
# --------------------------------------------------------------------------

# repeating-linear-gradient(178deg, #5b3920 0 2px, #6d452a 2px 7px,
#   #63401f 7px 9px, #7a4e2e 9px 15px, #5f3b21 15px 17px) — the v0.3 plank.
PLANK_BANDS = [(0, 2, "#5B3920"), (2, 7, "#6D452A"), (7, 9, "#63401F"), (9, 15, "#7A4E2E"), (15, 17, "#5F3B21")]
PLANK_PERIOD = dpx(17)
# Disabled / greyed wood (v0.3 "Board — no target in range").
PLANK_BANDS_GREY = [(0, 2, "#554B42"), (2, 7, "#62574C"), (7, 9, "#5A5048"), (9, 15, "#685D52"), (15, 17, "#5A5048")]


def plank_rects(x, y, w, h, bands=PLANK_BANDS) -> str:
    """Horizontal plank bands filling (x,y,w,h), period dpx(17), starting at
    band 0 on y — so a 9-slice centre that is a whole number of periods
    tiles seamlessly (StyleBoxTexture axis_stretch TILE)."""
    out = []
    period = dpx(17)
    yy = y
    while yy < y + h:
        for a, b, col in bands:
            top = yy + dpx(a)
            bot = min(yy + dpx(b), y + h)
            if top >= y + h:
                break
            out.append(rect(x, top, w, bot - top, fill=col))
        yy += period
    return "\n".join(out)


def clip_rrect(cid, x, y, w, h, r) -> str:
    return f'<clipPath id="{cid}"><rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" rx="{r:g}"/></clipPath>'


def clip_circle(cid, cx, cy, r) -> str:
    return f'<clipPath id="{cid}"><circle cx="{cx:g}" cy="{cy:g}" r="{r:g}"/></clipPath>'


def inset_shadow(x, y, w, h, r, colour, strength, depth, steps=12) -> str:
    """No SVG filters under ThorVG, so v0.3's `box-shadow: inset 0 0 Npx`
    is built from nested rounded-rect strokes fading inward."""
    out = []
    step = depth / steps
    for i in range(steps):
        t = i / steps
        op = strength * (1.0 - t) ** 1.8 / 2.2
        inset = step * i + step / 2
        out.append(rect(x + inset, y + inset, w - 2 * inset, h - 2 * inset,
                        rx=max(0.0, r - inset), fill="none", stroke=colour,
                        stroke_width=step, opacity=op))
    return "\n".join(out)


WOOD_FRAME_MARGIN = 56   # radius 36 + border 6 + stud room; theme MARGIN_WOOD_FRAME
WOOD_FRAME_CENTRE = 2 * PLANK_PERIOD


def gen_wood_frame() -> tuple[str, str]:
    """v0.3 modal frame: border-radius 18, 3px #2e1a0c border, plank wood,
    a warm top sheen / dark foot (linear 180deg rgba(255,215,150,.18) ->
    rgba(0,0,0,.3)), inset 0 2px 0 rgba(255,220,170,.35) top light and 11px
    brass studs 8px in from each corner. The centre is exactly two plank
    periods so the theme can TILE it vertically without stretching planks."""
    m = WOOD_FRAME_MARGIN
    w = h = 2 * m + WOOD_FRAME_CENTRE
    r = dpx(18)
    bw = dpx(3)
    body = [defs(
        clip_rrect("fclip", 0, 0, w, h, r),
        linear_gradient("fsheen", [(0, "#FFD796", 0.18), (1, "#FFD796", 0)], x1=0, y1=0, x2=0, y2=1),
        linear_gradient("ffoot", [(0, "#000000", 0), (1, "#000000", 0.3)], x1=0, y1=0, x2=0, y2=1),
    )]
    body.append(f'<g clip-path="url(#fclip)">')
    body.append(plank_rects(0, 0, w, h))
    body.append(rect(0, 0, w, m, fill="url(#fsheen)"))
    body.append(rect(0, h - m, w, m, fill="url(#ffoot)"))
    body.append(rect(r, bw, w - 2 * r, dpx(2), fill="#FFDCAA", opacity=0.35))
    body.append("</g>")
    body.append(rect(bw / 2, bw / 2, w - bw, h - bw, rx=r - bw / 2, fill="none",
                     stroke=PALETTE["wood_dark"], stroke_width=bw))
    stud_r = dpx(5.5)
    inset = dpx(8) + stud_r
    for cx, cy in [(inset, inset), (w - inset, inset), (inset, h - inset), (w - inset, h - inset)]:
        body.append(brass_stud(cx, cy, stud_r))
    return svg_doc(w, h, "\n".join(body)), f"wood_frame: {w:g}x{h:g}, 9-slice margin {m:g}px, centre {WOOD_FRAME_CENTRE:g} (tile)"


def gen_wood_plaque() -> tuple[str, str]:
    """v0.3 title plaque ("Port Royal"): radius 12, 3px border, the same
    planks + sheen, a brass stud centred in each end cap."""
    w, h = 400, 120
    end = dpx(32)
    r = dpx(12)
    bw = dpx(3)
    body = [defs(
        clip_rrect("pclip", 0, 0, w, h, r),
        linear_gradient("psheen", [(0, "#FFD796", 0.22), (1, "#000000", 0.25)], x1=0, y1=0, x2=0, y2=1),
    )]
    body.append('<g clip-path="url(#pclip)">')
    body.append(plank_rects(0, 0, w, h))
    body.append(rect(0, 0, w, h, fill="url(#psheen)"))
    body.append(rect(r, bw, w - 2 * r, dpx(2), fill="#FFDCAA", opacity=0.35))
    body.append("</g>")
    body.append(rect(bw / 2, bw / 2, w - bw, h - bw, rx=r - bw / 2, fill="none",
                     stroke=PALETTE["wood_dark"], stroke_width=bw))
    # Studs hug the ends (dpx(10) in) so the 48px content inset never
    # reaches them — at end*0.5 they sat under the HUD speed text.
    for ex in (dpx(10), w - dpx(10)):
        body.append(brass_stud(ex, h / 2, dpx(5)))
    return svg_doc(w, h, "\n".join(body)), f"wood_plaque: {w:g}x{h:g}, 3-slice ends {end:g}px (horizontal)"


PARCHMENT_MARGIN = 56


def _parchment_body(x, y, w, h, r, *, with_grain=True, burn=False) -> list[str]:
    """v0.3 parchment page: radial-gradient(ellipse at 20% 10%, #fdf1d2 0%,
    transparent 55%), repeating-linear-gradient(8deg, rgba(120,80,30,.05)
    0 2px, transparent 2px 7px), #ecd6a4; inset 0 0 24px rgba(110,70,25,.45).
    `burn` adds the toast's warm lower-right (radial at 85% 95%,
    rgba(150,95,40,.35))."""
    body = [defs(
        clip_rrect(f"pc{int(w)}_{int(h)}", x, y, w, h, r),
        radial_gradient("phi", [(0, "#FDF1D2", 1), (0.55, "#FDF1D2", 0)], cx=0.2, cy=0.1, r=0.7),
        radial_gradient("pburn", [(0, "#965F28", 0.35), (0.5, "#965F28", 0)], cx=0.85, cy=0.95, r=0.6),
    )]
    body.append(rect(x, y, w, h, rx=r, fill=PALETTE["parchment"]))
    body.append(f'<g clip-path="url(#pc{int(w)}_{int(h)})">')
    body.append(rect(x, y, w, h, fill="url(#phi)"))
    if burn:
        body.append(rect(x, y, w, h, fill="url(#pburn)"))
    if with_grain:
        # 8deg hairlines every 7 design px
        yy = y - dpx(10)
        while yy < y + h + dpx(10):
            body.append(line(x, yy, x + w, yy + w * math.tan(math.radians(8)) * 0.15,
                             stroke="#78501E", stroke_width=dpx(2) * 0.5, opacity=0.05, cap="butt"))
            yy += dpx(7)
    body.append(inset_shadow(x, y, w, h, r, "#6E4619", 0.45, dpx(24) * 0.9))
    body.append("</g>")
    return body


def gen_parchment_panel() -> tuple[str, str]:
    """9-slice page (Settings/Log/Codex …): radius 12, no deckle or dirt —
    v0.3's page is clean warm paper; the highlight/grain are all it has."""
    w = h = 240
    # No grain here: the page centre stretches to screen size and a 1px
    # hairline became a thick visible band (M22 6c sweep).
    body = _parchment_body(0, 0, w, h, dpx(12), with_grain=False)
    return svg_doc(w, h, "\n".join(body)), f"parchment_panel: {w:g}x{h:g}, 9-slice margin {PARCHMENT_MARGIN:g}px"


ROPE_MARGIN = 56
ROPE_STRIPE = dpx(4)       # 45deg stripes, 4px each colour (v0.3)


def gen_rope_parchment() -> tuple[str, str]:
    """v0.3 tutorial-toast card: a 3px rope border
    (repeating-linear-gradient(45deg, #c8a36a 0 4px, #8a6a3a 4px 8px),
    radius 18) around a radius-15 parchment with the warm burn, plus 10px
    studs. Rope stripes tile: the canvas period is 2*ROPE_STRIPE*sqrt2 on
    both axes and the theme sets axis_stretch TILE_FIT."""
    period = 2 * ROPE_STRIPE * math.sqrt(2)          # horizontal period of 45deg stripes
    n_centre = 3
    w = h = round(2 * ROPE_MARGIN + period * n_centre)
    r_out = dpx(18)
    pad = dpx(3)
    body = [defs(clip_rrect("rclip", 0, 0, w, h, r_out))]
    body.append(rect(0, 0, w, h, rx=r_out, fill="#8A6A3A"))
    body.append('<g clip-path="url(#rclip)">')
    k = -h
    while k < w + h:
        # a 45deg light stripe: band between lines x - y = k and x - y = k + stripe*sqrt2
        s = ROPE_STRIPE * math.sqrt(2)
        body.append(path(f"M {k:g} 0 L {k + s:g} 0 L {k + s + h:g} {h:g} L {k + h:g} {h:g} Z", fill="#C8A36A"))
        k += period
    body.append("</g>")
    body.extend(_parchment_body(pad, pad, w - 2 * pad, h - 2 * pad, dpx(15), burn=True))
    for cx, cy in [(dpx(12), dpx(12)), (w - dpx(12), dpx(12)), (dpx(12), h - dpx(12)), (w - dpx(12), h - dpx(12))]:
        body.append(brass_stud(cx, cy, dpx(5)))
    return svg_doc(w, h, "\n".join(body)), f"rope_parchment: {w:g}x{h:g}, 9-slice margin {ROPE_MARGIN:g}px (tile)"


TORN_MARGIN = 56
TORN_PERIOD = 96          # the jag pattern repeats exactly every TORN_PERIOD px


def _torn_edge_offsets(seed: str, n: int, amp: float) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(0.0, amp) for _ in range(n)]


def gen_torn_parchment() -> tuple[str, str]:
    """v0.3 dossier sheet (screen 01/02 detail panel): the page parchment with
    a torn top and bottom edge (the doc's clip-path polygon of ~2-3% jags) and
    a stronger burn (inset 0 0 28px rgba(110,70,25,.5)). The jag pattern is
    periodic in TORN_PERIOD so the theme can TILE the width seamlessly."""
    m = TORN_MARGIN
    w = 2 * m + TORN_PERIOD
    h = 2 * m + 64
    amp = dpx(5)
    steps = 8                       # jag points per period
    top = _torn_edge_offsets("torn-top", steps, amp)
    bot = _torn_edge_offsets("torn-bot", steps, amp)
    pts = []
    x = 0.0
    i = 0
    while x <= w + 0.01:
        pts.append((x, top[i % steps]))
        x += TORN_PERIOD / steps
        i += 1
    right = [(w, h * t) for t in (0.3, 0.7)]
    bpts = []
    x = w
    i = 0
    # walk the bottom right-to-left with the SAME periodic phase as left-to-right
    xs = []
    x = 0.0
    while x <= w + 0.01:
        xs.append(x)
        x += TORN_PERIOD / steps
    for k, xx in enumerate(reversed(xs)):
        idx = (len(xs) - 1 - k) % steps
        bpts.append((xx, h - bot[idx]))
    d = "M " + " L ".join(f"{px:.1f} {py:.1f}" for px, py in pts + right + bpts) + " Z"
    body = [defs(
        f'<clipPath id="tclip"><path d="{d}"/></clipPath>',
        radial_gradient("thi", [(0, "#FDF1D2", 1), (0.55, "#FDF1D2", 0)], cx=0.25, cy=0.15, r=0.7),
        radial_gradient("tburn", [(0, "#965F28", 0.4), (0.5, "#965F28", 0)], cx=0.85, cy=0.95, r=0.6),
    )]
    body.append(path(d, fill=PALETTE["parchment"]))
    body.append('<g clip-path="url(#tclip)">')
    body.append(rect(0, 0, w, h, fill="url(#thi)"))
    body.append(rect(0, 0, w, h, fill="url(#tburn)"))
    body.append(inset_shadow(0, 0, w, h, 0, "#6E4619", 0.5, dpx(28) * 0.9))
    body.append("</g>")
    body.append(path(d, fill="none", stroke="#6E4619", stroke_width=1.5, opacity=0.35))
    return svg_doc(w, h, "\n".join(body)), f"torn_parchment: {w:g}x{h:g}, 9-slice margin {m:g}px, tile x"


# --------------------------------------------------------------------------
# Buttons — v0.3 brass / coral / disabled faces, round wood
# --------------------------------------------------------------------------

_BTN_FACE_H = 64          # the visible face in the texture (stretched to the button)
_LIP_IDLE = dpx(6)        # UITokens.LIP_IDLE
_LIP_PRESSED = dpx(2)     # UITokens.LIP_PRESSED
_PRESS_DROP = dpx(4)      # UITokens.PRESS_OFFSET_Y
_BORDER = dpx(3)          # UITokens.BORDER_WIDTH
# Canvas is EXACTLY face + idle lip tall (see the Phase 4 note in git
# history): any empty band here shows as an empty band under every button.
_BTN_W, _BTN_H = 240, _BTN_FACE_H + _LIP_IDLE
assert _BTN_H == _PRESS_DROP + _BTN_FACE_H + _LIP_PRESSED

BTN_FAMILIES = {
    # v0.3 brass: linear-gradient(180deg,#f7de98 0%,#d9ab52 40%,#a8772e 75%,
    # #c99a48 100%), border #4a300f, lip 0 5px 0 #5a3a12, inset 0 2px 0
    # rgba(255,250,220,.7).
    "brass": {"kind": "linear", "stops": [(0, "#F7DE98"), (0.4, "#D9AB52"), (0.75, "#A8772E"), (1, "#C99A48")],
              "border": "#4A300F", "lip": "#5A3A12", "hi": ("#FFFADC", 0.7), "foot": None, "radius": dpx(14)},
    # v0.3 coral: radial-gradient(ellipse 80% 60% at 50% 16%, #ffd6ae 0%,
    # #ff9d5e 30%, #f0602a 66%, #b83a14 100%), border #4a1d08, lip #6a260c,
    # inset top rgba(255,255,255,.6), inset 0 -5px 0 rgba(120,30,0,.3).
    "primary": {"kind": "radial", "stops": [(0, "#FFD6AE"), (0.3, "#FF9D5E"), (0.66, "#F0602A"), (1, "#B83A14")],
                "border": "#4A1D08", "lip": "#6A260C", "hi": ("#FFFFFF", 0.6), "foot": ("#781E00", 0.3),
                "radius": dpx(18)},
    # v0.3 greyed: linear-gradient(180deg,#8a7a66,#5e5040), border #3a2e22.
    "disabled": {"kind": "linear", "stops": [(0, "#8A7A66"), (1, "#5E5040")],
                 "border": "#3A2E22", "lip": "#2A241E", "hi": ("#FFFFFF", 0.12), "foot": None, "radius": dpx(14)},
}


def _face_gradient(gid, fam) -> str:
    stops = [(o, c, 1) for o, c in fam["stops"]]
    if fam["kind"] == "linear":
        return linear_gradient(gid, stops, x1=0, y1=0, x2=0, y2=1)
    body = "".join(f'<stop offset="{o:g}" stop-color="{c}" stop-opacity="1"/>' for o, c, _ in stops)
    # ellipse 80% x 60% of the box, centred at (50%, 16%)
    return (f'<radialGradient id="{gid}" cx="0.5" cy="0.16" r="1" '
            f'gradientTransform="translate(0.5 0.16) scale(0.8 0.6) translate(-0.5 -0.16)">{body}</radialGradient>')


def _rounded_button_svg(fam_name: str, *, pressed: bool, radius: float | None = None) -> str:
    fam = BTN_FAMILIES[fam_name]
    r = radius if radius is not None else fam["radius"]
    face_y = _PRESS_DROP if pressed else 0
    lip_h = _LIP_PRESSED if pressed else _LIP_IDLE
    gid = f"face_{fam_name}_{'p' if pressed else 'i'}"
    body = [defs(_face_gradient(gid, fam), clip_rrect(f"c{gid}", 0, face_y, _BTN_W, _BTN_FACE_H, r))]
    # solid lip slab directly under the face
    body.append(rect(0, face_y + _BTN_FACE_H - r, _BTN_W, lip_h + r, rx=r, fill=fam["lip"]))
    body.append(rect(0, face_y, _BTN_W, _BTN_FACE_H, rx=r, fill=f"url(#{gid})"))
    body.append(f'<g clip-path="url(#c{gid})">')
    hi_col, hi_op = fam["hi"]
    body.append(rect(0, face_y + _BORDER, _BTN_W, dpx(2), fill=hi_col, opacity=hi_op if not pressed else hi_op * 0.6))
    if fam["foot"]:
        f_col, f_op = fam["foot"]
        body.append(rect(0, face_y + _BTN_FACE_H - _BORDER - dpx(5), _BTN_W, dpx(5), fill=f_col, opacity=f_op))
    body.append("</g>")
    body.append(rect(_BORDER / 2, face_y + _BORDER / 2, _BTN_W - _BORDER, _BTN_FACE_H - _BORDER,
                     rx=max(0, r - _BORDER / 2), fill="none", stroke=fam["border"], stroke_width=_BORDER))
    return svg_doc(_BTN_W, _BTN_H, "\n".join(body))


def _round_button_svg(state: str, *, coral: bool = False) -> tuple[str, float, float]:
    """v0.3 round buttons. Wood: planks + radial-gradient(circle at 35% 25%,
    rgba(255,220,160,.35), transparent 55%), 3px #2e1a0c, lip 0 6px 0
    #24140a, inset top light. Disabled: grey planks, #3a2e22 border."""
    pressed = state == "pressed"
    disabled = state == "disabled"
    diam = dpx(58)
    canvas_w = diam + dpx(6)
    canvas_h = diam + _LIP_IDLE + dpx(10)
    cx = canvas_w / 2
    face_cy = (_PRESS_DROP if pressed else 0) + canvas_h / 2
    lip_h = _LIP_PRESSED if pressed else _LIP_IDLE
    border = "#3A2E22" if disabled else PALETTE["wood_dark"]
    lip = "#2A241E" if disabled else "#24140A"
    gid = f"rw_{state}"
    body = [defs(clip_circle(f"c{gid}", cx, face_cy, diam / 2),
                 radial_gradient(f"h{gid}", [(0, "#FFDCA0", 0.35), (0.55, "#FFDCA0", 0)], cx=0.35, cy=0.25, r=0.75))]
    body.append(rect(cx - diam / 2, face_cy, diam, diam / 2 + lip_h, rx=diam / 2, fill=lip))
    body.append(f'<g clip-path="url(#c{gid})">')
    body.append(plank_rects(cx - diam / 2, face_cy - diam / 2, diam, diam,
                            bands=PLANK_BANDS_GREY if disabled else PLANK_BANDS))
    if not disabled:
        body.append(circle(cx, face_cy, diam / 2, fill=f"url(#h{gid})"))
        body.append(rect(cx - diam / 2, face_cy - diam / 2 + _BORDER, diam, dpx(2), fill="#FFDCAA", opacity=0.35))
    body.append("</g>")
    body.append(circle(cx, face_cy, diam / 2 - _BORDER / 2, fill="none", stroke=border, stroke_width=_BORDER))
    return svg_doc(canvas_w, canvas_h, "\n".join(body)), canvas_w, canvas_h


def gen_buttons() -> list[tuple[str, str, str]]:
    out = []
    for name, fam in (("button_primary", "primary"), ("button_brass", "brass")):
        r = BTN_FAMILIES[fam]["radius"]
        out.append((f"{name}_idle", _rounded_button_svg(fam, pressed=False), f"{name}_idle: {_BTN_W}x{_BTN_H}, radius {r:g}"))
        out.append((f"{name}_pressed", _rounded_button_svg(fam, pressed=True), f"{name}_pressed: {_BTN_W}x{_BTN_H}, radius {r:g}"))
        out.append((f"{name}_disabled", _rounded_button_svg("disabled", pressed=False, radius=r),
                    f"{name}_disabled: {_BTN_W}x{_BTN_H}, radius {r:g}"))
    for state in ("idle", "pressed", "disabled"):
        svg, cw, ch = _round_button_svg(state)
        out.append((f"button_wood_round_{state}", svg, f"button_wood_round_{state}: {cw:g}x{ch:g}"))
    return out


# --------------------------------------------------------------------------
# Controls — v0.3 toggle, slider, segmented, tabs, dropdown, scrollbar
# --------------------------------------------------------------------------

def _knob(cx, cy, r, gid) -> str:
    """Brass knob: radial-gradient(circle at 35% 30%, #fff3c4 0, #e2b75a 40%,
    #8a6224 100%), 1.5-2px #3a2410 border, 0 2px 2px rgba(0,0,0,.4)."""
    return (defs(radial_gradient(gid, [(0, "#FFF3C4", 1), (0.4, "#E2B75A", 1), (1, "#8A6224", 1)], cx=0.35, cy=0.3, r=0.75))
            + circle(cx, cy + dpx(1.5), r, fill="#000000", opacity=0.35)
            + circle(cx, cy, r, fill=f"url(#{gid})")
            + circle(cx, cy, r - dpx(0.75), fill="none", stroke="#3A2410", stroke_width=dpx(1.5)))


def gen_toggle(is_on: bool) -> tuple[str, str]:
    """62x30, radius 15, 2px #3a2410 border, inset 0 2px 4px rgba(0,0,0,.45);
    off #5a4632, on linear-gradient(180deg,#2a9a96,#17616a); 24px knob."""
    w, h = dpx(62), dpx(30)
    r = h / 2
    bw = dpx(2)
    body = [defs(linear_gradient("ton", [(0, "#2A9A96", 1), (1, "#17616A", 1)], x1=0, y1=0, x2=0, y2=1),
                 linear_gradient("tin", [(0, "#000000", 0.45), (1, "#000000", 0)], x1=0, y1=0, x2=0, y2=1),
                 clip_rrect("tclip", 0, 0, w, h, r))]
    body.append(rect(0, 0, w, h, rx=r, fill="url(#ton)" if is_on else "#5A4632"))
    body.append('<g clip-path="url(#tclip)">')
    body.append(rect(0, bw, w, dpx(4), fill="url(#tin)"))
    body.append("</g>")
    body.append(rect(bw / 2, bw / 2, w - bw, h - bw, rx=r - bw / 2, fill="none", stroke="#3A2410", stroke_width=bw))
    kr = dpx(12)
    kcx = (w - bw - dpx(2) - kr) if is_on else (bw + dpx(2) + kr)
    body.append(_knob(kcx, h / 2, kr, "tknob"))
    return svg_doc(w, h, "\n".join(body)), f"toggle_{'on' if is_on else 'off'}: {w:g}x{h:g}"


def gen_rope_slider() -> list[tuple[str, str, str]]:
    """Track: 14px tall, radius 7, #3a2616, 2px #4a300f border, inset shadow.
    Fill: linear-gradient(180deg,#8fe0d6,#1f8a8c 60%,#17616a) inside the
    border. Knob: 26px brass."""
    out = []
    th = dpx(14)
    w = 200
    bw = dpx(2)
    track = [defs(linear_gradient("sin", [(0, "#000000", 0.5), (1, "#000000", 0)], x1=0, y1=0, x2=0, y2=1),
                  clip_rrect("sclip", 0, 0, w, th, th / 2))]
    track.append(rect(0, 0, w, th, rx=th / 2, fill="#3A2616"))
    track.append('<g clip-path="url(#sclip)">' + rect(0, bw, w, dpx(3), fill="url(#sin)") + "</g>")
    track.append(rect(bw / 2, bw / 2, w - bw, th - bw, rx=th / 2 - bw / 2, fill="none", stroke="#4A300F", stroke_width=bw))
    out.append(("rope_slider_track", svg_doc(w, th, "\n".join(track)), f"rope_slider_track: {w:g}x{th:g}"))

    fill = [defs(linear_gradient("sfill", [(0, "#8FE0D6", 1), (0.6, "#1F8A8C", 1), (1, "#17616A", 1)], x1=0, y1=0, x2=0, y2=1))]
    fill.append(rect(bw, bw, w - 2 * bw, th - 2 * bw, rx=dpx(5), fill="url(#sfill)"))
    out.append(("rope_slider_fill", svg_doc(w, th, "\n".join(fill)), f"rope_slider_fill: {w:g}x{th:g}"))

    kd = dpx(26)
    kw, kh = kd + dpx(2), kd + dpx(3)
    out.append(("rope_slider_knob", svg_doc(kw, kh, _knob(kw / 2, kd / 2 + dpx(0.5), kd / 2 - dpx(0.5), "sknob")),
                f"rope_slider_knob: {kw:g}x{kh:g}"))
    return out


def gen_segmented() -> list[tuple[str, str, str]]:
    """Well: #3a2616, radius 12, inset 0 2px 3px rgba(0,0,0,.5). Selected
    pill: linear-gradient(180deg,#f7de98,#c89a45), radius 9."""
    out = []
    w, h = 160, dpx(30)
    well = [defs(linear_gradient("win", [(0, "#000000", 0.5), (1, "#000000", 0)], x1=0, y1=0, x2=0, y2=1),
                 clip_rrect("wclip", 0, 0, w, h, dpx(12)))]
    well.append(rect(0, 0, w, h, rx=dpx(12), fill="#3A2616"))
    well.append('<g clip-path="url(#wclip)">' + rect(0, 0, w, dpx(4), fill="url(#win)") + "</g>")
    out.append(("segmented_well", svg_doc(w, h, "\n".join(well)), f"segmented_well: {w:g}x{h:g}"))
    pill = [defs(linear_gradient("pill", [(0, "#F7DE98", 1), (1, "#C89A45", 1)], x1=0, y1=0, x2=0, y2=1))]
    pill.append(rect(0, 0, w, h - dpx(6), rx=dpx(9), fill="url(#pill)"))
    out.append(("segmented_pill", svg_doc(w, h - dpx(6), "\n".join(pill)), f"segmented_pill: {w:g}x{h - dpx(6):g}"))
    return out


def gen_tabs() -> list[tuple[str, str, str]]:
    """v0.3 tab rail. Idle: rgba(0,0,0,.28), radius 10. Active: the page's
    own #ecd6a4 with its highlight, square where it meets the page, and a
    3px brass edge (v0.3's inset 3px #c29444, on the top for a horizontal
    rail)."""
    out = []
    w, h = 140, dpx(34)
    r = dpx(10)
    idle = [path(f"M 0 {h:g} L 0 {r:g} Q 0 0 {r:g} 0 L {w - r:g} 0 Q {w:g} 0 {w:g} {r:g} L {w:g} {h:g} Z",
                 fill="#000000", opacity=0.28)]
    out.append(("tab_idle", svg_doc(w, h, "\n".join(idle)), f"tab_idle: {w:g}x{h:g}"))
    active = [defs(radial_gradient("tabhi", [(0, "#FDF1D2", 1), (0.6, "#FDF1D2", 0)], cx=0.25, cy=0.2, r=0.8))]
    shape = f"M 0 {h:g} L 0 {r:g} Q 0 0 {r:g} 0 L {w - r:g} 0 Q {w:g} 0 {w:g} {r:g} L {w:g} {h:g} Z"
    active.append(path(shape, fill=PALETTE["parchment"]))
    active.append(path(shape, fill="url(#tabhi)"))
    active.append(rect(r * 0.6, 0, w - r * 1.2, dpx(3), rx=dpx(1.5), fill=PALETTE["brass"]))
    out.append(("tab_active", svg_doc(w, h, "\n".join(active)), f"tab_active: {w:g}x{h:g}"))
    return out


def gen_dropdown_sheet() -> tuple[str, str]:
    """Popup list sheet — the same clean parchment as the page, with an ink
    rim so it reads as a separate sheet over the page."""
    w, h = 220, 160
    body = _parchment_body(0, 0, w, h, dpx(10), with_grain=False)
    body.append(rect(1.5, 1.5, w - 3, h - 3, rx=dpx(10) - 1.5, fill="none", stroke="#4A300F", stroke_width=3))
    return svg_doc(w, h, "\n".join(body)), f"dropdown_sheet: {w:g}x{h:g}"


def gen_dropdown_arrow() -> tuple[str, str]:
    w, h = dpx(12), dpx(8)
    sw = dpx(1.5)
    pts = f"{sw:g},{sw:g} {w / 2:g},{h - sw:g} {w - sw:g},{sw:g}"
    body = (f'<polyline points="{pts}" fill="none" stroke="#3A2410" '
            f'stroke-width="{sw * 1.4:g}" stroke-linecap="round" stroke-linejoin="round"/>')
    return svg_doc(w, h, body), f"dropdown_arrow: {w:g}x{h:g}"


def gen_scrollbar() -> list[tuple[str, str, str]]:
    out = []
    w, h = dpx(4), 200
    out.append(("scrollbar_track", svg_doc(w, h, rect(0, 0, w, h, rx=w / 2, fill="#3A2616", opacity=0.3)),
                f"scrollbar_track: {w:g}x{h:g}"))
    gw, gh = dpx(4), 60
    grabber = [defs(linear_gradient("sg", [(0, "#F7DE98", 1), (1, "#C89A45", 1)], x1=0, y1=0, x2=1, y2=0))]
    grabber.append(rect(0, 0, gw, gh, rx=gw / 2, fill="url(#sg)"))
    out.append(("scrollbar_grabber", svg_doc(gw, gh, "\n".join(grabber)), f"scrollbar_grabber: {gw:g}x{gh:g}"))
    return out


# --------------------------------------------------------------------------
# Misc — resource pill, rarity gem borders, cooldown ring mask, glow
# --------------------------------------------------------------------------

def gen_resource_pill() -> tuple[str, str]:
    """v0.3 HUD pill: linear-gradient(180deg,#3d2616,#1f1209), 2px #c29444
    border, inset 0 1px 0 rgba(255,230,170,.35), and the gloss span
    (top 0, left 10%, 40% x 40%, white .18 -> 0)."""
    w, h = 160, dpx(30)
    r = h / 2
    bw = dpx(2)
    body = [defs(linear_gradient("rp", [(0, "#3D2616", 1), (1, "#1F1209", 1)], x1=0, y1=0, x2=0, y2=1),
                 linear_gradient("rgl", [(0, "#FFFFFF", 0.18), (1, "#FFFFFF", 0)], x1=0, y1=0, x2=0, y2=1),
                 clip_rrect("rpc", 0, 0, w, h, r))]
    body.append(rect(0, 0, w, h, rx=r, fill="url(#rp)"))
    body.append('<g clip-path="url(#rpc)">')
    body.append(rect(w * 0.1, 0, w * 0.4, h * 0.4, rx=dpx(10), fill="url(#rgl)"))
    body.append(rect(r, bw, w - 2 * r, dpx(1), fill="#FFE6AA", opacity=0.35))
    body.append("</g>")
    body.append(rect(bw / 2, bw / 2, w - bw, h - bw, rx=r - bw / 2, fill="none", stroke=PALETTE["brass"], stroke_width=bw))
    return svg_doc(w, h, "\n".join(body)), f"resource_pill: {w:g}x{h:g}"


def gen_rarity_gem(name: str) -> tuple[str, str]:
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
    return svg_doc(w, h, "\n".join(body)), f"rarity_gem_{name}: {w:g}x{h:g}, glow {glow:g}"


def gen_cooldown_ring_mask() -> tuple[str, str]:
    w = h = 128
    cx = cy = w / 2
    body = [circle(cx, cy, w / 2 - 4, fill="none", stroke="#FFFFFF", stroke_width=8)]
    return svg_doc(w, h, "\n".join(body)), f"cooldown_ring_mask: {w:g}x{h:g}"


def gen_glow_sprite() -> tuple[str, str]:
    """v0.3 Primary glow: radial-gradient(circle, rgba(255,150,80,.85),
    rgba(255,120,60,0) 68%) — animated by PrimaryGlow (glowPulse 2.2s)."""
    w = h = 160
    body = [defs(radial_gradient("glow", [(0, "#FF9650", 0.85), (0.68, "#FF783C", 0), (1, "#FF783C", 0)]))]
    body.append(circle(w / 2, h / 2, w / 2, fill="url(#glow)"))
    return svg_doc(w, h, "\n".join(body)), f"glow_sprite: {w:g}x{h:g}"


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
    """v0.3 coin: radial-gradient(circle at 34% 30%, #fffbe0 0 10%, #ffd75e
    28%, #e0a023 62%, #8a5a0c 100%), 1.5px #3e2604 rim, inset -2px -2px 0
    rgba(120,70,0,.45) lower-right shade."""
    w = h = dpx(24)
    c = w / 2
    r = dpx(11) - dpx(0.75)
    body = [defs(radial_gradient("coin", [(0, "#FFFBE0", 1), (0.1, "#FFFBE0", 1), (0.28, "#FFD75E", 1),
                                          (0.62, "#E0A023", 1), (1, "#8A5A0C", 1)], cx=0.34, cy=0.3, r=0.8),
                 clip_circle("coinc", c, c, r))]
    body.append(circle(c, c, r, fill="url(#coin)"))
    body.append('<g clip-path="url(#coinc)">'
                + path(f"M {c - r:g} {c:g} A {r:g} {r:g} 0 0 0 {c + r:g} {c:g} "
                       f"A {r - dpx(2):g} {r - dpx(2):g} 0 0 1 {c - r:g} {c:g} Z", fill="#784600", opacity=0.45)
                + "</g>")
    body.append(circle(c, c, r, fill="none", stroke="#3E2604", stroke_width=dpx(1.5)))
    return svg_doc(w, h, "\n".join(body)), f"gold icon: {w:g}x{h:g}"


def gen_icon_wood() -> tuple[str, str]:
    """v0.3 log end: radial rings #6b4428 0 8%, #e2b884 9-22%, #c8955a
    23-34%, #e2b884 35-48%, #b8834a 49-60%, #6b4428 61-72%, #4a2c14 73%+,
    1.5px #2a1608 rim."""
    w = h = dpx(24)
    c = w / 2
    r = dpx(11) - dpx(0.75)
    rings = [(0.08, "#6B4428"), (0.22, "#E2B884"), (0.34, "#C8955A"), (0.48, "#E2B884"),
             (0.60, "#B8834A"), (0.72, "#6B4428"), (1.0, "#4A2C14")]
    body = []
    for frac, col in reversed(rings):
        body.append(circle(c, c, r * frac, fill=col))
    body.append(circle(c, c, r, fill="none", stroke="#2A1608", stroke_width=dpx(1.5)))
    return svg_doc(w, h, "\n".join(body)), f"wood icon: {w:g}x{h:g}"


def gen_icon_iron() -> tuple[str, str]:
    """v0.3 ingot: trapezoid polygon(18% 0,82% 0,100% 100%,0 100%), 22x14,
    linear-gradient(180deg,#f7f9fb 0 12%,#b4bcc6 30%,#6c7480 72%,#3a4048
    100%), 1px #1a1c20 outline."""
    w = h = dpx(24)
    iw, ih = dpx(22), dpx(14)
    x0, y0 = (w - iw) / 2, (h - ih) / 2
    d = (f"M {x0 + iw * 0.18:g} {y0:g} L {x0 + iw * 0.82:g} {y0:g} L {x0 + iw:g} {y0 + ih:g} "
         f"L {x0:g} {y0 + ih:g} Z")
    body = [defs(linear_gradient("ing", [(0, "#F7F9FB", 1), (0.12, "#F7F9FB", 1), (0.3, "#B4BCC6", 1),
                                         (0.72, "#6C7480", 1), (1, "#3A4048", 1)], x1=0, y1=0, x2=0, y2=1))]
    body.append(path(d, fill="url(#ing)", stroke="#1A1C20", stroke_width=dpx(1)))
    return svg_doc(w, h, "\n".join(body)), f"iron icon: {w:g}x{h:g}"


def gen_icon_rum() -> tuple[str, str]:
    """v0.3 barrel: 18x22, radius 6/9, linear-gradient(90deg,#4f2c14,#9c6436
    32%,#c68a50 46%,#7d4b25 78%,#45260f), #35271a hoops at 20-28% and
    72-80%, 1.5px #2a1608 rim."""
    w = h = dpx(24)
    bw_, bh = dpx(18), dpx(22)
    x0, y0 = (w - bw_) / 2, (h - bh) / 2
    body = [defs(linear_gradient("bar", [(0, "#4F2C14", 1), (0.32, "#9C6436", 1), (0.46, "#C68A50", 1),
                                         (0.78, "#7D4B25", 1), (1, "#45260F", 1)], x1=0, y1=0, x2=1, y2=0),
                 clip_rrect("barc", x0, y0, bw_, bh, dpx(6)))]
    body.append(rect(x0, y0, bw_, bh, rx=dpx(6), fill="url(#bar)"))
    body.append('<g clip-path="url(#barc)">'
                + rect(x0, y0 + bh * 0.2, bw_, bh * 0.08, fill="#35271A")
                + rect(x0, y0 + bh * 0.72, bw_, bh * 0.08, fill="#35271A") + "</g>")
    body.append(rect(x0, y0, bw_, bh, rx=dpx(6), fill="none", stroke="#2A1608", stroke_width=dpx(1.5)))
    return svg_doc(w, h, "\n".join(body)), f"rum icon: {w:g}x{h:g}"


def gen_icon_research() -> tuple[str, str]:
    """v0.3 research scroll: 22x20 radius 3, linear-gradient(180deg,#fbeecb,
    #dcc08b), #8a6224 rods at each 12% edge, ruled lines rgba(58,38,22,.4),
    a #2f6fd6 seal at 72% 74%, 1.5px #3a2616 rim."""
    w = h = dpx(24)
    sw, sh = dpx(22), dpx(20)
    x0, y0 = (w - sw) / 2, (h - sh) / 2
    body = [defs(linear_gradient("scr", [(0, "#FBEECB", 1), (1, "#DCC08B", 1)], x1=0, y1=0, x2=0, y2=1),
                 clip_rrect("scrc", x0, y0, sw, sh, dpx(3)))]
    body.append(rect(x0, y0, sw, sh, rx=dpx(3), fill="url(#scr)"))
    inner = [rect(x0, y0, sw * 0.12, sh, fill="#8A6224"), rect(x0 + sw * 0.88, y0, sw * 0.12, sh, fill="#8A6224")]
    yy = y0 + dpx(4)
    while yy < y0 + sh - dpx(2):
        inner.append(rect(x0 + sw * 0.18, yy, sw * 0.64, dpx(1), fill="#3A2616", opacity=0.4))
        yy += dpx(5)
    inner.append(circle(x0 + sw * 0.72, y0 + sh * 0.74, sw * 0.13, fill="#2F6FD6"))
    body.append('<g clip-path="url(#scrc)">' + "".join(inner) + "</g>")
    body.append(rect(x0, y0, sw, sh, rx=dpx(3), fill="none", stroke="#3A2616", stroke_width=dpx(1.5)))
    return svg_doc(w, h, "\n".join(body)), f"research icon: {w:g}x{h:g}"


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


def gen_icon_skull() -> tuple[str, str]:
    """v0.3 notoriety marker: a 30px bone disc (radial-gradient(circle at 35%
    30%, #fffdf2, #e8dcc0 55%, #9a8a6a), 2px #2a1608 border) holding the
    doc's own 20x20 skull path at 18px."""
    d = dpx(30)
    c = d / 2
    body = [defs(radial_gradient("bone", [(0, "#FFFDF2", 1), (0.55, "#E8DCC0", 1), (1, "#9A8A6A", 1)], cx=0.35, cy=0.3, r=0.8))]
    body.append(circle(c, c + dpx(1), c - dpx(1), fill="#000000", opacity=0.45))
    body.append(circle(c, c, c - dpx(1), fill="url(#bone)"))
    body.append(circle(c, c, c - dpx(2), fill="none", stroke="#2A1608", stroke_width=dpx(2)))
    k = dpx(18) / 20.0
    ox = oy = c - dpx(9)
    skull = ("M10 2C5.6 2 3 5 3 8.5c0 2.2 1 3.6 2.4 4.4V16h9.2v-3.1C16 12.1 17 10.7 17 8.5 17 5 14.4 2 10 2z")
    body.append(f'<g transform="translate({ox:g} {oy:g}) scale({k:g})">'
                f'<path d="{skull}" fill="#2A1608"/>'
                f'<circle cx="7.2" cy="9" r="1.9" fill="#F4EAD4"/><circle cx="12.8" cy="9" r="1.9" fill="#F4EAD4"/>'
                f'<path d="M8 16v2M10 16v2M12 16v2" stroke="#2A1608" stroke-width="1.4" fill="none"/></g>')
    return svg_doc(d, d, "\n".join(body)), f"skull marker: {d:g}x{d:g}"


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
    svg, meta = gen_rope_parchment(); emit("rope_parchment", svg, meta)
    svg, meta = gen_torn_parchment(); emit("torn_parchment", svg, meta)

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
                     ("codex", gen_icon_codex), ("new", gen_icon_new), ("wardrobe", gen_icon_wardrobe),
                     ("skull", gen_icon_skull)):
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
