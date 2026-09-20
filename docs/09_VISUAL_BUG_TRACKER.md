# Visual & Physics Bug Tracker

Working list of the "the game looks/feels wrong" defects, split into one
independently-verifiable item each.

**Method: screenshot first, one bug at a time.** Every item here was
characterised from an actual rendered frame before any code was changed, then
re-captured afterwards to validate. Reading source and reasoning about it
produced multiple wrong diagnoses across this work's history (see the "Wrong
turns" list in the resolved archive, linked below), so it is not an acceptable
substitute for looking at the game.

> **Resolved history moved out 2026-09-20.** Every closed item (V1–V6, V9–V17)
> now lives in `docs/16_MILESTONE_HISTORY.md`'s "Appendix — resolved
> visual/physics bug ledger" — that's the doc for "what happened," this one
> stays lean for "what's still open." Two illustrative examples are kept
> inline below since they explain *why* this harness exists at all.

## How to capture screenshots

A debug harness is checked in for this:

```
<godot> --path D:\Pirate-game res://scenes/debug/CaptureHarness.tscn --capture-dir=D:\Pirate-game\.capture
```

It instances `World.tscn`, captures the real viewport at frames 2 / 60 / 180 /
420 / 720 (≈0s, 1s, 3s, 7s, 12s) and quits on its own. The spread matters —
a physics bug looks fine at frame 2 and only shows itself seconds later.

Run it from **PowerShell, not Bash** — Bash strips the backslashes in
`--capture-dir=D:\...`, and every `save_png` then fails with err=12.

Engine on this machine (not vendored, gitignored):
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`

Files: `scenes/debug/CaptureHarness.tscn`, `scripts/debug/ScreenshotCapture.gd`.
Delete both once the visual bugs are closed.

## Status legend

- `[ ]` not started
- `[~]` fix written, validated by screenshot, not yet confirmed by a human playing
- `[x]` fixed and confirmed

## Why this harness matters (two examples — full ledger in the archive)

**Ships capsizing (archived as V1)** took four independent, stacked root
causes to fully fix — a sign-inverted restoring torque, an inverted-pendulum
center of mass, a steering servo that clobbered self-righting every physics
tick, and a `sin(tilt)` gain that fell to near-zero past 90°. Each fix was
individually correct and each one alone left the bug fully visible: a symptom
surviving a verified-correct fix is evidence of an *additional* cause, not of
a wrong fix — screenshots at t=1/3/7/12s were what caught that it wasn't done
each time.

**The permanent-sunset sky (archived as V4)** looked, from reading the source,
like `EnvironmentController` overwriting sky colours with an orange keyframe.
Fixing that left the horizon just as orange — the real cause was a separate,
never-updated `fog_light_color` tinting the whole distance regardless of what
the sky did. Re-capturing after the "fix" is what caught that the diagnosis
was only half right.

---

## V7 — Two ship models have no texture `[ ]`

Of the 74 models in `assets/models/`, 72 are stock Kenney (1 material, 1 embedded
`colormap` image, `baseColorTexture` present). **Two are not:**

| Model | Materials | Images | Textured |
|---|---|---|---|
| `ships/pirate-sloop-lvl1.glb` | 6 | 0 | 0 |
| `ships/pirate-fleet-standard-l2.glb` | 8 | 0 | 0 |

These carry colour purely in `baseColorFactor` (`hullWood`, `sailCanvas`,
`flagCrimson`, …). They therefore depend on `KenneyMaterialApplier`'s
`base_albedo` path while every other model depends on the texture path — so any
change to the applier affects the two groups differently.

`pirate-sloop-lvl1.glb` **is** referenced — it is `Sloop.tres`'s `model_path`,
and Sloop is the default enemy ship. So this is active, not latent as previously
recorded. It renders acceptably in captures, so it is cosmetic-risk rather than
a visible defect right now.

---

## V8 — Ships beach themselves on islands `[ ]`

**Found by screenshot.** Enemy ships sail into island terrain, ride up the
collision cylinder (which sits at `y = +2.0`, above the waterline) and end up
stranded and tipped over. The buoyancy fixes (V1, archived) cannot help — the
hull is resting on static geometry, not floating.

`EnemyAI` steers straight at its target with no obstacle avoidance
(`scripts/combat/EnemyAI.gd` — `set_input(throttle, turn)` from a simple
cross-product heading error). Needs either avoidance steering or a
repulsion/no-sail radius around islands.

---

## Verification

GUT suite baseline: see `docs/05_CURRENT_SYSTEMS.md` §0 for the current test
count (this tracker no longer maintains its own copy of that number — a stale
duplicate here has caused confusion before).

Per `CLAUDE.md`, camera feel and shader appearance cannot be fully verified
headlessly — but the screenshot harness gives real rendered evidence, which is
how every item in the resolved archive was confirmed or ruled out, and how V7/V8
above will be too.
