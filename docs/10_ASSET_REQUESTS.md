# Asset Requests — Generation Prompt Pack (M29-M35)

**Updated:** 2026-10-03 · **For:** the project owner, who supplies all art.
Only assets that are still **needed** are listed — delivered art (20 captain portraits, Higgins,
SFX/music, launcher icons, the brand emblem) is not repeated here.

## How to use this pack

1. Find the asset, copy its prompt block, paste it into the tool named.
2. **2D assets** (portraits, icons, flags, sails, banners, VFX, store art) → **Claude Design**,
   which outputs PNG or SVG directly.
3. **3D assets** (buildings, ships, port dioramas, figurehead) need two steps, because Claude Design
   produces images, not 3D files: (a) the **concept-sheet prompt** in Claude Design, then (b) the
   **3D prompt** plus that sheet in a text/image-to-3D tool such as **Meshy, Tripo or Rodin**,
   exporting `.glb` with the settings given. Optional clean-up in Blender: apply transforms, check
   triangle count, check orientation.
4. Save the file at the exact `res://` path given (that is `D:/Pirate-game/<path after res://>`).
   Godot creates the `.import` file itself. Tell Claude when a batch lands: portraits and icons
   need no code change; building/ship/port files are repointed in their resources in one small
   commit.

## Global technical settings

| Category | Format | Size / budget | Notes |
|---|---|---|---|
| Story portraits | PNG, RGBA, sRGB | 512×512, ≤ 500 KB | match `assets/portraits/Higgins.svg` style |
| Retention UI icons | PNG, RGBA | 64×64 (export 128×128 too), ≤ 100 KB | flat, high contrast |
| World event icons | SVG | viewBox 96×96, ≤ 4 KB | flat fills, 6-unit outline, legible at 48 dp |
| Faction flags / sails | PNG, RGBA | 512×340 / 512×512, ≤ 200 KB | flat colour, seamless sail edges |
| Owner banners | PNG, RGBA | 256×384, ≤ 100 KB | cream field (tinted in game) |
| VFX sheets | PNG, RGBA | 256² cells (512² explosion), grid, no gaps | cel-shaded |
| Buildings | GLB | L1 ≤ 600 → L5 ≤ 3,500 tris | base-centre origin, ground y = 0, front -Z |
| Ships | GLB | 2,500 / 4,500 / 7,000 tris by size | bow -Z, keel bottom y = 0, named sails/flags |
| Port dioramas | GLB | 40×40 m, ≤ 25,000 tris | 5 named plot markers |
| All 3D | — | one 256² (ships/bosses up to 512², ports 1024²) flat-swatch atlas or vertex colours | no PBR maps; the game re-shades with a toon shader and keeps your colours |

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.

---

## M29 — Story cast portraits (6 PNG)

Every named speaker in Chapters 1-5 already points at these paths; until a file exists the game
shows the speaker's initials. Style reference: `assets/portraits/Higgins.svg`.

### M29.2 — Factor Cornelius Hale

```
Generate a 512×512 PNG portrait of FACTOR CORNELIUS HALE.

Style: Match Higgins.svg — full bust, head-and-shoulders, weathered pirate-Caribbean ~1700s, 
subtle gradients, transparent background.

Character: Shrewd merchant factor, age 50s. Pragmatic, mercenary.
Clothing: Fine colonial coat (deep blue #3f4756 or dark grey), white linen collar, brass/gold 
buttons, signet ring.
Distinguishing: Sharp narrow face, thin mouth, thin mustache or goatee. Alert evaluative eyes. 
Minimal warmth.
Mood: Neutral to calculating. Businesslike.
Palette: Deep blues (#3f4756, #2b3544), whites (#e8dcc4, #d8cfbd), brass (#e8b25a), 
weathered skin (#b8956b, #9a7c5c, #7a6448).

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/Hale.png`

### M29.3 — Morrow (Morrow's Messenger)

```
Generate a 512×512 PNG portrait of MORROW (Morrow's Messenger).

Style: Match Higgins.svg, full bust, weathered ~1700s, transparent background.

Character: Shadowy information broker, age 40s–50s. Neutral intermediary.
Clothing: Worn sea gear, weathered leather jerkin (grey/brown), practical not ornate.
Distinguishing: Scarred/weathered face, one eye squinted or scarred, salt-and-pepper beard, 
lean sharp features.
Mood: Cautious, world-weary, calculating. Not aggressive.
Palette: Weathered neutrals (#6b6455, #8b8a7c, #5f4c3d), leather browns (#5a4a3a), 
grey-greens (#4a5c4a), skin (#9a7c5c, #8a6f5c).

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/MorrowsMessenger.png`

### M29.4 — Commander Hollis

```
Generate a 512×512 PNG portrait of COMMANDER HOLLIS.

Style: Match Higgins.svg, full bust, transparent background.

Character: Disciplined Royal Navy commander, age 50s–60s. Authoritative.
Clothing: FORMAL ROYAL NAVY — deep blue coat (#3f4756 or navy), gold/brass buttons, white 
linen collar, epaulettes, naval cravat, rank insignia.
Distinguishing: Stern weathered face, sharp jaw, cropped grey/white hair, piercing eyes, 
command presence.
Mood: Authoritative, stern, uncompromising. Military precision.
Palette: Royal Navy blues (#1f2a44, #2f3a5c, #3f4756), whites (#e8dcc4, #f0ead8), brass 
golds (#e8b25a), weathered skin (#a88a70, #8a6c58). Formal, British tone.

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/Hollis.png`

### M29.5 — Marguerite

```
Generate a 512×512 PNG portrait of MARGUERITE.

Style: Match Higgins.svg, full bust, transparent background.

Character: Legendary pirate captain, age 40s–50s. Confident, dangerous, commanding.
Clothing: Pirate captain's finery — rich jewel tones (emerald #3d5c4a, burgundy #5c3d42), 
gold trim, fine sailcloth/velvet. Tricorn hat (feathered or gold buckle), jewelry (rings, 
pendant, gold hoops).
Distinguishing: Strong confident face, sharp cheekbones, bold eyes, dark hair (long or swept 
back), possible scar (cheek/forehead). Slight smirk or determined expression.
Mood: Dangerous charm. Confident, commanding, sensual but fierce.
Palette: Deep jewel tones (emerald #3d5c4a, burgundy #5c3d42, plum #4a3a5c), golds 
(#e8b25a, #d4a02f), warm skin (#c4956f, #a87f5c, #8b6f5c). No pale tones.

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/Marguerite.png`

### M29.6 — Admiral Sir Edmund Vance

```
Generate a 512×512 PNG portrait of ADMIRAL SIR EDMUND VANCE.

Style: Match Higgins.svg, full bust, transparent background.

Character: Senior Royal Navy admiral, age 60s–70s. Distinguished, formidable.
Clothing: ADMIRAL DRESS — formal naval coat (deep navy #1f2a44 or black), elaborate gold 
braid, multiple brass buttons, white linen, formal cravat, bicorn/tricorn hat, epaulettes 
(flag rank).
Distinguishing: Distinguished aristocratic face, grey/white hair (or wig), sharp eyes, 
slight beard/clean-shaven, powerful bearing despite age.
Mood: Elite, commanding, measured. Ruthless but diplomatic.
Palette: Deep navy (#1f2a44, #2f3a5c), blacks (#2a2820, #1c222b), whites (#f0ead8, #e8dcc4), 
brass/golds (#e8b25a), refined skin (#9a8070, #8a6f5c). No vivid colours.

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/Vance.png`

### M29.7 — Almirante Beatriz de Cárdenas

```
Generate a 512×512 PNG portrait of ALMIRANTE BEATRIZ DE CÁRDENAS.

Style: Match Higgins.svg, full bust, transparent background.

Character: Spanish naval commander, age 50s. Powerful, dignified.
Clothing: SPANISH NAVAL FORMAL — rich deep coat (deep blue #3f4756 or burgundy #5c3d42), 
gold embroidery/brocade, brass/gold buttons, white linen, Spanish collar/ruff, rank insignia, 
medal/cross (Order of Santiago or similar).
Distinguishing: Strong commanding face, dark eyes, dark hair (or grey-touched), proud bearing, 
Mediterranean features, olive/tan skin.
Mood: Proud, commanding, noble. Formal and traditional.
Palette: Deep Spanish navy/burgundy (#3f4756 or #5c3d42), golds/ornate yellows (#e8b25a, 
#d4a02f), whites (#e8dcc4), deep reds (#5c1f24 for trim), warm Spanish skin (#b8956f, 
#a87f5c, #8a6f5c). Rich and formal.

Output: 512×512 PNG, RGBA, transparent, optimized (≤500 KB).
```

**Delivery path:** `res://assets/portraits/Cardenas.png`

---

---

## M30 — Retention & engagement UI icons

### Streak Calendar (3 variants, 64×64 PNG @ 128 DPI)

```
Generate three 64×64 PNG icons @ 128 DPI for a daily STREAK CALENDAR:

1. **Claimed (completed day):** Check mark or filled calendar day, bright colour (gold #e8b25a).
2. **Unclaimed (missed day):** Empty calendar slot, grey (#6b6455).
3. **Today:** Today's slot, highlighted with bright outline, flame (red #c1272d), or gold accent.

Each 64×64, flat, solid colours, high contrast, readable at scale.
Output: Three separate PNGs.
```

**Delivery paths:**
- `res://assets/ui/icons/streak_claimed.png`
- `res://assets/ui/icons/streak_unclaimed.png`
- `res://assets/ui/icons/streak_today.png`

### Weekly Goal Icon (64×64 PNG @ 128 DPI)

```
Weekly calendar, checkmark, or goal marker (flag, target, calendar grid).
Colours: Golds (#e8b25a), parchment creams (#dcc79c), deep accents (blue #3f4756).
Style: Flat, iconic, high contrast.
Output: 64×64 PNG, RGBA, transparent, optimized (≤100 KB).
```

**Delivery path:** `res://assets/ui/icons/weekly_goal.png`

### Achievement Badge (2 variants, 64×64 PNG @ 128 DPI)

```
Two icons:
1. **Locked:** Padlocked badge or greyed trophy, dim (grey #6b6455).
2. **Unlocked:** Shiny badge or star burst, bright (gold #e8b25a, jewel tones).

Output: Two separate 64×64 PNGs.
```

**Delivery paths:**
- `res://assets/ui/icons/achievement_locked.png`
- `res://assets/ui/icons/achievement_unlocked.png`

### Reward Chest Icon (64×64 PNG @ 128 DPI)

```
Open or overflowing treasure chest with coins/gems.
Colours: Golds (#e8b25a, #ffd700), jewel tones (ruby #c1272d, emerald #3d5c4a), wood browns (#5f4c3d).
Style: Flat, iconic, celebratory, high contrast.
Output: 64×64 PNG, RGBA, transparent, optimized (≤100 KB).
```

**Delivery path:** `res://assets/ui/icons/reward_chest.png`

### Inbox Icon (64×64 PNG @ 128 DPI)

```
Mail envelope, bell, or notification stack.
Colours: Golds (#e8b25a), parchment (#dcc79c), optional accent (blue #3f4756).
Style: Flat, iconic, readable at 64×64.
Output: 64×64 PNG, RGBA, transparent, optimized (≤100 KB).
```

**Delivery path:** `res://assets/ui/icons/inbox.png`

### Comeback Bonus Icon (64×64 PNG @ 128 DPI)

```
Welcome banner, gift box with bow, or rising arrow with gift.
Colours: Warm golds (#e8b25a), festive reds (#c1272d), celebratory greens (#5a8c3a).
Style: Flat, welcoming, high contrast.
Output: 64×64 PNG, RGBA, transparent, optimized (≤100 KB).
```

**Delivery path:** `res://assets/ui/icons/comeback_bonus.png`

### Captain Collection Icon (64×64 PNG @ 128 DPI)

```
Silhouettes of multiple captains (group of heads or crew), or ship's wheel with captain badge.
Colours: Golds (#e8b25a), deep blues (#3f4756), nautical theme.
Style: Flat, iconic, readable at 64×64.
Output: 64×64 PNG, RGBA, transparent, optimized (≤100 KB).
```

**Delivery path:** `res://assets/ui/icons/captain_collection.png`

---

---

## World event icons — 11 SVG (M30)

Shown beside the on-screen announcement when a world event fires. **Tool: Claude Design → SVG.**
Common spec for all: `viewBox="0 0 96 96"`, flat filled shapes (no strokes thinner than 4 units,
no gradients, no text, no filters), transparent background, a 6-unit dark outline (#1c222b) around
the whole silhouette so it reads on both light parchment and dark ocean, legible at 48×48 dp,
≤ 4 KB. Deliver to `res://assets/icons/events/<event_name>.svg`.

### `island_discovered` — "New island charted"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a small island silhouette with one palm tree and a dotted chart line ending in an X, framed by a compass-rose tick ring.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #5a8c3a, accent #e8b25a, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/island_discovered.svg`

### `merchant_convoy_spotted` — "Merchant convoy sighted"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: three overlapping merchant ship silhouettes in a line, the front one larger, with a coin symbol above.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #e8b25a, accent #8b6f47, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/merchant_convoy_spotted.svg`

### `floating_treasure_spotted` — "Treasure adrift"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: an open treasure chest bobbing on two wave lines with three sparkle stars above it.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #e8b25a, accent #2b9acd, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/floating_treasure_spotted.svg`

### `ghost_ship_spotted` — "Ghost ship sighted"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a ragged ship silhouette with torn sails dissolving into wisps of fog at the bottom.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #8bc7c4, accent #3d2e4a, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/ghost_ship_spotted.svg`

### `iron_vulture_spotted` — "The Iron Vulture hunts"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a vulture skull in profile with a riveted iron beak.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #4a4757, accent #c1272d, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/iron_vulture_spotted.svg`

### `fortunes_toll_spotted` — "Fortune's Toll sighted"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a large ship's bell with a gold coin stamped on it.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #e8b25a, accent #3d2817, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/fortunes_toll_spotted.svg`

### `drifting_wreckage_spotted` — "Drifting wreckage"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: broken planks and a snapped mast fragment floating on wave lines.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #8b8a7c, accent #2b9acd, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/drifting_wreckage_spotted.svg`

### `smugglers_cache_spotted` — "Smugglers' cache"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a half-buried crate tied with rope, a small lantern on top.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #8b6f47, accent #e8b25a, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/smugglers_cache_spotted.svg`

### `pirate_raiding_party_spotted` — "Raiding party"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: two crossed cutlasses behind a small skull.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #1c222b, accent #c1272d, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/pirate_raiding_party_spotted.svg`

### `royal_navy_patrol_spotted` — "Royal Navy patrol"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a naval spyglass crossed with an anchor under a small crown.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #3f4756, accent #e8b25a, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/royal_navy_patrol_spotted.svg`

### `wind_shifted` — "Wind shifted"
```
Design a flat game icon as clean SVG code, viewBox="0 0 96 96", transparent background.
Subject: a billowing sail with three curved wind strokes flowing across it.
Style: bold, chunky, instantly readable at 48×48 pixels on a phone; flat fills only;
main colour #e8dcc4, accent #2b9acd, 6-unit dark outline #1c222b around the outer silhouette;
no gradients, no text, no thin lines under 4 units, no filters or masks.
Era/tone: Caribbean pirate golden age (1660-1720), adventurous, not grim.
Output: only the SVG markup, optimized, under 4 KB.
```
Delivery: `res://assets/icons/events/wind_shifted.svg`

---

## Buildings — 10 types × 5 levels (50 models)

**Why:** every level of every building currently reuses ONE placeholder model (e.g. Farm L1-L5 =
`crate-bottles.glb`), so upgrading looks like nothing happened except the model growing.

**Size rule (read once):** each level is authored at its **final in-game size**. L1 matches the
current placeholder's footprint (measured from the GLB); each level after it may grow up to 1.2×
the previous (L5 ≤ ~2.1× L1), which is what players see today. When your models land, the game's
automatic `1.2^(level-1)` scale-up in `Island.gd` is switched off for that building so sizes aren't
doubled — that is a code change on our side, not yours.

**Delivery:** `res://assets/models/buildings/<type>_l<N>.glb` (e.g. `farm_l3.glb`). We repoint each
level's `.tres` `model_path` when the file lands.

**Two prompts per model:** (a) paste the concept prompt into **Claude Design** to get a turnaround
sheet; (b) feed that sheet plus the 3D prompt to a text/image-to-3D tool (Meshy, Tripo or Rodin) to
get the `.glb`. Claude Design does not export 3D files.

### Rum Distillery (`farm`) — produces rum (the building id is 'farm'; players see 'Rum Distillery')

**Rum Distillery — Level 1** · `res://assets/models/buildings/farm_l1.glb` · ≤ 600 tris · footprint ≤ 1.1 × 1.3 m, height ≤ 1.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Rum Distillery for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a lean-to of palm thatch on four poles sheltering ONE small copper pot still on a stone fire ring, two barrels and a bundle of cut sugar cane.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces rum (the building id is 'farm'; players see 'Rum Distillery'); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Rum Distillery" at a glance.
Footprint no larger than 1.1 m × 1.3 m, overall height about 1.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Rum Distillery for a Caribbean pirate empire game (1660-1720).
A lean-to of palm thatch on four poles sheltering ONE small copper pot still on a stone fire ring, two barrels and a bundle of cut sugar cane.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 1.1 m wide (X) × 1.3 m deep (Z) × 1.1 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Rum Distillery — Level 2** · `res://assets/models/buildings/farm_l2.glb` · ≤ 1,000 tris · footprint ≤ 1.3 × 1.6 m, height ≤ 1.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Rum Distillery for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an open-sided timber shed with a plank roof, TWO copper pot stills, a cane-crushing hand press, four stacked barrels and a water trough.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a lean-to of palm thatch on four poles sheltering ONE small copper pot still on a stone fi...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces rum (the building id is 'farm'; players see 'Rum Distillery'); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Rum Distillery" at a glance.
Footprint no larger than 1.3 m × 1.6 m, overall height about 1.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Rum Distillery for a Caribbean pirate empire game (1660-1720).
An open-sided timber shed with a plank roof, TWO copper pot stills, a cane-crushing hand press, four stacked barrels and a water trough.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 1.3 m wide (X) × 1.6 m deep (Z) × 1.3 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Rum Distillery — Level 3** · `res://assets/models/buildings/farm_l3.glb` · ≤ 1,600 tris · footprint ≤ 1.6 × 1.9 m, height ≤ 1.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Rum Distillery for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a stone-footed distillery house with whitewashed walls and a clay-tile roof, a squat brick chimney, a wooden cane mill turned by a capstan arm, barrel racks along one wall.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (an open-sided timber shed with a plank roof, TWO copper pot stills, a cane-crushing hand p...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces rum (the building id is 'farm'; players see 'Rum Distillery'); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Rum Distillery" at a glance.
Footprint no larger than 1.6 m × 1.9 m, overall height about 1.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Rum Distillery for a Caribbean pirate empire game (1660-1720).
A stone-footed distillery house with whitewashed walls and a clay-tile roof, a squat brick chimney, a wooden cane mill turned by a capstan arm, barrel racks along one wall.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 1.6 m wide (X) × 1.9 m deep (Z) × 1.6 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Rum Distillery — Level 4** · `res://assets/models/buildings/farm_l4.glb` · ≤ 2,400 tris · footprint ≤ 1.9 × 2.2 m, height ≤ 2.2 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Rum Distillery for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a two-storey distillery: stone ground floor, timber upper storey with a hoist beam, tall brick chimney trailing a little smoke, a covered barrel-aging wing on one side, sugar-cane cart.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a stone-footed distillery house with whitewashed walls and a clay-tile roof, a squat brick...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces rum (the building id is 'farm'; players see 'Rum Distillery'); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Rum Distillery" at a glance.
Footprint no larger than 1.9 m × 2.2 m, overall height about 2.2 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Rum Distillery for a Caribbean pirate empire game (1660-1720).
A two-storey distillery: stone ground floor, timber upper storey with a hoist beam, tall brick chimney trailing a little smoke, a covered barrel-aging wing on one side, sugar-cane cart.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 1.9 m wide (X) × 2.2 m deep (Z) × 2.2 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Rum Distillery — Level 5** · `res://assets/models/buildings/farm_l5.glb` · ≤ 3,500 tris · footprint ≤ 2.3 × 2.7 m, height ≤ 2.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Rum Distillery for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a grand plantation distillery compound on the same plot: arched stone still-house with TWO brick chimneys, a gleaming copper column still visible through an arched opening, a cooper's yard of stacked casks, a small bell tower and a gold-on-red trade pennant.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a two-storey distillery...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces rum (the building id is 'farm'; players see 'Rum Distillery'); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Rum Distillery" at a glance.
Footprint no larger than 2.3 m × 2.7 m, overall height about 2.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Rum Distillery for a Caribbean pirate empire game (1660-1720).
A grand plantation distillery compound on the same plot: arched stone still-house with TWO brick chimneys, a gleaming copper column still visible through an arched opening, a cooper's yard of stacked casks, a small bell tower and a gold-on-red trade pennant.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 2.3 m wide (X) × 2.7 m deep (Z) × 2.6 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Lumber Mill (`lumber_mill`) — produces wood

**Lumber Mill — Level 1** · `res://assets/models/buildings/lumber_mill_l1.glb` · ≤ 600 tris · footprint ≤ 2.5 × 2.5 m, height ≤ 0.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Lumber Mill for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a sawpit: a rectangular trench with a timber trestle over it, a long two-man pit saw resting on a half-cut log, three raw logs and a pile of sawdust.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces wood; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Lumber Mill" at a glance.
Footprint no larger than 2.5 m × 2.5 m, overall height about 0.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Lumber Mill for a Caribbean pirate empire game (1660-1720).
A sawpit: a rectangular trench with a timber trestle over it, a long two-man pit saw resting on a half-cut log, three raw logs and a pile of sawdust.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 2.5 m wide (X) × 2.5 m deep (Z) × 0.9 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Lumber Mill — Level 2** · `res://assets/models/buildings/lumber_mill_l2.glb` · ≤ 1,000 tris · footprint ≤ 3.0 × 3.0 m, height ≤ 1.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Lumber Mill for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an open shed over the sawpit with a shingle roof, stacked planks drying on cross-sticks, a chopping block with an axe, a log pile held by stakes.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a sawpit...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces wood; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Lumber Mill" at a glance.
Footprint no larger than 3.0 m × 3.0 m, overall height about 1.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Lumber Mill for a Caribbean pirate empire game (1660-1720).
An open shed over the sawpit with a shingle roof, stacked planks drying on cross-sticks, a chopping block with an axe, a log pile held by stakes.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 3.0 m wide (X) × 3.0 m deep (Z) × 1.1 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Lumber Mill — Level 3** · `res://assets/models/buildings/lumber_mill_l3.glb` · ≤ 1,600 tris · footprint ≤ 3.6 × 3.6 m, height ≤ 1.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Lumber Mill for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a small water-powered sawmill: a timber mill house with an overshot water wheel fed by a wooden flume, a vertical sash saw visible inside, plank stacks outside.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (an open shed over the sawpit with a shingle roof, stacked planks drying on cross-sticks, a...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces wood; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Lumber Mill" at a glance.
Footprint no larger than 3.6 m × 3.6 m, overall height about 1.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Lumber Mill for a Caribbean pirate empire game (1660-1720).
A small water-powered sawmill: a timber mill house with an overshot water wheel fed by a wooden flume, a vertical sash saw visible inside, plank stacks outside.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 3.6 m wide (X) × 3.6 m deep (Z) × 1.3 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Lumber Mill — Level 4** · `res://assets/models/buildings/lumber_mill_l4.glb` · ≤ 2,400 tris · footprint ≤ 4.3 × 4.3 m, height ≤ 1.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Lumber Mill for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a larger mill: the water wheel plus a second saw frame under an extension, a timber crane (A-frame with a block and tackle) lifting a log, drying racks of curved ship's knees.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a small water-powered sawmill...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces wood; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Lumber Mill" at a glance.
Footprint no larger than 4.3 m × 4.3 m, overall height about 1.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Lumber Mill for a Caribbean pirate empire game (1660-1720).
A larger mill: the water wheel plus a second saw frame under an extension, a timber crane (A-frame with a block and tackle) lifting a log, drying racks of curved ship's knees.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 4.3 m wide (X) × 4.3 m deep (Z) × 1.8 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Lumber Mill — Level 5** · `res://assets/models/buildings/lumber_mill_l5.glb` · ≤ 3,500 tris · footprint ≤ 5.2 × 5.2 m, height ≤ 2.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Lumber Mill for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a shipwright's timber yard: a tall wind-driven gang-saw mill with four canvas sails, a covered lumber store, stacks of mast-length spars on trestles, a bullock cart loaded with logs.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a larger mill...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces wood; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Lumber Mill" at a glance.
Footprint no larger than 5.2 m × 5.2 m, overall height about 2.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Lumber Mill for a Caribbean pirate empire game (1660-1720).
A shipwright's timber yard: a tall wind-driven gang-saw mill with four canvas sails, a covered lumber store, stacks of mast-length spars on trestles, a bullock cart loaded with logs.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 5.2 m wide (X) × 5.2 m deep (Z) × 2.1 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Iron Mine (`mine`) — produces iron

**Iron Mine — Level 1** · `res://assets/models/buildings/mine_l1.glb` · ≤ 600 tris · footprint ≤ 3.2 × 3.2 m, height ≤ 1.4 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Iron Mine for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a dirt mound with a square shaft hole lined with rough timber, a wooden ladder poking out, a pick and two baskets of reddish ore.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces iron; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Iron Mine" at a glance.
Footprint no larger than 3.2 m × 3.2 m, overall height about 1.4 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Iron Mine for a Caribbean pirate empire game (1660-1720).
A dirt mound with a square shaft hole lined with rough timber, a wooden ladder poking out, a pick and two baskets of reddish ore.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 3.2 m wide (X) × 3.2 m deep (Z) × 1.4 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Iron Mine — Level 2** · `res://assets/models/buildings/mine_l2.glb` · ≤ 1,000 tris · footprint ≤ 3.8 × 3.8 m, height ≤ 1.7 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Iron Mine for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a timber headframe (A-frame) over the shaft with a hand windlass and rope bucket, an ore pile, a small tool lean-to.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a dirt mound with a square shaft hole lined with rough timber, a wooden ladder poking out,...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces iron; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Iron Mine" at a glance.
Footprint no larger than 3.8 m × 3.8 m, overall height about 1.7 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Iron Mine for a Caribbean pirate empire game (1660-1720).
A timber headframe (A-frame) over the shaft with a hand windlass and rope bucket, an ore pile, a small tool lean-to.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 3.8 m wide (X) × 3.8 m deep (Z) × 1.7 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Iron Mine — Level 3** · `res://assets/models/buildings/mine_l3.glb` · ≤ 1,600 tris · footprint ≤ 4.6 × 4.6 m, height ≤ 2.0 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Iron Mine for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a working mine: a taller headframe with a horse-gin capstan, two ore carts on a short wooden-rail track, a small stone bloomery furnace glowing orange at its mouth.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a timber headframe (A-frame) over the shaft with a hand windlass and rope bucket, an ore p...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces iron; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Iron Mine" at a glance.
Footprint no larger than 4.6 m × 4.6 m, overall height about 2.0 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Iron Mine for a Caribbean pirate empire game (1660-1720).
A working mine: a taller headframe with a horse-gin capstan, two ore carts on a short wooden-rail track, a small stone bloomery furnace glowing orange at its mouth.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 4.6 m wide (X) × 4.6 m deep (Z) × 2.0 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Iron Mine — Level 4** · `res://assets/models/buildings/mine_l4.glb` · ≤ 2,400 tris · footprint ≤ 5.5 × 5.5 m, height ≤ 2.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Iron Mine for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a stone smelting house beside the shaft with a water-driven bellows wheel, a slag heap, iron bars stacked on a pallet, a covered ore crusher.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a working mine...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces iron; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Iron Mine" at a glance.
Footprint no larger than 5.5 m × 5.5 m, overall height about 2.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Iron Mine for a Caribbean pirate empire game (1660-1720).
A stone smelting house beside the shaft with a water-driven bellows wheel, a slag heap, iron bars stacked on a pallet, a covered ore crusher.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 5.5 m wide (X) × 5.5 m deep (Z) × 2.8 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Iron Mine — Level 5** · `res://assets/models/buildings/mine_l5.glb` · ≤ 3,500 tris · footprint ≤ 6.6 × 6.6 m, height ≤ 3.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Iron Mine for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a full colonial ironworks: a tapered stone blast furnace with a charging bridge, a large bellows wheel, ore chutes from the headframe, bundles of finished cannonballs and iron bar stock.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a stone smelting house beside the shaft with a water-driven bellows wheel, a slag heap, ir...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces iron; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Iron Mine" at a glance.
Footprint no larger than 6.6 m × 6.6 m, overall height about 3.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Iron Mine for a Caribbean pirate empire game (1660-1720).
A full colonial ironworks: a tapered stone blast furnace with a charging bridge, a large bellows wheel, ore chutes from the headframe, bundles of finished cannonballs and iron bar stock.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 6.6 m wide (X) × 6.6 m deep (Z) × 3.3 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Market (`market`) — produces gold through trade

**Market — Level 1** · `res://assets/models/buildings/market_l1.glb` · ≤ 600 tris · footprint ≤ 1.9 × 2.5 m, height ≤ 0.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Market for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: one canvas-awning market stall on four poles with a plank counter, a few crates of fruit, a sack of grain and a balance scale.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces gold through trade; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Market" at a glance.
Footprint no larger than 1.9 m × 2.5 m, overall height about 0.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Market for a Caribbean pirate empire game (1660-1720).
One canvas-awning market stall on four poles with a plank counter, a few crates of fruit, a sack of grain and a balance scale.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 1.9 m wide (X) × 2.5 m deep (Z) × 0.9 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Market — Level 2** · `res://assets/models/buildings/market_l2.glb` · ≤ 1,000 tris · footprint ≤ 2.3 × 3.0 m, height ≤ 1.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Market for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: two stalls side by side under striped canvas (cream and faded red), baskets of fish and fruit, a rug-covered counter, a small cart.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (one canvas-awning market stall on four poles with a plank counter, a few crates of fruit, ...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold through trade; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Market" at a glance.
Footprint no larger than 2.3 m × 3.0 m, overall height about 1.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Market for a Caribbean pirate empire game (1660-1720).
Two stalls side by side under striped canvas (cream and faded red), baskets of fish and fruit, a rug-covered counter, a small cart.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 2.3 m wide (X) × 3.0 m deep (Z) × 1.1 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Market — Level 3** · `res://assets/models/buildings/market_l3.glb` · ≤ 1,600 tris · footprint ≤ 2.7 × 3.6 m, height ≤ 1.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Market for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a covered market hall: open-sided timber frame with a pitched tile roof, a row of counters, hanging lanterns, barrels and bolts of cloth.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (two stalls side by side under striped canvas (cream and faded red), baskets of fish and fr...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold through trade; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Market" at a glance.
Footprint no larger than 2.7 m × 3.6 m, overall height about 1.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Market for a Caribbean pirate empire game (1660-1720).
A covered market hall: open-sided timber frame with a pitched tile roof, a row of counters, hanging lanterns, barrels and bolts of cloth.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 2.7 m wide (X) × 3.6 m deep (Z) × 1.3 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Market — Level 4** · `res://assets/models/buildings/market_l4.glb` · ≤ 2,400 tris · footprint ≤ 3.3 × 4.3 m, height ≤ 1.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Market for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an arcaded stone market: three round arches along the front, a small bell cupola on the roof, crates stamped with merchant marks, a hanging trade sign.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a covered market hall...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold through trade; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Market" at a glance.
Footprint no larger than 3.3 m × 4.3 m, overall height about 1.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Market for a Caribbean pirate empire game (1660-1720).
An arcaded stone market: three round arches along the front, a small bell cupola on the roof, crates stamped with merchant marks, a hanging trade sign.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 3.3 m wide (X) × 4.3 m deep (Z) × 1.8 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Market — Level 5** · `res://assets/models/buildings/market_l5.glb` · ≤ 3,500 tris · footprint ≤ 3.9 × 5.2 m, height ≤ 2.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Market for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a merchant exchange: two-storey stone counting house over an arcaded trading floor, a balcony with a brass weathervane, strongbox and ledgers visible through the arches, gold-trimmed shutters.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (an arcaded stone market...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold through trade; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Market" at a glance.
Footprint no larger than 3.9 m × 5.2 m, overall height about 2.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Market for a Caribbean pirate empire game (1660-1720).
A merchant exchange: two-storey stone counting house over an arcaded trading floor, a balcony with a brass weathervane, strongbox and ledgers visible through the arches, gold-trimmed shutters.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 3.9 m wide (X) × 5.2 m deep (Z) × 2.1 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Tavern (`tavern`) — produces gold and is where captains are hired

**Tavern — Level 1** · `res://assets/models/buildings/tavern_l1.glb` · ≤ 600 tris · footprint ≤ 4.7 × 3.0 m, height ≤ 2.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Tavern for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a palm-thatch rum shack: a bar counter made of a plank on two barrels, two stools, a hanging lantern and a chalkboard sign.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces gold and is where captains are hired; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Tavern" at a glance.
Footprint no larger than 4.7 m × 3.0 m, overall height about 2.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Tavern for a Caribbean pirate empire game (1660-1720).
A palm-thatch rum shack: a bar counter made of a plank on two barrels, two stools, a hanging lantern and a chalkboard sign.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 4.7 m wide (X) × 3.0 m deep (Z) × 2.6 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Tavern — Level 2** · `res://assets/models/buildings/tavern_l2.glb` · ≤ 1,000 tris · footprint ≤ 5.6 × 3.6 m, height ≤ 3.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Tavern for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a timber tavern with a covered front porch, a painted hanging sign (a tankard), benches outside, shuttered windows.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a palm-thatch rum shack...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold and is where captains are hired; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Tavern" at a glance.
Footprint no larger than 5.6 m × 3.6 m, overall height about 3.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Tavern for a Caribbean pirate empire game (1660-1720).
A timber tavern with a covered front porch, a painted hanging sign (a tankard), benches outside, shuttered windows.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 5.6 m wide (X) × 3.6 m deep (Z) × 3.1 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Tavern — Level 3** · `res://assets/models/buildings/tavern_l3.glb` · ≤ 1,600 tris · footprint ≤ 6.8 × 4.3 m, height ≤ 3.7 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Tavern for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a two-storey inn: stone ground floor, timber upper floor with a narrow balcony, a crooked chimney, lanterns either side of the door, a barrel stack by the side wall.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a timber tavern with a covered front porch, a painted hanging sign (a tankard), benches ou...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold and is where captains are hired; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Tavern" at a glance.
Footprint no larger than 6.8 m × 4.3 m, overall height about 3.7 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Tavern for a Caribbean pirate empire game (1660-1720).
A two-storey inn: stone ground floor, timber upper floor with a narrow balcony, a crooked chimney, lanterns either side of the door, a barrel stack by the side wall.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 6.8 m wide (X) × 4.3 m deep (Z) × 3.7 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Tavern — Level 4** · `res://assets/models/buildings/tavern_l4.glb` · ≤ 2,400 tris · footprint ≤ 8.1 × 5.2 m, height ≤ 5.2 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Tavern for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a busy inn with a walled courtyard: tables under a vine-covered pergola, a stable lean-to, a second hanging sign, a notice board for crew wanted.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a two-storey inn...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold and is where captains are hired; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Tavern" at a glance.
Footprint no larger than 8.1 m × 5.2 m, overall height about 5.2 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Tavern for a Caribbean pirate empire game (1660-1720).
A busy inn with a walled courtyard: tables under a vine-covered pergola, a stable lean-to, a second hanging sign, a notice board for crew wanted.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 8.1 m wide (X) × 5.2 m deep (Z) × 5.2 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Tavern — Level 5** · `res://assets/models/buildings/tavern_l5.glb` · ≤ 3,500 tris · footprint ≤ 9.7 × 6.2 m, height ≤ 6.2 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Tavern for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a famous pirate tavern: three storeys leaning slightly, a rooftop terrace strung with lanterns, a ship's figurehead mounted over the door, a large hanging sign with a skull-and-tankard emblem in gold.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a busy inn with a walled courtyard...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces gold and is where captains are hired; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Tavern" at a glance.
Footprint no larger than 9.7 m × 6.2 m, overall height about 6.2 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Tavern for a Caribbean pirate empire game (1660-1720).
A famous pirate tavern: three storeys leaning slightly, a rooftop terrace strung with lanterns, a ship's figurehead mounted over the door, a large hanging sign with a skull-and-tankard emblem in gold.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 9.7 m wide (X) × 6.2 m deep (Z) × 6.2 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Warehouse (`warehouse`) — raises storage caps (no production)

**Warehouse — Level 1** · `res://assets/models/buildings/warehouse_l1.glb` · ≤ 600 tris · footprint ≤ 7.7 × 5.3 m, height ≤ 3.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Warehouse for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a yard of stacked crates and barrels under an oiled canvas tarp roped to stakes.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: raises storage caps (no production); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Warehouse" at a glance.
Footprint no larger than 7.7 m × 5.3 m, overall height about 3.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Warehouse for a Caribbean pirate empire game (1660-1720).
A yard of stacked crates and barrels under an oiled canvas tarp roped to stakes.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 7.7 m wide (X) × 5.3 m deep (Z) × 3.9 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Warehouse — Level 2** · `res://assets/models/buildings/warehouse_l2.glb` · ≤ 1,000 tris · footprint ≤ 9.2 × 6.4 m, height ≤ 4.7 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Warehouse for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a timber storage shed with wide double doors, a loading step, sacks piled by the door.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a yard of stacked crates and barrels under an oiled canvas tarp roped to stakes...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises storage caps (no production); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Warehouse" at a glance.
Footprint no larger than 9.2 m × 6.4 m, overall height about 4.7 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Warehouse for a Caribbean pirate empire game (1660-1720).
A timber storage shed with wide double doors, a loading step, sacks piled by the door.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 9.2 m wide (X) × 6.4 m deep (Z) × 4.7 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Warehouse — Level 3** · `res://assets/models/buildings/warehouse_l3.glb` · ≤ 1,600 tris · footprint ≤ 11.1 × 7.6 m, height ≤ 5.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Warehouse for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a long timber storehouse with a hoist beam and pulley over the loft door, a loading platform, numbered bays.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a timber storage shed with wide double doors, a loading step, sacks piled by the door...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises storage caps (no production); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Warehouse" at a glance.
Footprint no larger than 11.1 m × 7.6 m, overall height about 5.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Warehouse for a Caribbean pirate empire game (1660-1720).
A long timber storehouse with a hoist beam and pulley over the loft door, a loading platform, numbered bays.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 11.1 m wide (X) × 7.6 m deep (Z) × 5.6 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Warehouse — Level 4** · `res://assets/models/buildings/warehouse_l4.glb` · ≤ 2,400 tris · footprint ≤ 13.3 × 9.2 m, height ≤ 7.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Warehouse for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a stone warehouse with a slate roof, a wooden quayside crane on a swivel, iron-banded doors, a clerk's lean-to office.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a long timber storehouse with a hoist beam and pulley over the loft door, a loading platfo...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises storage caps (no production); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Warehouse" at a glance.
Footprint no larger than 13.3 m × 9.2 m, overall height about 7.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Warehouse for a Caribbean pirate empire game (1660-1720).
A stone warehouse with a slate roof, a wooden quayside crane on a swivel, iron-banded doors, a clerk's lean-to office.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 13.3 m wide (X) × 9.2 m deep (Z) × 7.8 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Warehouse — Level 5** · `res://assets/models/buildings/warehouse_l5.glb` · ≤ 3,500 tris · footprint ≤ 16.0 × 11.0 m, height ≤ 9.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Warehouse for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a bonded customs warehouse: three bays under a long stone roof, each with a hoist, a small clock gable, crates stamped with the player's emblem, a cobbled loading apron.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a stone warehouse with a slate roof, a wooden quayside crane on a swivel, iron-banded door...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises storage caps (no production); it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Warehouse" at a glance.
Footprint no larger than 16.0 m × 11.0 m, overall height about 9.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Warehouse for a Caribbean pirate empire game (1660-1720).
A bonded customs warehouse: three bays under a long stone roof, each with a hoist, a small clock gable, crates stamped with the player's emblem, a cobbled loading apron.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 16.0 m wide (X) × 11.0 m deep (Z) × 9.3 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Shipyard (`shipyard`) — builds and repairs ships

**Shipyard — Level 1** · `res://assets/models/buildings/shipyard_l1.glb` · ≤ 600 tris · footprint ≤ 1.9 × 2.5 m, height ≤ 1.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Shipyard for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a short timber slipway running into the water with the bare keel and first few ribs of a small boat, a tar pot over a fire.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: builds and repairs ships; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Shipyard" at a glance.
Footprint no larger than 1.9 m × 2.5 m, overall height about 1.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Shipyard for a Caribbean pirate empire game (1660-1720).
A short timber slipway running into the water with the bare keel and first few ribs of a small boat, a tar pot over a fire.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 1.9 m wide (X) × 2.5 m deep (Z) × 1.3 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Shipyard — Level 2** · `res://assets/models/buildings/shipyard_l2.glb` · ≤ 1,000 tris · footprint ≤ 2.3 × 3.0 m, height ≤ 1.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Shipyard for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a slipway with a half-planked hull on blocks, a scaffold of poles, a rope coil, a sawhorse and planks.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a short timber slipway running into the water with the bare keel and first few ribs of a s...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: builds and repairs ships; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Shipyard" at a glance.
Footprint no larger than 2.3 m × 3.0 m, overall height about 1.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Shipyard for a Caribbean pirate empire game (1660-1720).
A slipway with a half-planked hull on blocks, a scaffold of poles, a rope coil, a sawhorse and planks.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 2.3 m wide (X) × 3.0 m deep (Z) × 1.6 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Shipyard — Level 3** · `res://assets/models/buildings/shipyard_l3.glb` · ≤ 1,600 tris · footprint ≤ 2.7 × 3.6 m, height ≤ 1.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Shipyard for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a covered slip: a timber shed roof over the slipway, a simple shear-legs crane, a forge for nails, stacked curved timbers.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a slipway with a half-planked hull on blocks, a scaffold of poles, a rope coil, a sawhorse...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: builds and repairs ships; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Shipyard" at a glance.
Footprint no larger than 2.7 m × 3.6 m, overall height about 1.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Shipyard for a Caribbean pirate empire game (1660-1720).
A covered slip: a timber shed roof over the slipway, a simple shear-legs crane, a forge for nails, stacked curved timbers.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 2.7 m wide (X) × 3.6 m deep (Z) × 1.9 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Shipyard — Level 4** · `res://assets/models/buildings/shipyard_l4.glb` · ≤ 2,400 tris · footprint ≤ 3.3 × 4.3 m, height ≤ 2.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Shipyard for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a dry dock: a stone-lined basin with wooden gates, a nearly finished hull inside, a ropewalk shed along one side, capstans.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a covered slip...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: builds and repairs ships; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Shipyard" at a glance.
Footprint no larger than 3.3 m × 4.3 m, overall height about 2.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Shipyard for a Caribbean pirate empire game (1660-1720).
A dry dock: a stone-lined basin with wooden gates, a nearly finished hull inside, a ropewalk shed along one side, capstans.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 3.3 m wide (X) × 4.3 m deep (Z) × 2.6 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Shipyard — Level 5** · `res://assets/models/buildings/shipyard_l5.glb` · ≤ 3,500 tris · footprint ≤ 3.9 × 5.2 m, height ≤ 3.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Shipyard for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a grand naval yard: two slipways (one with a large hull in frame), a tall sheer-legs mast crane, a sail loft building, a figurehead carver's bench and the player's flag on a pole.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a dry dock...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: builds and repairs ships; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Shipyard" at a glance.
Footprint no larger than 3.9 m × 5.2 m, overall height about 3.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Shipyard for a Caribbean pirate empire game (1660-1720).
A grand naval yard: two slipways (one with a large hull in frame), a tall sheer-legs mast crane, a sail loft building, a figurehead carver's bench and the player's flag on a pole.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 3.9 m wide (X) × 5.2 m deep (Z) × 3.1 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Academy (`academy`) — produces research

**Academy — Level 1** · `res://assets/models/buildings/academy_l1.glb` · ≤ 600 tris · footprint ≤ 2.8 × 3.1 m, height ≤ 2.0 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Academy for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a chart table under a canvas awning: rolled maps, a brass astrolabe, a stool and a lantern.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: produces research; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Academy" at a glance.
Footprint no larger than 2.8 m × 3.1 m, overall height about 2.0 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Academy for a Caribbean pirate empire game (1660-1720).
A chart table under a canvas awning: rolled maps, a brass astrolabe, a stool and a lantern.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 2.8 m wide (X) × 3.1 m deep (Z) × 2.0 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Academy — Level 2** · `res://assets/models/buildings/academy_l2.glb` · ≤ 1,000 tris · footprint ≤ 3.4 × 3.7 m, height ≤ 2.4 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Academy for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a small round stone tower with a telescope poking from the top window and a chalk star-chart on a board by the door.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a chart table under a canvas awning...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces research; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Academy" at a glance.
Footprint no larger than 3.4 m × 3.7 m, overall height about 2.4 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Academy for a Caribbean pirate empire game (1660-1720).
A small round stone tower with a telescope poking from the top window and a chalk star-chart on a board by the door.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 3.4 m wide (X) × 3.7 m deep (Z) × 2.4 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Academy — Level 3** · `res://assets/models/buildings/academy_l3.glb` · ≤ 1,600 tris · footprint ≤ 4.0 × 4.5 m, height ≤ 2.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Academy for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an observatory: the stone tower plus a domed wooden roof with an opening slit, a covered porch with a globe on a stand.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a small round stone tower with a telescope poking from the top window and a chalk star-cha...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces research; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Academy" at a glance.
Footprint no larger than 4.0 m × 4.5 m, overall height about 2.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Academy for a Caribbean pirate empire game (1660-1720).
An observatory: the stone tower plus a domed wooden roof with an opening slit, a covered porch with a globe on a stand.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 4.0 m wide (X) × 4.5 m deep (Z) × 2.9 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Academy — Level 4** · `res://assets/models/buildings/academy_l4.glb` · ≤ 2,400 tris · footprint ≤ 4.8 × 5.4 m, height ≤ 4.0 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Academy for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an observatory with a library wing: arched windows, book-crammed shelves visible, a sundial in a small paved court.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (an observatory...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces research; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Academy" at a glance.
Footprint no larger than 4.8 m × 5.4 m, overall height about 4.0 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Academy for a Caribbean pirate empire game (1660-1720).
An observatory with a library wing: arched windows, book-crammed shelves visible, a sundial in a small paved court.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 4.8 m wide (X) × 5.4 m deep (Z) × 4.0 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Academy — Level 5** · `res://assets/models/buildings/academy_l5.glb` · ≤ 3,500 tris · footprint ≤ 5.8 × 6.4 m, height ≤ 4.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Academy for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a navigators' college: a three-storey building with a central observatory dome, a large brass armillary sphere in the forecourt, a weather vane and banners.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (an observatory with a library wing...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: produces research; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Academy" at a glance.
Footprint no larger than 5.8 m × 6.4 m, overall height about 4.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Academy for a Caribbean pirate empire game (1660-1720).
A navigators' college: a three-storey building with a central observatory dome, a large brass armillary sphere in the forecourt, a weather vane and banners.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 5.8 m wide (X) × 6.4 m deep (Z) × 4.8 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Fortress (`fortress`) — raises raid defence score

**Fortress — Level 1** · `res://assets/models/buildings/fortress_l1.glb` · ≤ 600 tris · footprint ≤ 1.4 × 1.2 m, height ≤ 0.9 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Fortress for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: an earthwork redoubt: a low U-shaped bank of packed earth and gabions (wicker baskets of earth) sheltering TWO small cannons.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: raises raid defence score; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Fortress" at a glance.
Footprint no larger than 1.4 m × 1.2 m, overall height about 0.9 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Fortress for a Caribbean pirate empire game (1660-1720).
An earthwork redoubt: a low U-shaped bank of packed earth and gabions (wicker baskets of earth) sheltering TWO small cannons.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 1.4 m wide (X) × 1.2 m deep (Z) × 0.9 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Fortress — Level 2** · `res://assets/models/buildings/fortress_l2.glb` · ≤ 1,000 tris · footprint ≤ 1.7 × 1.4 m, height ≤ 1.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Fortress for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a timber palisade fort: sharpened log walls on a square plan, a firing step, FOUR cannons through gaps, a small gate.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (an earthwork redoubt...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence score; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Fortress" at a glance.
Footprint no larger than 1.7 m × 1.4 m, overall height about 1.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Fortress for a Caribbean pirate empire game (1660-1720).
A timber palisade fort: sharpened log walls on a square plan, a firing step, FOUR cannons through gaps, a small gate.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 1.7 m wide (X) × 1.4 m deep (Z) × 1.1 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Fortress — Level 3** · `res://assets/models/buildings/fortress_l3.glb` · ≤ 1,600 tris · footprint ≤ 2.0 × 1.7 m, height ≤ 1.3 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Fortress for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a stone bastion corner: a low angled stone wall with an arrowhead bastion, embrasures for SIX cannons, a flag pole.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a timber palisade fort...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence score; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Fortress" at a glance.
Footprint no larger than 2.0 m × 1.7 m, overall height about 1.3 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Fortress for a Caribbean pirate empire game (1660-1720).
A stone bastion corner: a low angled stone wall with an arrowhead bastion, embrasures for SIX cannons, a flag pole.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 2.0 m wide (X) × 1.7 m deep (Z) × 1.3 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Fortress — Level 4** · `res://assets/models/buildings/fortress_l4.glb` · ≤ 2,400 tris · footprint ≤ 2.4 × 2.1 m, height ≤ 1.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Fortress for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a full bastioned fort: four angled bastions, a powder magazine with a barrel roof, EIGHT cannons, a sentry box.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a stone bastion corner...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence score; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Fortress" at a glance.
Footprint no larger than 2.4 m × 2.1 m, overall height about 1.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Fortress for a Caribbean pirate empire game (1660-1720).
A full bastioned fort: four angled bastions, a powder magazine with a barrel roof, EIGHT cannons, a sentry box.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 2.4 m wide (X) × 2.1 m deep (Z) × 1.8 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Fortress — Level 5** · `res://assets/models/buildings/fortress_l5.glb` · ≤ 3,500 tris · footprint ≤ 2.9 × 2.5 m, height ≤ 2.1 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Fortress for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a citadel: thick star-fort walls, a square stone keep in the middle, TEN cannons, a large flag, a mortar emplacement.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (a full bastioned fort...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence score; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Fortress" at a glance.
Footprint no larger than 2.9 m × 2.5 m, overall height about 2.1 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Fortress for a Caribbean pirate empire game (1660-1720).
A citadel: thick star-fort walls, a square stone keep in the middle, TEN cannons, a large flag, a mortar emplacement.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 2.9 m wide (X) × 2.5 m deep (Z) × 2.1 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

### Watchtower (`watchtower`) — raises raid defence and detection

**Watchtower — Level 1** · `res://assets/models/buildings/watchtower_l1.glb` · ≤ 600 tris · footprint ≤ 3.0 × 3.0 m, height ≤ 2.8 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 1 Watchtower for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a lookout platform on four tall poles with a ladder and a rope-hung bell.
Level 1 of 5 — the look is humble, improvised. This is the first thing a player builds; it should look modest but charming, never broken.
Purpose in game: raises raid defence and detection; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Watchtower" at a glance.
Footprint no larger than 3.0 m × 3.0 m, overall height about 2.8 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 1 Watchtower for a Caribbean pirate empire game (1660-1720).
A lookout platform on four tall poles with a ladder and a rope-hung bell.
Level 1 of 5 (humble, improvised). Use the attached concept sheet for shapes and colours.
Fit inside 3.0 m wide (X) × 3.0 m deep (Z) × 2.8 m tall (Y); front faces -Z.
Budget: at most 600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Watchtower — Level 2** · `res://assets/models/buildings/watchtower_l2.glb` · ≤ 1,000 tris · footprint ≤ 3.6 × 3.6 m, height ≤ 3.4 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 2 Watchtower for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a timber watchtower with a shingled roof, a spyglass on a rail, a ladder and a signal flag.
Level 2 of 5 — the look is established. It must read as the next step up from Level 1 (a lookout platform on four tall poles with a ladder and a rope-hung bell...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence and detection; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Watchtower" at a glance.
Footprint no larger than 3.6 m × 3.6 m, overall height about 3.4 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 2 Watchtower for a Caribbean pirate empire game (1660-1720).
A timber watchtower with a shingled roof, a spyglass on a rail, a ladder and a signal flag.
Level 2 of 5 (established). Use the attached concept sheet for shapes and colours.
Fit inside 3.6 m wide (X) × 3.6 m deep (Z) × 3.4 m tall (Y); front faces -Z.
Budget: at most 1,000 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Watchtower — Level 3** · `res://assets/models/buildings/watchtower_l3.glb` · ≤ 1,600 tris · footprint ≤ 4.3 × 4.3 m, height ≤ 4.0 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 3 Watchtower for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a round stone watchtower with a crenellated top and an iron fire basket for signal fires.
Level 3 of 5 — the look is prosperous. It must read as the next step up from Level 2 (a timber watchtower with a shingled roof, a spyglass on a rail, a ladder and a signal flag...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence and detection; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Watchtower" at a glance.
Footprint no larger than 4.3 m × 4.3 m, overall height about 4.0 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 3 Watchtower for a Caribbean pirate empire game (1660-1720).
A round stone watchtower with a crenellated top and an iron fire basket for signal fires.
Level 3 of 5 (prosperous). Use the attached concept sheet for shapes and colours.
Fit inside 4.3 m wide (X) × 4.3 m deep (Z) × 4.0 m tall (Y); front faces -Z.
Budget: at most 1,600 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Watchtower — Level 4** · `res://assets/models/buildings/watchtower_l4.glb` · ≤ 2,400 tris · footprint ≤ 5.2 × 5.2 m, height ≤ 5.6 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 4 Watchtower for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: the stone tower taller with a covered top room and a swivel gun on a pivot mount, a small guard hut at the base.
Level 4 of 5 — the look is fortified and expanding. It must read as the next step up from Level 3 (a round stone watchtower with a crenellated top and an iron fire basket for signal fires...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence and detection; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Watchtower" at a glance.
Footprint no larger than 5.2 m × 5.2 m, overall height about 5.6 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 4 Watchtower for a Caribbean pirate empire game (1660-1720).
The stone tower taller with a covered top room and a swivel gun on a pivot mount, a small guard hut at the base.
Level 4 of 5 (fortified and expanding). Use the attached concept sheet for shapes and colours.
Fit inside 5.2 m wide (X) × 5.2 m deep (Z) × 5.6 m tall (Y); front faces -Z.
Budget: at most 2,400 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

**Watchtower — Level 5** · `res://assets/models/buildings/watchtower_l5.glb` · ≤ 3,500 tris · footprint ≤ 6.2 × 6.2 m, height ≤ 6.7 m (masts/flags may exceed height by 50%)

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Level 5 Watchtower for a stylized low-poly
pirate empire mobile game. Show FOUR views on one sheet at the same scale: front, left side,
top-down, and a 3/4 isometric hero view, on a flat light-grey background with a 1-metre grid
and a small human figure (1.7 m) for scale. Label each view.

Subject: a lighthouse-watchtower: a tall tapering tower with a glazed lantern room glowing warm, a gallery rail, a swivel gun and the player's flag.
Level 5 of 5 — the look is grand, a landmark. It must read as the next step up from Level 4 (the stone tower taller with a covered top room and a swivel gun on a pivot mount, a small ...) on the SAME plot: keep the same ground footprint centre and orientation, reuse its materials, and add size, height and detail.
Purpose in game: raises raid defence and detection; it sits in a building slot on a small Caribbean island and is seen
from above at a distance, so the silhouette and roof shape must say "Watchtower" at a glance.
Footprint no larger than 6.2 m × 6.2 m, overall height about 6.7 m.

Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG concept sheet, 2048×1536, no text other than view labels.
```

(b) 3D tool (Meshy / Tripo / Rodin) — model
```
Low-poly stylized 3D model: Level 5 Watchtower for a Caribbean pirate empire game (1660-1720).
A lighthouse-watchtower: a tall tapering tower with a glazed lantern room glowing warm, a gallery rail, a swivel gun and the player's flag.
Level 5 of 5 (grand, a landmark). Use the attached concept sheet for shapes and colours.
Fit inside 6.2 m wide (X) × 6.2 m deep (Z) × 6.7 m tall (Y); front faces -Z.
Budget: at most 3,500 triangles. Chunky readable shapes, flat-shaded, no tiny
details under 5 cm, no floating parts, closed meshes where possible.
Export: one .glb (glTF 2.0 binary), Y-up, 1 unit = 1 metre, transforms applied,
origin at the CENTRE OF THE BASE with the ground plane at y = 0 (nothing below y = 0 except up
to 0.1 m of foundation sink). Single object or named child parts, no rig, no animation, no lights,
no cameras. Materials: flat colour only — either vertex colours or ONE 256x256 colour-atlas
texture made of flat palette swatches (UVs collapsed onto swatches, like the Kenney colormap).
No normal/roughness/metallic maps: the game re-shades every surface with its own toon shader
and keeps your base colours.
```

---

## Ships — 8 player classes + 6 enemy/boss models

**Physics-critical size rule:** the game builds each ship's collision hull from its scene's box, and
derives buoyancy and stability from that box. Your model does not change the box — but if the hull
doesn't sit inside it, the ship will look like it floats wrong. Every player class shares one box:
**4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z)**. Keep the HULL (keel to deck rail, excluding bowsprit, masts and sails)
inside it. Masts may rise to ~10 m; bowsprit and stern gallery may overhang the length a little.

**Gun ports:** the number per side must match the class (the game fires that many guns per side).

**Two prompts per model:** (a) Claude Design concept sheet, (b) text/image-to-3D for the `.glb`.

> Export: one .glb, Y-up, 1 unit = 1 metre, transforms applied. Orientation is critical:
> BOW points to -Z (Godot forward), STERN to +Z, PORT side -X, STARBOARD side +X. Origin at the
> centre of the keel bottom: the lowest point of the hull sits at y = 0 (the ship scene sets the
> waterline). Node names matter — the game finds parts by name:
>   - every sail mesh named "sail-a", "sail-b", "sail-c"... with its PIVOT AT THE TOP (on the yard),
>     because furling scales each sail along Y toward its pivot;
>   - every flag/pennant named "flag-a", "flag-b"... (the game tints these with the owner's colour);
>   - hull, deck, masts, rigging and guns may be one mesh or named parts ("hull", "deck", "mast-*").
> Optional: an empty node named "figurehead-socket" at the stem for cosmetic figureheads.
> No rig, no animation. Flat colour: vertex colours or one 256x256 swatch atlas (512x512 allowed for
> Galleon / Man O'War / bosses). No PBR maps — the toon shader re-shades it.

### Dinghy (`dinghy`) · `res://assets/models/ships/dinghy.glb` · 3 gun ports per side · ≤ 2,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Dinghy for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a small armed longboat: clinker-built open hull, three swivel guns per side on the gunwales, a short stub mast with one small lug sail, oars shipped along the sides, a lantern at the stern. Exactly 3 gun ports on EACH side.
Character: The player's very first boat — scrappy and underdog.
Proportions: overall about 1.4 m beam × 2.8 m length (including bowsprit), masts up to 1.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Dinghy sailing ship, Caribbean 1660-1720, for a mobile game.
A small armed longboat: clinker-built open hull, three swivel guns per side on the gunwales, a short stub mast with one small lug sail, oars shipped along the sides, a lantern at the stern. Exactly 3 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 1.4 m beam, ≤ 2.8 m length incl. bowsprit, masts ≤ 1.0 m. At most 2,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Sloop (`sloop`) · `res://assets/models/ships/sloop.glb` · 3 gun ports per side · ≤ 2,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Sloop for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a single-masted Caribbean sloop: low sleek hull, one tall mast with a big gaff mainsail and a jib on a long bowsprit, three gun ports per side, a tiller at the stern. Exactly 3 gun ports on EACH side.
Character: Fast and nimble, the classic pirate starter ship.
Proportions: overall about 4.8 m beam × 8.8 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Sloop sailing ship, Caribbean 1660-1720, for a mobile game.
A single-masted Caribbean sloop: low sleek hull, one tall mast with a big gaff mainsail and a jib on a long bowsprit, three gun ports per side, a tiller at the stern. Exactly 3 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 8.8 m length incl. bowsprit, masts ≤ 10.0 m. At most 2,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Schooner (`schooner`) · `res://assets/models/ships/schooner.glb` · 4 gun ports per side · ≤ 4,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Schooner for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a two-masted schooner: narrow raked hull, two raked masts with gaff fore-and-aft sails, a jib and staysail, four gun ports per side, a small raised quarterdeck. Exactly 4 gun ports on EACH side.
Character: Built for speed and chasing merchantmen.
Proportions: overall about 4.8 m beam × 8.8 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Schooner sailing ship, Caribbean 1660-1720, for a mobile game.
A two-masted schooner: narrow raked hull, two raked masts with gaff fore-and-aft sails, a jib and staysail, four gun ports per side, a small raised quarterdeck. Exactly 4 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 8.8 m length incl. bowsprit, masts ≤ 10.0 m. At most 4,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Corvette (`corvette`) · `res://assets/models/ships/corvette.glb` · 4 gun ports per side · ≤ 4,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Corvette for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a small three-masted corvette (sloop-of-war): flush gun deck with four gun ports per side, square sails on fore and main, a lateen mizzen, neat painted gunwale stripe. Exactly 4 gun ports on EACH side.
Character: A proper warship in miniature, disciplined lines.
Proportions: overall about 3.6 m beam × 9.9 m length (including bowsprit), masts up to 9.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Corvette sailing ship, Caribbean 1660-1720, for a mobile game.
A small three-masted corvette (sloop-of-war): flush gun deck with four gun ports per side, square sails on fore and main, a lateen mizzen, neat painted gunwale stripe. Exactly 4 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 3.6 m beam, ≤ 9.9 m length incl. bowsprit, masts ≤ 9.0 m. At most 4,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Brigantine (`brigantine`) · `res://assets/models/ships/brigantine.glb` · 5 gun ports per side · ≤ 4,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Brigantine for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a two-masted brigantine: square-rigged foremast, fore-and-aft mainsail on the main mast, five gun ports per side, a raised forecastle and quarterdeck with a stern lantern. Exactly 5 gun ports on EACH side.
Character: The pirate's workhorse — balanced, menacing.
Proportions: overall about 4.8 m beam × 10.6 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Brigantine sailing ship, Caribbean 1660-1720, for a mobile game.
A two-masted brigantine: square-rigged foremast, fore-and-aft mainsail on the main mast, five gun ports per side, a raised forecastle and quarterdeck with a stern lantern. Exactly 5 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 10.6 m length incl. bowsprit, masts ≤ 10.0 m. At most 4,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Frigate (`frigate`) · `res://assets/models/ships/frigate.glb` · 5 gun ports per side · ≤ 4,500 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Frigate for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a three-masted frigate: long elegant hull with a single continuous gun deck of five ports per side, full square rig, a quarterdeck with a carved stern gallery and windows. Exactly 5 gun ports on EACH side.
Character: Fast warship of the line's edge; prestige.
Proportions: overall about 4.8 m beam × 13.1 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Frigate sailing ship, Caribbean 1660-1720, for a mobile game.
A three-masted frigate: long elegant hull with a single continuous gun deck of five ports per side, full square rig, a quarterdeck with a carved stern gallery and windows. Exactly 5 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 13.1 m length incl. bowsprit, masts ≤ 10.0 m. At most 4,500 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Galleon (`galleon`) · `res://assets/models/ships/galleon.glb` · 6 gun ports per side · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Galleon for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a three-masted galleon: tall stepped stern castle with gilded windows, high forecastle, six gun ports per side, square sails on fore and main and a lateen mizzen, heavy and broad. Exactly 6 gun ports on EACH side.
Character: A floating fortress of treasure.
Proportions: overall about 4.8 m beam × 13.1 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Galleon sailing ship, Caribbean 1660-1720, for a mobile game.
A three-masted galleon: tall stepped stern castle with gilded windows, high forecastle, six gun ports per side, square sails on fore and main and a lateen mizzen, heavy and broad. Exactly 6 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 13.1 m length incl. bowsprit, masts ≤ 10.0 m. At most 7,000 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Man O'War (`man_o_war`) · `res://assets/models/ships/man_o_war.glb` · 8 gun ports per side · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Create an orthographic turnaround concept sheet of a Man O'War for a stylized low-poly pirate
mobile game. Views at the same scale on a flat light-grey background with a 1-metre grid:
starboard side profile, top-down plan, bow-on front, stern, and a 3/4 hero view. Label views.
The ship: a two-decked ship of the line: two tiers of gun ports (eight per side visible across both decks), massive full square rig with topgallants, ornate stern with three tiers of windows, a big figurehead. Exactly 8 gun ports on EACH side.
Character: The pinnacle of naval power — overwhelming.
Proportions: overall about 4.8 m beam × 13.1 m length (including bowsprit), masts up to 10.0 m;
the hull from keel to deck rail fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z).
Paint it in the PLAYER livery: weathered dark wood hull (#5f4c3d, #3d2817) with a brass-yellow
rail stripe (#e8b25a), off-white canvas sails (#e8dcc4) and a black flag. Sails and flags must be
clearly separate shapes from the hull and rigging.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536, view labels only.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of a Man O'War sailing ship, Caribbean 1660-1720, for a mobile game.
A two-decked ship of the line: two tiers of gun ports (eight per side visible across both decks), massive full square rig with topgallants, ornate stern with three tiers of windows, a big figurehead. Exactly 8 gun ports per side with short cannon muzzles.
Use the attached concept sheet. Hull (keel to rail) fits within 4.6 m wide (X) × 2.0 m tall (Y) × 9.0 m long (Z);
overall ≤ 4.8 m beam, ≤ 13.1 m length incl. bowsprit, masts ≤ 10.0 m. At most 7,000 triangles.
Sails as separate meshes named sail-a, sail-b, ... each with its pivot on its yard (top edge);
flags named flag-a, flag-b, ...; optional empty "figurehead-socket" at the stem.
BOW toward -Z, starboard +X, keel bottom at y = 0.
Export .glb, Y-up, metres, transforms applied, flat colours (vertex colours or one 256x256
swatch atlas), no PBR maps, no rig, no animation.
```

### Enemy and boss ships

Each boss keeps its own collision box (listed). Same export, naming and orientation rules as above.

#### Generic enemy warship · scene `scenes/world/EnemyShip.tscn` · `res://assets/models/ships/enemy_brig.glb` · hull box 4.6 × 2.0 × 9.0 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of Generic enemy warship for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a mid-sized two-masted warship (brig) with five gun ports per side, plain hull, square sails — a neutral design that the game re-tints per faction through its flags.
Intent: Must look generic enough to serve Royal Navy, Spanish and pirate crews; faction identity comes from flags.
The hull from keel to deck rail fits within 4.6 × 2.0 × 9.0 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of Generic enemy warship, a Caribbean 1660-1720 sailing ship for a mobile game.
A mid-sized two-masted warship (brig) with five gun ports per side, plain hull, square sails — a neutral design that the game re-tints per faction through its flags.
Hull (keel to rail) inside 4.6 × 2.0 × 9.0 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

#### HMS Intransigent (Admiral Vance, Royal Navy) · scene `scenes/world/IntransigentBoss.tscn` · `res://assets/models/ships/boss_intransigent.glb` · hull box 4.6 × 2.0 × 9.0 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of HMS Intransigent (Admiral Vance, Royal Navy) for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a Royal Navy fourth-rate ship of the line: navy-blue hull with a yellow-ochre gun-deck stripe (Nelson chequer style), two tiers of gun ports, white sails, a large red ensign at the stern, a gilded lion figurehead.
Intent: Chapter 4 boss: disciplined, immaculate, imposing — the Admiralty's pride.
The hull from keel to deck rail fits within 4.6 × 2.0 × 9.0 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of HMS Intransigent (Admiral Vance, Royal Navy), a Caribbean 1660-1720 sailing ship for a mobile game.
A Royal Navy fourth-rate ship of the line: navy-blue hull with a yellow-ochre gun-deck stripe (Nelson chequer style), two tiers of gun ports, white sails, a large red ensign at the stern, a gilded lion figurehead.
Hull (keel to rail) inside 4.6 × 2.0 × 9.0 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

#### Silver Fleet flagship (Almirante Cárdenas, Spain) · scene `scenes/world/CardenasBoss.tscn` · `res://assets/models/ships/boss_cardenas.glb` · hull box 4.6 × 2.0 × 9.0 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of Silver Fleet flagship (Almirante Cárdenas, Spain) for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a Spanish treasure galleon flagship: deep red and gold hull, towering gilded stern castle with balconies, crosses of Burgundy on the sails, silver chests visible on deck, a carved saint figurehead.
Intent: Chapter 5 boss: wealth and empire made into a ship.
The hull from keel to deck rail fits within 4.6 × 2.0 × 9.0 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of Silver Fleet flagship (Almirante Cárdenas, Spain), a Caribbean 1660-1720 sailing ship for a mobile game.
A Spanish treasure galleon flagship: deep red and gold hull, towering gilded stern castle with balconies, crosses of Burgundy on the sails, silver chests visible on deck, a carved saint figurehead.
Hull (keel to rail) inside 4.6 × 2.0 × 9.0 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

#### The Iron Vulture (pirate raider) · scene `scenes/world/IronVultureBoss.tscn` · `res://assets/models/ships/boss_iron_vulture.glb` · hull box 3.6 × 1.8 × 7.5 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of The Iron Vulture (pirate raider) for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a black pirate raider armoured with riveted iron plates over the bow and gunwales, a ram beak at the stem, ragged dark-red sails, a vulture-skull figurehead, chains and hooks hanging from the yards.
Intent: Smaller and meaner than other bosses — a predator.
The hull from keel to deck rail fits within 3.6 × 1.8 × 7.5 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of The Iron Vulture (pirate raider), a Caribbean 1660-1720 sailing ship for a mobile game.
A black pirate raider armoured with riveted iron plates over the bow and gunwales, a ram beak at the stem, ragged dark-red sails, a vulture-skull figurehead, chains and hooks hanging from the yards.
Hull (keel to rail) inside 3.6 × 1.8 × 7.5 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

#### Fortune's Toll (privateer toll-collector) · scene `scenes/world/FortunesTollBoss.tscn` · `res://assets/models/ships/boss_fortunes_toll.glb` · hull box 4.2 × 1.9 × 8.4 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of Fortune's Toll (privateer toll-collector) for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a gaudy privateer frigate: hull painted in black with gold scrollwork, a giant brass bell at the bow, coin-shaped shields along the rails, purple and gold striped sails.
Intent: Arrogant, rich, theatrical: 'every captain pays eventually'.
The hull from keel to deck rail fits within 4.2 × 1.9 × 8.4 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of Fortune's Toll (privateer toll-collector), a Caribbean 1660-1720 sailing ship for a mobile game.
A gaudy privateer frigate: hull painted in black with gold scrollwork, a giant brass bell at the bow, coin-shaped shields along the rails, purple and gold striped sails.
Hull (keel to rail) inside 4.2 × 1.9 × 8.4 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

#### Ghost Fleet flagship · scene `scenes/world/GhostFleetBoss.tscn` · `res://assets/models/ships/boss_ghost_fleet.glb` · hull box 4.6 × 2.0 × 9.0 m (W × H × L) · ≤ 7,000 tris

(a) Claude Design — concept sheet
```
Orthographic turnaround concept sheet of Ghost Fleet flagship for a stylized low-poly pirate mobile game:
starboard profile, top-down, bow-on, stern and 3/4 hero view, same scale, flat light-grey
background with a 1-metre grid, view labels only.
The ship: a drowned ghost galleon: rotted grey-green timbers with holes showing the ribs, tattered translucent sails, barnacles and seaweed, faint teal lanterns, a broken figurehead.
Intent: Eerie and wrong; the materials should look waterlogged. Use pale teal emissive-looking colour (flat colour, no emission maps) on lanterns.
The hull from keel to deck rail fits within 4.6 × 2.0 × 9.0 m (width × height × length); masts ≤ 10 m.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: one PNG sheet, 2048×1536.
```

(b) 3D tool — model
```
Low-poly stylized 3D model of Ghost Fleet flagship, a Caribbean 1660-1720 sailing ship for a mobile game.
A drowned ghost galleon: rotted grey-green timbers with holes showing the ribs, tattered translucent sails, barnacles and seaweed, faint teal lanterns, a broken figurehead.
Hull (keel to rail) inside 4.6 × 2.0 × 9.0 m (X width × Y height × Z length); masts ≤ 10 m; ≤ 7,000 tris.
Sails named sail-a, sail-b... pivot on the yard; flags named flag-a...; BOW toward -Z,
starboard +X, keel bottom at y = 0. Export .glb, Y-up, metres, transforms applied, flat colours
(vertex colours or one 512x512 swatch atlas), no PBR maps, no rig, no animation.
```

---

## Faction flags and sails — 10 PNG (M31)

Used by the `FactionData.flag_texture_path` / `sail_texture_path` seams (wired in M31). **Tool:
Claude Design → PNG.** Flags: 512×340 (3:2), RGBA, the flag shape filling the canvas, flat colour
with 2-3 tone cloth folds, no pole. Sails: 512×512, RGBA, a square sail panel filling the canvas
(the game stretches it over sail meshes), seamless edges, no rigging drawn. ≤ 200 KB each.

### Royal Navy (Britain)
Flag · `res://assets/factions/royal_navy/flag.png`
```
Create a flat stylized flag texture, 512×340 PNG with transparent edges: a 1660-1700 English naval red ensign: a solid red field with the cross of St George (red cross on white) in the upper canton next to the hoist.
Painted in a low-poly game style — flat colours with two or three tone bands suggesting gentle
cloth folds, no photographic fabric texture, no pole, no text. Palette: navy blue #3f4756, red #c1272d, white #f0ece0, gold #e8b25a.
Must stay recognisable when shrunk to 32 pixels wide on a phone.
```
Sail · `res://assets/factions/royal_navy/sail.png`
```
Create a square sail texture, 512×512 PNG, for a stylized low-poly pirate game: off-white canvas with faint seams and a small red cross of St George near the head of the sail.
Flat colours with subtle horizontal panel seams every 64 px, edges seamless (no border drawn,
no rope, no mast). Palette: navy blue #3f4756, red #c1272d, white #f0ece0, gold #e8b25a. It will be stretched over sail meshes, so keep the emblem
centred and inside the middle 70%.
```

### Spanish Empire
Flag · `res://assets/factions/spanish_empire/flag.png`
```
Create a flat stylized flag texture, 512×340 PNG with transparent edges: the Spanish Cross of Burgundy: a white field with a red saw-toothed diagonal cross (ragged staff saltire).
Painted in a low-poly game style — flat colours with two or three tone bands suggesting gentle
cloth folds, no photographic fabric texture, no pole, no text. Palette: red #c1272d, gold #d4a02f, white #f0ece0.
Must stay recognisable when shrunk to 32 pixels wide on a phone.
```
Sail · `res://assets/factions/spanish_empire/sail.png`
```
Create a square sail texture, 512×512 PNG, for a stylized low-poly pirate game: pale linen canvas with a large red Cross of Burgundy centred, slightly faded.
Flat colours with subtle horizontal panel seams every 64 px, edges seamless (no border drawn,
no rope, no mast). Palette: red #c1272d, gold #d4a02f, white #f0ece0. It will be stretched over sail meshes, so keep the emblem
centred and inside the middle 70%.
```

### Merchant Guild
Flag · `res://assets/factions/merchant_guild/flag.png`
```
Create a flat stylized flag texture, 512×340 PNG with transparent edges: a merchant house flag: a gold field with a dark-blue balance-scale emblem and a narrow blue border.
Painted in a low-poly game style — flat colours with two or three tone bands suggesting gentle
cloth folds, no photographic fabric texture, no pole, no text. Palette: gold #e8b25a, deep blue #2b3544, cream #e8dcc4.
Must stay recognisable when shrunk to 32 pixels wide on a phone.
```
Sail · `res://assets/factions/merchant_guild/sail.png`
```
Create a square sail texture, 512×512 PNG, for a stylized low-poly pirate game: cream canvas with a blue horizontal band and a small gold scale emblem.
Flat colours with subtle horizontal panel seams every 64 px, edges seamless (no border drawn,
no rope, no mast). Palette: gold #e8b25a, deep blue #2b3544, cream #e8dcc4. It will be stretched over sail meshes, so keep the emblem
centred and inside the middle 70%.
```

### Pirate Clans
Flag · `res://assets/factions/pirate_clans/flag.png`
```
Create a flat stylized flag texture, 512×340 PNG with transparent edges: a black pirate flag with a white skull above crossed bones, a red hourglass to one side.
Painted in a low-poly game style — flat colours with two or three tone bands suggesting gentle
cloth folds, no photographic fabric texture, no pole, no text. Palette: black #1c222b, bone white #e8dcc4, red #c1272d.
Must stay recognisable when shrunk to 32 pixels wide on a phone.
```
Sail · `res://assets/factions/pirate_clans/sail.png`
```
Create a square sail texture, 512×512 PNG, for a stylized low-poly pirate game: patched dark-grey canvas with mismatched repair squares and a faded skull.
Flat colours with subtle horizontal panel seams every 64 px, edges seamless (no border drawn,
no rope, no mast). Palette: black #1c222b, bone white #e8dcc4, red #c1272d. It will be stretched over sail meshes, so keep the emblem
centred and inside the middle 70%.
```

### Ghost Fleet
Flag · `res://assets/factions/ghost_fleet/flag.png`
```
Create a flat stylized flag texture, 512×340 PNG with transparent edges: a torn, rotted flag of faded sea-green with a pale skeletal hand, edges shredded.
Painted in a low-poly game style — flat colours with two or three tone bands suggesting gentle
cloth folds, no photographic fabric texture, no pole, no text. Palette: sea-green #5f8f87, bone #d8cfbd, shadow #2a2820.
Must stay recognisable when shrunk to 32 pixels wide on a phone.
```
Sail · `res://assets/factions/ghost_fleet/sail.png`
```
Create a square sail texture, 512×512 PNG, for a stylized low-poly pirate game: translucent-looking tattered grey-green sail with holes and drifting strands.
Flat colours with subtle horizontal panel seams every 64 px, edges seamless (no border drawn,
no rope, no mast). Palette: sea-green #5f8f87, bone #d8cfbd, shadow #2a2820. It will be stretched over sail meshes, so keep the emblem
centred and inside the middle 70%.
```

## Island owner banners — 5 PNG (M31)

A small banner shown at each owned island and in its port view (`IslandData.owner_banner_path`).
The banner shows the island's **own heraldry**; the owner's colour is tinted on top by the game,
so paint the field in light neutral cream (#e8dcc4) and the emblem in dark ink. 256×384 PNG, RGBA,
a vertical swallow-tailed pennant hanging from a short crossbar, ≤ 100 KB.

### Port Royal · `res://assets/islands/port_royal/owner_banner.png`
```
Create a vertical swallow-tailed pennant banner, 256×384 PNG, transparent background, hanging
from a short dark wooden crossbar at the top. Field: plain light cream #e8dcc4 (it will be tinted
in game). Emblem centred in dark ink #2a2820: a drowned church bell tower half under stylized waves (the 1692 earthquake). Flat stylized low-poly game style, 2-3
fold tones, no text, readable at 48 px tall.
```

### Tortuga · `res://assets/islands/tortuga/owner_banner.png`
```
Create a vertical swallow-tailed pennant banner, 256×384 PNG, transparent background, hanging
from a short dark wooden crossbar at the top. Field: plain light cream #e8dcc4 (it will be tinted
in game). Emblem centred in dark ink #2a2820: a turtle shell with a single crossed cutlass. Flat stylized low-poly game style, 2-3
fold tones, no text, readable at 48 px tall.
```

### Pelican Cay · `res://assets/islands/pelican_cay/owner_banner.png`
```
Create a vertical swallow-tailed pennant banner, 256×384 PNG, transparent background, hanging
from a short dark wooden crossbar at the top. Field: plain light cream #e8dcc4 (it will be tinted
in game). Emblem centred in dark ink #2a2820: a pelican in flight over a low sandbar. Flat stylized low-poly game style, 2-3
fold tones, no text, readable at 48 px tall.
```

### Skull Cove · `res://assets/islands/skull_cove/owner_banner.png`
```
Create a vertical swallow-tailed pennant banner, 256×384 PNG, transparent background, hanging
from a short dark wooden crossbar at the top. Field: plain light cream #e8dcc4 (it will be tinted
in game). Emblem centred in dark ink #2a2820: a skull-shaped volcanic caldera with a single opening. Flat stylized low-poly game style, 2-3
fold tones, no text, readable at 48 px tall.
```

### Cartagena Outpost · `res://assets/islands/cartagena_outpost/owner_banner.png`
```
Create a vertical swallow-tailed pennant banner, 256×384 PNG, transparent background, hanging
from a short dark wooden crossbar at the top. Field: plain light cream #e8dcc4 (it will be tinted
in game). Emblem centred in dark ink #2a2820: a star-fort bastion with a treasure chest on its wall. Flat stylized low-poly game style, 2-3
fold tones, no text, readable at 48 px tall.
```

---

## Combat VFX sprite sheets — 6 PNG (M33)

**Tool: Claude Design → PNG.** Each sheet is a regular grid with NO gaps or padding between cells;
every cell has the effect centred on the same anchor point; transparent background; flat
stylized cel-shaded look (2-3 tones per colour, hard edges), matching low-poly toon rendering.
Delivered to `res://assets/vfx/<name>.png`.

### `cannon_muzzle_flash` · 4 frames · 2×2 grid · 256×256 px cells · sheet 512×512 px
```
Create a sprite sheet PNG of exactly 512×512 pixels: a 2×2 grid (columns × rows) of
256×256 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
4 frames total. Animation: a cannon muzzle blast seen from the side: frame 1 a tight white-yellow core, frame 2 a wide orange flame cone with sparks, frame 3 the flame breaking into puffs, frame 4 thin grey smoke wisps.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #fff4c2, #ffb347, #e8662a, #8b8a7c. Keep the effect centred on the same point in every cell and inside the cell.
```

### `water_splash` · 8 frames · 4×2 grid · 256×256 px cells · sheet 1024×512 px
```
Create a sprite sheet PNG of exactly 1024×512 pixels: a 4×2 grid (columns × rows) of
256×256 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
8 frames total. Animation: a cannonball hitting water: a narrow white spout rising, a crown splash with droplets, falling spray, a fading ring of foam on the surface.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #ffffff, #cfeff2, #1ba3b5. Keep the effect centred on the same point in every cell and inside the cell.
```

### `hull_hit_splinters` · 6 frames · 3×2 grid · 256×256 px cells · sheet 768×512 px
```
Create a sprite sheet PNG of exactly 768×512 pixels: a 3×2 grid (columns × rows) of
256×256 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
6 frames total. Animation: a cannonball striking a wooden hull: a burst of brown wood splinters and a puff of dust spreading outward and falling.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #8b6f47, #5f4c3d, #d4a574, #b8b0a0. Keep the effect centred on the same point in every cell and inside the cell.
```

### `ship_fire` · 8 frames · 4×2 grid · 256×256 px cells · sheet 1024×512 px
```
Create a sprite sheet PNG of exactly 1024×512 pixels: a 4×2 grid (columns × rows) of
256×256 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
8 frames total. Animation: a looping deck fire: licking stylized flames (three tongues) that sway and flicker; frame 8 loops back to frame 1 seamlessly.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #fff4c2, #ffb347, #e8662a, #8b0000. Keep the effect centred on the same point in every cell and inside the cell.
```

### `smoke_plume` · 8 frames · 4×2 grid · 256×256 px cells · sheet 1024×512 px
```
Create a sprite sheet PNG of exactly 1024×512 pixels: a 4×2 grid (columns × rows) of
256×256 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
8 frames total. Animation: a looping column of chunky stylized smoke puffs rising and drifting right, fading at the top; seamless loop.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #5a5a5a, #8b8a7c, #b8b0a0. Keep the effect centred on the same point in every cell and inside the cell.
```

### `ship_explosion` · 10 frames · 5×2 grid · 512×512 px cells · sheet 2560×1024 px
```
Create a sprite sheet PNG of exactly 2560×1024 pixels: a 5×2 grid (columns × rows) of
512×512 cells, no gaps, transparent background, read left-to-right then top-to-bottom,
10 frames total. Animation: a powder magazine explosion: bright flash, an expanding fireball with debris planks flying out, then a dark smoke mushroom dissipating.
Style: stylized cel-shaded game VFX, flat shapes with 2-3 tone steps and hard edges, chunky
readable forms (this plays small on a phone), no photographic texture, no motion blur.
Palette: #ffffff, #fff4c2, #ffb347, #e8662a, #3d2817, #5a5a5a. Keep the effect centred on the same point in every cell and inside the cell.
```

---

## Port-view island scenes — 5 (M32)

When the player docks, the camera moves to a close view of the island where the buildings stand in
their real slots. These are **environment dioramas**: one per island, holding the terrain, shore,
dock and dressing — NOT the buildings (those are the 50 models above, placed in the 5 slots).
Delivery: `res://assets/models/ports/<island_id>.glb`; we wrap it in the scene referenced by
`IslandData.port_scene_path`. Size: fits a 40 m × 40 m square, sea level at y = 0, five flat
3.5 m × 3.5 m building plots clearly readable, ≤ 25,000 tris, one 1024×1024 swatch atlas.

### Port Royal · `res://assets/models/ports/port_royal.glb`
(a) Claude Design — concept painting
```
Paint a 3/4 top-down concept of Port Royal, a port on a Caribbean island (1660-1720) for a stylized
low-poly mobile game: a ruined colonial port half-drowned by an earthquake: a broken stone church tower standing in the shallows, collapsed brick warehouses with water in their ground floors, a surviving timber wharf, palm trees, and five empty level building plots marked by stone foundations. Camera ~35° down, the whole island filling the frame, sea around it.
Mark the five building plots with numbered flat stone pads. Flat-shaded low-poly style.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: 2048×1536 PNG.
```
(b) 3D tool — diorama
```
Low-poly stylized island diorama of Port Royal: a ruined colonial port half-drowned by an earthquake: a broken stone church tower standing in the shallows, collapsed brick warehouses with water in their ground floors, a surviving timber wharf, palm trees, and five empty level building plots marked by stone foundations. Use the attached concept.
Fits a 40 m × 40 m square; sea level y = 0 (terrain below water allowed down to -2 m);
five flat 3.5 m × 3.5 m stone building pads, level and unobstructed, named plot-1 ... plot-5
as empty marker nodes at each pad centre. No buildings on the pads. ≤ 25,000 triangles.
Export .glb, Y-up, metres, transforms applied, flat colours via one 1024x1024 swatch atlas,
no PBR maps.
```

### Tortuga · `res://assets/models/ports/tortuga.glb`
(a) Claude Design — concept painting
```
Paint a 3/4 top-down concept of Tortuga, a port on a Caribbean island (1660-1720) for a stylized
low-poly mobile game: a lively pirate harbour on a rocky green island: a crooked timber waterfront, a hillside of colourful shacks, a small stone fort on the headland, rowboats, and five building plots on terraces. Camera ~35° down, the whole island filling the frame, sea around it.
Mark the five building plots with numbered flat stone pads. Flat-shaded low-poly style.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: 2048×1536 PNG.
```
(b) 3D tool — diorama
```
Low-poly stylized island diorama of Tortuga: a lively pirate harbour on a rocky green island: a crooked timber waterfront, a hillside of colourful shacks, a small stone fort on the headland, rowboats, and five building plots on terraces. Use the attached concept.
Fits a 40 m × 40 m square; sea level y = 0 (terrain below water allowed down to -2 m);
five flat 3.5 m × 3.5 m stone building pads, level and unobstructed, named plot-1 ... plot-5
as empty marker nodes at each pad centre. No buildings on the pads. ≤ 25,000 triangles.
Export .glb, Y-up, metres, transforms applied, flat colours via one 1024x1024 swatch atlas,
no PBR maps.
```

### Pelican Cay · `res://assets/models/ports/pelican_cay.glb`
(a) Claude Design — concept painting
```
Paint a 3/4 top-down concept of Pelican Cay, a port on a Caribbean island (1660-1720) for a stylized
low-poly mobile game: a low sandy cay with mangroves and pelican rookeries in driftwood, a fishermen's pier with drying nets, turquoise shallows, and five building plots on the sand ridge. Camera ~35° down, the whole island filling the frame, sea around it.
Mark the five building plots with numbered flat stone pads. Flat-shaded low-poly style.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: 2048×1536 PNG.
```
(b) 3D tool — diorama
```
Low-poly stylized island diorama of Pelican Cay: a low sandy cay with mangroves and pelican rookeries in driftwood, a fishermen's pier with drying nets, turquoise shallows, and five building plots on the sand ridge. Use the attached concept.
Fits a 40 m × 40 m square; sea level y = 0 (terrain below water allowed down to -2 m);
five flat 3.5 m × 3.5 m stone building pads, level and unobstructed, named plot-1 ... plot-5
as empty marker nodes at each pad centre. No buildings on the pads. ≤ 25,000 triangles.
Export .glb, Y-up, metres, transforms applied, flat colours via one 1024x1024 swatch atlas,
no PBR maps.
```

### Skull Cove · `res://assets/models/ports/skull_cove.glb`
(a) Claude Design — concept painting
```
Paint a 3/4 top-down concept of Skull Cove, a port on a Caribbean island (1660-1720) for a stylized
low-poly mobile game: a drowned volcanic caldera reached through one narrow rock entrance: black rock walls shaped faintly like a skull, a rum-smugglers' dock inside, steam vents, and five plots carved into the inner slope. Camera ~35° down, the whole island filling the frame, sea around it.
Mark the five building plots with numbered flat stone pads. Flat-shaded low-poly style.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: 2048×1536 PNG.
```
(b) 3D tool — diorama
```
Low-poly stylized island diorama of Skull Cove: a drowned volcanic caldera reached through one narrow rock entrance: black rock walls shaped faintly like a skull, a rum-smugglers' dock inside, steam vents, and five plots carved into the inner slope. Use the attached concept.
Fits a 40 m × 40 m square; sea level y = 0 (terrain below water allowed down to -2 m);
five flat 3.5 m × 3.5 m stone building pads, level and unobstructed, named plot-1 ... plot-5
as empty marker nodes at each pad centre. No buildings on the pads. ≤ 25,000 triangles.
Export .glb, Y-up, metres, transforms applied, flat colours via one 1024x1024 swatch atlas,
no PBR maps.
```

### Cartagena Outpost · `res://assets/models/ports/cartagena_outpost.glb`
(a) Claude Design — concept painting
```
Paint a 3/4 top-down concept of Cartagena Outpost, a port on a Caribbean island (1660-1720) for a stylized
low-poly mobile game: a fortified Spanish staging port: a stone star-fort bastion, a customs house with red tile roofs, a treasure-fleet mole with mooring posts, and five plots inside the walls. Camera ~35° down, the whole island filling the frame, sea around it.
Mark the five building plots with numbered flat stone pads. Flat-shaded low-poly style.
Style anchor (apply to every prompt): Caribbean pirate golden age, 1660-1720. Stylized
low-poly, flat-shaded faces, hard readable silhouettes, chunky proportions that read from a
top-down 3/4 mobile camera ~40 m away. Matches the Kenney Pirate Kit look already in the game.
Palette: ocean #1ba3b5 #2b9acd #0f8b8c; land #5a8c3a #7ba438; sand #d4a574 #c49060;
wood #8b6f47 #5f4c3d #3d2817; weathered wood #6b6455 #8b8a7c; brass/gold #e8b25a #d4a02f;
iron #4a4757 #2a2820; canvas/linen #e8dcc4 #d8cfbd; enemy red #c1272d #8b0000.
No photorealism, no PBR maps, no smooth bevels, no baked ambient occlusion.
Output: 2048×1536 PNG.
```
(b) 3D tool — diorama
```
Low-poly stylized island diorama of Cartagena Outpost: a fortified Spanish staging port: a stone star-fort bastion, a customs house with red tile roofs, a treasure-fleet mole with mooring posts, and five plots inside the walls. Use the attached concept.
Fits a 40 m × 40 m square; sea level y = 0 (terrain below water allowed down to -2 m);
five flat 3.5 m × 3.5 m stone building pads, level and unobstructed, named plot-1 ... plot-5
as empty marker nodes at each pad centre. No buildings on the pads. ≤ 25,000 triangles.
Export .glb, Y-up, metres, transforms applied, flat colours via one 1024x1024 swatch atlas,
no PBR maps.
```

## Figurehead — Golden Eagle cosmetic (M33)

Replaces the placeholder prism in `scenes/cosmetics/FigureheadGoldenEagle.tscn`.
Delivery: `res://assets/models/cosmetics/figurehead_golden_eagle.glb`.

(a) Claude Design — concept
```
Concept sheet of a carved ship's figurehead: a golden eagle with wings swept back along the hull
and talons gripping a scroll, Caribbean 1660-1720, stylized low-poly game style. Side, front and
3/4 views on a flat grey background with a 10 cm grid. Gilded wood (#e8b25a, #d4a02f) with
dark-brown shading (#5f4c3d). Output 1536×1024 PNG.
```
(b) 3D tool — model
```
Low-poly stylized ship figurehead: golden eagle, wings swept back, talons on a scroll.
Size about 0.5 m long × 0.3 m wide × 0.45 m tall. Its back face is flat and sits on the origin
(it mounts at a ship's stem); it faces -Z. ≤ 800 triangles, flat gold colours (vertex colour or a
small swatch atlas). Export .glb, Y-up, metres, transforms applied, no rig.
```

## Play Store feature graphic (M35)

Delivery: `res://assets/branding/feature_graphic.png` (also uploaded to the Play Console).
```
Create a Google Play feature graphic, exactly 1024×500 PNG (no transparency), for "Pirate Empire",
a mobile strategy game where you build a pirate empire in the 1660-1720 Caribbean. Scene: a
player galleon with black flag broadside to a Spanish treasure galleon, cannon smoke between them,
a sunlit island harbour with the player's buildings behind, turquoise sea. Stylized low-poly art,
flat-shaded, bold silhouettes. Leave the left 40% calmer (sky/sea) for the logo; put NO text in
the image. Keep important content away from the outer 10% (Play crops it).
Palette: ocean #1ba3b5 #2b9acd, sand #d4a574, wood #5f4c3d, gold #e8b25a, Spanish red #c1272d.
```


## Delivery checklist

The retention UI icons (§M30) are listed in their own section above.

| # | Path | Format | Tool | Needed by |
|---|---|---|---|---|
| 1 | `res://assets/portraits/Hale.png` | PNG 512² | Claude Design | M29 |
| 2 | `res://assets/portraits/MorrowsMessenger.png` | PNG 512² | Claude Design | M29 |
| 3 | `res://assets/portraits/Hollis.png` | PNG 512² | Claude Design | M29 |
| 4 | `res://assets/portraits/Marguerite.png` | PNG 512² | Claude Design | M29 |
| 5 | `res://assets/portraits/Vance.png` | PNG 512² | Claude Design | M29 |
| 6 | `res://assets/portraits/Cardenas.png` | PNG 512² | Claude Design | M29 |
| 7 | `res://assets/models/buildings/farm_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 8 | `res://assets/models/buildings/farm_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 9 | `res://assets/models/buildings/farm_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 10 | `res://assets/models/buildings/farm_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 11 | `res://assets/models/buildings/farm_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 12 | `res://assets/models/buildings/lumber_mill_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 13 | `res://assets/models/buildings/lumber_mill_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 14 | `res://assets/models/buildings/lumber_mill_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 15 | `res://assets/models/buildings/lumber_mill_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 16 | `res://assets/models/buildings/lumber_mill_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 17 | `res://assets/models/buildings/mine_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 18 | `res://assets/models/buildings/mine_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 19 | `res://assets/models/buildings/mine_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 20 | `res://assets/models/buildings/mine_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 21 | `res://assets/models/buildings/mine_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 22 | `res://assets/models/buildings/market_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 23 | `res://assets/models/buildings/market_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 24 | `res://assets/models/buildings/market_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 25 | `res://assets/models/buildings/market_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 26 | `res://assets/models/buildings/market_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 27 | `res://assets/models/buildings/tavern_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 28 | `res://assets/models/buildings/tavern_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 29 | `res://assets/models/buildings/tavern_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 30 | `res://assets/models/buildings/tavern_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 31 | `res://assets/models/buildings/tavern_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 32 | `res://assets/models/buildings/warehouse_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 33 | `res://assets/models/buildings/warehouse_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 34 | `res://assets/models/buildings/warehouse_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 35 | `res://assets/models/buildings/warehouse_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 36 | `res://assets/models/buildings/warehouse_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 37 | `res://assets/models/buildings/shipyard_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 38 | `res://assets/models/buildings/shipyard_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 39 | `res://assets/models/buildings/shipyard_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 40 | `res://assets/models/buildings/shipyard_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 41 | `res://assets/models/buildings/shipyard_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 42 | `res://assets/models/buildings/academy_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 43 | `res://assets/models/buildings/academy_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 44 | `res://assets/models/buildings/academy_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 45 | `res://assets/models/buildings/academy_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 46 | `res://assets/models/buildings/academy_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 47 | `res://assets/models/buildings/fortress_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 48 | `res://assets/models/buildings/fortress_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 49 | `res://assets/models/buildings/fortress_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 50 | `res://assets/models/buildings/fortress_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 51 | `res://assets/models/buildings/fortress_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 52 | `res://assets/models/buildings/watchtower_l1.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 53 | `res://assets/models/buildings/watchtower_l2.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 54 | `res://assets/models/buildings/watchtower_l3.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 55 | `res://assets/models/buildings/watchtower_l4.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 56 | `res://assets/models/buildings/watchtower_l5.glb` | GLB | Claude Design + 3D tool | M29-M32 |
| 57 | `res://assets/models/ships/dinghy.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 58 | `res://assets/models/ships/sloop.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 59 | `res://assets/models/ships/schooner.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 60 | `res://assets/models/ships/corvette.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 61 | `res://assets/models/ships/brigantine.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 62 | `res://assets/models/ships/frigate.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 63 | `res://assets/models/ships/galleon.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 64 | `res://assets/models/ships/man_o_war.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 65 | `res://assets/models/ships/enemy_brig.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 66 | `res://assets/models/ships/boss_intransigent.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 67 | `res://assets/models/ships/boss_cardenas.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 68 | `res://assets/models/ships/boss_iron_vulture.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 69 | `res://assets/models/ships/boss_fortunes_toll.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 70 | `res://assets/models/ships/boss_ghost_fleet.glb` | GLB | Claude Design + 3D tool | M30-M32 |
| 71 | `res://assets/icons/events/island_discovered.svg` | SVG | Claude Design | M30 |
| 72 | `res://assets/icons/events/merchant_convoy_spotted.svg` | SVG | Claude Design | M30 |
| 73 | `res://assets/icons/events/floating_treasure_spotted.svg` | SVG | Claude Design | M30 |
| 74 | `res://assets/icons/events/ghost_ship_spotted.svg` | SVG | Claude Design | M30 |
| 75 | `res://assets/icons/events/iron_vulture_spotted.svg` | SVG | Claude Design | M30 |
| 76 | `res://assets/icons/events/fortunes_toll_spotted.svg` | SVG | Claude Design | M30 |
| 77 | `res://assets/icons/events/drifting_wreckage_spotted.svg` | SVG | Claude Design | M30 |
| 78 | `res://assets/icons/events/smugglers_cache_spotted.svg` | SVG | Claude Design | M30 |
| 79 | `res://assets/icons/events/pirate_raiding_party_spotted.svg` | SVG | Claude Design | M30 |
| 80 | `res://assets/icons/events/royal_navy_patrol_spotted.svg` | SVG | Claude Design | M30 |
| 81 | `res://assets/icons/events/wind_shifted.svg` | SVG | Claude Design | M30 |
| 82 | `res://assets/factions/royal_navy/flag.png` | PNG 512×340 | Claude Design | M31 |
| 83 | `res://assets/factions/royal_navy/sail.png` | PNG 512² | Claude Design | M31 |
| 84 | `res://assets/factions/spanish_empire/flag.png` | PNG 512×340 | Claude Design | M31 |
| 85 | `res://assets/factions/spanish_empire/sail.png` | PNG 512² | Claude Design | M31 |
| 86 | `res://assets/factions/merchant_guild/flag.png` | PNG 512×340 | Claude Design | M31 |
| 87 | `res://assets/factions/merchant_guild/sail.png` | PNG 512² | Claude Design | M31 |
| 88 | `res://assets/factions/pirate_clans/flag.png` | PNG 512×340 | Claude Design | M31 |
| 89 | `res://assets/factions/pirate_clans/sail.png` | PNG 512² | Claude Design | M31 |
| 90 | `res://assets/factions/ghost_fleet/flag.png` | PNG 512×340 | Claude Design | M31 |
| 91 | `res://assets/factions/ghost_fleet/sail.png` | PNG 512² | Claude Design | M31 |
| 92 | `res://assets/islands/port_royal/owner_banner.png` | PNG 256×384 | Claude Design | M31 |
| 93 | `res://assets/models/ports/port_royal.glb` | GLB | Claude Design + 3D tool | M32 |
| 94 | `res://assets/islands/tortuga/owner_banner.png` | PNG 256×384 | Claude Design | M31 |
| 95 | `res://assets/models/ports/tortuga.glb` | GLB | Claude Design + 3D tool | M32 |
| 96 | `res://assets/islands/pelican_cay/owner_banner.png` | PNG 256×384 | Claude Design | M31 |
| 97 | `res://assets/models/ports/pelican_cay.glb` | GLB | Claude Design + 3D tool | M32 |
| 98 | `res://assets/islands/skull_cove/owner_banner.png` | PNG 256×384 | Claude Design | M31 |
| 99 | `res://assets/models/ports/skull_cove.glb` | GLB | Claude Design + 3D tool | M32 |
| 100 | `res://assets/islands/cartagena_outpost/owner_banner.png` | PNG 256×384 | Claude Design | M31 |
| 101 | `res://assets/models/ports/cartagena_outpost.glb` | GLB | Claude Design + 3D tool | M32 |
| 102 | `res://assets/vfx/cannon_muzzle_flash.png` | PNG sheet | Claude Design | M33 |
| 103 | `res://assets/vfx/water_splash.png` | PNG sheet | Claude Design | M33 |
| 104 | `res://assets/vfx/hull_hit_splinters.png` | PNG sheet | Claude Design | M33 |
| 105 | `res://assets/vfx/ship_fire.png` | PNG sheet | Claude Design | M33 |
| 106 | `res://assets/vfx/smoke_plume.png` | PNG sheet | Claude Design | M33 |
| 107 | `res://assets/vfx/ship_explosion.png` | PNG sheet | Claude Design | M33 |
| 108 | `res://assets/models/cosmetics/figurehead_golden_eagle.glb` | GLB | Claude Design + 3D tool | M33 |
| 109 | `res://assets/branding/feature_graphic.png` | PNG 1024×500 | Claude Design | M35 |

