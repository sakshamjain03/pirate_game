# Requirements Document

## Introduction

Milestone M11 (originally "M10 — Depth" before the presentation-audit renumbering) turns the
game's one-note systems into real choices. By the end of M10, a player can see a legible, sized
world; M11 is what gives them reasons to engage with each faction and region differently rather
than repeating the same combat/economy loop with bigger numbers. Specifically: the tech tree has
only 2 of a targeted 12–15 entries (`docs/14_SYSTEM_INVENTORY.md`'s content-volume table), wind and
cannonball arcing are both explicitly deferred design intent in `docs/navalCombat.md`, there are
still only 3 of a targeted 8–10 world events and 1 of a targeted 3 bosses, and audio is completely
absent (`assets/audio/` has zero files, confirmed directly), against `AGENTS.md`'s explicit "no
silent interactions" rule.

Full context: `docs/15_MASTER_PLAN.md`'s M11 entry, `docs/14_SYSTEM_INVENTORY.md`'s content-volume
targets table, `docs/navalCombat.md` (wind/arcing design intent beyond what M8 shipped).

---

## Requirements

### Requirement 1 — Tech tree expansion

**User Story:** As a player, I want meaningful research choices, so unlocking tech feels like a
strategic decision rather than a formality with only two options ever.

#### Acceptance Criteria

1. 10–13 new `TechData` resources SHALL be authored (bringing the total to the 12–15 target),
   each with a real gameplay effect consistent with `TechManager`'s existing multiplicative
   modifier system (health/damage/speed/storage) — no new tech-effect category unless an existing
   one genuinely cannot express the intended effect.
2. Techs SHALL be gated by prerequisite/tier in a way consistent with `Academy`'s existing
   building-tier gating (M7's `reinforced_hulls` precedent), not all available from game start.
3. Each new tech's cost/effect SHALL be authored against a real balance rationale (see Requirement
   7), not an arbitrary placeholder value — this project's own D53 history is the direct
   consequence of skipping this step.

### Requirement 2 — Wind and sail-trim mechanic

**User Story:** As a player, I want wind direction to matter tactically, so positioning in combat
and navigation involves reading the environment, not just steering toward a target.

#### Acceptance Criteria

1. A wind direction/strength value SHALL exist per encounter or globally (per
   `docs/navalCombat.md`'s deferred design intent), affecting ship speed based on heading relative
   to wind (e.g. faster running with the wind, slower beating against it).
2. This SHALL integrate with `ShipMovement`'s existing speed calculation, not a parallel movement
   system.
3. Wind SHALL be visually/audibly legible to the player (sail visual state, a UI indicator, or
   both) — a mechanic the player can't perceive isn't a mechanic they can play around.

### Requirement 3 — Cannonball arcing

**User Story:** As a player, I want cannon fire to have real ballistic trajectory, so range and
positioning matter more than they do with today's straight-line shots.

#### Acceptance Criteria

1. `Cannonball.gd`'s projectile motion SHALL gain an arc (gravity-affected trajectory) rather than
   pure straight-line velocity, consistent with `docs/05_CURRENT_SYSTEMS.md`'s already-noted "no
   cannonball arcing (straight-line only)" gap.
2. `FiringSolver`'s range/arc-lock calculations SHALL account for the new trajectory so that "in
   range" continues to mean "will actually hit," not just "within an arbitrary radius."
3. This SHALL NOT regress `cannon_range`'s already-balanced ballistic reach (re-tuned during M8 to
   match real travel distance) — re-verify the range/reach relationship holds after arcing changes
   flight time.

### Requirement 4 — Hull-facing armor variance

**User Story:** As a player, I want where I get hit to matter beyond the existing stern-crit arc,
so positioning defensively is as meaningful as positioning offensively.

#### Acceptance Criteria

1. `ShipStats`/`ShipDamage` SHALL support a per-facing armor value (bow/broadside/stern) beyond
   today's single stern-crit-multiplier model.
2. This SHALL extend, not replace, the existing stern-arc-crit system — `FiringSolver`'s existing
   `SIDE_BOW`/`SIDE_STERN` geometry (M8 Phase 2) is the natural basis for facing detection.

### Requirement 5 — 2 more bosses

**User Story:** As a player, I want more than one memorable boss fight in the game, so the
Chapter 4/5 encounters aren't the only high-stakes fights that exist.

#### Acceptance Criteria

1. 2 new dedicated bosses SHALL be authored (bringing the total to 3, per
   `docs/14_SYSTEM_INVENTORY.md`'s content-volume target), each with a dedicated `ShipStats`, AI
   profile, and `EncounterData` — following the exact pattern HMS Intransigent/Cárdenas' escort
   already established (M7), including `required_chapter_id`-equivalent gating or an ambient-pool
   placement appropriate to where each boss fits narratively.
2. Each boss SHALL have a distinct mechanical identity (not a reskinned stat bump) — reuse
   `AIProfileData.role` and `CombatModifiers`/`BattleUpgradeData` to differentiate, consistent with
   M8's "role is a content tag, not a second numeric system" precedent.

### Requirement 6 — Diplomacy and trade routes

**User Story:** As a player, I want ways to engage factions besides fighting them, so notoriety
and reputation feel like they cut both ways.

#### Acceptance Criteria

1. A treaty/tribute mechanic SHALL let the player spend resources to temporarily improve standing
   with a faction (per PRD §16, referenced in `docs/15_MASTER_PLAN.md`'s M11 scope), extending
   `FactionManager`'s existing reputation system rather than building a parallel one.
2. Trade routes SHALL become placeable/manageable objects (per `docs/14_SYSTEM_INVENTORY.md`'s
   "today: abstract missions only" gap) rather than purely abstract `FleetManager` missions — the
   exact UI/data shape is an open design question the implementer SHALL resolve against
   `FleetManager`'s existing mission-tracking pattern before writing new persistence.

### Requirement 7 — World events expansion

**User Story:** As a player, I want more variety in what the ocean throws at me, so `EventManager`
doesn't feel like the same 3 events on repeat.

#### Acceptance Criteria

1. 5–7 new `EventData` resources SHALL be authored (bringing the total to the 8–10 target),
   building on M10's `EventData` resource work (if M10 has landed by the time this milestone
   starts — re-verify against current `docs/05_CURRENT_SYSTEMS.md`).

### Requirement 8 — Full SFX pass and music

**User Story:** As a player, I want the game to make sound, so combat, building, and discovery
have the feedback `AGENTS.md` itself requires ("no silent interactions" — currently unmet with 0
audio files in the project).

#### Acceptance Criteria

1. 25–30 SFX cues SHALL be sourced/authored covering, at minimum: cannon fire (currently silent —
   `AudioManager` already warns "No audio asset for 'cannon'" on every shot), building
   construction/upgrade, boarding, victory/defeat, resource collection, UI interaction.
2. Ambient music/shanties SHALL be added for at minimum the main menu and one in-world state (e.g.
   calm sailing vs. combat), via `AudioManager`'s existing bus system
   (`default_bus_layout.tres`), not a new audio pipeline.
3. Every SFX/music asset SHALL be wired through `AudioManager.play_sound()`'s existing lookup
   convention, matching however `AudioManager` currently identifies missing assets (per the
   already-visible warning pattern), so a future missing-asset gap is caught the same way this
   one was.

### Requirement 9 — Portrait sourcing/integration

**User Story:** As a player, I want to see the faces of the captains and named characters I
recruit and meet, closing the "generic fallback" gap M9's Presentation Pass only worked around.

#### Acceptance Criteria

1. Real portrait art (or a curated stock-asset-derived substitute, following the same
   stock-asset-first precedent as M10's building-art sourcing) SHALL be sourced/authored for as
   many of the 27 named characters (20 captains + 7 named cast) as feasible.
2. Portraits SHALL be wired through M9's portrait-fallback mechanism (`portrait_path` resolution),
   which was explicitly built to only need real asset files added, no logic changes.
3. Any character still without real art at this milestone's close SHALL continue using M9's
   intentional fallback treatment, not regress to an unstyled placeholder.

### Requirement 10 — Balance model

**User Story:** As a maintainer, I want every new economy number this milestone introduces (tech
costs, boss rewards, event outcomes) to trace back to a documented model, so this milestone doesn't
reproduce a D53-class pricing disaster.

#### Acceptance Criteria

1. A balance spreadsheet or equivalent documented model (per `docs/14_SYSTEM_INVENTORY.md` §6's
   flagged gap — "no spreadsheet, no model") SHALL exist covering, at minimum, every new tech's
   cost/effect ratio and every new boss's reward tier, authored against the existing ship-cost
   ladder (`docs/13_CAMPAIGN_LEVELS_1-5.md` §2) as a reference scale.
2. This model SHALL be checked into the repo (e.g. `docs/BALANCE_MODEL.md` or a linked
   spreadsheet reference) so it's available to whoever authors M12's/M13's content next, not a
   one-off artifact that disappears after this milestone.

### Requirement 11 — Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an "M11 — Depth" section.
2. `docs/14_SYSTEM_INVENTORY.md`'s content-volume table SHALL be updated to reflect the new
   counts (techs, bosses, world events, SFX cues, portraits).
3. `docs/15_MASTER_PLAN.md`'s M11 exit-criteria results SHALL be filled in.

---

## Non-Goals

- Multiplayer, PvP, guilds, or any player-to-player diplomacy — Requirement 6's diplomacy is
  strictly player-vs-NPC-faction, per `AGENTS.md`'s permanent v1 restriction.
- Monetization of any kind — `AGENTS.md` (amended 2026-08-27): no paid feature ships before
  the M13 launch build, and M11 is well before it. Cosmetics and billing are owned by M16/M17;
  see `docs/17_MONETIZATION.md`.
- A fourth/fifth region — still M14 scope.
- Analytics, crash reporting, save versioning/backup, localization, or a playtest protocol — all
  M12 scope.
- Android export/store readiness — M13 scope.
