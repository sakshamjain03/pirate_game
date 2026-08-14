# navalCombat.md

> Version: 0.1
> Status: Living Document — locked design decisions for real-time naval combat
> Owner: Project Lead
>
> Source: "Pirate Empire — Naval Combat Decisions v0.1" (user, 2026-08-14).
> Reconciled against what M1–M6 actually shipped — see §0 and the ⚠️ markers throughout.
> Related: `docs/05_CURRENT_SYSTEMS.md` (ground truth) · `docs/14_SYSTEM_INVENTORY.md` (gap
> tracking) · `docs/13_CAMPAIGN_LEVELS_1-5.md` (where each mechanic is first taught).

---

# 0. Reconciliation — what this changes about the shipped game

This document **locks the target design**. Before treating anything below as already true, three
real gaps against the current code, found while writing this doc on 2026-08-14:

| # | This doc says | Code currently does | Verdict |
|---|---|---|---|
| ⚠️ R1 | §4: cannons fire **automatically** when the arc is aligned and reloaded; player skill is positioning | `ShipController.fire_cannons(side)` fires **only on a manual key press** (`fire_port` / `fire_starboard` input actions, `ShipCombat.fire_broadside()`) | **Design change, not yet built.** This is the single biggest mechanical shift in this doc — see §14 |
| ⚠️ R2 | §7: hull + sails, "don't implement crew simulation" | M6 already shipped **crew** as a third damage pool (`ShipDamage.crew`, gates firing, feeds boarding) plus a full boarding system | **Superseded by an already-shipped decision.** Ripping crew out would delete working M6 content for no gain — see §14 |
| ⚠️ R3 | §22: "❌ Boarding minigame" locked out | M6 already shipped **boarding** (non-minigame: a deterministic crew-count comparison through the existing UI) | **Not a conflict** — this doc only excludes a *minigame*, and the shipped system isn't one. Recorded for clarity, not as a defect |

**Resolution, in one line:** adopt this doc's *positioning-and-timing* combat identity and its
automatic-fire model going forward; **keep** the crew pool and boarding system M6 already built,
since they satisfy §6's "positioning, timing, aim, dodging, ability usage" skill list rather than
contradicting it. R1 is the only genuine rework, and it is scoped as its own milestone in §14 —
it is **not** part of M7 (campaign spine), which assumes today's firing model.

---

# 1. What is a battle?

Real-time, player-controlled naval combat. The player actively pilots **one flagship**. This is
not an RTS where the player micromanages a squadron — it is
**Black-Flag-style ship handling + mobile action combat + empire progression**, matching
`docs/00_VISION.md` §10's Combat Philosophy ("never a passive animation... winning should feel
earned").

---

# 2. Camera

Third-person, elevated, positioned behind/above the player's ship. Not top-down/RTS, not
first-person. The player must always clearly see: their ship, nearby enemies, projectiles, and
the surrounding battlefield.

✅ **Matches shipped code.** `CameraRig` + `SpringArm3D` already implements exactly this framing
(D31 fixed its collision behaviour). No change required.

---

# 3. Player movement

Virtual joystick / WASD / controller stick drives forward, reverse, and turning. The ship has
inertia — it should read as a heavy sailing vessel without being a simulator: **easy to control,
difficult to master.** No realistic wind simulation in v1.

✅ **Matches shipped code.** `ShipMovement` + `BuoyancySimulator` already deliver
acceleration/drag/drift/turn-rate with mass-appropriate inertia (D33 fixed capsizing; D34 tuned
damping). Wind-as-mechanic is correctly deferred — see `docs/14_SYSTEM_INVENTORY.md` §2 ("Wind as
a mechanic ❌ M9").

---

# 4. How cannons work — ⚠️ the central design change

**Decision:** the player does **not** manually fire every cannon. Cannons fire automatically once
the firing arc is aligned on a target and the weapon has reloaded. Player skill is expressed as
**positioning**, not tapping.

```
Enemy enters your port-side arc
        ↓
Broadside indicator appears
        ↓
Cannons auto-fire when reload is ready
        ↓
Enemy takes damage
```

The player may additionally trigger an **optional full-broadside special** — a deliberate,
player-timed volley layered on top of the automatic baseline, not a replacement for it.

**Current code (§0 R1):** `ShipCombat.fire_broadside(side)` fires only when the player presses
`fire_port`/`fire_starboard`. There is no arc-alignment check, no auto-fire, and no broadside
indicator. This is a real rework, scoped in §14 — not a same-day fix.

## Weapon slots

A ship *can* have: Port broadside, Starboard broadside, Bow weapon, Stern weapon, Special weapon.
Most starter ships need only broadside + one special.

**Current code:** `ShipCombat` implements port/starboard marker arrays only. Bow/stern/special
weapon slots do not exist yet. Scoped alongside the auto-fire rework in §14, not before.

---

# 5. Firing mechanics — arc → indicator → auto-fire → damage

Same information as §4, stated as the concrete pipeline an implementer builds against:

1. **Arc check** — is a valid enemy inside this side's firing cone and within `cannon_range`?
2. **Indicator** — surface it to the player (a HUD marker, a highlight ring, or a UI icon per
   side) so alignment is legible before the guns fire, not only after.
3. **Reload gate** — `ShipStats.fire_rate` already exists as the per-side cooldown; the auto-fire
   loop reuses it rather than inventing a second timer.
4. **Fire** — reuses the existing `Cannonball` spawn + `AmmoData` (round/chain/grape) pipeline
   unchanged. This doc changes *when* firing happens, not *what* fires.

---

# 6. Combat skill — where difficulty actually lives

Skill comes from, in this priority order:

1. **Positioning** — get beside the enemy, into your own firing arc.
2. **Timing** — choose when to turn, retreat, or commit.
3. **Aim** — align the broadside (a direct consequence of #1 once auto-fire ships).
4. **Dodging** — avoid enemy fire.
5. **Ability usage** — trigger captain/ship abilities at the right moment.

This is explicitly *not* "click enemy → auto-battle." §21 restates this as the full pre/during/
post-battle loop.

**Already shipped and consistent with this list:** stern-arc crits (`ShipDamage.apply_hit()`,
rewards positioning), ammo choice (rewards timing/aim — chain to cripple, grape to soften for
boarding), and boarding itself (a positioning+timing payoff). Nothing here is undone by adopting
auto-fire — it changes *which* action expresses aim, not whether aim matters.

---

# 7. Ship health — hull / sails / crew

**Decision as stated by the user:** keep it simple — Hull (main HP) and Sails (mobility, reduced
by sail damage), a visible "critical" state at low hull, then Sunk. Explicitly deferred: crew
simulation, individual cannon health, flooding, "dozens of component states."

**⚠️ Reconciliation (§0 R2):** M6 already shipped **crew as a real third pool**
(`ShipDamage.crew`, gates firing rate below a fraction of max, drives boarding outcomes,
recruited at the Tavern for gold/rum). This is a *coarse* crew abstraction — a single number, not
a simulation — so it does not violate the spirit of "don't build crew simulation, individual
cannon health, or flooding." **It stays.** Ripping it out would delete working, tested M6 content
(`test_damage_model.gd`, `test_boarding.gd`, M6 Requirements 3 and 4 in full) to chase a document
that predates it.

Final model — hull / sails / crew, exactly as M6 shipped:

| Pool | Effect at zero | Owner |
|---|---|---|
| Hull | Ship destroyed | `ShipDamage.hull` |
| Sails | Speed floored at `min_speed_fraction` | `ShipDamage.sails` |
| Crew | Cannot fire | `ShipDamage.crew` |

**Visible critical state** (hull very low → visibly damaged hull before sinking) is **not yet
built** — see `docs/14_SYSTEM_INVENTORY.md` §3, "Damage state on hulls ❌ M8". This is the one
piece of §7 still open, and it is already scheduled.

Correctly still out of scope, per the original decision: individual cannon health, flooding
simulation, per-crew-member state.

---

# 8. Ship roles

Real roles, not just bigger numbers: **Scout** (fast, fragile) · **Raider** (fast damage) ·
**Balanced** (general-purpose) · **Heavy** (slow, durable) · **Artillery** (long range, heavy
volleys) · **Support** (repairs/buffs).

**Current code:** the 8 authored `ShipStats` already form a size/role ladder (Dinghy scout-ish →
Man O'War heavy), and `AIProfileData` already differentiates enemy *behaviour* by role
(`HarassingSloop`, `AggressiveGalleon`, `StandardEnemy`). What's missing is **Support** as a
player-usable role (repair/buff) and explicit role tagging — folded into the `ship_class` field
already scoped for M7 in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2 (D53/D54).

---

# 9. Fleet system

Outside battle, the player assembles a fleet: **Flagship + N support ships + Captain.** Early
game: the player pilots the flagship; support ships are AI-controlled. This caps mobile
complexity while leaving room to grow.

**Current code:** `FleetManager` already models an owned-ships/captains roster with one active
ship, but support ships do not yet fight alongside the player in real-time combat — they exist
only as background trade/patrol missions. AI-controlled support ships *in battle* is new scope,
tracked in §14.

---

# 10. Captain / hero system

Captains are gameplay-changing heroes, not flat stat sticks. Each has a **passive** (always
active) and an **active ability** (player-triggered in battle). Progression: Recruit → Level →
Unlock abilities → Improve skills → Specialize.

**Current code:** `CaptainData` already implements passive stat modifiers (speed/turn/damage/
health/boarding — though see D55, boarding is currently unauthored on all 20) and XP/leveling.
**Active, player-triggered abilities in battle do not exist yet.** This is new scope for the
combat-rework milestone in §14, and it is the mechanism that finally gives each of the 20
captains in `docs/12_CHARACTER_BIBLE.md` a distinct *in-battle* verb, not just a passive number.

---

# 11. Temporary battle upgrades (the roguelite layer)

During selected battles, the player is offered a choice of temporary upgrades — active for that
battle only, never a replacement for permanent ship progression. Example choices: Burning Shot
(+fire damage), Heavy Volley (+50% broadside damage), Rapid Reload (−30% reload time), Emergency
Repairs (restore 20% hull).

**Current code:** does not exist. **Net-new system**, scoped in §14. Reuses existing plumbing
where possible — e.g. "Emergency Repairs" is a straightforward call into `ShipDamage`'s existing
pool-restoration path; "Rapid Reload" multiplies the existing `ShipStats.fire_rate` at the
per-instance level M6 already established for empire-scaled enemy stats
(`EnemySpawner.compute_spawn_multiplier()`'s duplicate-never-mutate pattern is the template).

---

# 12. When upgrades appear

Not on a fast fixed timer (avoids noise). Target cadence: **every ~30–60 seconds, or after major
combat milestones**, offering 2–4 choices in a normal battle and more meaningful choices in a
boss fight. Exact cadence and choice count are tuning, not a fixed spec — refine in playtest
(`docs/15_MASTER_PLAN.md` M10).

---

# 13. Battle duration, victory, defeat, rewards, and progression

These sections carry no reconciliation gap — restated here concisely because they set concrete
tuning targets other docs should build against.

## Duration targets

| Encounter | Target |
|---|---|
| Normal | 2–5 min |
| Elite | 5–8 min |
| Boss | 5–12 min |

Consistent with `docs/00_VISION.md` §16's session-length bands and the per-chapter boss timings
in `docs/13_CAMPAIGN_LEVELS_1-5.md` (Ch4/Ch5 bosses).

## Victory

Ends on primary objective completion (enemies destroyed / convoy defeated / boss defeated /
target escaped-protected) → Victory → Rewards → XP → back to world.

## Defeat — no punishing loss

On defeat: ship damaged, some resources possibly lost, expedition fails, repair required.
**Permanent player progression is never lost.** Message to the player is "try a better strategy,"
never "you lost three hours."

✅ **Already the shipped behaviour.** `docs/06_NARRATIVE_AND_WORLD.md` §7 anti-softlock rule 2
("the player can never lose their last ship permanently... respawns at home with a repair cost,
never a game over") already states this exact contract independently, and `DeathScreen.tscn` +
`ShipController.respawn()` already implement it. No change required — this doc just confirms the
existing rule from the combat side.

## Rewards feed the empire

Gold, wood, iron, rum, ship XP, captain XP, blueprints, rare loot, reputation.

✅ **Mostly shipped.** Gold/wood/iron/rum/reputation/notoriety loot scaling is M6 Task 22
(`docs/05_CURRENT_SYSTEMS.md`). **Not yet shipped:** ship XP as a concept (ships don't level —
only captains do) and "blueprints" as an item type. Both are candidates for the M9 depth pass in
`docs/15_MASTER_PLAN.md`, not blockers for anything sooner.

## Ship progression — level + modules

Two layers: a simple numeric **Level**, and meaningful **Modules** (Hull / Cannon / Sail /
Utility / Special) that let two players build a "Fast Sloop" vs. a "Tank Sloop" from the same
hull rather than everyone converging on identical stats.

**Current code:** ships have neither a level nor a module system — `FleetManager` treats an owned
`ShipStats` resource as fixed once bought. This is genuinely new scope; see §14.

## Visual progression

Upgrades should visibly change the ship, L1 (small wooden starter) through L5
(elite/legendary silhouette).

🟡 **Partial.** `docs/14_SYSTEM_INVENTORY.md` already tracks *building* visual level-up as
scale-only, not distinct models (§3). Ships have no level concept yet at all (see above), so ship
visual progression is net-new, gated on the module/level system existing first.

## The full strategic loop (§21 of the source)

**Before battle:** which fleet? which ships? which captain? which modules?
**During battle:** where do I position? when do I attack? which enemy first? which ability?
which temporary upgrade?
**After battle:** what do I upgrade?

This loop is the throughline the rest of this document exists to support, and it is consistent
with (not a replacement for) the chapter/objective loop in `docs/06_NARRATIVE_AND_WORLD.md` §4 —
the campaign frames *why* you fight; this loop is *how* a single fight plays.

---

# 14. What v1 explicitly does not do

Locked out for v1, per the source decisions:

Full manual cannon aiming (superseded by §4's auto-fire-on-alignment model) · individual crew
management (the shipped crew pool stays a single number, not a roster) · realistic wind
simulation · manual control of every support ship in battle · a boarding **minigame** (the
already-shipped non-minigame boarding stays — see §0 R3) · complex naval physics simulation ·
20+ weapon types · dozens of status effects · real-time PvP · multiplayer networking · huge
fleets on-screen simultaneously.

These are explicitly future possibilities, not permanent exclusions — consistent with
`AGENTS.md`'s existing PvP/multiplayer prohibition for v1.

## Future PvP compatibility (no networking now)

The eventual asynchronous-PvP shape: Player A's fleet → AI-controlled battle → Player B's defense
fleet, or an async replay. **The requirement this places on the architecture today:** combat
simulation, player input, and presentation must stay separable, the way `ShipCombat` (simulation)
/ `ShipController` (input) / `ShipVisuals` (presentation) are already split. No networking code is
written now — this is a constraint on *not coupling* those three layers, not a task.

---

# 15. Scope note — a dedicated combat-rework milestone, not folded into M7

`docs/15_MASTER_PLAN.md`'s M7 (Campaign Spine & Economy Correction) is written against **today's**
manual-fire combat model — its chapter objectives (`DESTROY_SHIPS`, `BOARD_SHIPS`, `DEFEAT_BOSS`)
resolve from signals that already exist and do not depend on how firing is triggered. **This
document's central change — automatic fire on arc alignment (§4), weapon slots (§4), captain
active abilities (§10), temporary battle upgrades (§11), and ship modules (§13) — is scoped as
its own milestone, inserted after M7 and before M9 in the roadmap:**

**M8 — Combat Identity Rework** *(renumbers the legibility-focused milestone previously called M8
in `docs/15_MASTER_PLAN.md` to M8.5, or folds it in — reconcile numbering when this milestone is
actually scaffolded)*

- Arc-alignment detection + broadside indicator + auto-fire loop, replacing the manual
  `fire_port`/`fire_starboard` trigger with an optional player-timed full-broadside special.
- Bow/stern/special weapon slots on `ShipStats`.
- Captain active abilities (one per captain, keyed to their existing passive flavour in
  `docs/12_CHARACTER_BIBLE.md`).
- Temporary in-battle upgrade offers (roguelite layer), 2–4 choices per normal encounter.
- Ship modules (Hull/Cannon/Sail/Utility/Special) + a ship Level separate from captain Level.
- AI-controlled support ships fighting alongside the player.
- Enemy behavior differentiation by role (Raider/Artillery/Tank/Support/Boss), extending
  `AIProfileData` rather than replacing it.
- Encounter-type framework: Encounter / Convoy / Ambush / Elite / Boss / Defense, as data
  (`EventData`, already scoped in `docs/14_SYSTEM_INVENTORY.md` §1).

This is deliberately **not** small — it touches the core input loop of the game — and should get
its own `requirements.md`/`design.md`/`tasks.md` under `.kiro/specs/`, planned in the same way
M1–M6 were, rather than being absorbed as a task inside another milestone.
