# Design Document: Milestone M30 — Battle & Empire Depth

## 1. Why this design shape

**Extend, don't duplicate** (AGENTS.md). Every M30 mechanic hangs off a system that already
exists:

| Concern | Existing system |
|---|---|
| Targeting | `FiringSolver` |
| Battle boundary and phases | `EncounterManager` |
| In-battle modifiers | `CombatModifiers` |
| Boarding and landing math | `BoardingSystem` |
| Damage events | `ShipDamage` |
| Persistence | the managers' `get_save_data`/`load_save_data` |
| Empire timers | `ScheduleManager`. It never gates combat, so raid and assault clocks live in `EmpireManager`/`EncounterManager`. |
| Upgrade rolling | the shared roller extracted in W0 |

All numbers go into `Resource` files.

**Wave order:** foundations (W0) → readable combat (W1) → boarding (W2, which island landings and
prizes reuse) → islands (W3) → stakes (W4) → builds (W5) → empire shape (W6) → ascension (W7).

**Fragile areas.** These are never edited:
- `BuoyancySimulator` and the `ShipMovement` buoyancy/stability/yaw-servo code
- the `ShipCollisionHandler` AABB
- cannon forward from `parent.global_transform.basis` (bow is −Z, broadsides fire ±X)
- `EnemyAI._get_avoidance_turn`/`_probe`/`_push_to_open_water`
- `tests/test_ship_combat.gd`

**The only `ShipMovement` edit allowed is lines 88–92**: the speed-target wind term, in W0/W6.

## 2. New and changed files (by wave)

| Wave | New | Changed |
|---|---|---|
| W0 | `scripts/core/SaveIntegrity.gd` (helpers), `scripts/combat/UpgradeRoller.gd`, `scripts/world/WindConfigData.gd`, `scripts/world/DefeatPenaltyData.gd`, `supabase/migrations/0001…0006_*.sql`, `resources/balance/WindConfig.tres`, `DefeatPenalty.tres` | `SaveManager.gd`, `AuthManager.gd`, `EntitlementManager.gd`, `StoreManager.gd`, `Island.gd`, `FleetManager.gd`, `CaptainData.gd`, `CampaignManager.gd`, `PauseMenu.gd`, `EmpireManager.gd`, `ShipCombat.gd` (velocity line), `EnemyAI.gd`, `EncounterManager.gd`, `MaelstromRun.gd`, `CombatModifiers.gd`, `ShipDamage.gd`, `Cannonball.gd`, `RegionData.gd`, `EnemySpawner.gd`, `MobileControls.gd`, `WorldManager.gd`, `DeathScreen.gd`, `ShipMovement.gd` (88–92 only), `supabase/functions/delete-account/index.ts`, `docs/SUPABASE_SETUP.md` |
| W1 | `SquadSlotData.gd`, `SquadTacticData.gd`, `BraceData.gd`, `FuryData.gd`, `StarConditionData.gd`, `PreparationData.gd`, `scenes/combat/PowderKeg.tscn` + `.gd`, `scripts/ui/SpyglassBriefing.gd`, `scripts/ui/ThreatDecals.gd`, `scripts/ui/RibbonStack.gd` | `AIProfileData.gd`, `AIDifficultyData.gd`, `EnemyAI.gd` (`_process_attack` `ideal_position` only), `ShipCombat.gd`, `ShipDamage.gd`, `FiringSolver.gd`, `EncounterData.gd`, `EncounterManager.gd`, `HeatTierData.gd`, `CameraRig.gd`, `FloatingDamage.gd`, `HapticFeedbackManager.gd`, `WorldHUD.gd` |
| W2 | `scripts/combat/boarding/BoardingBattle.gd`, `BoardingDeckBuilder.gd`, `DefenderData.gd`, `DefenderIntentData.gd`, `BoardingActionData.gd`, `BoardingDeckProfile.gd`, `BoardingObjectiveData.gd`, `MoraleComponent.gd`, `scripts/ui/BoardingOverlay.gd/.tscn`, `scripts/ui/PrizeLedger.gd`, `OwnedSquadData.gd`, `CrewTraitData.gd`, `CrewRankTable.gd`, `CrewStationApplier.gd`, `PrizeCourtData.gd`, `EnemyCaptainData.gd` | `BoardingSystem.gd`, `BoardingData.gd`, `FleetManager.gd`, `OwnedShipData.gd`, `ShipController.gd` (`_on_died` captured branch), `FactionManager.gd`, `EnemyHealthBarWidget.gd`, `CaptainAbilityData.gd`, `SettingsManager.gd`, `CampaignManager.gd`/`ObjectiveData.gd` (append) |
| W3 | `scenes/world/ShoreBattery.tscn` + `ShoreBattery.gd`, `FortificationData.gd`, `IslandDefenseData.gd`, `EncounterPhaseData.gd` | `Island.gd`, `Island.tscn` (`FortSlots`), `IslandData.gd`, `EncounterData.gd`, `EncounterManager.gd`, `FiringSolver.gd` (min range, `fortification` group), `ShipStats.gd`, `ShipDamage.gd` (ammo resistance), `BuildingData.gd`, `ScheduleManager.gd` (`can_finish` hook), `FactionData.gd` |
| W4 | `scripts/world/CargoHold.gd`, `ColorsConfigData.gd`, `RaidData.gd`, `HarbourPlanData.gd`, `CaptureOptionData.gd` | `LootDrop.gd`, `BoardingSystem.gd`, `EncounterManager.gd` (grant paths), `DockingSystem.gd`, `DeathScreen.gd`, `EmpireManager.gd`, `EnemyAI.gd` (`_may_engage_player`), `LootScalingData.gd`, `RaidReportScreen.gd`, `WorldMapScreen.gd`, `LocalNotificationManager.gd` |
| W5 | `ShipStatusEffects.gd`, `StatusEffectData.gd`, `UpgradeSynergyData.gd`, `BossPhaseController.gd`, `BossPhaseData.gd`, `SalvageRecipeData.gd` | `AmmoData.gd`, `ShipCombat.gd`, `BattleUpgradeData.gd`, `UpgradeRoller.gd`, `MaelstromRun.gd`, boss scenes, `EventManager.gd` |
| W6 | `HullTraitData.gd`, `SailTrimData.gd`, `CharterData.gd`, `ModifierSetData.gd` | `ShipStats.gd`, `IslandData.gd`, `Island.gd`, `TechData.gd`, `TechManager.gd`, `IslandMenu.gd`, `FleetManager.gd`, `ShipMovement.gd` (88–92 only) |
| W7 | `AgeData.gd`, `LandmarkData.gd`, `RelicData.gd`, `WonderStageData.gd`, `LetterOfMarqueData.gd`, `FreePortData.gd` | `EmpireManager.gd`, `FactionManager.gd`, `Island.gd`, `CargoHold.gd`, `ScheduleManager.gd` (new kinds plus a speed source) |

## 3. W0 — Save integrity and cloud sync

### 3.1 Island ownership (W0-1.1/1.2)

The `SaveManager.save_game()` islands entry gains two fields:

```gdscript
save_dict["islands"][id] = {
    "buildings": island.get_built_building_ids(),
    "discovered": ...,
    "island_type": island.island_data.island_type,                  # int enum
    "owner_faction_id": owner.faction_id if owner else "",
}
```

**On load,** restore these *before* `restore_buildings()` and before the offline catch-up loop
(`:540-543`).
- Resolve `owner_faction_id` through `EmpireManager._get_faction_by_id`. If it doesn't resolve:
  `push_error`, and keep the authored value.
- **Migration** for an entry with no `island_type` key: if `buildings` is non-empty, or
  `id == EmpireManager.home_island_id`, set FRIENDLY with the player faction.

**Carry-forward (W0-1.7):** start from the previously loaded islands dictionary, then overwrite the
entries for live nodes, so that content-gated islands keep their entries.

### 3.2 Captain progression (W0-1.3)

- `FleetManager.get_save_data()` stores `{path, level, current_xp}` per captain.
- `load_save_data` loads the `.tres`, calls `duplicate()` and applies level/XP. Old saves (a bare
  path string) load as level 1.
- Every `add_xp` call site already goes through the owned captain instance after the duplicate.
  **Hazard:** `CampaignManager`/`EncounterManager` must reference the owned instance, never
  `load()`.

### 3.3 Save on exit (W0-1.4)

`SaveManager._notification(what)` saves on `NOTIFICATION_APPLICATION_PAUSED` and
`NOTIFICATION_WM_CLOSE_REQUEST`, but only when `SceneManager.is_campaign()` and the World is
loaded. That's the M26 rule: never call `save_game()` outside World. `PauseMenu` Quit and Settings
call `SaveManager.save_game()` before changing scene.

### 3.4 Cloud conflict and sync (W0-1.5/1.6, W0-2)

- **`_apply_cloud_save`:** after writing the file, `SceneManager.reload_world()`. Set
  `_suspend_autosave = true` while the conflict dialog is open.
- **Keep This Device:** `economy.eights = max(local, cloud)` before pushing.
- **`AuthManager.refresh_session()`:** clear the session only when `code in [400, 401]` and the
  body's `error` is `invalid_grant` or `refresh_token_not_found`. Otherwise return false and set
  `session_degraded`.
  - Store `expires_at`, and refresh 60s before it.
  - Keep a single in-flight refresh (`_refreshing: Signal`).
  - `_clear_session()` emits `signed_out`.
- **`_fetch_cloud_save()`** returns `{status: "ok"|"none"|"error", row}`.
  - `_cloud_baseline_known[user_id]` gates every upload.
  - In-World with status `ok` and no local save: apply the save silently and reload the world.
- **Upload queue:**
  - `_upload_in_flight` plus `_dirty_snapshot`.
  - `http.timeout = 15`.
  - Backoff `[30, 120, 600]` seconds.
  - `user://cloud_pending.json`.
  - Skip when the hash (a SHA-1 of the JSON) equals the last uploaded hash.
- **`_load_blocked`:** set on any `load_failed`, or on a cloud row with
  `save_schema_version > SAVE_SCHEMA_VERSION`. While it's set, `save_game()` and
  `_sync_to_cloud` return early, and the HUD shows "Save protected: update the game".
- **`owner_user_id`** is stamped in `save_dict`. On sign-in, if it differs from the signed-in user
  and is non-empty, show a ChoiceDialog (parented to the root) before any upload.
- **`save_revision`:** increments on every save. The upload sends `expected_revision`. **Hazard:**
  the server-side compare needs migration 0005 applied, so until then the client does a
  best-effort check.
- **Sync status:** `SaveManager.sync_status_changed(state, since_unix)` drives a WorldHUD/Account
  line.

### 3.5 Store and entitlement safety (W0-3)

- `StoreManager._create_backend()`: use the stub only if `OS.is_debug_build()`. Otherwise use a
  `StoreBackendUnavailable` that returns "Unavailable" and never grants.
- **Migrations** are authored as idempotent SQL files, following
  `wf_4b855b7f-477`/schema-security §4. The delete-account function deletes `player_entitlements`
  as well, or relies on the cascade.
  - **Applying them to the live project is an outward action: ask the owner first.**

## 4. W0 — Combat foundations

- **Range velocity (B2).** In `ShipCombat._spawn_cannonball`, multiply the *speed scalar* by
  `range_mult` from `CombatModifiers`/`AmmoData`. The direction vector stays the basis-derived
  one. Test: with a ×1.2 range, a shot lands at ≥ 0.95 × the solver range.
- **Friendly AI (B4/B5).**
  - `EnemyAI._find_wounded_ally()` scans `"friendly_ship"` when `self.is_in_group("friendly_ship")`.
  - `_find_nearest_hostile_enemy()` skips targets whose AI isn't provoked or engaging, using the
    same predicate as `_may_engage_player`.
- **Shared roller (B8).** A static `UpgradeRoller.roll(pool, count, held: Dictionary, filters)`.
  Both `EncounterManager.roll_upgrade_choices` and `MaelstromRun.pick_choices` call it. W5 adds
  tag weighting here only.
- **Encounter exclusivity (B6).** `start_encounter` returns false (plus `encounter_failed`) while
  one is active. Ambient ships within `data.radius` of the centre are parked (AI IDLE, invisible
  to spawning) and restored on `_resolve`.
- **Modifier lifetimes (B7).** `CombatModifiers` layers become `{key: {fx, lifetime}}`, with
  `lifetime ∈ {ENCOUNTER, TIMED, PERSISTENT}`. `reset()` clears only ENCOUNTER layers. Brace,
  Fury, stations and statuses declare their own lifetime.
- **`apply_profile()` (B17).** Factor the `_ready()` profile block into
  `apply_profile(p: AIProfileData)`. `_ready` calls it.
- **`hit_resolved`.** Emitted at the end of `apply_hit` and `apply_impact`:
  - `source: Node` (an optional parameter added to `apply_hit`; Cannonball passes its shooter)
  - `facing: StringName` (`&"stern" | &"bow" | &"beam"`)
  - `pool_deltas: Dictionary`
  - `ammo_id: StringName`
  - `hit_tags: PackedStringArray` (used by W2)

  `FloatingDamage` and the crew writes route through this signal and `pool_changed`.
- **Profile pool.** `RegionData.enemy_profile_pool: Array[AIProfileData]` +
  `enemy_profile_weights: PackedFloat32Array`. `EnemySpawner` assigns before `add_child`, the same
  way `_spawn_allies` does.
- **Context arbiter.** `WorldManager.get_context_verb() -> StringName` is evaluated in priority
  order from registered providers (`register_context_provider(verb, priority, callable)`).
  `MobileControls` shows the icon and label. The `dock` action dispatches to the winner. The
  existing board-else-dock logic (`:86-92`) becomes two providers.

## 5. W1 — Readable combat

- **Tactics.**
  - In `_process_attack`, the perpendicular offset is rotated by
    `smoothed_bearing = lerp_angle(prev, profile.preferred_bearing_deg, 1 - exp(-dt / 0.8))`,
    relative to the target's heading. It is low-pass filtered because of the "circling-of-death"
    note at `:353-359`.
  - LONG_GUNNER adds a kite: while `dist < kite_min_distance`, the ideal position is pushed
    outward.
  - FIRESHIP: `ideal_position = target`. On contact it applies area damage (reusing the
    `MaelstromRun._detonate_keg` damage function, extracted into a static) and frees itself.
  - **The avoidance turn is still applied last, unchanged.**
  - *Accepted deviation (W1 review):* besides `ideal_position`, a tactic profile also sets
    `AIProfileData.attack_throttle` (the ATTACK-state throttle, legacy 0.5 by default): a Long
    Gunner idles at 0.4 to hold range, a fireship closes at 1.0. Steering and avoidance code are
    unchanged. A FIRESHIP also excludes its own target from hull (not terrain) avoidance while
    engaged, the same exclusion a ram run already had, or it could never reach contact.
  - *Accepted deviation (W1 review): station-keeping.* W1-1.1 says "only `ideal_position`
    changes", but `_steer_towards` has no arrival slow-down, so a hull aimed at a point one turning
    circle off the target orbits it and never settles (a Raker under physics was still abeam at
    t=20 s). `EnemyAI._try_station_keep()` therefore runs for every non-STANDARD tactic once the
    hull is within `AIProfileData.station_radius` of its ideal point (not for a Long Gunner inside
    its kite line). It aims `station_lookahead_seconds` of the target's forward speed ahead of the
    point along the target's heading, and sets the throttle to the target's own forward speed plus
    `station_speed_gain` × the distance to that aim point along the hull's bow, so the hull slows
    onto the point instead of overshooting. Both the aim point and the throttle change, not just
    `ideal_position`. Steering, the sharp-turn throttle cut and the avoidance override are still
    `_steer_towards`'s, unchanged. `station_radius <= 0` turns it off. The `station_*` fields are
    placeholders, to be tuned in M31.
- **Wind-up.** In `ShipCombat._physics_process`, the auto-fire branch becomes:
  - on arc lock with the reload ready, emit `broadside_windup` and start `_windup_t`;
  - fire when it elapses, if the target is still in the arc;
  - **`fire_broadside()` is untouched**, because `test_ship_combat.gd:97` needs a synchronous
    `true`.

  The duration comes from `AIDifficultyData.for_ship(parent)` (null for player and friendly hulls,
  meaning 0).
- **Brace.**
  - Adds `CombatModifiers.damage_taken_mult` on the TIMED layer, and `ShipCombat.is_bracing`
    blocks firing.
  - `ShipDamage.apply_hit`/`apply_impact` multiply incoming damage by
    `modifiers.get_damage_taken_mult()`.
  - Perfect window: the Brace press lands within `perfect_window` of a wind-up's end.
  - *Accepted deviation (W1 review):* the reduction lives on a **PERSISTENT** `CombatModifiers`
    layer (`ShipCombat.BRACE_LAYER`, set by `apply_brace()` and cleared when the window closes),
    not the TIMED layer. `ShipCombat` already runs the window's clock, because it gates the guns
    and starts the cooldown. A TIMED entry can't be cancelled early, and can't be told apart from
    captain-ability bursts. Brace is also offered on the context button only while a hostile
    wind-up is aimed at the player.
- **Squads.**
  - `_spawn_composition`: if `data.squad` is non-empty, loop over the slots and set
    `ai.ai_profile` before `add_child`.
  - `SquadTacticData` assigns each slot a `preferred_bearing_deg` override.
  - `_validate` accepts a squad when `enemy_scene` is empty.
- **Fury.**
  - `ShipCombat` adds `fury: float`, filled from `hit_resolved` (outgoing), the brace signal and
    kills.
  - At 1.0 the special is ready, even if its timer hasn't finished. The timer path still works,
    so the semantics of `test_battle_upgrades.gd:206-218` hold.
- **Stars.** `EncounterData.star_conditions: Array[StarConditionData]`.
  - `EncounterManager` evaluates them on `_resolve`.
  - Best stars per encounter id live in `CampaignManager` save data, omitted when empty.

## 6. W2 — Three Bells + Prize Fleet

### 6.1 Flow

```
context verb "Board" → BoardingSystem.begin_boarding()
 ├─ Quick setting / strength ≥ overwhelm_ratio×enemy → attempt_boarding() (unchanged) + toast
 └─ else lock _locked_enemy; deck = BoardingDeckBuilder.build(enemy, hit_tags_log, bearing, crew)
        BoardingOverlay opens (tree paused; SaveManager._suspend_autosave; AdManager suspended)
        BoardingBattle(seed, deck, squads, bells=2+round(hull_frac*5) clamp 4)
        loop: player spends 3 CP → ring_bell() → events → UI
        end: objective seized | strike (morale≤30) | last bell → cut loose
        → BoardingSystem._apply_outcome(outcome) → boarding_resolved (once) + boarding_outcome(id, details)
        → Colours: PrizeLedger(Keep/Ransom/Break)
```

### 6.2 The model

`BoardingBattle` is a pure RefCounted model with no Node dependencies, seeded through
`RandomNumberGenerator`.
- **Zones:** FORECASTLE, WAIST, QUARTERDECK, plus HOLD below. Each zone has slots.
- **Defenders:** `DefenderData` has `hp`, `attack`, an `intents: Array[DefenderIntentData]`
  rotation, `morale_value` and `removed_by_tags`.
- **Actions:** `BoardingActionData` has `cp_cost`, `target_rule`, `damage`, `push`,
  `cancels_intent`, `required_role` and `icon`.
- **Resolution order per bell:**
  1. Player actions, in the order queued.
  2. Defender intents, in index order.
  3. Outside-threat intents.
  4. Timed events (jettison at bell 2, officers escape at the last bell).
  5. Morale check.
- **No dice.** Flat numbers only.

### 6.3 Deck building

`BoardingDeckBuilder` takes:
- the `BoardingDeckProfile` for faction × class
- removals from the target's recent `hit_tags` (logged by `BoardingSystem` from the target's
  `hit_resolved`)
- the entry zone from the relative bearing at the tap

### 6.4 Prize Fleet

- `OwnedShipData.uid: String`, generated on add or migration. `active_missions` and captain
  pairing re-key by uid. **Save version bump.**
- `test_fleet_manager.gd:58` (one hull per class) is **rewritten deliberately**: `add_ship()`
  stays idempotent for purchases, and `add_prize()` allows duplicates.
- `ShipController._on_died(captured := false)`: the captured branch skips the explosion, the loot
  drop and notoriety. Bosses keep the destroyed path.
- **Stats.** A prize's hull stats are resolved through `ShipStats` by `ship_id` →
  `res://resources/ships/<id>.tres`, using `push_error` on a miss. Enemy-only and boss hulls are
  never offered.

### 6.5 Ship's Company

- `OwnedSquadData` holds `{uid, role, rank, xp, wounds, trait}` per squad, saved under
  `FleetManager`.
- `ShipDamage.crew` stays the sum, so old saves derive template squads.
- `CrewStationApplier` reapplies stations as a PERSISTENT CombatModifiers layer, with a stacking
  cap.

## 7. W3 — Island battles

- **`ShoreBattery`.**
  - Root `StaticBody3D` on layers 16 and 17, positioned outside r≈39 or above y≈4.5.
  - `var faction`, signal `ship_destroyed`, and the `fortification` group (**not**
    `enemy_ship`).
  - Children: `ShipDamage`, `ShipCombat`, `FiringSolver`, `CombatModifiers`. Seaward markers only.
  - Grape → crew 0 → silent. Re-man with `repair("crew")` from the island garrison pool after
    `remann_seconds`.
- **Ammo resistance.** `ShipStats.ammo_resistance: Dictionary` (e.g. `{&"round": 0.5}`) is read in
  `apply_hit`.
- **Phases.**
  - `EncounterData.phases: Array[EncounterPhaseData]`.
  - `_tick_active`: on a phase's objective met → `_phase_index += 1`, spawn that phase's group, and
    offer an upgrade if `offers_on_phase_end`.
  - The last phase → `_resolve(VICTORY)`.
  - Existing encounters with no phases behave as one phase.
- **`Island`.**
  - `_spawn_defenses()` becomes `arm_defenses(IslandDefenseData)`.
  - Capture listens to the assault's `encounter_ended(victory)`.
  - `_defenders_spawned` re-arms on retake.
  - Colonize stays separate (`IslandMenu.gd:260-280`).
- **Lofted shot (Mortar Pit).** Add an extra elevation pitch *after* the basis-derived forward, as
  `Basis(right_axis, pitch) * forward`, so the basis rule holds. If this proves risky, the Mortar
  Pit is deferred, and a test asserts it is absent.

## 8. W4 — Stakes

- **`CargoHold`** is a component on PlayerShip. The three grant paths call `hold.add(dict)`
  instead of `ResourceManager.add_resource`:
  - `LootDrop._collect`
  - `BoardingSystem._apply_outcome`
  - `EncounterManager._grant_rewards`

  Exceptions:
  - In Maelstrom mode the hold is bypassed (isolation).
  - Eights always bypass the hold.

  `DockingSystem` banks up to the storage cap. `DeathScreen` uses `DefeatPenaltyData`. On sinking,
  a wreck marker holds 50% of the unbanked hold.
- **Pending raid.**
  - `EmpireManager.pending_raid = {faction_id, target_island_id, composition_id, eta_unix,
    bearing}`, saved and omitted when null.
  - `_check_raid` creates it.
  - At ETA, if the player is inside the harbour radius, a DEFENSE encounter starts. Otherwise
    `_resolve_raid(faction, region)` runs with the original signature, made level-aware and capped.
  - An ETA that lapsed while offline resolves on load.
- **Harbour Plan.**
  - `HarbourPlanData` maps a socket to `{approach, battery_type}`.
  - Offline resolution: socket strength × approach weight (facing 1.0, adjacent 0.4, opposite 0.0)
    × the role counter multiplier.

## 9. W5 / W6 / W7 — Highlights

- **`ShipStatusEffects`** replaces `ShipDamage._speed_penalty` with a list, applied through
  `apply_impact`. Cap 3, and at most 1 particle emitter per status per hull.
- **Ammo** applies at the next reload (`next_ammo` per side), so `test_manual_fire.gd:146` holds.
- **`ModifierSetData`** keys use empire scope only: `production_mult`, `raid_defense`, `heat_gain`,
  `hold_capacity`, `loot_mult`, … They are aggregated once in `TechManager.get_mod(key)` and never
  overlap CombatModifiers.
- **Build slots** count `base_id` types: `has_building_type`, not `has_building`.
- **Ages and wonder** are `ScheduleManager` jobs with new kinds plus a speed source (Academy or
  Shipyard level), as AGENTS.md requires.

## 10. Known hazards (checked in code)

1. **`boarding_resolved` has 4 listeners** (CampaignManager:188, FactionManager:66,
   SeasonalEventManager:118, WorldHUD:572). It must fire exactly once.
2. **Tree pause.** `UpgradeChoiceScreen` pauses the tree, and so will the boarding overlay. The
   encounter offer timer must not fire while paused.
3. **`EnemyAI` reads `ai_profile` only in `_ready`** until W0 `apply_profile` lands.
4. **Three bosses spawn outside `EncounterManager`** (EventManager:261-330). Boss phases must live
   on the boss node.
5. **Ambient hulls stay alive during an encounter** until W0's parking lands. Check the ship
   budget at every wave.
6. **`ScheduleManager` `KINDS` is a whitelist**, every kind needs a speed source, and `finish_now`
   is generic, so add a `can_finish(job)` hook.
7. **Tests that pin old rules** may only be rewritten deliberately, with the justification in the
   commit:
   - `test_manual_fire:146`
   - `test_battle_upgrades:206-218`
   - `test_fleet_manager:58`
   - `test_empire_manager:96-160` (keep the signature)
8. **Headful captures write the real `user://`** (M26 memory). Back it up and restore it around
   capture runs.
