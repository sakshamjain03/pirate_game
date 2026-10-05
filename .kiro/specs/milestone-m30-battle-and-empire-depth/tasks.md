# Implementation Plan: Milestone M30 — Battle & Empire Depth

## Overview

**Depends on M29 Checkpoint B**, which is open as of 2026-10-05. Close it first, or record exactly
what couldn't be verified (Rule 8).

Before Task 0.1, read this spec's `requirements.md`, `design.md` and `notes-sync-audit.md`, plus
the `docs/05_CURRENT_SYSTEMS.md` sections for every file a task touches.

**The owner chose to run all waves straight through.** Every wave still ends in a real checkpoint:
- the full suite
- `checkpoint-reviewer`
- a headful capture where the wave is visual
- commit and push, with `git add` scoped to the files you changed (other sessions edit this repo)

**Every fix task starts with a failing test.** If the test passes before you change anything, tick
the task, append `(stale: <why>)`, and move on.

Every new test file is flat: `tests/test_m30_<area>.gd`. Mutation-check every new test: break the
fix and watch the test fail.

**Commands:**
- Single file: `.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- Full suite: the same command with `-gdir=res://tests`
- Never use `--check-only`.
- Rebuild the class cache with `--headless --import --path .` after adding a `class_name`.

**Every new gameplay number** lives in a `.tres` file, commented `# placeholder: tune in M31`.

## Tasks

### Wave 0 — Foundations, save integrity, sync safety

**0-A Save integrity** (these protect beta players' saves now, so do them first)
- [ ] 0.1 Island ownership persists, with migration and carry-forward of gated islands. Files: `SaveManager.gd` (islands save/load), `Island.gd` (an ownership getter/setter, if needed)
  - **Verify:** `tests/test_m30_island_ownership_save.gd`
    - Colonize and capture, save, reload: still FRIENDLY with the right owner, and production ticks.
    - An old-format entry with buildings migrates to FRIENDLY.
    - An unknown faction id → `push_error`, and the authored value is kept.
    - A gated island's entry survives a save.
  - _Requirements: W0-1.1, W0-1.2, W0-1.7_
- [ ] 0.2 Captain level and XP persist; captains are duplicated on load. Files: `FleetManager.gd`, `CaptainData.gd`
  - **Verify:** `tests/test_m30_captain_progress_save.gd`
    - Level a captain, save, reload: same level and XP.
    - The `.tres` on disk is unchanged.
    - An old bare-path save loads at level 1.
    - An unresolvable path is kept in the save, with a `push_error`.
  - _Requirements: W0-1.3, W0-1.8_
- [ ] 0.3 Save when leaving the World. Files: `SaveManager.gd` (`_notification`), `PauseMenu.gd`
  - **Verify:** `tests/test_m30_save_on_exit.gd`
    - A simulated `NOTIFICATION_APPLICATION_PAUSED` in campaign mode writes the save.
    - PauseMenu Settings and Quit call `save_game` first.
    - In Maelstrom mode nothing is written.
  - _Requirements: W0-1.4_
- [ ] 0.4 Keep Cloud reloads the World; Keep This Device max-merges Eights; autosave is suspended while the dialog is open; the dialog is parented to root. Files: `SaveManager.gd`
  - **Verify:** `tests/test_m30_cloud_conflict.gd`, with a stubbed fetch
    - After Keep Cloud, the in-memory state matches the cloud row.
    - No upload happens while the dialog is open.
    - After Keep This Device, eights = max.
  - _Requirements: W0-1.5, W0-1.6, W0-2.5_
- [ ] 0.5 Raids never steal Eights. Files: `EmpireManager.gd`
  - **Verify:** `tests/test_m30_raid_no_eights.gd`. Force a lost raid with eights = 500: eights stay 500, and the other resources drop. `test_empire_manager.gd` passes unmodified.
  - _Requirements: W0-3.2_

**0-B Sync resilience**
- [ ] 0.6 `refresh_session` keeps the session on network or 5xx errors; refresh before expiry; one refresh at a time; `_clear_session` emits `signed_out`. Files: `AuthManager.gd`
  - **Verify:** `tests/test_m30_auth_refresh.gd`, with a stubbed transport
    - code 0 → still signed in, and degraded.
    - 400 `invalid_grant` → signed out, and the signal fires.
    - Two concurrent callers → one request.
  - _Requirements: W0-2.1, W0-2.2_
- [ ] 0.7 The fetch result distinguishes ok/none/error; uploads wait for a known baseline; `_load_blocked` on a failed load or a newer schema. Files: `SaveManager.gd`
  - **Verify:** `tests/test_m30_cloud_fetch_guard.gd`
    - A fetch error → no upload, even after autosave.
    - A newer-schema row → `save_game` is a no-op and the HUD flag is set.
    - Status `none` → uploads are allowed.
  - _Requirements: W0-2.3, W0-2.4_
- [ ] 0.8 Upload queue: one in flight, the latest snapshot queued, a 15s timeout, backoff, a persisted pending flag, a hash skip. Files: `SaveManager.gd`
  - **Verify:** `tests/test_m30_upload_queue.gd`
    - 3 rapid saves → at most 2 requests, and the last payload equals the final state.
    - An unchanged snapshot → 0 requests.
    - The pending flag survives a simulated restart.
  - _Requirements: W0-2.6_
- [ ] 0.9 `owner_user_id` stamp plus an account-mismatch prompt; the chapter-Eights ledger moves into the save; `save_revision`. Files: `SaveManager.gd`, `CampaignManager.gd`
  - **Verify:** `tests/test_m30_account_scope.gd`
    - Sign in as B over A's save → the prompt shows and no upload happens.
    - The ledger round-trips inside the save, and the old file is migrated once.
    - The revision increments on every save.
  - _Requirements: W0-2.8, W0-2.9_
- [ ] 0.10 Sync status line ("Cloud sync failing since X"). Files: `SaveManager.gd` (signal), `WorldHUD.gd` or the Settings Account tab
  - **Verify:** `tests/test_m30_sync_status.gd`. Failures → the status `failing` with `since`. A success → `ok`. The label shows the text.
  - _Requirements: W0-2.7_

**0-C Store and backend safety**
- [ ] 0.11 Release builds never use `StoreBackendStub`. Files: `StoreManager.gd` (plus a `StoreBackendUnavailable.gd`)
  - **Verify:** `tests/test_m30_store_release_guard.gd`. With `is_debug_build` stubbed false on a non-Android platform → the backend is unavailable, the Buy button is disabled, and `begin_purchase` grants nothing.
  - _Requirements: W0-3.1_
- [ ] 0.12 Author `supabase/migrations/0001–0006` and the updated `delete-account`; update `docs/SUPABASE_SETUP.md` (3 tables, how to apply, keep-alive). **Do not apply to the live project without owner approval.**
  - **Verify:** the files exist. Each migration is idempotent (`if exists`/`if not exists`). `delete-account` deletes every user table. The doc lists `player_entitlements`. The owner confirms before applying.
  - _Requirements: W0-3.3_

**0-D Combat foundations**
- [ ] 0.13 Range multipliers scale launch speed (the velocity line only). Files: `ShipCombat.gd`
  - **Verify:** `tests/test_m30_range_velocity.gd`. With ×1.2 range, the ball lands at ≥ 0.95 × the solver range. The direction equals the basis-derived forward. `test_ship_combat.gd` passes unmodified.
  - _Requirements: W0-4.1_
- [ ] 0.14 Friendly support heals only its own side; friendly AI engages only provoked or engaging hostiles. Files: `EnemyAI.gd` (`_find_wounded_ally`, `_find_nearest_hostile_enemy` only)
  - **Verify:** `tests/test_m30_friendly_ai_side.gd`. A friendly Tender never repairs an `enemy_ship`. A friendly ally ignores a passive ambient hull. Avoidance functions are byte-identical (`git diff` shows no hunks in them).
  - _Requirements: W0-4.2, W0-4.3_
- [ ] 0.15 Shared `UpgradeRoller`, used by `EncounterManager` and `MaelstromRun`. Files: `scripts/combat/UpgradeRoller.gd`, both callers
  - **Verify:** `tests/test_m30_upgrade_roller.gd` (seeded, same distribution for both callers). `test_battle_upgrades.gd` and the Maelstrom tests pass.
  - _Requirements: W0-4.4_
- [ ] 0.16 Encounter exclusivity plus ambient parking; `CombatModifiers` layer lifetimes. Files: `EncounterManager.gd`, `CombatModifiers.gd`
  - **Verify:** `tests/test_m30_encounter_exclusive.gd`
    - A second `start_encounter` → false plus `encounter_failed`.
    - Ambient hulls inside the radius are parked during the encounter and restored after.
    - `reset()` keeps PERSISTENT layers.
  - _Requirements: W0-4.5, W0-4.6_
- [ ] 0.17 `EnemyAI.apply_profile()`; `RegionData.enemy_profile_pool` assigned before `add_child`. Files: `EnemyAI.gd` (refactor of the `_ready` profile block), `RegionData.gd`, `EnemySpawner.gd`, region `.tres`
  - **Verify:** `tests/test_m30_profile_pool.gd`. Across 200 seeded spawns, the profile distribution matches the weights. `apply_profile` after `_ready` changes the behaviour fields.
  - _Requirements: W0-4.7, W0-4.9_
- [ ] 0.18 `ShipDamage.hit_resolved` plus `hit_tags`; crew writes through `pool_changed`; FloatingDamage on every cannon hit. Files: `ShipDamage.gd`, `Cannonball.gd`, `FloatingDamage.gd`, `BoardingSystem.gd` (crew write)
  - **Verify:** `tests/test_m30_hit_resolved.gd`. One hit → exactly one signal with facing, deltas and ammo. The stern arc → `&"stern"`. A boarding crew loss emits `pool_changed`.
  - _Requirements: W0-4.8_
- [ ] 0.19 Data-drive the hardcoded numbers: `WindConfigData` (`ShipMovement.gd` lines 88–92 only), `DefeatPenaltyData` (`DeathScreen.gd`), capture notoriety (`Island.gd`)
  - **Verify:** `tests/test_m30_data_driven_numbers.gd`. Default `.tres` values reproduce the old behaviour exactly. `grep -n "lerp(0.85" scripts/` and `grep -n "0\.2)" scripts/ui/DeathScreen.gd` return nothing.
  - _Requirements: W0-4.10_
- [ ] 0.20 Context-button arbiter with registered providers. Files: `WorldManager.gd`, `MobileControls.gd`
  - **Verify:** `tests/test_m30_context_arbiter.gd`. Board beats Dock when eligible. The registered priority order holds. The icon and label update. Existing dock and board tests pass.
  - _Requirements: W0-4.11_
- [ ] 0.21 Rewrite `docs/navalCombat.md` §14 (now unlocked vs still out) and add a `docs/05` M30 section skeleton.
  - **Verify:** both are present. `sync-systems-doc` raises no M30 Wave 0 gaps.
  - _Requirements: all W0_
- [ ] **Checkpoint W0**
  - Full suite, with a count ≥ the baseline plus the new tests and 0 failures.
  - `checkpoint-reviewer`.
  - `SelfPlayHarness` headless grep, or a recorded reason it couldn't run.
  - Commit and push.
  - A manual checklist for the owner: two devices, two accounts, offline → online, and a paused project.

### Wave 1 — Every fight is a read
- [ ] 1.1 `AIProfileData.tactic`/`preferred_bearing_deg`/`kite_min_distance`/`ammo_rules`; tactic positioning in `_process_attack` (`ideal_position` only, low-pass filtered). Files: `AIProfileData.gd`, `EnemyAI.gd`
  - **Verify:** `tests/test_m30_enemy_tactics.gd`. A Raker settles in the stern quarter (±25°) within 20s. A Long Gunner keeps ≥ `kite_min_distance`. A Ram-Runner telegraphs before the ram. The avoidance diff is empty.
  - _Requirements: W1-1.1_
- [ ] 1.2 Fireship profile plus contact area damage (extract `_detonate_keg` into a shared static). Files: `MaelstromRun.gd` (extraction), new `AreaDamage.gd`, `resources/combat/ai_profiles/Fireship.tres`
  - **Verify:** `tests/test_m30_fireship.gd`. Contact → area damage to every hull within radius, and the fireship frees itself. The Maelstrom keg tests pass.
  - _Requirements: W1-1.1_
- [ ] 1.3 Author the tactic profiles, plus faction role mixes in the region pools. Files: `resources/combat/ai_profiles/*.tres`, `resources/world/regions/*.tres`
  - **Verify:** `tests/test_lint_resource_exports.gd` passes. A profile-pool test asserts each faction's mix.
  - _Requirements: W1-1.1_
- [ ] 1.4 Broadside wind-up gate in the auto-fire loop, plus the `broadside_windup` signal and `AIDifficultyData.broadside_windup_seconds`. Files: `ShipCombat.gd`, `AIDifficultyData.gd`, difficulty `.tres`
  - **Verify:** `tests/test_m30_windup.gd`. An enemy fires only after the wind-up. A player hull fires immediately. `fire_broadside()` is still synchronous. `test_ship_combat.gd` passes unmodified.
  - _Requirements: W1-1.2_
- [ ] 1.5 Threat decals (wedge tinted by ammo, rim arrow; at most 2, by priority). Files: `scripts/ui/ThreatDecals.gd`, `WorldHUD.gd`
  - **Verify:** `tests/test_m30_threat_decals.gd` (budget and priority), plus a **headful capture** of a wedge.
  - _Requirements: W1-1.2_
- [ ] 1.6 Brace: `BraceData`, `damage_taken_mult`, perfect window, guns blocked, cooldown, and an arbiter provider. Files: `BraceData.gd` + `.tres`, `CombatModifiers.gd`, `ShipDamage.gd`, `ShipCombat.gd`, `WorldManager.gd`
  - **Verify:** `tests/test_m30_brace.gd`. Bracing → damage × (1 − reduction). Perfect → the larger reduction plus Fury. Firing while bracing → false. During cooldown → no brace.
  - _Requirements: W1-1.3_
- [ ] 1.7 Squads (`SquadSlotData`, `SquadTacticData`), the fallback, `_validate`, 6 authored squads, and heat-tier squad pools. Files: `EncounterData.gd`, `EncounterManager.gd`, `HeatTierData.gd`, `resources/combat/squads/*.tres`
  - **Verify:** `tests/test_m30_squads.gd`. A squad spawns mixed hulls with their profiles set before `_ready`. Hostile count ≤ 4. An empty squad uses the old fields. `test_lint_encounter_data.gd` passes.
  - _Requirements: W1-1.4, W1-1.5_
- [ ] 1.8 Aim-by-bearing `priority_mode` (player), plus a tap-to-mark `priority_target`. Files: `FiringSolver.gd`, `PlayerShip.tscn`, `WorldManager.gd`
  - **Verify:** `tests/test_m30_aim_by_bearing.gd`. Of two hulls in the arc, the one nearer the centre line wins for the player and the nearer one wins for the AI. A marked target wins while it's in the arc.
  - _Requirements: W1-1.6_
- [ ] 1.9 Spyglass Briefing (roster card, opening ammo per side, 3 Preparations, Watchtower intel gate). Files: `scripts/ui/SpyglassBriefing.gd`, `PreparationData.gd` + `.tres`, `EncounterManager.gd`
  - **Verify:** `tests/test_m30_spyglass.gd` (intel by Watchtower level, preparation effects applied), plus a **headful capture**.
  - _Requirements: W1-2.1_
- [ ] 1.10 Powder Kegs (scene, fuse, detonation, stock per sortie, arbiter provider, Raker pathing around kegs through the existing probe). Files: `PowderKeg.tscn/.gd`, `KegConfigData.gd` + `.tres`, `WorldManager.gd`
  - **Verify:** `tests/test_m30_powder_keg.gd`. Drop is only available with an enemy in the stern cone. Detonation damage is applied. Stock decrements and refills at port.
  - _Requirements: W1-2.2_
- [ ] 1.11 Feedback pack: rake cone, ribbons (at most 3), colour damage numbers, camera offset punch, haptics, reduced motion. Files: `RibbonStack.gd`, `CameraRig.gd`, `FloatingDamage.gd`, `HapticFeedbackManager.gd`, `WorldHUD.gd`
  - **Verify:** `tests/test_m30_feedback.gd`. Ribbon cap holds. The punch uses `h/v_offset` and never `time_scale`. Reduced motion → no punch. Plus a **headful capture**.
  - _Requirements: W1-2.3_
- [ ] 1.12 Fury (fills from `hit_resolved`, rakes, brace, kills; extra fill on the special timer). Files: `ShipCombat.gd`, `FuryData.gd` + `.tres`, `WorldHUD.gd`
  - **Verify:** `tests/test_m30_fury.gd`. Rakes fill more than plain hits. At 1.0 the special is ready early. `test_battle_upgrades.gd:206-218` passes unmodified.
  - _Requirements: W1-2.4_
- [ ] 1.13 Sortie Stars (`StarConditionData`, evaluation on resolve, best per encounter saved, cosmetic totals). Files: `EncounterData.gd`, `EncounterManager.gd`, `CampaignManager.gd`, the results popup
  - **Verify:** `tests/test_m30_stars.gd`. Each condition kind evaluates. Best stars persist (omitted when empty). No campaign gate reads stars.
  - _Requirements: W1-2.5_
- [ ] **Checkpoint W1:** full suite; headful capture (wind-up wedge, brace, squad, keg, ribbons, briefing); `checkpoint-reviewer`; docs/05; commit and push.

### Wave 2 — Boarding: Three Bells + Prize Fleet
- [ ] 2.1 `BoardingSystem` foundation: `_apply_outcome` extraction, `begin_boarding` routing (Quick, Overwhelm, tactical), target lock, `boarding_outcome` signal, `BoardingData` fields, settings toggle, seeded `LootTableData.roll(rng)`. Files: `BoardingSystem.gd`, `BoardingData.gd`, `LootTableData.gd`, `SettingsManager.gd`, `WorldManager.gd`
  - **Verify:** `tests/test_m30_boarding_routing.gd`. `boarding_resolved` fires once on every path. `tests/test_boarding.gd` and `tests/test_m29_boarding_loot_once.gd` pass unmodified.
  - _Requirements: W2.1_
- [ ] 2.2 `BoardingBattle` pure model (zones, defenders, intents, CP, bells, resolution order, end conditions) plus the data resources. Files: `scripts/combat/boarding/BoardingBattle.gd`, `DefenderData.gd`, `DefenderIntentData.gd`, `BoardingActionData.gd`, `BoardingObjectiveData.gd`
  - **Verify:** `tests/test_m30_boarding_battle.gd`
    - The same seed and actions → identical events.
    - Bell count = 2 + round(h × 5), capped at 4.
    - Each objective zone ends the battle with its outcome.
    - Morale ≤ 30 → strike.
    - Reaching the last bell → cut loose.
  - _Requirements: W2.2_
- [ ] 2.3 `BoardingDeckBuilder` (gunnery `hit_tags` removals, entry by bearing, faction × class profile, crew fraction) plus the `hit_tags` log. Files: `BoardingDeckBuilder.gd`, `BoardingDeckProfile.gd` + `.tres`, `BoardingSystem.gd`
  - **Verify:** `tests/test_m30_boarding_deck.gd`. Grape hits remove Deckhands, a stern-rake wounds the Officer, beam entry lands at the Waist, bow entry at the Forecastle.
  - _Requirements: W2.3_
- [ ] 2.4 Author the content: 5 defenders, 6 actions, 3 objectives, faction × class profiles. Files: `resources/combat/boarding/**`
  - **Verify:** `test_lint_resource_exports.gd`. A content test ensures every profile references valid defenders and actions.
  - _Requirements: W2.2, W2.3_
- [ ] 2.5 `BoardingOverlay` UI (tree paused, autosave and ads suspended, glyph-disc art seams), outside threats shown as intents, Brace and Point-Blank CP, preview strip on `EnemyHealthBarWidget`. Files: `BoardingOverlay.gd/.tscn`, `EnemyHealthBarWidget.gd`, `WorldHUD.gd`, `docs/10_ASSET_REQUESTS.md`
  - **Verify:** `tests/test_m30_boarding_overlay.gd` (pause flags, no upgrade offer while open), plus a **headful capture** of the overlay and the preview strip.
  - _Requirements: W2.2, W2.3, W2.4_
- [ ] 2.6 Morale component, Wavering, strike colours, Take Prize verb, Dread/Renown axis (saved, omitted at 0). Files: `MoraleComponent.gd`, `EnemyAI.gd` (FLEE trigger only), `EmpireManager.gd`, `WorldManager.gd`
  - **Verify:** `tests/test_m30_morale.gd`. Morale drains as designed. A struck ship stops firing. Take Prize opens Three Bells with Colours weakened. The axis round-trips.
  - _Requirements: W2.5_
- [ ] 2.7 Fleet uid identity plus a migration off index keys, with a save version bump. Files: `OwnedShipData.gd`, `FleetManager.gd`, `SaveManager.gd`
  - **Verify:** `tests/test_m30_fleet_uid_migration.gd`. An old save loads with uids; missions and captain pairing are preserved. `test_fleet_manager.gd:58` is rewritten deliberately (purchases stay idempotent, prizes may duplicate), with the justification in the commit.
  - _Requirements: W2.6_
- [ ] 2.8 Prize capture (captured `_on_died` branch, `add_prize`, condition, provenance trait, `ship_id` resolver), Prize Ledger (Keep, Ransom, Break), Send Home, transit save, recapture roll. Files: `ShipController.gd`, `FleetManager.gd`, `PrizeLedger.gd`, `FactionManager.gd` (`ransom_officers`)
  - **Verify:** `tests/test_m30_prize_fleet.gd`. Colours → a prize arrives at the next dock (or is recaptured, seeded). A boss → the destroyed path. Ransom changes gold and reputation. Transit round-trips.
  - _Requirements: W2.6_
- [ ] 2.9 Prize courts plus captives (pressed or loyal) plus campaign "capture" objective variants (append-only). Files: `PrizeCourtData.gd` + `.tres`, `ObjectiveData.gd`, `CampaignManager.gd`
  - **Verify:** `tests/test_m30_prize_court.gd`. A Navy court refuses merchant prizes, with a reputation cost. Pirate havens pay 0.7×. `test_campaign_golden_path.gd` passes.
  - _Requirements: W2.6_
- [ ] 2.10 Ship's Company: `OwnedSquadData`, ranks, wounds, traits, sea stations (`CrewStationApplier`, PERSISTENT layer, stacking cap), Tavern Green squads, elite only from boarding, Brig and Cabin objectives. Files: `OwnedSquadData.gd`, `CrewTraitData.gd`, `CrewRankTable.gd`, `CrewStationApplier.gd`, `FleetManager.gd`, `IslandMenu.gd` (Tavern)
  - **Verify:** `tests/test_m30_ships_company.gd`. Squads round-trip. An old save derives template squads from crew. Station bonuses apply, and are suspended while boarding. The stacking cap holds.
  - _Requirements: W2.7_
- [ ] 2.11 Captain Orders in `CaptainAbilityData` (Board First hero, No Quarter, +CP); Nemesis officers (`EnemyCaptainData`, wanted poster); Infirmary and Training Yard functions. Files: `CaptainAbilityData.gd`, captain ability `.tres`, `EnemyCaptainData.gd`, building `.tres`
  - **Verify:** `tests/test_m30_captain_orders.gd`. Cutlass enters as a hero. No Quarter disables surrender. An escaped officer reappears promoted.
  - _Requirements: W2.7_
- [ ] **Checkpoint W2:** full suite; headful capture (overlay, preview strip, Prize Ledger); `checkpoint-reviewer`; docs/05; commit and push.

### Wave 3 — The island fights back
- [ ] 3.1 `ShoreBattery` scene (StaticBody plus combat components, `fortification` group, faction, `ship_destroyed`), `FortificationData`, `min_cannon_range`, ammo resistance, grape suppress and re-man, round destroy plus saved rubble. Files: `ShoreBattery.tscn/.gd`, `FortificationData.gd`, `FiringSolver.gd`, `ShipStats.gd`, `ShipDamage.gd`, `PlayerShip.tscn` (`target_groups`)
  - **Verify:** `tests/test_m30_shore_battery.gd`. Grape → silent, then re-mans. Round → destroyed, and the rubble persists across a save. Not in `enemy_ship`. The player solver targets it.
  - _Requirements: W3.1_
- [ ] 3.2 Battery and landmark content (Culverin, Signal Tower, Powder Magazine, Flagstaff); Mortar Pit via the lofted-shot path, or deferred with a test. Files: `resources/fortifications/**`, `ShipCombat.gd` (additive pitch only, if lofted)
  - **Verify:** `tests/test_m30_landmarks.gd`. The Signal Tower spawns reinforcements until destroyed. The Magazine AoE hits batteries within radius. A lofted shot's direction is the basis-forward plus pitch.
  - _Requirements: W3.1_
- [ ] 3.3 Phased encounters (`EncounterPhaseData`, `Kind.ASSAULT`, the new objectives, phase-boundary offers, spawn-at-position, partial stars). Files: `EncounterPhaseData.gd`, `EncounterData.gd`, `EncounterManager.gd`
  - **Verify:** `tests/test_m30_phases.gd`. Phases advance. `encounter_ended` fires once, after the last phase. An encounter without phases behaves as before. The enum values are append-only.
  - _Requirements: W3.2_
- [ ] 3.4 `IslandDefenseData` replaces `_spawn_defenses` and the died-capture; assault context verb; landing through the boarding model; Blockade; re-arm on retake. Files: `IslandDefenseData.gd`, `Island.gd`, `IslandData.gd`, island `.tres`
  - **Verify:** `tests/test_m30_island_assault.gd`. Assault victory → captured. Friendly fire on a defender doesn't capture. Blockade drains the garrison. `test_campaign_golden_path.gd`: every CAPTURE_ISLAND in Ch1–5 is completable, and Ch2 is winnable with Sloop-class stats (simulated).
  - _Requirements: W3.3, W3.4_
- [ ] 3.5 Garrison scaling plus `FactionData.fortification_strength_mult`. Files: `FactionData.gd`, faction `.tres`, `Island.gd`
  - **Verify:** `tests/test_m30_garrison_scaling.gd`. Scales with region and heat. An island-tier change → no change.
  - _Requirements: W3.5_
- [ ] 3.6 Player forts as guns (`BuildingData.fortifications`, `FortSlots`, Watchtower range and mark, `ScheduleManager.can_finish`). Files: `BuildingData.gd`, Fortress/Watchtower `.tres`, `Island.gd`, `Island.tscn`, `ScheduleManager.gd`
  - **Verify:** `tests/test_m30_player_forts.gd`. Fortress L1/L3/L5 → 1/2/3 batteries. Eights can't finish a repair while a raid is pending. Plus a **headful capture** of an assault.
  - _Requirements: W3.6_
- [ ] **Checkpoint W3:** full suite; headful capture (batteries, arcs, landing ring); `checkpoint-reviewer`; docs; commit and push.

### Wave 4 — Every sortie is a bet
- [ ] 4.1 `CargoHold` (grant paths, bank on dock up to the cap, overflow kept, Maelstrom bypass, Eights bypass, save, wreck marker with 50%, banking split). Files: `CargoHold.gd`, `LootDrop.gd`, `BoardingSystem.gd`, `EncounterManager.gd`, `DockingSystem.gd`, `DeathScreen.gd`
  - **Verify:** `tests/test_m30_cargo_hold.gd`. Loot goes to the hold, not the bank. Docking banks it. Sinking loses the hold, and the wreck holds 50%. Maelstrom is unaffected. ACCUMULATE objectives count banked amounts.
  - _Requirements: W4.1_
- [ ] 4.2 Colors (False Colors and blowing them, Jolly Roger multiplier in `LootScalingData`, Tavern bribe). Files: `ColorsConfigData.gd` + `.tres`, `EmpireManager.gd`, `EnemyAI.gd` (`_may_engage_player`), `LootScalingData.gd`
  - **Verify:** `tests/test_m30_colors.gd`. False Colors: ×0.5 notoriety, no unprovoked engagement, blown at heat 3+ (seeded). The Roger multiplies loot by tier.
  - _Requirements: W4.2_
- [ ] 4.3 Pending raids (ETA, bearing, marker, notification, four answers, capped loss, truce, offline resolution, signature kept). Files: `RaidData.gd` + `.tres`, `EmpireManager.gd`, `RaidReportScreen.gd`, `WorldMapScreen.gd`, `LocalNotificationManager.gd`
  - **Verify:** `tests/test_m30_pending_raid.gd`. Pending raids round-trip. Intercept cancels the raid. Defend starts a DEFENSE encounter. An offline lapse resolves on load. Losses ≤ 10% of unprotected storage. `test_empire_manager.gd` passes.
  - _Requirements: W4.3_
- [ ] 4.4 Harbour Plan, Raid Log, Revenge. Files: `HarbourPlanData.gd`, `EmpireManager.gd`, `IslandMenu.gd`, `RaidReportScreen.gd`
  - **Verify:** `tests/test_m30_harbour_plan.gd`. Approach weighting is 1.0/0.4/0.0. The counter multiplier applies. The log has a line per approach. Revenge starts within 24h.
  - _Requirements: W4.4_
- [ ] 4.5 Per-island raid targeting plus the "Provokes:" preview. Files: `EmpireManager.gd`, `WorldMapScreen.gd`
  - **Verify:** `tests/test_m30_raid_targeting.gd` (weighting by contested, value and distance).
  - _Requirements: W4.5_
- [ ] 4.6 Capture aftermath (Sack, Garrison, Raze) plus retakes. Files: `CaptureOptionData.gd` + `.tres`, `Island.gd`, `IslandData.gd`, `EmpireManager.gd`
  - **Verify:** `tests/test_m30_aftermath.gd`. Sack → neutral, with gold. Garrison → batteries flip and upkeep ticks. Raze → contested ×3. A lost retake flips the island back. CAPTURE objectives still fire.
  - _Requirements: W4.6_
- [ ] **Checkpoint W4:** full suite, including the offline regression (absence never destroys buildings or takes Eights); headful capture of the raid banner; `checkpoint-reviewer`; commit and push.

### Wave 5 — Builds, not buffs
- [ ] 5.1 `ShipStatusEffects` (absorbs the speed penalty; Burn, Crippled; cap 3; particle cap). Files: `ShipStatusEffects.gd`, `StatusEffectData.gd`, `ShipDamage.gd`
  - **Verify:** `tests/test_m30_status_effects.gd`. The old chain-shot slow test passes. Burn ticks through `apply_impact`. Cap 3.
  - _Requirements: W5.1_
- [ ] 5.2 Ammo commitment (next load at next reload), HeatedShot, counter triangle and weakness tags. Files: `ShipCombat.gd`, `AmmoData.gd`, `HeatedShot.tres`, `ShipStats.gd`
  - **Verify:** `tests/test_m30_ammo_commitment.gd`. `test_manual_fire.gd:146` passes unmodified. A weakness hit is ×1.5.
  - _Requirements: W5.2_
- [ ] 5.3 Tagged upgrades (tags, triggers, keystones, cursed picks, faction pools) in `UpgradeRoller`; retag the 22; add about 12. Files: `BattleUpgradeData.gd`, `UpgradeSynergyData.gd`, `UpgradeRoller.gd`, `resources/combat/upgrades/*.tres`
  - **Verify:** `tests/test_m30_tagged_upgrades.gd`. Held tags double the offer weight. A keystone appears only once its requirements are met. Triggers fire on `hit_resolved`.
  - _Requirements: W5.3_
- [ ] 5.4 `BossPhaseController` on all boss scenes (including those spawned by EventManager); Intransigent and Cárdenas phases. Files: `BossPhaseController.gd`, `BossPhaseData.gd`, `scenes/world/*Boss.tscn`
  - **Verify:** `tests/test_m30_boss_phases.gd`. Thresholds trigger the profile swap and adds. Adds respect the hull cap. DEFEAT_BOSS still fires.
  - _Requirements: W5.4_
- [ ] 5.5 Legendary Ships (one per region, map marker, skull rating, first-kill Eights, rematch for cosmetics). Files: `resources/enemies/Legendary*.tres`, `EventManager.gd` or `EncounterData`, `WorldMapScreen.gd`
  - **Verify:** `tests/test_m30_legendary.gd`. The first kill grants Eights once, and that persists. A rematch grants cosmetics only.
  - _Requirements: W5.5_
- [ ] 5.6 Salvage-forged modules (salvage in the hold, Shipyard recipes, sidegrades with drawbacks). Files: `SalvageRecipeData.gd` + `.tres`, `IslandMenu.gd` (Shipyard)
  - **Verify:** `tests/test_m30_salvage.gd` (craft consumes salvage, drawbacks apply).
  - _Requirements: W5.6_
- [ ] 5.7 Maelstrom: Call the Wave, Chart nodes, Locker meta (firewalled). Files: `MaelstromRun.gd`, `MaelstromCurveData.gd`, `LockerData.gd`
  - **Verify:** `tests/test_m30_maelstrom_depth.gd`. Calling early pays a bounty and respects the cap. The Locker never changes campaign state (isolation test).
  - _Requirements: W5.7_
- [ ] **Checkpoint W5:** full suite; `checkpoint-reviewer`; commit and push.

### Wave 6 — The empire is a shape
- [ ] 6.1 Hull traits plus sail trim (speed vs reload; never turn) plus class-restricted encounters. Files: `HullTraitData.gd`, `SailTrimData.gd`, `ShipStats.gd`, ship `.tres`, `EncounterData.gd`
  - **Verify:** `tests/test_m30_hull_traits.gd`. Each trait applies. Sail trim changes reload, not `turn_rate`. The yaw-servo diff is empty.
  - _Requirements: W6.1_
- [ ] 6.2 Island slots (counted by type), affinities, exclusive fertilities, adjacency, charters, `ModifierSetData` aggregator, fractional accumulator, grandfathering. Files: `IslandData.gd`, `Island.gd`, `CharterData.gd`, `ModifierSetData.gd`, `TechManager.gd`, `IslandMenu.gd`
  - **Verify:** `tests/test_m30_island_slots.gd`. The duplicate `farm_l1` loophole is closed. Old saves are grandfathered. Golden path: Ch1–5's required buildings fit.
  - _Requirements: W6.2_
- [ ] 6.3 Either/or tech pairs, verb-granting techs, L5 building forks. Files: `TechData.gd`, `TechManager.gd`, `resources/techs/*.tres`, building `.tres`
  - **Verify:** `tests/test_m30_tech_pairs.gd` (an exclusive pair locks out the other, and unlocking a verb enables it).
  - _Requirements: W6.3_
- [ ] 6.4 Points-of-sail curve (floor about 0.6) plus an AI tack helper. Files: `WindConfigData.gd` + `.tres`, `ShipMovement.gd` (88–92 only), `EnemyAI.gd` (`ideal_position` helper)
  - **Verify:** `tests/test_m30_points_of_sail.gd` (curve values, floor, the AI reaches an upwind target). The diff outside lines 88–92 is empty.
  - _Requirements: W6.4_
- [ ] 6.5 Patrol lowers raid odds; rising colonize cost. Files: `FleetManager.gd`, `EmpireManager.gd`, `IslandData.gd`
  - **Verify:** `tests/test_m30_missions_balance.gd`.
  - _Requirements: W6.5_
- [ ] **Checkpoint W6:** full suite; `checkpoint-reviewer`; commit and push.

### Wave 7 — Ascension
- [ ] 7.1 Empire Ages plus landmark picks plus the Crown's Answer window. Files: `AgeData.gd`, `LandmarkData.gd`, `EmpireManager.gd`, `ScheduleManager.gd` (kind plus speed source)
  - **Verify:** `tests/test_m30_ages.gd`. An age gates above `required_island_tier`. Landmarks are exclusive. Ages save and round-trip.
  - _Requirements: W7.1_
- [ ] 7.2 Relics (in the hold, buoy on sinking, Reliquary perks) plus the Pirate Republic wonder (5 stages; Eights can't skip). Files: `RelicData.gd`, `WonderStageData.gd`, `CargoHold.gd`, `Island.gd`, `ScheduleManager.gd`
  - **Verify:** `tests/test_m30_relics_wonder.gd`. A relic is never destroyed. `finish_now` is refused for wonder jobs.
  - _Requirements: W7.2, W7.3_
- [ ] 7.3 Letters of Marque. Files: `LetterOfMarqueData.gd`, `FactionManager.gd`
  - **Verify:** `tests/test_m30_marque.gd`.
  - _Requirements: W7.4_
- [ ] 7.4 Free Port patronage. Files: `FreePortData.gd`, `IslandData.gd`, `IslandMenu.gd`
  - **Verify:** `tests/test_m30_free_ports.gd` (favour never decays, tiers unlock).
  - _Requirements: W7.5_
- [ ] **Checkpoint W7 (milestone close)**
  - Full suite.
  - `checkpoint-reviewer` against the whole spec.
  - `sync-systems-doc`.
  - Update `docs/04_GAME_LOOP.md`, `docs/CONTENT_AUTHORING_GUIDE.md` and `docs/15_MASTER_PLAN.md`.
  - Memory update.
  - Commit and push.

## Notes

- **Risky areas:**
  - 2.7 (fleet uid migration: a save version bump).
  - 0.4/0.7–0.9 (save and sync paths: test with stubbed transport only; never hit the live
    project from tests).
  - 3.4 (removes the capture path the campaign relies on: the golden-path test is mandatory).
  - 1.4 (wind-up changes enemy DPS: retune with care).
- **Outward-facing action:** 0.12's migrations must not be applied to the live Supabase project
  until the owner approves.
- **Headful captures write the real `user://`.** Back it up and restore it.
- **Parallelism:** within Wave 0, 0-A/0-B/0-C are independent of 0-D. Tasks within a wave that
  share files run in sequence.
- **Out of M30:** M31 tunes every `# placeholder` number (stub at
  `.kiro/specs/milestone-m31-balance-math-sheet/`). The multiplayer track has its design input at
  `.kiro/specs/track-multiplayer/`.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["0.1","0.2","0.3","0.4","0.5","0.6","0.7","0.8","0.9","0.10","0.11","0.12","0.13","0.14","0.15","0.16","0.17","0.18","0.19","0.20","0.21","Checkpoint W0"] },
    { "id": 1, "tasks": ["1.1","1.2","1.3","1.4","1.5","1.6","1.7","1.8","1.9","1.10","1.11","1.12","1.13","Checkpoint W1"] },
    { "id": 2, "tasks": ["2.1","2.2","2.3","2.4","2.5","2.6","2.7","2.8","2.9","2.10","2.11","Checkpoint W2"] },
    { "id": 3, "tasks": ["3.1","3.2","3.3","3.4","3.5","3.6","Checkpoint W3"] },
    { "id": 4, "tasks": ["4.1","4.2","4.3","4.4","4.5","4.6","Checkpoint W4"] },
    { "id": 5, "tasks": ["5.1","5.2","5.3","5.4","5.5","5.6","5.7","Checkpoint W5"] },
    { "id": 6, "tasks": ["6.1","6.2","6.3","6.4","6.5","Checkpoint W6"] },
    { "id": 7, "tasks": ["7.1","7.2","7.3","7.4","Checkpoint W7"] }
  ]
}
```
