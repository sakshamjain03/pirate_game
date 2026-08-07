# Requirements Document

## Introduction

Milestone M5 — Launch Readiness closes the two remaining gaps between the current build and
`AGENTS.md`'s MVP Philosophy launch-scope checklist (Three Regions, Eight Buildings, Eight
Ships, Twenty Captains, Four Resources, Offline Gameplay, Single Player, World Events, Boss
Battles, No Multiplayer/Guilds/PvP).

Everything else on that checklist is already met and needs no further work this milestone:
Regions (3, via milestone-m4-empire-escalation), Buildings (10, exceeds 8),
Ships (8, exact match — `resources/ships/*.tres`), World Events (`EventManager`,
`WorldEventManager`), Boss Battles (`GhostShipStats.tres` + `WorldEventManager`'s periodic boss
ship), and the No Multiplayer/Guilds/PvP constraints (nothing to build — correctly absent).

The two real gaps, confirmed by direct code inspection:

1. **No offline-progress system exists anywhere.** `SaveManager.gd` persists no save timestamp;
   nothing on load computes elapsed real time and grants catch-up production or resolves
   in-flight fleet missions. A player who closes the game returns to exactly the state they
   left, with no sense that their empire kept running.
2. **The captain roster is at 5 of the 20-captain target.** `CaptainData.gd`'s schema already
   supports this — it is a pure data-authoring gap, not an engineering one.

This milestone assumes milestone-m4-empire-escalation is complete (its Task 22 final checkpoint
has passed — see `docs/05_CURRENT_SYSTEMS.md` §5).

---

## Glossary

- **Offline tick**: One replay of `ResourceManager.global_economy_tick`'s existing effects
  (island building production, fleet mission earnings) — the same signal both `Island.gd` and
  `FleetManager.gd` already subscribe to during normal play, replayed programmatically on load
  to simulate ticks that would have fired while the game was closed.
- **Offline cap**: A maximum elapsed duration (and therefore a maximum number of offline ticks)
  applied on load, so a player who leaves the game closed for days doesn't return to an amount
  of production disproportionate to actually playing.

---

## Requirements

### Requirement 1: Elapsed-time tracking

**User Story:** As a player, I want the game to know how long I was away, so that it can credit
me for time passed while the game was closed.

#### Acceptance Criteria

1. `SaveManager.gd`'s `save_game()` SHALL persist a top-level `last_saved_unix: int` timestamp
   (`Time.get_unix_time_from_system()`) in the save dictionary, alongside the existing
   `player`/`economy`/`islands`/`fleet`/`tech`/`factions`/`empire`/`tutorial` sections.
2. `SaveManager.gd`'s `load_game()` SHALL read `last_saved_unix` and compute
   `elapsed_seconds = now - last_saved_unix`, clamped to `0` if negative (e.g. system clock
   changes) or if the key is absent (first load of a save written before this milestone).

---

### Requirement 2: Capped offline economy catch-up

**User Story:** As a player, I want my islands' buildings to have kept producing resources while
I was away, so that leaving the game doesn't feel like a wasted opportunity cost.

#### Acceptance Criteria

1. ON load, AFTER islands' built buildings are restored (existing step 3 of `load_game()`) and
   fleet state is restored (existing step 3), THE `SaveManager` SHALL compute
   `offline_ticks = floor(elapsed_seconds / ResourceManager.ECONOMY_TICK_INTERVAL)`.
2. `offline_ticks` SHALL be capped at a configurable maximum (suggested default: the number of
   ticks in 4 real-time hours) so idle time beyond the cap grants no further catch-up.
3. FOR each offline tick (up to the cap), THE `SaveManager` SHALL directly invoke each loaded
   island's and `FleetManager`'s existing per-tick logic (the same methods
   `ResourceManager.global_economy_tick` normally triggers), so building production and fleet
   mission earnings/XP apply identically to how they would have during real elapsed ticks. THIS
   REQUIREMENT SHALL NOT duplicate that production/earning logic anywhere else.
   **THIS REQUIREMENT SHALL NOT emit the shared `global_economy_tick` signal itself** —
   `FactionManager.gd` also subscribes to that signal, and its handler has a 20%-per-tick chance
   to dispatch a Royal Navy hunter ship when reputation is very negative; replaying the raw
   signal hundreds of times during catch-up would spawn an unbounded, unintended number of
   hostile ships, which is a combat/threat side effect, not an economy one, and out of scope
   here. Target the two intended systems (island production, fleet missions) directly instead.
4. Resource storage caps (`ResourceManager.max_storage`) SHALL still apply during offline
   catch-up — offline ticks use the same `add_resource()` path as live ticks, so this is
   automatic as long as Requirement 2.3 is implemented via signal re-emission and not a bypass.
5. IF `offline_ticks == 0` (player returned within one tick interval), THEN no catch-up occurs
   and no offline-return notice is shown (Requirement 3).

---

### Requirement 3: Offline-return visibility

**User Story:** As a player, I want to be told what happened while I was away, so that offline
progress feels like a real, legible benefit rather than an invisible number change.

#### Acceptance Criteria

1. WHEN `offline_ticks > 0` on load, THE game SHALL show a one-time, dismissable notice
   summarizing time away and resources gained, reusing `WorldHUD.gd`'s existing
   `announce_event()` transient-notice pattern (already used for island capture and region
   activation) rather than building a new UI system.
2. THIS notice SHALL NOT block gameplay — it appears after the World scene has loaded and the
   player can dismiss it or ignore it without consequence.

---

### Requirement 4: Twenty-captain roster

**User Story:** As a player, I want a meaningfully large roster of captains to recruit and
choose between, so that fleet composition is an actual strategic choice, not a formality.

#### Acceptance Criteria

1. 15 new `CaptainData` `.tres` resources SHALL be authored under `resources/captains/`,
   bringing the total roster to 20, following the exact schema of the 5 existing captains
   (`captain_id`, `captain_name`, `background`, and the real exported
   `base_speed_modifier`/`base_turn_rate_modifier`/`base_damage_modifier`/`base_health_modifier`
   fields — NOT the getter-only computed property names of the same shape without the `base_`
   prefix; see `docs/05_CURRENT_SYSTEMS.md` D14 for why that distinction matters).
2. EACH new captain's four `base_*_modifier` values SHALL be distinct from at least 3 of the 5
   existing captains' value tuples (no two captains should be statistically interchangeable),
   and SHALL stay within `CaptainData.gd`'s existing `@export_range(0.1, 3.0)` bounds.
3. EACH new captain SHALL have a distinct `captain_id` and a `background` line consistent with
   the existing captains' tone (short, characterful, one sentence).
4. `IslandMenu.gd`'s Tavern tab (already generic over `FleetManager.owned_captains` /
   a recruitable-captain list) SHALL require no structural changes to display and hire the new
   captains — if it does, that is a sign the roster expansion revealed a hidden assumption and
   should be fixed as part of this requirement, not worked around.
5. Hire costs / unlock conditions for the new captains SHALL be tuned (in whatever mechanism
   `IslandMenu.gd`/`FleetManager` already uses for the existing 5) so the roster has a sense of
   progression rather than all 20 being available identically from the start.

---

## Out of Scope

- A 4th/5th region, additional buildings beyond 8, or additional ship hulls beyond 8 — those
  MVP-checklist items are already met; this milestone does not touch them.
- Idle/incremental-game push notifications or any mobile-specific "come back" prompting —
  out of scope for this milestone; `AGENTS.md`'s MVP scope is a single-session desktop/prototype
  target for now.
- Rebalancing the 5 existing captains' narrative roles — D14's fix (base_* field names) restored
  their originally-intended values; this milestone does not redesign them.
- Any offline combat/raid resolution beyond what `EmpireManager`'s existing raid-check-on-load
  already does (see milestone-m4-empire-escalation Requirement 6.3) — offline catch-up here is
  economy/missions only, not raids.
