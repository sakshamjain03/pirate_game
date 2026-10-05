# Requirements Document

## Introduction

The owner's beta feedback is that the game is "very basic". It doesn't keep players engaged in
strategic planning, or in fighting ship and island battles.

A read-only audit (2026-10-05) used:
- 6 system maps
- a 4-designer panel with 2 critics
- a reference sweep across RTS/4X, mobile strategy and pirate action games
- a 5-concept boarding panel
- a 6-agent cloud-sync audit

It confirmed many systems but almost no real decisions:
- Positioning plus broadside timing is the only combat verb.
- Every ordinary enemy runs `StandardEnemy.tres`.
- Upgrades are flat multipliers.
- Boarding is an instant crew comparison.
- An island is captured by sinking one ship.
- Raids are an off-screen dice roll.
- Every empire choice is vertical: build everything, research everything, buy the biggest hull.

The audit also confirmed **progress-loss bugs** in save and cloud sync: island ownership is never
saved, captain XP resets, a failed refresh signs players out, and more. It also found
**security defects** in entitlements, Eights and account deletion.

M30 makes:
- every fight a readable puzzle,
- **boarding a central pillar** (the owner chose the "Three Bells + Prize Fleet" hybrid),
- islands set-piece battles you assault and defend,
- every sortie a bet,
- the empire a shape the player chooses, with a long ascension arc.

It does all of this through `Resource` data that M31's balance sheet will tune.

**Already met; no further work here:**
- Hull/sails/crew pools, facing armour, ramming and chasers.
- Wind as a speed term.
- Captain abilities: 20 are authored.
- The encounter boundary (`EncounterManager`).
- Heat tiers.
- The Maelstrom mode.
- M27 timers and Eights.
- M28 lessons.
- M29 faction consequences.

M30 extends these and never duplicates them. **Out of M30:** the balance tuning pass (M31) and
everything multiplayer (the MP track).

Owner decisions (2026-10-05):
- Design docs are revisable during beta. `docs/navalCombat.md` §14 gets rewritten.
- Sinking loses only the unbanked Hold.
- Boarding is the "Three Bells + Prize Fleet" hybrid. Crew-% cards and the rock-paper-scissors
  duel were rejected.
- All waves run straight through.
- Reference games: Age of Empires, Clash of Clans, Black Flag, Total War and Sid Meier's Pirates!.

## Glossary

- **Wind-up:** the telegraph window, which can't be skipped, before an enemy broadside fires.
- **Brace:** a player verb that cuts incoming damage for a short window, at the cost of being
  unable to fire.
- **Tactic:** an `AIProfileData` behaviour that shapes where an enemy positions itself. The values
  are STANDARD, STERN_RAKER, LONG_GUNNER, RAM_RUNNER, TENDER and FIRESHIP.
- **Squad:** a mixed enemy composition from `SquadSlotData` entries, with at most 4 hostiles.
- **Fury:** a charge that fills the special broadside from play: hits, rakes, braces and kills.
- **Sortie:** one trip out of port and back.
- **Hold:** loot carried aboard until it's banked at an owned port. It is not the Maelstrom's
  "plunder".
- **Three Bells:** the tactical boarding battle. It plays out over 2–4 "bells" (turns), with 3
  command points (CP) per bell.
- **Prize:** a captured enemy hull that joins the fleet as an `OwnedShipData` with
  `is_prize = true`.
- **Shore battery:** a static fortification built from the existing combat components, never an
  EnemyAI ship.
- **Assault:** a phased `EncounterData` (`Kind.ASSAULT`) that captures an island.
- **Pending raid:** a telegraphed raid with a target island and an ETA, held by `EmpireManager`.
- **Harbour Plan:** the battery-socket layout of an owned island, by approach direction. It is
  also the future multiplayer defence snapshot.
- **Context-button arbiter:** the single function that picks which verb `BtnDock` shows.

## Requirements

### Requirement W0-1: Save integrity — no progress loss
**User Story:** As a beta player, I want every bit of progress to survive a restart, a scene change
and a device switch, so that I never lose my empire.

#### Acceptance Criteria
1. WHEN an island is captured or colonised and the game is saved and reloaded, THE island SHALL
   keep its `island_type` and `owner_faction`.
   - Ownership SHALL be restored before buildings and before the offline catch-up.
   - An unresolvable faction id SHALL `push_error`.
2. WHEN loading a save written before this change, THE system SHALL mark an island FRIENDLY if it
   has buildings or matches `home_island_id`.
3. WHEN a captain gains XP or levels up, THE level and XP SHALL persist across a restart.
   - Captains SHALL be duplicated on load and never mutate the shared `.tres`.
4. WHEN the player leaves the World through any route, THE game SHALL save first. Routes:
   - PauseMenu Quit
   - PauseMenu Settings
   - Android `NOTIFICATION_APPLICATION_PAUSED`
   - `WM_CLOSE_REQUEST`
5. WHEN the player chooses "Keep Cloud", THE World SHALL reload from the applied save, so that no
   later autosave can push stale in-memory state.
6. WHEN the player chooses "Keep This Device", THE Eights balance SHALL be max-merged with the
   cloud value, the same way Keep Cloud does it.
7. WHEN an island node is disabled by the content gate, THE save SHALL carry its previous entry
   forward unchanged.
8. IF a ship or captain resource path can't be resolved on load, THEN THE original path SHALL be
   kept in the save, and a `push_error` SHALL be raised.

### Requirement W0-2: Cloud sync resilience
**User Story:** As a player who is signed in, I want sync to survive offline play, a paused server
and conflicts, so that the cloud never overwrites good progress.

#### Acceptance Criteria
1. WHEN a session refresh fails with network code 0 or 5xx, THE session SHALL be kept.
   - It SHALL be cleared only on an explicit invalid-grant response, and clearing SHALL emit
     `signed_out`.
2. THE client SHALL refresh the access token before it expires, with at most one refresh in flight.
3. `_fetch_cloud_save` SHALL distinguish `ok`, `none` and `error`.
   - Uploads SHALL be blocked until one fetch for the current user has succeeded.
4. IF the local load fails, or the cloud row has a newer schema, THEN autosave and cloud upload
   SHALL be disabled for the rest of the session.
5. WHILE a cloud-conflict dialog is open, THE game SHALL neither autosave nor upload.
   - The dialog SHALL be parented to the tree root.
6. Uploads:
   - Uploads SHALL be serialised: one in flight, with the latest snapshot queued.
   - Uploads SHALL have an HTTP timeout.
   - Uploads SHALL back off after failure.
   - A pending-upload flag SHALL persist to disk.
   - An unchanged snapshot (same hash) SHALL not be uploaded again.
7. THE HUD or Account tab SHALL show "Cloud sync failing since <time>" while uploads fail.
8. THE local save SHALL record `owner_user_id`.
   - WHEN a different account signs in, THE game SHALL ask before uploading.
   - The chapter-Eights ledger SHALL live inside the save, so it is account-scoped.
9. Conflicts SHALL be decided by a monotonic `save_revision` and server time, not by the device
   clock.

### Requirement W0-3: Store and entitlement safety (client side)
**User Story:** As the owner, I want release builds to be unable to grant paid items for free, so
that monetization can't be exploited.

#### Acceptance Criteria
1. IN a non-debug build on a platform without a real store backend, THE store SHALL show
   "Unavailable", and `StoreBackendStub` SHALL never grant anything.
2. A lost raid SHALL never remove the premium currency.
3. THE repository SHALL contain authored SQL migrations (`supabase/migrations/0001`–`0006`):
   - cascade on foreign keys
   - an entitlement ledger
   - purchases
   - a wallet
   - hardening of `player_saves`
   - grant hygiene

   It SHALL also contain an updated `delete-account` function that removes every user table.
   - **Applying them to the live project requires explicit owner approval.**

### Requirement W0-4: Combat foundations
**User Story:** As a developer, I want the combat seams that M30 builds on to be correct, so that new
mechanics don't stack onto latent bugs.

#### Acceptance Criteria
1. WHEN a range multiplier is applied, THE cannonball launch speed SHALL scale with it, so that
   shots reach the solver's range. Only the velocity changes, never the basis-derived direction.
2. A friendly SUPPORT ship SHALL only heal its own side.
3. Friendly AI SHALL only engage hostiles that are provoked or engaging.
4. There SHALL be one shared upgrade roller, used by both `EncounterManager` and `MaelstromRun`.
5. WHILE an encounter is active:
   - a second `start_encounter` SHALL be refused or queued, and
   - ambient ships inside its radius SHALL be parked or despawned.
6. `CombatModifiers` layers SHALL have explicit lifetimes, and `reset()` SHALL clear only
   encounter-scoped layers.
7. `EnemyAI.apply_profile()` SHALL re-apply a profile after `_ready`.
8. `ShipDamage` SHALL emit `hit_resolved(source, facing, pool_deltas, ammo_id)` for every hit and
   impact.
   - Every cannon hit SHALL produce FloatingDamage.
   - Crew writes SHALL go through `pool_changed`.
9. Ambient enemies SHALL draw an `ai_profile` from a weighted `RegionData.enemy_profile_pool`,
   assigned before `add_child`.
10. These hardcoded gameplay numbers SHALL move into data:
    - the wind lerp
    - the 20% death penalty
    - the island capture notoriety
11. A single context-button arbiter SHALL choose the `BtnDock` verb. Priority: Repel > Brace >
    Board/Take Prize > Keg > Land > Assault > Spyglass > Dock.

### Requirement W1-1: Readable enemies
**User Story:** As a player, I want enemies with distinct, telegraphed tactics, so that every fight
is a puzzle I read and answer.

#### Acceptance Criteria
1. Each tactic SHALL position the enemy differently, using a low-pass-filtered
   `preferred_bearing_deg` and `kite_min_distance`. Only `ideal_position` changes; avoidance is
   untouched.
   - STERN_RAKER holds the target's stern quarter.
   - LONG_GUNNER kites at long range.
   - RAM_RUNNER uses a telegraphed ram.
   - TENDER heals.
   - FIRESHIP rams and burns.
2. WHEN an enemy broadside is about to fire, THE enemy SHALL hold fire for
   `broadside_windup_seconds`.
   - It SHALL emit `broadside_windup(side, duration, target)`.
   - A wedge decal tinted by ammo type SHALL show, plus a rim arrow when the shooter is off-screen.
   - Player hulls have no wind-up.
3. WHEN the player presses Brace during a wind-up that covers them, THEN:
   - Damage taken SHALL be reduced by `BraceData.reduction` for `BraceData.window`.
   - A Perfect Brace (pressed in the last `perfect_window`) SHALL reduce it further and grant
     Fury.
   - The player's own guns SHALL be unable to fire while bracing.
   - A cooldown SHALL apply.
4. `EncounterData.squad` SHALL spawn mixed compositions with formation bearings, at most 4
   hostiles. It SHALL fall back to `enemy_scene`/`enemy_count` when empty.
5. Heat tiers SHALL select squad pools, so that higher heat means harder compositions.
6. THE player's FiringSolver SHALL prefer the hull nearest the arc's centre line, plus an optional
   tap-to-mark override. The AI SHALL keep nearest-target behaviour.

### Requirement W1-2: Combat verbs, feedback and stakes
**User Story:** As a player, I want more meaningful verbs and clear feedback, so that good play feels
good and is rewarded.

#### Acceptance Criteria
1. WHEN an encounter starts, THE Spyglass Briefing SHALL show:
   - the roster as role icons,
   - weaknesses,
   - formation, and
   - the star-2 hint,

   and let the player pick an opening ammo per side and 1 of 3 Preparations. Watchtower level
   SHALL gate how much intel it shows.
2. Powder Kegs:
   - WHEN an enemy is inside the stern cone, THE context button SHALL offer Keg.
   - A keg SHALL float with a visible fuse and detonate on contact or proximity.
   - The stock per sortie is data-driven.
3. A feedback pack SHALL provide:
   - a rake cone on the current target,
   - at most 3 ribbons,
   - colour-coded damage numbers,
   - a camera offset punch (never `time_scale`), and
   - haptics,

   all respecting reduced motion.
4. Fury:
   - Fury SHALL fill from hits, rakes, Perfect Brace and kills, as an extra fill on the existing
     special timer.
   - The existing special-cooldown upgrade semantics SHALL still hold.
5. Every encounter SHALL award 1–3 Sortie Stars for meeting its authored conditions. Stars SHALL
   never gate campaign content.

### Requirement W2: Boarding — the central pillar (Three Bells + Prize Fleet)
**User Story:** As a player, I want boarding to be a tactical battle shaped by my gunnery, whose
outcome grows my fleet and crew, so that taking ships is the heart of piracy.

#### Acceptance Criteria
1. Starting a boarding:
   - `attempt_boarding()` SHALL behave exactly as before (deterministic auto-resolve).
   - `begin_boarding()` SHALL route Quick or Overwhelm to it, and otherwise lock the target and
     emit `boarding_started`.
   - `boarding_resolved` SHALL fire exactly once per boarding.
   - `tests/test_boarding.gd` and `tests/test_m29_boarding_loot_once.gd` SHALL pass unmodified.
2. THE Three Bells battle SHALL be a seeded, deterministic, pure model.
   - Number of bells = 2 + round(hull fraction × 5), at most 4.
   - 3 CP per bell. The bell rings automatically after 6s.
   - Each defender shows a telegraphed intent.
   - Player actions resolve first, then intents in order.
   - Seizing an objective zone ends the battle with that zone's outcome.
3. THE deck SHALL be built from the gunnery used before boarding:
   - grape removes Deckhands
   - chain removes Riggers
   - a stern-rake wounds the Officer

   It SHALL also use the faction × class profile, the entry bearing and the crew fraction. A
   preview strip on the enemy health bar SHALL update live.
4. Outside hostiles SHALL appear as intents. Brace and Point-Blank SHALL spend CP.
5. Morale:
   - Enemy morale SHALL drain from crew loss, rakes and the leader sinking.
   - A Wavering telegraph SHALL lead to FLEE or strike colours.
   - A struck ship SHALL be takeable through the context verb.
   - A Dread/Renown axis SHALL persist, omitted while it is zero.
6. The Prize Fleet:
   - A Colours outcome SHALL offer Keep (send home with a prize crew), Ransom officers, or Break
     for salvage.
   - Kept prizes SHALL join the fleet, with `uid`, `is_prize`, `condition` and
     `provenance_trait`.
   - Duplicate hulls SHALL be allowed for prizes.
   - Old saves SHALL migrate to uid identity.
   - Prizes in transit SHALL persist, and arrive at the next dock with a recapture roll.
7. The Ship's Company:
   - The crew SHALL be made of named squads with role, rank, XP, wounds and trait.
   - Squads SHALL give sea-station bonuses, which are suspended while that squad is boarding.
   - Elite squads SHALL come only from boarding outcomes.
   - Captain Orders SHALL change boarding rules.
   - `ShipDamage.crew` SHALL remain the total, so old saves load.
8. Repel: enemies with the boarding tactic SHALL be able to grapple the player, and play SHALL
   use the same battle model on the player's deck.

### Requirement W3: Island battles
**User Story:** As a player, I want islands that fight back and assaults with phases and choices, so
that taking an island is a real battle.

#### Acceptance Criteria
1. Shore batteries:
   - They SHALL be StaticBodies built from the existing combat components, and SHALL never be in
     the `enemy_ship` group.
   - Grape suppresses: crew reaches 0, the battery goes silent, then it re-mans from the
     garrison.
   - Round destroys: stone takes ×0.5, and rubble persists for `rebuild_seconds` and is saved.
2. `EncounterData.phases` SHALL advance phase by phase, and `encounter_ended` SHALL fire only
   after the last phase.
   - There SHALL be a `Kind.ASSAULT`, plus SILENCE_FORTIFICATIONS and HOLD_ZONE objectives
     (append-only).
   - Upgrade offers SHALL appear at phase boundaries.
3. `IslandDefenseData` SHALL replace the single hardcoded defender.
   - Capturing SHALL follow from assault victory, which removes the friendly-fire capture hazard.
   - Every CAPTURE_ISLAND objective in Ch1–5 SHALL remain winnable, and Ch2 in a Sloop.
4. Landing SHALL use the boarding model against the island target. A Blockade option SHALL drain
   the garrison over ticks.
5. Garrison strength SHALL scale with region × heat × `FactionData.fortification_strength_mult`,
   never with the island's own tier.
6. Owned Fortress and Watchtower levels SHALL spawn friendly batteries and grant range or mark
   bonuses. Eights SHALL be unable to finish a fort repair while a raid is pending.

### Requirement W4: Every sortie is a bet
**User Story:** As a player, I want risk and stakes on every trip and visible threats to my empire,
so that I plan instead of reacting to reports.

#### Acceptance Criteria
1. The Hold:
   - Combat loot SHALL go into the Hold.
   - Docking at an owned port SHALL bank it, up to the storage cap.
   - Sinking SHALL lose the unbanked Hold (with 50% recoverable at the wreck), replacing the 20%
     gold penalty.
   - Eights SHALL never enter the Hold.
   - The Hold SHALL persist, omitted when empty.
2. Colors:
   - False Colors SHALL halve notoriety gain, and can be blown at heat tier 3+.
   - The Jolly Roger SHALL scale loot by heat tier through `LootScalingData`.
3. Raids SHALL become pending raids, with:
   - an ETA and an approach bearing
   - a map marker and a notification
   - four answers: Intercept, Defend in harbour, Pay tribute, Ignore/offline

   Losses SHALL be capped at 10% of unprotected storage, and a lost raid SHALL grant an 8h truce.
4. Harbour Plan sockets SHALL determine per-approach raid resolution and the live defence. A Raid
   Log and Revenge SHALL exist.
5. Raids SHALL target any owned island.
6. Capture aftermath (Sack/Garrison/Raze) SHALL ship together with retake attempts.

### Requirement W5: Builds, not buffs
**User Story:** As a player, I want upgrades, ammo and bosses that reward a coherent build, so that
runs play differently.

#### Acceptance Criteria
1. `ShipStatusEffects` SHALL absorb the existing speed penalty, and SHALL add Burn and Crippled
   (cap 3).
2. Ammo loads SHALL apply at the next reload.
   - HeatedShot SHALL exist.
   - A published counter triangle SHALL apply ×1.5 against matching weakness tags.
3. Upgrades:
   - Upgrades SHALL carry tags, triggers, keystones and cursed drawbacks.
   - The shared roller SHALL weight offers toward tags already held.
   - The existing 22 upgrades SHALL be retagged.
4. Boss phases SHALL run through a `BossPhaseController` on boss scenes, including bosses spawned
   by EventManager.
5. One Legendary Ship per region SHALL be visible on the map, with a first-kill Eights grant.
6. Salvage-forged modules SHALL be sidegrades with drawbacks.
7. Maelstrom SHALL gain:
   - Call the Wave
   - route nodes on the Chart
   - a firewalled meta (the Locker)

### Requirement W6: The empire is a shape
**User Story:** As a player, I want specialization choices that close doors, so that my empire
differs from another player's.

#### Acceptance Criteria
1. Hull traits SHALL give each hull a sideways identity.
   - Sail trim SHALL trade speed against reload, and SHALL never change turn rate.
2. Islands:
   - Islands SHALL have build slots counted by building type, plus affinities and a charter.
   - Old saves over the limit SHALL be grandfathered.
   - The buildings that Ch1–5 require SHALL fit within the slots.
3. Tech SHALL include either/or pairs and verb-granting techs, aggregated once through
   `ModifierSetData`.
4. Wind SHALL become a data-driven points-of-sail curve with a floor of about 0.6, plus an AI tack
   helper.
5. Patrol missions SHALL lower raid odds, so that trade isn't strictly dominant.

### Requirement W7: Ascension
**User Story:** As a long-term player, I want an arc of ages, relics and a wonder, so that there's
always a meaningful goal.

#### Acceptance Criteria
1. Empire Ages:
   - There SHALL be four ages, each a timed investment.
   - At each age the player SHALL pick one of two exclusive landmarks.
   - An age-up SHALL open an opt-in "Crown's Answer" raid window.
2. Relics:
   - Relics SHALL be carried home in the Hold.
   - A relic SHALL never be destroyed: on sinking it becomes a recoverable buoy.
   - Banking a relic SHALL grant its perk.
3. The Pirate Republic wonder SHALL have 5 stages. Eights SHALL never skip a stage timer.
4. Letters of Marque SHALL bind the player to one patron, with grades and consequences.
5. Free Ports SHALL grant favour tiers. Favour SHALL never decay.

## Out of Scope

| Item | Why or where it goes |
|---|---|
| Balance tuning of all new numbers | **M31**; every new value is marked `# placeholder: tune in M31` |
| Anything multiplayer: PvP, the home archipelago, async raids, the brawl, server-authoritative wallet RPCs | The **MP track**. M30 only authors the migrations (W0-3.3), and applying them needs owner approval. |
| Escort/consort wings | Deferred |
| Expedition board | Contracts milestone |
| Captain postings/traits | Deferred |
| Population tiers | Deferred |
| Storm season | Deferred |
| Leviathan | Deferred |
| Harbour boom | Deferred |
| Flooding | Deferred |
| Lay-the-guns | Deferred |
| Shoal volumes | Deferred |
| Any change to buoyancy, stability torque or the yaw servo, the collision AABB, the cannon basis-forward, or EnemyAI avoidance | Never |
| Live real-device verification of feel, FPS, haptics, notifications and sync | Reported as unverified rather than claimed |
