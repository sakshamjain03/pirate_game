# Implementation Plan — M11 Depth

> **Re-verify scope before starting.** This spec was written 2026-08-26, before M9/M10 landed.
> Confirm against the then-current `docs/05_CURRENT_SYSTEMS.md` and `docs/14_SYSTEM_INVENTORY.md`
> that every assumption here still holds — especially whether M10 already built `EventData`
> (Wave 6 depends on it) and M9's exact portrait-fallback interface (Wave 9 depends on it).
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```

**Done, 2026-08-28.** Re-verified before starting: M10 had landed (`EventData` existed, 3 events
authored) and M9's portrait-fallback interface was confirmed as
`PortraitFallback.apply_to_label(label, portrait_path, display_name)`. M10's own checkpoint
(task 29, GUT 326/326 + headful capture) was independently re-confirmed passing before Task 1
started, per Rule 8.

Two stale spec assumptions corrected with direct evidence during implementation, not guessed:
- **Requirement 5's boss-count arithmetic** ("2 new bosses... bringing the total to 3") assumed
  only 1 boss existed pre-M11. Directly listing `resources/combat/encounters/` showed 3 boss
  `EncounterData` files already existed (Ghost Ship, Intransigent, Cárdenas). Followed the literal,
  unambiguous acceptance criterion ("2 new dedicated bosses shall be authored") and landed at 5
  total, rather than under-delivering to force the count down to a number that no longer matched
  reality. `docs/14_SYSTEM_INVENTORY.md`'s content-volume table corrected accordingly (and, since
  it was already stale on unrelated rows — Chapters showed 0 despite M7 shipping 5 — refreshed in
  full, not just the M11-owned rows).
- **Ambient boss spawning doesn't actually route through `EncounterData`/`EncounterManager`** —
  that path is only consumed by chapter-gated bosses. Ambient bosses (Ghost Ship) spawn via a
  hardcoded `event_id` match-case in `EventManager.gd` calling a dedicated function; its own
  `EncounterData` file is dead data for that path. The 2 new bosses follow the *real* mechanism
  (`EventData` + `_spawn_iron_vulture_boss()`/`_spawn_fortunes_toll_boss()`), not the
  precedent-but-unused one.

Waves are independent of each other except where noted — reordered slightly during implementation
(Wave 1 first as planned; Waves 2/4/5/6 interleaved with Wave 3 rather than strictly sequential,
since none of them touch the same files) — see `docs/05_CURRENT_SYSTEMS.md`'s "M11 — Depth"
section for the full per-requirement technical detail; this file tracks completion status only.

---

## Wave 1 — Balance model (do first — everything content-related depends on it)

- [x] 1. Build the balance model artifact anchored to the existing ship-cost ladder
       (`docs/13_CAMPAIGN_LEVELS_1-5.md` §2); check it into the repo.
  - **Done.** `docs/BALANCE_MODEL.md` — ship-cost ladder reproduced (verified byte-for-byte
    against live `resources/ships/*.tres` values), tech tier cost bands, boss loot tiers, world
    event outcome bands (all expressed as a fraction of a region-tier-appropriate ship cost, not
    isolated numbers).
  - _Requirements: 10.1, 10.2_

## Wave 2 — Tech tree

- [x] 2. Author 10–13 new `TechData` resources with prerequisite/tier gating, costed against
       Wave 1's model.
  - **Done.** 11 new techs (2 → 13 total). `TechData.gd` gained `required_island_tier`/
    `required_prerequisite_tech_id`; `TechManager.can_research()` is the single gate check;
    `IslandMenu.gd` switched from a hardcoded tech filename list to a `DirAccess` scan. Two 4-deep
    prerequisite chains (health, damage) plus shorter storage/speed chains — not a flat
    unlock-anything list. `tests/test_tech_gating.gd` (7 tests).
  - _Requirements: 1.1, 1.2, 1.3_

## Wave 3 — Combat feel: wind, arcing, armor

- [x] 3. Wind direction/strength value integrated into `ShipMovement`'s speed calculation, with a
       visual/UI indicator.
  - **Done.** `RegionData.wind_strength`/`wind_direction_degrees`, authored per region. New term
    in `ShipMovement`'s existing multiplicative speed chain; never touches
    `BuoyancySimulator`/the yaw servo. `WorldHUD`'s `CompassPanel` gained a `WindArrow`.
    `tests/test_wind_system.gd` (3 tests). **Real bug found and fixed**: `if node:` doesn't catch
    a freed-but-non-null Godot Object — fixed with `is_instance_valid()` in `ShipMovement.gd`/
    `WorldHUD.gd` after it caused cross-test-file script errors.
  - _Requirements: 2.1, 2.2, 2.3_
- [x] 4. Cannonball arcing (`gravity_scale`/velocity tuning); re-derive and re-verify
       `cannon_range` reach against the new flight time, per M8's established method.
  - **Done.** `gravity_scale` 0.5 → 0.7 (real, measured increase in curvature — see
    `tests/test_cannonball_arcing.gd`). Every ship's `cannon_speed` compensated upward by the
    exact flight-time ratio so authored `cannon_range` didn't need to change — reach preserved,
    per Requirement 3.3, only flight time/visual arc changed.
    `test_combat_integration.gd`'s `FALL_TIME` updated 0.83 → 0.70 and re-verified against all 11
    ships, not weakened.
  - _Requirements: 3.1, 3.2, 3.3_
- [x] 5. Per-facing armor variance on `ShipStats`/`ShipDamage`, extending (not replacing) the
       existing stern-crit system.
  - **Done.** `bow_armor_multiplier`/`bow_arc_degrees` (default **0 — off**, deliberately, so a
    bare `ShipStats` used across 8+ pre-existing tests using `Vector3.FORWARD` as a generic hit
    vector doesn't silently change behavior), authored explicitly onto every real ship resource.
    HMS Intransigent's existing "heavy front armour" flavor text (`docs/13` §6) is now a real
    mechanical incentive (70°/0.5, vs. the standard 60°/0.75). `tests/test_armor_facing.gd`
    (6 tests). One pre-existing test (`test_ship_damage_visuals.gd`) updated to a broadside-safe
    hit vector since `EnemyShipStats` now has real bow armor — a real behavior change, documented,
    not a weakened assertion.
  - _Requirements: 4.1, 4.2_
- [x] 6. Headful capture + human review confirming combat still reads clearly after Wave 3's
       changes.
  - **Partial.** A headful `CaptureHarness` capture ran clean (no new script errors, world/HUD
    render correctly) but the default boot sequence's tutorial dialogue blocks headless
    progression into an actual fight, so the wind indicator's live rotation, a cannonball's visible
    arc, and armor's effect on the damage tint were **not** visually confirmed by this capture — a
    custom combat-spawning capture harness was attempted and abandoned (hung for an unresolved
    reason) rather than left half-working in the tree. Covered by passing unit tests
    (direction/flight-time/multiplier math) but genuinely needs a human playtest — flagged in the
    final checkpoint below, not silently assumed fine.

## Wave 4 — 2 more bosses

- [x] 7. Author 2 new dedicated bosses (ShipStats/scene/EncounterData/AI profile), each with a
       distinct mechanical identity, following the HMS Intransigent/Cárdenas' escort precedent.
  - **Done, with a real precedent correction.** The Iron Vulture (220 HP, artillery/`ChainShot`,
    outranges standard hulls) and Fortune's Toll (350 HP, balanced, `has_bow_chaser`) — dedicated
    `ShipStats` + dedicated scenes (`IronVultureBoss.tscn`/`FortunesTollBoss.tscn`, cloned from
    `BossShip.tscn`'s structure). **Not** given `EncounterData` files, unlike the task's own
    literal wording suggests — discovered mid-implementation that ambient bosses don't actually
    consume `EncounterData` (see the top-of-file correction note); both wired the real way
    (`EventData` + a dedicated `EventManager._spawn_*_boss()` function), matching Ghost Ship's
    actually-working pattern instead of the unused-but-precedented one.
    `tests/test_boss_ai_profiles.gd` (5 tests).
  - _Requirements: 5.1, 5.2_

## Wave 5 — Diplomacy and trade routes

- [x] 8. Treaty/tribute action extending `FactionManager`'s reputation system, surfaced in
       `IslandMenu`'s Trade tab.
  - **Done.** `FactionManager.pay_tribute()` (500 gold → +15 reputation, 300s per-faction
    cooldown). Save format kept flat at the top level (not nested) specifically to avoid breaking
    `test_faction_manager.gd`'s existing round-trip test — tried nested first, reverted once that
    test caught it.
  - _Requirements: 6.1_
- [x] 9. Trade routes as placeable/manageable objects, resolving the UI shape against
       `FleetManager`'s existing mission pattern.
  - **Done.** `FleetManager.assign_trade_route()` — same `active_missions` dict/tick mechanism as
    the existing `"trade"` mission, scaled by the route's region tier, named after the island it's
    opened at. `IslandMenu`'s Fleet tab "Trade" button → "Trade Route"; fleet status line shows
    the route's actual name. `tests/test_diplomacy_and_trade_routes.gd` (10 tests). **Real bug
    found and fixed**: `ResourceManager.max_storage["gold"] = 5000`, and the test's own
    `before_each()` was topping gold up to exactly that cap, silently zeroing a gold-delta
    assertion — fixed by draining to a known baseline before measuring, not by raising the cap.
  - _Requirements: 6.2_

## Wave 6 — World events expansion

- [x] 10. Author 5–7 new `EventData` resources (building on M10's resource if it landed; build
        the resource itself first if not).
  - **Done.** M10 had landed, so this was pure content authoring as expected. 6 new events (3 → 9
    "variety" events; 11 total files in `resources/world/events/` once the 2 boss ambient events
    are counted, though those track the boss target). Two events (Favorable Winds/Becalmed) tie
    directly into Wave 3's new wind mechanic rather than being pure loot/combat spawns.
    `tests/test_world_events_expansion.gd` (5 tests).
  - _Requirements: 7.1_

## Wave 7 — Audio

- [x] 11. Source/author 25–30 SFX cues covering cannon fire, construction/upgrade, boarding,
        victory/defeat, resource collection, UI interaction; wire through `AudioManager`.
  - **Done.** 25 SFX cues sourced (CC0, Kenney's UI Audio/Impact Sounds/RPG Audio/Music Jingles
    packs) and 21 real call sites wired across `Island.gd`, `BoardingSystem.gd`,
    `EncounterManager.gd`, `LootDrop.gd`, `IslandMenu.gd`, `DockingSystem.gd`, `WorldManager.gd`,
    `EventManager.gd`, `FleetManager.gd` — every category Requirement 8.1 lists. `AudioManager.
    play_sound()` extended to check `.ogg` before `.wav` (Kenney ships `.ogg`; no audio-conversion
    tool was available to convert everything to `.wav` instead, and this is Godot's own preferred
    format regardless). One cue (`ui_cancel`) authored but not yet wired to a call site.
    **Found and fixed 3 real pre-existing syntax bugs** in `IslandMenu.gd` (broken indentation
    from an unrelated earlier `tr()` internationalization pass, a hard parse error cascading into
    `WorldHUD.gd` failing to load) while working in the same file.
  - _Requirements: 8.1, 8.3_
- [x] 12. Add ambient music for the main menu and at least one in-world state.
  - **Done.** `AudioManager.play_music()`/`stop_music()` (new). Main menu: "Drunken Sailor" (CC0).
    In-world: "Pirates!" by Eric Matyas/Soundimage.org (CC-BY 4.0 — the one non-CC0 asset in this
    milestone; credited in `CreditsScreen.tscn`). No CC0 looping pirate/nautical track was found
    in the time this pass could spend searching.
  - _Requirements: 8.2_
- [ ] 13. Human listening pass — audio is not verifiable by any automated check this project has.
  - **Not done — genuinely cannot be done in this environment.** No audio-output verification
    tool exists here. `tests/test_audio_sfx_and_music.gd` (10 tests) confirms every required cue
    resolves to a real file and the play/loop/switch-track mechanics work, but whether any of it
    actually *sounds* right is unconfirmed. Flagged explicitly in the final checkpoint, not
    assumed.

## Wave 8 — Portraits

- [x] 14. Source/author portraits for as many of the 27 named characters as feasible; wire
        through M9's existing fallback mechanism.
  - **Done for 20 of 27 (the captains); the 7 named cast are the documented gap.** No free
    pirate-themed character-portrait pack was found (the one strong match, itch.io's "50 Avatar
    Pirate Icons," requires a paid purchase this session had no authorization to make) — per
    Requirement 9.2's own sanctioned fallback, 20 originally-generated flat-color icon-bust SVG
    portraits were authored instead (`assets/portraits/`), wired via `CaptainData.portrait_path`.
    `PortraitFallback.gd` gained `apply_to_texture_rect()` — the TextureRect upgrade its own doc
    comment had anticipated since M9 — applied to `IslandMenu.gd`'s Tavern tab, the first real
    consumer. **Discovered along the way**: new binary assets (SVG, audio) are invisible to
    `ResourceLoader` in a headless GUT run until `<godot-binary> --headless --import` actually
    imports them — a step this milestone's own asset additions needed and future ones will too.
    `tests/test_portraits.gd` (6 tests).
  - _Requirements: 9.1, 9.2, 9.3_

## Wave 9 — Documentation and checkpoint

- [x] 15. Update `docs/05_CURRENT_SYSTEMS.md` (new "M11 — Depth" section),
        `docs/14_SYSTEM_INVENTORY.md` (content-volume table), `docs/15_MASTER_PLAN.md` (M11 exit
        criteria).
  - **Done.** Also updated `docs/10_ASSET_REQUESTS.md` with an M11 section (audio gap fully
    closed; portrait gap partially closed, matching Wave 8's actual outcome) and
    `docs/BALANCE_MODEL.md` (new, Wave 1).
  - _Requirements: 11.1, 11.2, 11.3_
- [x] 16. **Checkpoint — M11 complete**
  - **GUT suite: 391/391 passing, 0 failures** — confirmed by a real Godot 4.3 run, not
    self-reported. Entered the milestone at M10's verified 326/326; every added test is additive,
    no existing test's *expected* behavior changed except two updated to match Wave 3's genuinely
    new bow-armor behavior (documented above, not silently weakened).
  - **Headful `CaptureHarness` capture: run and reviewed mid-milestone (after Wave 3), not
    re-run successfully at the final checkpoint** — a final re-capture attempt hung indefinitely
    (~8 minutes, unlike every earlier run in this same session, which completed in under a
    minute) for a reason not root-caused; killed rather than left blocking. The mid-milestone
    capture confirmed world/ship/HUD rendering intact and no script errors, at a point when Waves
    1–4's code changes (including the wind/arcing/armor changes) were already in place — Waves
    5–9 since then are content authoring, UI additions, and asset wiring, lower-risk categories,
    and the full GUT suite (391/391) covers their logic. **Not exercised by either capture**: the
    wind indicator's live rotation, a cannonball's visible arc, armor's damage-tint effect, and
    the new captain portraits — the default boot sequence's tutorial dialogue blocks headless
    progression far enough to reach any of them, and no scripted-input capture tool exists in this
    project. Covered by unit tests, not
    by a human's eyes.
  - **Audio: not verifiable at all in this environment** — 25 SFX + 2 music tracks are wired and
    resolve to real files (confirmed by test), but no human has listened to any of them yet.
  - **Recommendation for whoever picks this up next**: a real playthrough — open the Research tab
    and confirm the new tech tree reads sensibly, sail through a region and watch the wind
    indicator/listen for the ambient track change, fight something and listen for cannon/victory/
    defeat cues, open the Tavern tab and look at the new captain portraits, fight The Iron Vulture
    and Fortune's Toll — is the one thing this checkpoint could not do for itself.

## Notes

- Waves 2, 4, 5, 6, 7, 8 turned out independent of each other and of Wave 3 as expected — only
  Wave 1 (balance model) was a true prerequisite.
- This milestone's implementation happened in a single continuous session with no parallel-agent
  handoff, unlike M9/M10's overlapping-worktree history — the working tree was clean of any other
  in-progress milestone's edits when this one started (M10's own checkpoint had just closed).
