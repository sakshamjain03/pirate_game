# Requirements Document

## Introduction

Two problems, one system.

**1. Combat plays itself.** `ShipCombat._physics_process` auto-fires whenever `FiringSolver`
reports arc-lock, so the player never presses anything to shoot. The depth is all there — three
damage pools (hull/sails/crew), three ammo types with real multipliers, stern crits, bow armour,
boarding, 15 AI profiles — and none of it is visible or chosen. Chain shot wrecks sails so a target
cannot flee; grape shot kills crew so boarding succeeds; round shot kills hull so you get loot
instead of a prize. That triangle is fully implemented and completely unreadable, so no player will
ever discover it.

**2. The open sea has no pressure curve.** Ambient enemies spawn at a flat cap of 5 regardless of
what the player has done, and every enemy chases on sight. Sailing is equally dangerous when you
are unknown and when you have burned three ports.

The fix for (2) is a **GTA-style wanted level**: the danger of the open sea is a direct function of
the trouble the player has caused. At low heat, ships leave you alone unless provoked. At high heat
they swarm. Heat bleeds off on its own, faster if you lie low in port, or instantly for Pieces of
Eight.

This is deliberately **not an energy system** and must never become one. It gates nothing: sailing,
combat and boarding stay unlimited at every heat level (`docs/00_VISION.md` §19.2). What it creates
is *pressure the player chooses to relieve*, which is the compliant shape of the same commercial
idea.

**Already met, no work needed:** `EmpireManager.notoriety` already exists, already rises on kills
(+1 non-empire, +5 empire), already decays, and already drives region activation — heat **reuses
that number and must not add a second one**. `EnemySpawner.compute_spawn_multiplier()` already
scales enemy stats by region tier and notoriety. `MobileControls` already has fire, captain
ability, special broadside, dock, sail and anchor buttons. `ShipDamage` already emits
`pool_changed(pool, current, maximum)` for all three pools. `ShipCombat.fire_broadside(side)` and
the `fire_port`/`fire_starboard` input actions already exist and work.

## Glossary

- **Heat** — the player's wanted level, 0-5, derived from `EmpireManager.notoriety`. A presentation
  and behaviour band over an existing number, **not a new stat**.
- **Heat tier** — one authored `HeatTierData`: notoriety threshold, ambient enemy cap, spawn
  cadence, aggression, and whether enemies engage unprovoked.
- **Passive / provoked** — below the "hostile on sight" tier an AI ship patrols and ignores the
  player until provoked. **Provocation** = the player fires on it, rams it, boards it, or its
  faction is already hostile (`FactionManager.is_hostile()`).
- **Lying low** — docked at a player-owned island, where heat decays faster.
- **Eights** — Pieces of Eight, the single premium currency.

## Requirements

### Requirement 1: Firing is an action the player takes

**User Story:** As a player, I want to choose when to fire, so that combat is something I play
rather than something I watch.

#### Acceptance Criteria

1. `ShipCombat.auto_fire_enabled` SHALL default to **false**.
2. Arc-lock SHALL continue to gate whether a side *may* fire. Aiming SHALL remain positional — no
   reticle, no aim stick — so play stays one-thumb.
3. Auto-fire SHALL be exposed as an **accessibility setting**, persisted via `SettingsManager`, and
   SHALL behave exactly as today when enabled.
4. Mobile SHALL gain an **ammo-swap** control cycling round/chain/grape, showing the active type.
   No other new button: fire, captain ability and special broadside already exist, and ramming is
   collision-driven since M23.
5. Changing ammo SHALL NOT reset an in-progress reload.

### Requirement 2: The damage triangle is legible

**User Story:** As a player, I want to see what my shots are doing to hull, sails and crew, so that
choosing an ammo type is a decision instead of a guess.

#### Acceptance Criteria

1. `EnemyHealthBarWidget` SHALL show **hull, sails and crew** as three distinct segments, fed by
   `ShipDamage.pool_changed`, not hull alone.
2. Each pool SHALL be visually distinguishable without relying on colour alone
   (`docs/18_ACCESSIBILITY.md`).
3. WHEN a pool is crippled (sails at/below the flee threshold, crew low enough that boarding would
   succeed), THE widget SHALL mark that state, so the player can read "this one can be taken".
4. Floating damage numbers SHALL indicate which pool was hit.
5. THE player's own HUD SHALL show the active ammo type and per-side reload state.

### Requirement 3: Heat — the open sea reacts to what the player has done

**User Story:** As a player, I want the sea to get more dangerous as I cause more trouble and calmer
when I lie low, so that my notoriety is something I feel rather than a number on a bar.

#### Acceptance Criteria

1. Heat SHALL be derived from `EmpireManager.notoriety`. NO second stat SHALL be introduced.
2. Heat tiers SHALL be **authored data** (`HeatTierData` resources in a catalog), never thresholds
   hardcoded in a script. Tier boundaries SHALL align with the existing region-activation
   thresholds (60, 150) so the two escalation systems agree.
3. EACH tier SHALL author at minimum: ambient enemy cap, spawn interval, enemy strength multiplier,
   whether enemies engage unprovoked, and a display name.
4. `EnemySpawner` SHALL take its cap, cadence and strength from the current tier rather than its
   current fixed `max_enemies = 5`.
5. BELOW the "hostile on sight" tier, an AI ship SHALL patrol and SHALL NOT chase or fire on the
   player until **provoked** — the player fires on it, rams it, boards it, or its faction is
   already hostile. Provocation SHALL be per-ship, not global.
6. Provocation SHALL NOT bypass the existing obstacle-avoidance behaviour that stops enemies
   beaching.
7. Heat SHALL decay continuously at an authored per-tier rate after a short grace period, and
   SHALL decay faster while the player is docked at an owned island ("lying low").
8. THE player SHALL be able to spend **Eights** to drop heat immediately. This SHALL be optional
   relief, never the only path down (§19.2: a timer must also be shortenable by playing).
9. THE current heat tier SHALL be visible in the HUD, and a tier change SHALL be announced.
10. Heat SHALL persist across save/load via the existing `EmpireManager` notoriety persistence —
    no new save section.

### Requirement 4: Pieces of Eight exists as a currency

**User Story:** As a player, I want the premium currency to be something I already hold and
understand before I am ever asked to buy it.

#### Acceptance Criteria

1. Eights SHALL be a `ResourceManager` currency with its own storage rules.
2. Eights SHALL NOT be grantable by island production or the economy tick. An attempt to author a
   building that produces them SHALL `push_error`, not silently succeed (§19.2).
3. Eights SHALL be earnable in M25 from **chapter completion** and **first-time boss kills**, so
   the heat-clear in 3.8 is usable by a player who has spent nothing.
4. Eights SHALL be spendable on the heat clear.
5. Purchasing, the store, and cosmetics remain **out of scope** — they land in M31.

### Requirement 5: Difficulty escalation is authored

**User Story:** As a designer, I want per-chapter escalation in one data file, so that tuning the
curve does not mean editing scripts.

#### Acceptance Criteria

1. THE heat tier catalog SHALL be the single source of ambient-encounter escalation, absorbing the
   `DifficultyCurve.tres` deferred from M24 rather than adding a parallel file.
2. NO ambient-encounter tuning value SHALL remain hardcoded in `EnemySpawner`.

## Out of scope

- Enemy pre-fire/pre-ram telegraphs. Wanted, but they touch `EnemyAI`'s attack loop next to the
  fragile avoidance code; deferred to a focused pass rather than bundled with a default-flip.
- Store, IAP, cosmetics, achievements — M31.
- Any change to buoyancy, stability, the yaw servo, collision hull AABB, or hull-basis cannon
  direction.
