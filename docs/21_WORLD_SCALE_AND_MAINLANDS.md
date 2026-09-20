# 21_WORLD_SCALE_AND_MAINLANDS.md

> Version: 1.1
> Status: Design doc — not yet implemented; tasks in §9 are picked up incrementally, a few at a
> time, not as one pass.
> Owner: Project Lead
>
> Builds on: `docs/11_WORLD_MAP.md` (geography, world bounds — see its §4c for the
> 2026-09-21 realistic-geography repositioning and its principle 4 for the bounded-square-world
> design this doc's §5 leans on). Ground truth for what exists today: `docs/05_CURRENT_SYSTEMS.md`.
>
> **Scope note (added in the §6-§8 expansion pass):** this doc covers world-building/content/
> immersion decisions — "does the world feel like a real place." It deliberately does not
> duplicate `docs/15_MASTER_PLAN.md` §3.1's gap register (19 items, all monetization/platform/
> technical-debt, owned by M16-M21) — those are a different axis of "not done yet" and already
> tracked. Every gap named below was confirmed absent by reading the actual scripts/docs, not
> assumed.

---

# 1. Problem statement

Three related complaints, one root cause: islands are built at a scale that made sense as a
gameplay diagram (a building menu with some trees around it) but doesn't read as a real place next
to a ship.

**Measured, not estimated:**

| | Size (world units) |
|---|---|
| Starter ship hull (Sloop-class) | ~4.8 wide × 9 long (`PlayerShip.tscn`'s `BoxShape3D_hull` comment) |
| Island terrain footprint | ~24 across (collision cylinder radius 11u, `docs/11_WORLD_MAP.md`'s physical-constants table) |
| Ratio | an island is only ~2.5-3 ship-lengths wide |

At that ratio an island reads as a large boat, not a landmass. Every island also looks nearly
identical up close — 3 palms, 3 rocks, 2 barrels, 1 chest, the same 8 building slots — because all
11 islands instance the exact same `scenes/world/Island.tscn`, differentiated only by
`IslandData.terrain_theme`'s material re-tint (`Island._apply_terrain_theme()`).

Separately: Spain and Britain are supposed to be the two great imperial powers of the setting
(`resources/factions/SpanishEmpire.tres`, `RoyalNavy.tres`, both `is_empire = true`), but
mechanically they're represented only by a handful of enemy ships and one capturable outpost
(Cartagena). There's no sense of "this is a small pirate world sandwiched between two vast
empires" — the empires feel exactly as large as the one island each currently owns.

This doc designs fixes for both, sized to be implemented a few tasks at a time (§9), not as one
big rewrite. **Nothing in this doc is implemented yet** — it's the plan to work from.

---

# 2. Island scale-up

**Target:** roughly 3-4× the current linear scale — terrain radius from ~11-12u to ~35-45u
(~70-90u across), so an island reads as multiple ship-lengths in every direction: "a place you
sail around," not "a prop you sail past."

**How, not stretching:** `Island.tscn`'s sand/grass pieces (`patch-sand-foliage.glb`/
`patch-grass-foliage.glb`) are modular Kenney tile pieces, already used 4-up + 2-up to form the
current footprint. A bigger footprint should come from **tiling more copies** edge-to-edge, not
scaling the existing tiles further up — stretching a tile 3-4× visibly distorts its
texture/proportions; tiling doesn't. This also opens the door to varying island *shape* (oval vs.
round), not just size, by choosing the tile layout per island.

## Ripple-effect checklist

This change touches shared geometry and several distance-based rules elsewhere in the game —
treat it as one isolated task, verified fully (GUT + the headful capture harness) before layering
§3 or §4 on top:

| Item | Current | Needs |
|---|---|---|
| `Island.tscn` `CollisionShape3D` cylinder radius | 11u | Raise to match the new footprint (~35-45u) |
| `Buildings/BuildingSlots` marker positions | 8 slots, within ±9u of center | Move outward to the new footprint; add more slots (~12-16) so a bigger island doesn't look sparse |
| `Dock` (`structure-platform-dock.glb`) + `DockArea` position | x=19 | Move further out, past the new terrain edge |
| Existing `Foliage`/`Props` decor | positioned for the old footprint | Reposition (see §3 for also *adding* more) |
| `docs/11_WORLD_MAP.md`'s physical-constants table | radius 11u / beach-union radius ≈13.7u / min spacing 40u | Update all three together — min spacing is derived as union radius × 2 + navigation clearance |
| `tests/test_world_map_layout.gd`'s `MIN_ISLAND_SPACING` constant | 40u | Raise to match; **re-run and manually check every pairwise distance** — the tightest current pairs (e.g. Skull Cove ↔ Blackwater Shoal at 110u, from the 2026-09-21 geography-repositioning pass) are the most likely to need moving further apart |
| `PlayerShip` spawn transform in `World.tscn` | 100u south of Port Royal | Re-check clearance against the bigger Port Royal footprint |
| `CameraSettings.tres` default zoom/spring-arm distance | tuned for the old footprint | Likely needs to start further back so a bigger island still fits in frame |
| Docking trigger distance / `IslandData.docking_speed_limit` | tuned for the old dock position | Re-tune once the dock moves outward |

**Why do this first, alone:** §3 and §4 build directly on the new footprint; §8's populated ports
build on §4's settlement growth. §5, §6, and §7 are independent of it and can happen in any order.
Doing scale-up last would mean redoing decor/building placement twice. Doing it in the same pass as
decor/buildings would make a broken test failure much harder to attribute to the right cause.

---

# 3. Filler decor (trees, bushes, rocks)

Current `Foliage`/`Props` nodes in `Island.tscn`: 3 palms (`palm-detailed-bend.glb` ×2,
`palm-detailed-straight.glb` ×1), 3 rocks (`rocks-sand-a.glb` ×2, `rocks-sand-b.glb` ×1), 2
barrels, 1 chest — identical on every island, positioned for the old ~24u footprint.

**v1 task (cheap — do right after scale-up lands):** add more instances of the same asset kinds,
repositioned to fill the new ~70-90u footprint, still shared across all islands (matches the
existing "one scene, many instances" pattern — no per-island authoring burden). Available without
any new art, already in `assets/models/`: `palm-bend.glb`, `palm-straight.glb`, `grass.glb`,
`grass-plant.glb`, `rocks-a.glb`/`rocks-b.glb`/`rocks-c.glb` (in addition to the `-sand-` variants
already used). Purely decorative — no `CollisionShape3D`, no gameplay hook, same
`KenneyMaterialApplier` re-tint pattern every existing prop already uses.

**Stretch task (optional, do later):** vary decor by `IslandData.terrain_theme`, the same axis
`Island._apply_terrain_theme()` already re-tints materials on — e.g. denser palm clusters on
`TROPICAL`, sparser/scorched rock piles on `VOLCANIC`/`CALDERA`, driftwood/wreckage props instead
of palms on `DROWNED_RUIN` (Port Royal). Needs a small per-theme prop list (an array on
`IslandData`, or a lookup table keyed by `TerrainTheme`), read once in `Island._ready()` alongside
the existing terrain re-tint call.

---

# 4. Repeatable / cosmetic buildings

**Problem:** `Island.build_structure()` refuses if `has_building(building.building_id)` is already
true — correct for economy buildings (one Farm, upgraded in place via `upgrade_structure()`) but
blocks placing, say, three decorative houses on the same island.

**Design:**
- Add `@export var is_repeatable: bool = false` to `BuildingData.gd`.
- In `Island.build_structure()`, skip the `has_building()` uniqueness check when
  `building.is_repeatable` is true.
- Repeated instances need a synthetic per-instance id for save/restore, since
  `Island._resolve_building()` currently maps one `building_id` to one `<Name>_L<Level>.tres` path,
  and `restore_buildings()`/`get_built_building_ids()` assume every id is unique. Concrete
  sub-task: suffix repeated ids with an index (e.g. `house_cottage#2`) and teach
  `_resolve_building()` to strip the suffix before resolving the `.tres` path.
- New `BuildingData` resources, all cheap and **zero production** (this is population/prosperity
  signaling, not economy — keep it out of the circular-economy balance `docs/13` cares about): a
  couple of house variants (reuse `structure.glb` + `structure-roof.glb`, already the flavor House
  prop in `Island.tscn`, just re-colored via `KenneyMaterialApplier` for variety — same trick
  `Island.gd`'s `_spawn_building_visual()` already applies for the default structure model) and a
  generic port flourish (`structure-platform-dock-small.glb`/`structure-platform.glb`).
- Gate unlock behind `Island.get_island_tier()` (already the average built-building level) so a
  growing settlement visibly fills in as tier rises, rather than every repeatable building being
  available from tier 1 — reuses an existing mechanic instead of adding a second progression axis.
- **Needs retesting once slot count grows (§2):** `_spawn_building_visual()` currently wraps
  building index onto slot index via `slot_index % slots.size()` — with more slots *and* more
  repeated buildings both changing, verify this still looks reasonable rather than stacking models
  on the same marker.

---

# 5. Imperial mainlands (Spain priority, Britain deferred)

**Goal:** make Spain and Britain feel like vast hostile nations the player's pirate world is
sandwiched between, without building or making explorable their actual territory — "cut off from
the screen," and non-interactable for now.

**The mechanism already exists.** `WorldBoundsData`/`ShipController._clamp_to_world_bounds()`
(±1400u square, landed 2026-09-21) already physically stops any ship at the world edge. A mainland
landmass whose *detailed* near-coastline sits right at that edge — and whose landform simply keeps
going past it, or fades into fog beyond — needs **no new blocking logic**. The player sees a real
coast, tries to keep sailing along or into it, and is stopped by the same wall that already
exists, which reads as "this country is bigger than what I can reach," not as an arbitrary wall.
This is the "classic move" the request describes, and it's nearly free given what already shipped.

**Spain, priority:** place beyond Imperial Waters' south/south-east edge — per
`docs/11_WORLD_MAP.md` §4c/§1, Imperial Waters already sits south/south-east and is home to
Cartagena Outpost, so this directly extends the existing Spanish-antagonist thread rather than
introducing a new one. A believable near-coastline: a fort/watchtower silhouette (reuse
`tower-*.glb`/`castle-*.glb`, already in the asset kit for the Fortress/Watchtower buildings), a
treeline, a few coastal rock/prop clusters — built from the same modular-tiling approach as
islands (§2), just elongated along the world edge instead of radial.

**Britain, explicitly deferred/optional:** Britain's regional presence is already carried by Port
Royal (historically English Jamaica) and the Royal Navy fleet. A second mainland risks diluting
that read rather than sharpening it. Recommendation: ship Spain's mainland, playtest whether it
delivers the "sandwiched between two empires" feeling on its own, and only add a British mainland
(likely north, echoing the real North American colonies) if it doesn't.

**Implementation shape:** a new, lightweight scenery component (e.g. `Mainland.gd`/
`Mainland.tscn`), deliberately **not** an `Island.gd` instance — no `IslandData`, no dock, no
`capture_island()` — so the build/capture/colonize machinery can never accidentally treat it as
capturable. Placed as static geometry in `World.tscn`, at the same tier as `Ocean`/`Environment`,
not under the `Islands` node.

**Stretch ideas (optional, not required for v1 of this feature):**
- Heavier fog at that specific world edge, reusing `RegionData.fog_density_multiplier`'s existing
  per-region pattern, to reinforce "the rest is lost in the haze."
- A location-flavored variant of the existing boundary message
  (`ShipController._clamp_to_world_bounds()`'s "The charts end here…") specific to Spanish waters —
  e.g. referencing a coastal patrol turning the player back.

---

# 6. Building visual progression (a related, already-identified gap)

Found while researching §4, not new: `docs/10_ASSET_REQUESTS.md`'s M10 update closed the "every
building is a grey box" gap by assigning each of the 10 building chains one real Kenney model
(Watchtower → `tower-watch.glb`, Fortress → `tower-complete-large.glb`, etc.), but explicitly flags
that this is **one model reused across all 5 levels**, not 5 visually escalating stages —
`Island.upgrade_structure()` just scales the existing model ×1.2 per level
(`pow(1.2, new_building.level - 1)`, `Island.gd`). `docs/10`'s own §"PROGRESSION DESIGN" already
specifies exactly what 5 real escalating stages should look like per building (improvised →
established → prosperous → fortified → grand, warming color temperature) and even has ready-to-use
generation prompts — **this was scoped and never executed**, not undiscovered.

**Why it belongs in this doc:** it's the same "investment must be visible" principle driving §4's
repeatable buildings, and the same player (a returning player checking on their island) benefits
from both landing together. Doesn't block anything else here — purely additive, and entirely
art-generation work (`docs/10`'s prompts are ready to paste), not code.

**Recommendation:** treat as its own backlog item (§9's task 10), lower priority than §2's
scale-up (which changes the footprint every building sits in) but worth doing before or alongside
§4's new house/port content, since a session authoring building visuals may as well cover both the
old chains and the new repeatable ones in one pass.

---

# 7. Ambient ocean life & weather events

`docs/00_VISION.md` §11 ("Exploration Philosophy") states the world should feel alive, and §6
("The Daily Experience") explicitly lists "a storm has appeared" as a moment that should make
opening the game feel meaningful. Neither currently exists as anything the player can see:

- **No ambient sea life at all.** Confirmed by grep — no `fish`, `wildlife`, `seagull`, or
  `dolphin` anywhere in `scripts/`. The ocean is visually empty except ships, islands, and loot
  crates.
- **No discrete weather *events*.** `RegionData` has `wave_intensity_multiplier`/
  `fog_density_multiplier`/`wind_strength` as static per-region ambience, and
  `EncounterManager`/`EventManager` already drive ambient combat encounters and ocean events (wind
  shifts, etc. — confirmed in `tests/test_world_events_expansion.gd`), but there is no `storm`,
  `lightning`, or `rain` anywhere in `scripts/` (confirmed by grep) — nothing like the Vision doc's
  "a storm has appeared" exists as a visible moment, only the static per-region wave/fog/wind
  baseline.

**Design directions (cheapest first):**
1. **Ambient decoration, zero gameplay hook** — seagulls circling near islands (a simple
   looping-flight `MeshInstance3D`/particle trick), floating debris/driftwood on the open ocean,
   maybe a fish-jump particle burst. Same "purely decorative" principle as §3's island filler,
   applied to open water. Cheapest, lowest-risk addition in this whole doc.
2. **A visible storm event** — reuses `EventManager`'s existing ocean-event dispatch
   (`world_event_triggered`, per `tests/test_event_manager_properties.gd`) to add a new event kind
   that temporarily spikes `wave_intensity`/darkens the sky/adds rain particles and a lightning
   flash + thunder SFX (audio pack already has impact/ambient sounds per `docs/10`'s M11 update —
   check for a reusable cue before sourcing a new one). Should be *felt* (camera shake, HUD tint)
   more than it's a mechanical difficulty spike, matching Vision §10's "combat should require
   decisions" — a storm changes how the player plays, it doesn't just tax a stat.
3. **Day/night cycle — flag as a big, separate decision, not a small task.** Nothing in
   `docs/00_VISION.md` demands one explicitly, but it's a common "does this feel like a real world"
   expectation. Scope honestly before starting: it touches every region's lighting
   (`EnvironmentSettings.tres`, `WorldEnvironment`'s sky/ambient setup, `DirectionalLight3D`
   angle/color), likely wants no gameplay tied to it at first (pure lighting cycle, no
   night-specific spawns), and needs a decision on cycle length vs. session length (Vision §16 says
   sessions run 2-60 minutes — a full day/night cycle within that range moves fast; matching real
   time would mean most sessions never see a change). Recommend explicitly deciding whether this
   is in scope at all before putting it in the task backlog as more than a placeholder.

---

# 8. Populated ports (the game currently has zero characters)

`docs/10_ASSET_REQUESTS.md` §6 ("What is NOT needed") states plainly: **"Characters or crew
figures — the game has no character models and M6 does not add any."** That's still true — no
character/NPC asset or script exists anywhere in the project. Every port, tavern, and market is
visited but never actually populated; the player never sees another person, only buildings and
ships. For a game whose vision explicitly says "the Empire is the player" and captains are
"heroes" (`docs/00_VISION.md` §2), a settlement with no visible inhabitants undercuts that framing
more than any of the other gaps in this doc.

**This is a real, larger gap — scope it honestly, don't fold it into a "few hours" task.** Full
character models/rigs/animation are a different asset pipeline than anything this project has used
(Kenney's building/ship/prop kits have no figures). Options, cheapest first:

1. **Static crowd silhouettes** — flat, unanimated billboard or low-poly blob figures standing
   near the dock/tavern, purely decorative (same non-interactive principle as §3/§7). No new
   pipeline needed beyond a couple of simple placeholder meshes/sprites, similar in spirit to how
   `docs/10_ASSET_REQUESTS.md`'s M11 update had captain portraits fall back to flat-color
   silhouette busts when no pirate-themed art was found (`PortraitFallback`) — the same fallback
   philosophy applies here.
2. **Simple idle/walk-loop figures** — a real (if very cheap) character pipeline; meaningfully more
   work than 1, and the point at which this stops being a "pick a few at a time" task and becomes
   its own mini-milestone.
3. **Do nothing yet** — legitimate option. Flagging the gap here so it's a deliberate choice, not
   an oversight, the same way `docs/10` already flagged it once and it was correctly deferred
   through M6-M21 rather than blocking anything.

**Recommendation:** try option 1 once §2's bigger islands and §4's repeatable-building settlement
growth exist to scatter figures around — a crowd on the current tiny footprint would look cramped
regardless of approach.

---

# 9. Task backlog (pick a few at a time)

Ordered so each task is independently implementable and verifiable. Later tasks within a section
assume earlier ones in that section landed; the sections are otherwise independent of each other
except where noted.

1. **Island scale-up** (§2) — do this alone first. Acceptance: GUT
   (`test_world_map_layout.gd` passes with the new `MIN_ISLAND_SPACING`; every pairwise distance
   manually re-verified), headful capture harness shows a visibly bigger island relative to the
   ship with no clipping/overlap between neighbors.
2. **Reposition existing decor to the new footprint** — mechanical follow-up to 1, not a new
   design decision. Acceptance: headful screenshot, every prop sits on terrain, none floating or
   clipped through the new geometry.
3. **More filler decor, v1** (§3 v1 task) — more of the same asset kinds, still shared across
   islands. Acceptance: headful screenshot, island reads as fuller; GUT suite unaffected (no
   gameplay code touched, decoration only).
4. **`is_repeatable` + build-flow bypass** (§4, first three bullets) — the mechanical enabler, no
   new content yet. Acceptance: a GUT test placing the same repeatable `building_id` twice on a
   test island, confirming both persist through a save/restore round trip.
5. **House/port-flourish content + tier gating** (§4, remaining bullets) — the actual buildable
   content. Acceptance: manual or `SelfPlayHarness` check that houses become available at the
   intended tier and multiple can actually be placed.
6. **Per-theme decor variants** (§3 stretch) — optional, only after 3 if there's appetite for it.
7. **Spanish mainland** (§5, Spain) — additive, lowest risk to existing systems since it never
   touches `Island.gd`. Acceptance: headful screenshot from Imperial Waters showing the coastline
   at the world edge; confirm the existing world-bounds clamp already prevents sailing past it (no
   new blocking code needed for that part — just verify it wasn't accidentally bypassed by the new
   geometry, e.g. a mesh placed just inside the boundary rather than at/beyond it).
8. **British mainland** (§5, deferred) — revisit only after playtesting 7; may not be needed at
   all if Spain's mainland already delivers the intended scale/threat feeling.
9. **Ambient ocean decoration** (§7.1) — seagulls, floating debris, fish-jump particles; purely
   decorative, no gameplay hook, can happen any time independent of everything else in this doc.
   Acceptance: headful screenshot over open water, no performance regression (spot-check FPS in
   the capture harness log).
10. **Building visual progression** (§6) — art-generation work against `docs/10`'s existing,
    ready-to-use prompts; do alongside or right after 5 so one pass covers both old chains and new
    repeatable buildings. Acceptance: headful screenshot comparing a level-1 and level-5 building
    of the same chain, visibly different without reading a label.
11. **A visible storm event** (§7.2) — reuses `EventManager`'s existing event dispatch. Acceptance:
    trigger it manually (or via a GUT test calling the dispatch directly) and confirm via headful
    capture that sky/wave/particle changes are actually visible, not just a stat change.
12. **Populated ports, option 1 (static crowd silhouettes)** (§8) — do after 1-2 so figures have a
    bigger settlement to stand in. Acceptance: headful screenshot, a dock/tavern reads as inhabited.
13. **Day/night cycle** (§7.3) — explicitly not scoped to a single task yet. Before adding this to
    a future pass, first answer in writing (update this section): is it in scope at all, what cycle
    length, does anything gate on it (recommend: nothing, at least initially). Only break it into
    implementable tasks once those questions have real answers.
14. **Populated ports, option 2 (idle/walk-loop figures)** (§8) — only if 12 ships and still feels
    insufficient; treat as its own mini-milestone rather than a doc task, per §8's own recommendation.
