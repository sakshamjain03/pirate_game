# Design Document — M11 Depth

## Architecture direction by requirement

All eleven requirements are additive content/systems work layered on existing managers — none
require a new autoload or a new persistence path. The unifying rule, per `AGENTS.md`: extend the
manager that already owns the relevant axis (faction → `FactionManager`, region → `RegionData`/
`EmpireManager`, combat modifier → `CombatModifiers`/`AIProfileData`) rather than introducing a
parallel system for "depth."

### Requirement 1 — Tech tree

`TechManager` already recalculates multiplicative global modifiers from unlocked `TechData`
resources — this scales by authoring more `.tres` files, not code changes, unless a genuinely new
modifier category is needed (e.g. a boarding-specific or region-specific modifier `TechManager`
doesn't currently apply). Gate tiering: reuse `BuildingData.required_island_tier`'s pattern — add
an equivalent `TechData.required_tech_id` (prerequisite chain) or `required_island_tier` if
tier-gating fits better than a dependency chain. Author against Requirement 10's balance model
before picking final cost numbers.

### Requirement 2 — Wind

Lightest-weight integration: a single global (or per-`EncounterData`) wind direction/strength
value, read by `ShipMovement`'s existing speed calculation as one more multiplicative term (same
pattern `ShipDamage.get_speed_multiplier()`'s sail-damage penalty already composes with). Visual
legibility: reuse sail geometry already present on every ship model — a simple sail-angle/fill
visual tied to heading-relative-to-wind, or a compass-adjacent UI indicator reusing `WorldHUD`'s
existing `CompassPanel` positioning convention rather than a new indicator style.

### Requirement 3 — Cannonball arcing

`Cannonball.gd` is a `RigidBody3D`; today's straight-line flight is likely a `gravity_scale` of 0
or a very short flight time. Arcing predominantly means tuning `gravity_scale`/initial velocity to
a real ballistic arc and re-deriving `cannon_range`'s achieved distance the same way M8's Phase-1
balance correction did (`docs/05_CURRENT_SYSTEMS.md`'s "Balance correction — cannon_range was
unreachable" section documents the exact math: speed × flight time). `FiringSolver`'s range gate
must be re-validated against the new flight time using that same derivation, and
`test_combat_integration.gd`'s existing range/reach assertion (added in M8 specifically to prevent
this drift) should catch a mismatch — treat that test failing as a signal to fix the range
authoring, not to weaken the test.

### Requirement 4 — Hull-facing armor

`FiringSolver` already computes which side (`SIDE_PORT`/`SIDE_STARBOARD`/`SIDE_BOW`/`SIDE_STERN`)
a hit arrives from for targeting purposes — `ShipDamage.apply_hit()` already has a stern-crit
special case. Generalize: a per-facing armor multiplier array on `ShipStats`, keyed by the same
side enum `FiringSolver` already defines, applied in `apply_hit()` alongside (not replacing) the
existing stern-crit logic — bow armor typically highest (thick forward timbers), broadside
moderate, stern already covered by the crit multiplier.

### Requirement 5 — 2 more bosses

Follow the HMS Intransigent/Cárdenas' escort precedent exactly (`docs/05_CURRENT_SYSTEMS.md`'s M7
section): dedicated `ShipStats` (non-shared, so `DEFEAT_BOSS` objective matching by `ship_id` stays
unambiguous), dedicated scene, dedicated `EncounterData` with `Kind.BOSS`. Placement: if narratively
tied to a specific chapter/region, use `required_chapter_id` (M7.5's gate mechanism); if meant as a
standalone "found while exploring" encounter (a good fit for the Requirement 7 world-events
expansion's spirit), leave `required_chapter_id` empty and add to the ambient pool directly, per
whichever region fits the boss's narrative weight — high-tier regions for a harder fight.

### Requirement 6 — Diplomacy and trade routes

**Diplomacy:** `FactionManager.reputation` is already a per-faction float the player's actions
move. A treaty/tribute action is the inverse of the existing "attack this faction's ship" reputation
delta — a UI action (likely in `IslandMenu`'s Trade tab, where faction-adjacent interactions already
live) that spends resources for a reputation bump, on a cooldown to prevent spamming it back to
neutral. **Trade routes:** `FleetManager`'s background missions already tick gold/reputation on a
timer — the "placeable object" upgrade is presentation/management (a route the player can see,
name, and reassign) more than new mechanics; the underlying tick logic likely doesn't need to
change, only how it's exposed and configured. Resolve the exact UI shape against `IslandMenu`'s
Fleet tab conventions before writing new persistence — this is flagged as an open design question
in `requirements.md` deliberately, since the "right" UI shape depends on playtesting feedback this
milestone doesn't yet have (ties into Requirement 10/M12's own playtest-protocol gap).

### Requirement 7 — World events

If M10 has landed by the time this milestone starts, `EventData` already exists — this is purely
authoring more `.tres` files through that resource. If M10 hasn't landed yet (re-verify against
current `docs/05_CURRENT_SYSTEMS.md`), this requirement's scope folds into building the `EventData`
resource itself first — don't duplicate that work if M10 already did it.

### Requirement 8 — SFX and music

`AudioManager` already has a working bus/play-sound pipeline (`default_bus_layout.tres`) and
already surfaces missing-asset warnings clearly (confirmed directly: "No audio asset for 'cannon' —
assets/audio/ is empty" fires on every shot in the current build) — this requirement is asset
sourcing/authoring against an already-working integration point, not new code. Source via free/
CC-licensed SFX libraries (Freesound, Kenney's own audio packs — consistent with this project's
established Kenney-first asset sourcing pattern) or lightweight procedural generation (the
tech-stack doc's own note on Audacity/Bfxr as intended tools) rather than assuming custom
commissioned audio is required.

### Requirement 9 — Portraits

M9's Presentation Pass (Requirement 8 there) already built a shared fallback mechanism specifically
so this requirement only needs to add real files — confirm that mechanism's exact interface
(`PortraitFallback.get_portrait_texture()` or equivalent, per M9's `design.md`) before starting,
since it may have landed with a different final shape than proposed there. Source via the same
stock-asset-first approach as M10's building art, or simple programmatic/stylized portraits
(silhouettes, flat-color icon busts matching `docs/03_ART_DIRECTION.md`'s low-poly/stylized
direction) if bespoke character art isn't feasible within this milestone.

### Requirement 10 — Balance model

Not a code deliverable — a documentation/spreadsheet artifact. Anchor it against the one balance
ladder this project already has real numbers for: the ship-cost ladder in
`docs/13_CAMPAIGN_LEVELS_1-5.md` §2 (established during the D53 fix). Every new tech/boss
reward/event outcome this milestone introduces should be expressible as "worth roughly N% of a
[ship tier]" or similar relative anchor, not an isolated guess — this is exactly the discipline
`docs/14_SYSTEM_INVENTORY.md` §6 identifies as missing and directly responsible for D53.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone: whatever M10's checkpoint closes at (0 known failures expected,
per M10's Ocean LOD work).

Requirements 2/3/4 (wind, arcing, armor variance) touch the core combat feel — per this project's
own risk register (`docs/15_MASTER_PLAN.md` §5, "Combat rework... regresses feel"), verify against
a fresh headful capture that combat still reads clearly, not just that automated tests pass.
Requirement 8 (audio) is the one item in this milestone verifiable by ear, not by screenshot — note
in the checkpoint that this needs an actual human listening, the audio equivalent of this project's
established "needs a human at the controls" caveat.
