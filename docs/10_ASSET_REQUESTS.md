# 10_ASSET_REQUESTS.md

> Version: 1.1
> Status: Living Document — building-model gap closed (M10), custom-art prompts below kept as
> historical reference only
> Owner: Project Lead
> Companion to: M6 — Black Flag Combat & Island Economy (see `docs/16_MILESTONE_HISTORY.md`)

---

# M10 update (2026-08-27) — building models resolved via stock assets, not custom generation

Per M10 Requirement 8, existing vendored Kenney assets (`assets/models/`) were surveyed before
assuming custom art was necessary, mirroring the D40 ship-model-remap precedent this doc's §"THE
GAP THIS FILLS" section already references. Result: **all 50 of 50** building-level combinations
(`resources/buildings/*.tres`, 10 chains × 5 levels) now have a real `model_path` set, closing the
gap this document was originally written to fill — the custom-generation prompts below were never
used.

What was found and assigned (one shared model per whole chain, all 5 levels — the same "3-stage
reuse" pattern this document's own fallback language anticipated, just at chain granularity):
Watchtower → `tower-watch.glb`; Fortress → `tower-complete-large.glb`; Academy →
`tower-middle-windows.glb`; Mine → `tower-base.glb`; Warehouse → `tower-complete-small.glb`;
Market → `structure-platform-small.glb`; Lumber Mill → `structure-platform.glb`; Shipyard →
`structure-platform-dock-small.glb`; Tavern → `castle-door.glb`; Farm (actually the Rum Distillery
chain — an id-naming holdover, see `produces_resource = "rum"` on every `Farm_L*.tres`) →
`crate-bottles.glb`, found only during the M10 pass (the other nine were already assigned before
M10 started, from an earlier undocumented pass this document was never updated to reflect).

None of these are bespoke per-level progression art — each chain reuses one representative prop
across all 5 levels, not 5 visually escalating models. If true per-level visual progression is
wanted later, the custom-generation prompts below remain valid and unused; until then this is
considered a closed gap, not a partial one, per Requirement 8 AC2's "a partial improvement... is
an acceptable outcome" allowance — here the outcome is a full 50/50 assignment, just not bespoke
per-level art.

---

# M11 update (2026-08-28) — audio closed via stock CC0 assets; portraits partially closed

## Audio (Requirement 8) — closed, 0 → 25 SFX cues + 2 music tracks

Sourced via free/CC0 packs rather than custom generation, mirroring M10's building-art precedent:
Kenney's UI Audio, Impact Sounds, RPG Audio, and Music Jingles packs (all CC0, kenney.nl — UI Audio
specifically via github.com/Calinou/kenney-ui-audio, which packages Kenney's own CC0 pack with
direct per-file download URLs, avoiding a zip-extraction step for just 5 files). Music: "Drunken
Sailor" (an OPL2 rendering, CC0, opengameart.org) for the main menu; "Pirates!" by Eric Matyas of
Soundimage.org (CC-BY 4.0 — the one non-CC0 asset in this pass, credited in `CreditsScreen.tscn`)
for in-world sailing music, since no CC0 looping pirate/nautical track was found in the time this
pass could spend searching.

All 25 SFX cues Requirement 8.1 lists a category for are covered (cannon, explosion, building
construct/upgrade, boarding start/success/fail, victory/defeat, resource collection, tech/ship/
captain purchases, docking, discovery, treasure-found, wind-shift, level-up, and 5 UI cues) — see
`docs/05_CURRENT_SYSTEMS.md`'s M11 section for the exact file-to-call-site mapping. One authored
cue (`ui_cancel.wav`) has no call site wired yet. `AudioManager.play_sound()` was extended to check
`.ogg` before `.wav` (Kenney ships `.ogg`; Godot's own preferred compressed format) rather than
converting every sourced file to `.wav` — no audio-conversion tool (ffmpeg or equivalent) was
available in this environment, so this was the correct fix, not a workaround.

**Gap**: no human has listened to any of these 25 cues in the actual running game. This document's
own standard (survey/source before assuming custom work is needed) was followed for *finding*
assets; whether the specific ones picked (an impact-sound pack substituting for cannon fire and
ship destruction, since no dedicated explosion/cannon-boom CC0 pack was found) sound *right* in
context is unverified and should be a human's first pass, not assumed.

## Portraits (Requirement 9) — 20 of 27 closed, stock-art search came up empty

Unlike M10's building models, no suitable free (CC0 or free-with-attribution) pirate-themed
character-portrait pack was found. The one strong match — itch.io's "50 Avatar Pirate Icons," 50
distinct pirate character avatars, 512×512 — requires a $0.70 minimum purchase, which this session
had no authorization to make on the user's behalf. `opengameart.org`'s "CC0 Portraits" collection
(200+ portraits, genuinely CC0) was checked directly and confirmed to have no pirate-themed entries
among them.

Per Requirement 9.2's own explicit fallback ("simple programmatic/stylized portraits — silhouettes,
flat-color icon busts... if bespoke character art isn't feasible"), 20 originally-generated SVG
flat-color icon-bust portraits were authored instead — a solid background color, a simple
silhouette bust shape, and the character's initial, in `assets/portraits/`, one per captain,
wired via each `CaptainData.portrait_path` and rendered in `IslandMenu.gd`'s Tavern tab through a
new `PortraitFallback.apply_to_texture_rect()`. These are originally-authored placeholder-grade
art, not sourced/licensed assets, so no attribution entry was needed.

**Still open**: the 7 named cast (Higgins, Hale, Morrow, Hollis, Vance, Cárdenas, the Cartographer)
have no portrait art and keep M9's monogram fallback — `TutorialDialogue.gd`'s
`PortraitFallback.apply_to_label()` call site was left as-is rather than upgraded, since there was
nothing to show through it yet. If a future milestone finds or commissions real character art for
either group, `portrait_path` + `apply_to_texture_rect()` are both already in place; only the asset
files and, for the named cast, a `TutorialDialogue.tscn` `TextureRect` addition (mirroring
`IslandMenu.gd`'s Tavern-tab pattern) would be needed.

---

# Purpose

3D asset requests for **Claude Design**, one prompt block per asset, ready to paste.

Each request states the gap it fills, the technical constraints that make it drop into this
project without rework, and a paste-ready generation prompt.

**Deliver as `.glb`.** Drop finished files into `assets/models/buildings/` (create it) using the
exact filenames given here — the M6 building resources reference those paths by name.

---

# THE GAP THIS FILLS

The project has **72 Kenney `.glb` models**, and ships are now adequately covered (all 8 ship
classes were remapped onto textured stock models on 2026-08-09).

Buildings are the real gap. There are exactly **three** building meshes —
`structure.glb`, `structure-platform.glb`, and `structure-roof.glb` — and **ten** building types
(Lumber Mill, Mine, Farm, Market, Warehouse, Tavern, Shipyard, Watchtower, Fortress, Academy).
Every one of them renders as the same box with an optional roof. `Island.gd` currently fakes
an upgrade by **scaling the model up by 1.2×**.

M6 introduces **5 upgrade levels per building**. Without new art, a player who spends an hour
earning a level-5 Lumber Mill sees a slightly larger identical box. That defeats the entire
retention loop the milestone is built around — Clash of Clans works because investment is
*visible*.

---

# TECHNICAL CONSTRAINTS — apply to every asset below

These are not stylistic preferences; violating them causes real, already-observed breakage.

## 1. Texturing — the critical one

Color **must** live in a **single shared texture atlas** (Kenney's `colormap.png` convention:
a small palette-grid PNG where each UV island samples a flat color patch).

**Do not** author color in glTF `baseColorFactor` with no texture.

Why: `scripts/components/KenneyMaterialApplier.gd` re-seeds every surface from that surface's
own imported color/texture, with `tint_strength` defaulting to `0`. Models carrying color only
in material factors do not read correctly through the toon shader pass. Two such models
(`pirate-sloop-lvl1.glb`, `pirate-fleet-standard-l2.glb`) existed in this project and were
**deleted on 2026-08-09** for exactly this reason.

If reusing a shared atlas is not possible, a per-model atlas PNG is acceptable — the
requirement is that color comes from a **texture**, not from a material factor.

## 2. Style

Flat-shaded **low-poly**, matching the Kenney "Pirate Kit" look:
- Hard/faceted normals, no smooth shading, no bevels.
- Flat color patches — **no** gradients, no PBR detail maps, no normal/roughness/AO maps.
- No baked lighting or ambient occlusion. The project runs a custom toon shader with a chained
  outline pass; baked light fights it.
- Chunky, readable silhouettes. This is a **mobile** game viewed from a distant top-down-ish
  camera — detail below roughly 10 cm world scale is wasted.

## 3. Budget

- **300–1,200 triangles per model.** Level 1 near the low end, level 5 near the high end.
- One material per model.
- No rigs, no animations, no cameras, no lights in the export.

## 4. Orientation, scale, and pivot

- **Y-up. −Z forward.** (Godot convention.)
- **Pivot at the base center** — models are placed on `Marker3D` slots and must sit on the
  ground, not float or sink.
- **Size budget: fit within a 0.85 × 0.85 unit footprint and 1.0 unit height at authored
  scale.** Island building slots are scaled **3.5×** and the closest slot pair is ~3 world
  units apart, so anything larger will overlap its neighbour at level 5.
- Level 5 may exceed the height budget up to ~1.4 units (tall buildings read as impressive),
  but **must not** exceed the footprint.

## 5. Naming

`<building>_l<level>.glb`, lowercase, e.g. `lumber_mill_l1.glb` … `lumber_mill_l5.glb`.
This matches the `<building>_l<level>` `building_id` convention M6 Task 17 depends on.

---

# PROGRESSION DESIGN — what "5 levels" should look like

Do not model five sizes of the same shape. Each level should read as a **different stage of
investment** at a glance, from a distance, without a label:

| Level | Reads as | Materials | Silhouette change |
|-------|----------|-----------|-------------------|
| 1 | Improvised / squatter | Rough logs, patched cloth, bare dirt | Small, low, asymmetric |
| 2 | Established | Sawn planks, proper roof | Taller, squarer, tidier |
| 3 | Prosperous | Painted wood, shutters, a chimney//sign | Adds a second volume or storey |
| 4 | Fortified | Stone footing, iron fittings, banners | Notably taller, stone base |
| 5 | Grand | Cut stone, tile roof, gold trim, flags | Landmark — tallest, most ornate |

**The colour temperature should warm as levels rise** (weathered grey-brown → rich warm timber →
painted accents → gold). That gives the player an at-a-glance read on island wealth.

---

# PRIORITY ORDER

If capacity is limited, generate in this order. P1 alone makes M6 shippable.

| Priority | Assets | Why |
|----------|--------|-----|
| **P1** | Lumber Mill, Mine, Farm — all 5 levels each (15 models) | The three core production buildings. These are what a player upgrades first and most often. |
| **P2** | Warehouse, Market, Tavern — all 5 levels each (15 models) | Storage caps, gold, and crew recruitment — the buildings the M6 economy loop routes through. |
| **P3** | Shipyard, Watchtower, Fortress, Academy — all 5 levels each (20 models) | Lower build frequency; the fake 1.2× scale is tolerable here for longer. |
| **P4** | Boarding VFX props (below) | Combat climax currently has no visual language at all. |

A viable reduced-scope fallback: **3 stages instead of 5** (levels 1–2 share a model, 3–4 share,
5 unique). That is 3 models per building instead of 5 and still delivers visible progression.

---

# 1. PRODUCTION BUILDINGS (P1)

## 1.1 Lumber Mill — `lumber_mill_l1..l5.glb`

```
Generate 5 low-poly 3D building models as a single upgrade progression for a stylized pirate
strategy game: a LUMBER MILL at levels 1 through 5.

Style: flat-shaded low-poly, faceted (hard) normals, no smooth shading. Flat color patches
sampled from a single shared texture atlas — NOT material base-color factors, and no gradients,
normal maps, roughness maps, or baked ambient occlusion. Chunky readable silhouettes for a
mobile game seen from a distant camera. Think Kenney "Pirate Kit".

Budget: 300-1200 triangles each (level 1 lowest, level 5 highest). One material per model.
No rig, no animation, no lights or cameras in the export.

Orientation and scale: Y-up, -Z forward, pivot at the BASE CENTER so it sits on the ground.
Must fit within a 0.85 x 0.85 unit footprint and 1.0 unit height (level 5 may reach 1.4 units
tall but must not exceed the footprint).

The 5 levels must read as different stages of investment at a glance, not 5 sizes of one shape:
- Level 1: a crude open-air saw pit. Rough unmilled logs, a hand saw, a dirt clearing, a
  lean-to of patched canvas. Weathered grey-brown timber. Small, low, deliberately asymmetric.
- Level 2: an enclosed timber shed with a proper pitched plank roof, a stacked log pile and a
  sawhorse. Tidier, squarer, taller.
- Level 3: a working mill — adds a large water wheel or windmill blade on one side, a chimney,
  and a painted sign. A second volume appears. Richer warm timber tones.
- Level 4: a fortified mill on a cut-stone footing, iron bands and brackets, a hoist crane arm
  for lifting logs, a small banner. Notably taller with a visible stone base.
- Level 5: a grand industrial sawmill. Cut stone ground floor, tiled roof, twin water wheels or
  a large geared mechanism, gold-trimmed sign, pennant flags. The landmark of the island.

Warm the color temperature as levels rise: weathered grey-brown at level 1, rich warm timber by
level 3, painted accents and gold trim by level 5.

Export each level as a separate .glb named lumber_mill_l1.glb through lumber_mill_l5.glb.
```

## 1.2 Mine — `mine_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a MINE at levels 1 through 5, for a stylized pirate strategy game.

- Level 1: a bare dig site. A hole in rocky ground, a wooden ladder, a pickaxe, a single ore
  cart with no track, scattered spoil. Grey stone and raw dirt.
- Level 2: a timber-framed mine entrance with support beams, a short length of rail track and a
  loaded ore cart. A patched canvas awning.
- Level 3: adds a wooden headframe/winch tower over the shaft, a rope pulley, crates of sorted
  ore, and a small forge with a chimney.
- Level 4: cut-stone reinforced entrance arch, iron-banded supports, a taller headframe, a
  banner, glowing ore veins visible in the rock face.
- Level 5: a grand mining complex — stone gatehouse entrance, tall iron-and-timber headframe
  with a large geared winch, multiple rail lines, gold-trimmed ore carts, pennant flags, and
  visible gold/gem veins in the surrounding rock.

Export as mine_l1.glb through mine_l5.glb.
```

## 1.3 Farm — `farm_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a FARM / PLANTATION at levels 1 through 5, tropical pirate-island setting.

- Level 1: a scratch plot. A few rows of ragged crops in bare soil, a crooked wooden fence
  section, a hand hoe. No building. Dusty muted greens.
- Level 2: tidy planted rows, a small thatched-roof hut, a full simple fence, a water barrel.
- Level 3: adds a raised timber granary on stilts, banana/palm crops, a handcart, a well.
  Lusher, more saturated greens.
- Level 4: stone-walled field borders, a larger tiled-roof farmhouse, a windmill or irrigation
  screw, livestock pen, a banner.
- Level 5: a grand plantation estate. Cut-stone manor with a tiled roof and veranda, ordered
  crop terraces, a large windmill, gold-trimmed gate, pennant flags, dense lush foliage.

Export as farm_l1.glb through farm_l5.glb.
```

---

# 2. ECONOMY BUILDINGS (P2)

## 2.1 Warehouse — `warehouse_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a WAREHOUSE / STOREHOUSE at levels 1 through 5. This building visibly holds MORE cargo
at each level — quantity of visible barrels, crates and sacks is the primary progression read.

- Level 1: an open canvas lean-to over a few stacked barrels and one crate. Sand floor.
- Level 2: a plank shed with a door, a modest stack of crates and barrels under the eaves.
- Level 3: a two-storey timber storehouse with a loading hatch, an external hoist beam and rope,
  a larger cargo stack, a painted sign.
- Level 4: stone ground floor, iron-reinforced double doors, a covered loading dock, many
  crates and roped cargo bales, a banner.
- Level 5: a grand cut-stone bonded warehouse. Tiled roof, arched iron-bound doors, a large
  external crane, dense stacks of gold-trimmed chests, barrels and bales, pennant flags.

Export as warehouse_l1.glb through warehouse_l5.glb.
```

## 2.2 Market — `market_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a MARKET / TRADING POST at levels 1 through 5. Progression reads as: one trader's mat
becomes a bustling trade hall.

- Level 1: a single ragged cloth mat on the sand with a few goods, a leaning pole with a faded
  pennant.
- Level 2: a striped canvas market stall with a wooden counter, hanging scales, baskets.
- Level 3: a row of two or three joined stalls under a shared awning, a signboard, hanging
  lanterns, spice sacks and rolled fabrics.
- Level 4: a permanent stone-footed trading post with a tiled awning, a strongbox, a ledger
  desk, a banner, crates stamped with trade marks.
- Level 5: a grand trade hall — cut-stone arcade with columns, tiled roof, rich awnings, gold
  scales and coin chests, hanging lanterns, pennant flags.

Export as market_l1.glb through market_l5.glb.
```

## 2.3 Tavern — `tavern_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a TAVERN at levels 1 through 5. This is where the player recruits crew, so it should
read as increasingly LIVELY and inviting — warm light, signage, seating.

- Level 1: a plank counter across two barrels under a canvas scrap, a stool, scattered bottles.
- Level 2: a small timber shack tavern with a door, a hanging sign, a bench and table outside,
  a lantern.
- Level 3: a proper two-storey inn with shuttered windows, a painted swinging sign, outdoor
  tables and benches, several lanterns, a chimney with smoke.
- Level 4: stone ground floor with a timber upper storey, a balcony, a large carved sign, many
  lanterns, rum barrels stacked outside, a banner.
- Level 5: a grand pirate tavern — cut stone with a tiled roof, a wide balcony, an ornate
  gold-trimmed sign, abundant warm lanterns, a bonfire pit, pennant flags, many barrels.

Export as tavern_l1.glb through tavern_l5.glb.
```

---

# 3. MILITARY & SPECIALIST BUILDINGS (P3)

## 3.1 Shipyard — `shipyard_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a SHIPYARD / DRY DOCK at levels 1 through 5. Progression reads as the size of vessel
under construction: a rowboat becomes a ship of the line.

- Level 1: a sand slipway with a half-built rowboat hull on wooden blocks, a saw, loose planks.
- Level 2: a timber slipway with a small ship's hull frame (visible ribs), a tool rack, a
  canvas shelter.
- Level 3: a covered dry dock with a partly planked mid-size hull, scaffolding, a mast crane,
  a rope walk and pitch barrels.
- Level 4: a stone-walled dock with a large hull under construction, tall scaffolding, an iron
  crane, a forge, a banner.
- Level 5: a grand naval yard — cut-stone dock walls, a near-complete large warship hull with
  masts stepped, twin cranes, a gantry, gold-trimmed figurehead, pennant flags.

Export as shipyard_l1.glb through shipyard_l5.glb.
```

## 3.2 Watchtower — `watchtower_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a WATCHTOWER at levels 1 through 5. Progression is primarily HEIGHT and fortification.
Note: this project already contains modular Kenney tower pieces (tower-base, tower-middle,
tower-top, tower-roof) — matching their proportions and stacking logic is desirable.

- Level 1: a crude wooden lookout platform on four poles with a ladder, a small pennant.
- Level 2: an enclosed timber tower, one storey, with a railed platform and a hanging bell.
- Level 3: a two-storey tower with a stone base, a shingled conical roof, a lantern beacon,
  arrow slits.
- Level 4: a three-storey stone tower with battlements, an iron brazier, a mounted spyglass,
  a banner.
- Level 5: a grand stone lighthouse-fort — tall, tapered, battlemented, a large glowing beacon
  lantern at the top, gold trim, multiple pennant flags, a small mounted cannon.

Level 5 may reach 1.4 units tall. Export as watchtower_l1.glb through watchtower_l5.glb.
```

## 3.3 Fortress — `fortress_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a FORTRESS / STRONGHOLD at levels 1 through 5. This is the island's defensive
centerpiece and should read as the most imposing structure at every level.

- Level 1: an earth-and-log palisade corner with a sharpened stake wall and a wooden gate.
- Level 2: a timber blockhouse with a walled compound and a single small cannon.
- Level 3: a stone-walled fort with corner bastions, two cannon embrasures, a gatehouse.
- Level 4: a larger stone fort with battlements, four cannons, a raised keep, iron portcullis,
  banners.
- Level 5: a grand citadel — thick cut-stone curtain walls, angled bastions, a tall central
  keep with a tiled roof, many cannons, gold-trimmed gate, numerous pennant flags.

Level 5 may reach 1.4 units tall. Export as fortress_l1.glb through fortress_l5.glb.
```

## 3.4 Academy — `academy_l1..l5.glb`

```
[Use the identical Style / Budget / Orientation / atlas paragraphs from 1.1, then:]

Subject: a NAVIGATOR'S ACADEMY at levels 1 through 5 — where captains train and research
happens. Reads as scholarly: charts, instruments, astronomy.

- Level 1: a canvas awning over a chart table with rolled maps, a compass and a sextant on a
  crate.
- Level 2: a small timber study hut with shuttered windows, a chart rack, a telescope on a
  tripod outside.
- Level 3: a two-storey building with a domed observation cupola, a larger telescope, hanging
  star charts, a globe.
- Level 4: a stone-based hall with an arched entrance, a proper observatory dome, an armillary
  sphere, a banner.
- Level 5: a grand academy — cut-stone with columns, a large copper observatory dome, a great
  brass telescope, gold-trimmed astronomical instruments, pennant flags.

Export as academy_l1.glb through academy_l5.glb.
```

---

# 4. BOARDING VFX PROPS (P4)

M6 introduces boarding as the climax of ship combat (Requirement 3). It currently has **no
visual language whatsoever**. These are small props, not buildings — one model each, no levels.

```
Generate 4 small low-poly prop models for ship boarding in a stylized pirate game.

Style, budget, atlas and orientation constraints: identical to the building requests — flat-
shaded low-poly, faceted normals, color from a shared texture atlas (NOT material factors), no
normal/roughness maps, no baked AO, one material each, Y-up, -Z forward, no rig or animation.

Budget here is smaller: 100-400 triangles each.

1. grappling_hook.glb — an iron three-pronged grappling hook with a short coil of rope at the
   eye. Pivot at the rope end. Roughly 0.3 units long.

2. boarding_plank.glb — a wide weathered timber plank with iron end-caps and rope lashings,
   for bridging two hulls. Pivot at one END (it rotates down into place). Roughly 2.0 units
   long, 0.4 wide.

3. boarding_rope.glb — a taut rope line with a small hook at one end and a knot at the other.
   Pivot at the knot end. Roughly 2.0 units long. Keep it a simple low-poly tube, not a
   simulated rope.

4. cutlass.glb — a curved pirate cutlass with a brass basket hilt and a leather grip. Pivot at
   the base of the grip. Roughly 0.5 units long.
```

---

# 5. DELIVERY CHECKLIST

When assets come back, verify before dropping them in:

- [ ] Filenames match exactly (`<building>_l<level>.glb`, lowercase).
- [ ] Color comes from a **texture**, not `baseColorFactor`. Open the `.glb` and confirm an
      image is embedded. **This is the single most common failure** — two models already had to
      be deleted from this project for exactly this.
- [ ] Pivot is at the base center; the model sits on the ground, not floating or sunk.
- [ ] Footprint within 0.85 × 0.85 units (height up to 1.0, or 1.4 for level 5).
- [ ] Triangle count within budget.
- [ ] No rig, animation, camera, or light in the export.
- [ ] Level 5 is visibly, obviously grander than level 1 **from a distance**, with no label.

Place files in `assets/models/buildings/`. Godot will generate `.import` files automatically on
next editor open — commit those alongside the `.glb`.

Then M6 Task 17 wires each level's `.tres` to its model via `BuildingData.model_path`.

---

# 6. WHAT IS *NOT* NEEDED

To avoid wasted generation effort:

- **Ships** — all 8 classes were remapped to textured stock models on 2026-08-09 and are fine.
- **Terrain, palms, rocks, barrels, crates, chests, cannons, flags** — the Kenney set already
  covers these well (72 models).
- **Characters or crew figures** — the game has no character models and M6 does not add any.
- **UI icons** — 2D, handled separately, not part of this request.
