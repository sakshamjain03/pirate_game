# Requirements Document

## Introduction

Three player-reported gaps in how ships behave at sea:

1. **Ships stick to each other and to other surfaces.** Two hulls that touch can lock face-to-face
   and grind; ships snag on island shorelines and glue themselves to the world edge. Root causes
   (see `design.md` §3): the `ShipMovement` yaw servo erases contact-induced yaw every tick, all
   ship hulls are sharp-cornered boxes on Godot's default friction of 1.0, enemy hulls don't
   collide with each other (mask 5 omits layer 2) so they interpenetrate, the world-edge clamp
   teleports `global_position` every tick, and `EnemyAI` whiskers only see terrain.
2. **Contact between ships does nothing.** There is no ramming. A bow driven into an enemy's
   midship should be the heaviest blow in the game for the victim and a light one for the rammer,
   the way Sea of Thieves / AC IV: Black Flag treat it.
3. **Ship progression is one number.** `OwnedShipData` has a ship `level` (1–5) and swappable
   modules, but nothing per-part. The player wants hull, bow, stern, sails and cannons upgradable
   individually, gated Clash-of-Clans Town-Hall style: the ship's level caps every part's level,
   and the ship can only level up once every part has reached its current level.

**Already met, no work needed:** swappable modules (`ShipModuleData`, one per slot) and the
duplicate-never-mutate stat pipeline (`OwnedShipData.get_effective_stats()`); per-facing armor
(`ShipDamage.apply_hit` stern/bow/broadside); `FiringSolver.are_hostile()` as the single
hostility rule. This milestone extends all three, it does not replace them.

This milestone runs alongside the in-progress M22 UI overhaul — it touches ship physics/combat/
progression files, not `scripts/ui/` theming, except for the one `IslandMenu` progression panel.

## Glossary

- **Ship level** — `OwnedShipData.level`, the "Town Hall". Caps every component's level.
- **Component** — one upgradable part of an owned hull: `hull`, `bow`, `stern`, `sails`,
  `cannons`. Authored as `ShipComponentData` resources. Distinct from a **module** (swappable
  item in a slot): components are *how strong* a part is, modules are *what kind* of part it is.
- **Component level** — `OwnedShipData.component_levels[id]`, 1..ship level.
- **Hull zone** — BOW / MIDSHIP / STERN, classified from a contact point's position along the
  ship's local Z axis.
- **Ram** — a ship-to-ship contact whose closing speed exceeds `RamConfigData.min_closing_speed`.
- **Closing speed** — relative velocity of the two hulls projected on the contact normal.
- **Contact yaw grace** — a short window after an impact during which `ShipMovement`'s yaw servo
  runs at reduced authority so collision spin survives.

## Requirements

### Requirement 1: Ships do not stick to each other or to surfaces

**User Story:** As a player, I want ships to slide or bounce off each other and off islands, so
that a collision never leaves me locked in place.

#### Acceptance Criteria

1. THE ship collision hull SHALL be a convex prism with a pointed bow and chamfered stern whose
   bounding box equals the previous box, so contacts glance off instead of snagging on corners
   and GodotPhysics' AABB-based inertia is unchanged.
2. EVERY ship body and island StaticBody SHALL use an authored low-friction `PhysicsMaterial`.
3. Enemy-side ships SHALL collide with each other (collision_mask includes layer 2).
4. WHEN a ship registers an impact, THE `ShipMovement` yaw servo SHALL run at reduced authority
   for `contact_yaw_grace` seconds, without changing how roll/pitch are preserved.
5. IF a ship is touching a body with throttle > 0.3 and forward speed < 0.6 m/s for more than
   1.2 s, THEN it SHALL receive one separating impulse along the averaged contact normal.
6. THE world edge SHALL push ships back with a soft inward force inside a margin before the
   existing hard clamp is reached, so the clamp is a rare backstop rather than the normal contact.
7. WHEN an AI ship is not ramming, its whiskers SHALL also steer it away from other ships.

### Requirement 2: Zone-based ramming damage

**User Story:** As a player, I want to ram enemy ships and have the damage depend on speed, size,
and where the hulls meet, so that ramming is a real tactic.

#### Acceptance Criteria

1. WHEN two hostile ships make contact with closing speed ≥ `min_closing_speed`, BOTH ships SHALL
   take hull damage scaled by closing speed², the mass ratio, and the zone matrix.
2. A BOW-into-MIDSHIP ram SHALL deal the matrix maximum to the struck ship and a small fraction
   to the rammer.
3. The rammer's `ShipStats.ram_damage_mult` and the victim's `ShipStats.impact_resistance` SHALL
   scale the damage dealt/taken.
4. A STERN hit SHALL also apply a timed speed penalty (rudder damage).
5. Contacts between non-hostile ships (per `FiringSolver.are_hostile`) SHALL deal no damage but
   still separate.
6. Hitting terrain above `min_closing_speed` SHALL damage only the ship, scaled by
   `grounding_damage_mult`.
7. The same pair of bodies SHALL NOT be damaged again within `pair_cooldown` seconds.
8. All ramming balance values SHALL live in `resources/combat/RamConfig.tres`.
9. Ram damage SHALL go through a new `ShipDamage.apply_impact()`; `apply_hit()` stays unchanged.

### Requirement 3: Component upgrades gated by ship level

**User Story:** As a player, I want to upgrade my ship's hull, bow, stern, sails and cannons
separately, but only up to my ship's level, so that progression has Town-Hall-style milestones.

#### Acceptance Criteria

1. EACH owned ship SHALL track a level per component (`hull`, `bow`, `stern`, `sails`, `cannons`),
   starting at 1.
2. A component upgrade SHALL be refused WHEN the component's level ≥ the ship level.
3. A ship level-up SHALL be refused UNLESS every component's level ≥ the current ship level.
4. Component upgrades SHALL cost resources from the component's authored cost curve and apply its
   per-level stat multipliers inside `get_effective_stats()`.
5. `OwnedShipData.MAX_LEVEL` SHALL be 10.
6. Component levels SHALL round-trip through save/load; a pre-M23 save with no component data
   SHALL load with every component at the saved ship level.
7. An unresolvable component id or module path on load SHALL `push_error`, never skip silently.
8. The IslandMenu fleet panel SHALL show each component's level/cap/cost with an upgrade button,
   and SHALL explain why a disabled button is disabled.

### Requirement 4: AI ships ram deliberately

**User Story:** As a player, I want aggressive enemies to try to ram me when I show them my
broadside, so that ramming is a threat as well as a tool.

#### Acceptance Criteria

1. `AIProfileData` SHALL expose `ram_tendency` (0–1, default 0).
2. WHEN an AI in ATTACK has `ram_tendency` > 0, its target's broadside faces it, and its hull
   fraction ≥ the target's, THEN on a re-evaluation timer it MAY commit to a ram run with
   probability `ram_tendency`.
3. During a ram run, terrain avoidance SHALL remain active; only avoidance of the ram target is
   suppressed. The run SHALL abort on timeout, a completed impact, or falling below the flee
   threshold.
4. At least the AggressiveGalleon and IronVulture profiles SHALL have `ram_tendency` > 0.

### Requirement 5: Realistic cannon fire — slower reloads, more guns with upgrades, hits vs misses

**User Story:** As a player, I want broadsides to feel heavy and deliberate — slow reloads, a
rippling volley where some guns misfire or miss depending on the angle — and my gun count to grow
as I upgrade my cannons, so that positioning and upgrades both matter.

#### Acceptance Criteria

1. Authored `fire_rate` on every ship/enemy `ShipStats` `.tres` SHALL be rebalanced so a broadside
   reloads in roughly 4–10 s (was 0.3–2 s); per-ball `cannon_damage` SHALL be raised so damage per
   second stays in the same band and each volley matters.
2. A broadside SHALL fire as a ripple — gun *n* fires `ripple_interval × n` seconds after the
   first — rather than all at once. The first gun fires immediately.
3. EACH gun after the first SHALL independently misfire with probability
   `base_misfire_chance + crew_misfire_chance × (1 − crew fraction)`; a misfire produces smoke
   but no ball.
4. EACH ball SHALL be fired with a random aim error whose spread grows with how far the target sits
   off the perfect beam (0° → `base_spread_degrees`, arc edge → + `off_beam_spread_degrees`) and
   with range; hits and misses then come from the real ball trajectories.
5. A ball striking a hull's MIDSHIP zone at a glancing angle SHALL deal reduced damage
   (`lerp(glancing_damage_min, 1.0, incidence)`, incidence = |hit dir · hull right|); bow/stern
   (raking) hits are not reduced.
6. `ShipStats.cannons_per_side` (0 = one gun per authored marker, the existing behavior) SHALL set
   how many guns a broadside has; extra guns get generated firing points spread along the side.
7. The `cannons` component SHALL add guns per side at authored component levels.
8. All values SHALL live in `resources/combat/CannonConfig.tres`.

### Requirement 6: Player-selectable AI difficulty

**User Story:** As a player, I want to choose how tough enemy ships are in Settings, so that the
game isn't punishingly harsh unless I want it to be.

#### Acceptance Criteria

1. `SettingsManager` SHALL persist `ai_difficulty` (0 Relaxed, 1 Normal, 2 Hard, 3 Brutal;
   default Normal) in `settings.cfg`.
2. Each level SHALL be an `AIDifficultyData` resource with multipliers for enemy cannon damage,
   enemy reload time, enemy aim spread, detection range, and ram tendency.
3. The multipliers SHALL apply only to hostile, non-player-side ships, SHALL be read at use time
   (a Settings change takes effect in the current session without reload), and SHALL NOT mutate
   any shared `ShipStats` resource.
4. The Settings menu SHALL expose the choice as a labeled option.
5. Normal SHALL be noticeably gentler than the pre-M23 behavior (the user reports it as too harsh).

## Out of Scope

- Boarding-on-ram (grappling into `BoardingSystem`) — natural follow-up, not requested.
- Flooding / slow-sink over time — the user chose the arcade-real feel, not simulation-heavy.
- Upgrade timers — upgrades are instant; timers drift toward the monetization never-list.
- Distinct ship models per level — `docs/navalCombat.md` visual progression stays future work.
- Component levels on AI ships — they keep using plain `ShipStats` (new stats default to 1.0).
- Any change to `BuoyancySimulator.gd`.
