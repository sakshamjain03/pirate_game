# Requirements Document

## Introduction

M24-M28 delivered the playable slice. On 2026-10-03 the project owner asked for the game to become
an engaging, bug-free Android hit, and approved a roadmap (M29-M35) that starts here. **M29 fixes
what is broken or unwired before anything new is built on top of it.**

It is based on an 8-domain audit: 17 agents, with every finding re-checked by a skeptic. Then:
- 6 lane drafters checked each finding against the code again.
- 6 critics reviewed the drafts.
- I spot-checked the results by hand.

Only findings that reproduced made it into this document.

**The audit had false positives. Keep them out of scope:**
- **E1-E4, E11, MISSED_6:** "building `.tres` files gutted, Ch1 impossible". Godot leaves out
  `@export` fields whose value equals the script default. `LumberMill_L1.tres` really does produce 5
  wood for 50 gold, through the `BuildingData.gd` defaults.
- **E9:** Farm's display name "Rum Distillery" is correct. It produces rum.
- **MISSED-2:** `EnemyAI._get_avoidance_turn()` exists. V8 beaching is a residual edge case.
- **PERSISTENCE-005:** settings live in `user://settings.cfg` on purpose. They are device-level,
  and they are not save state.
- **F019 / OwnedShipData preload:** speculative, and not reproduced.

**Rule: reproduce first.** Every requirement below starts as a failing test or a concrete repro. If
it won't reproduce during implementation, close it as stale with a one-line note in `tasks.md`, and
don't fix it blind.

**Confirmed real (spot-checked by hand):**
- **No reputation consequence for violence.** `FactionManager.add_reputation()` is only called by
  tribute and by `FleetManager` trade routes.
- **Nothing happens after Chapter 5.** `_advance_to_next_chapter()` returns early.
- **Ten `EventManager.trigger_event()` sources reach the player through nothing:** merchant
  convoy, ghost ship, the Iron Vulture, smugglers' cache, and the rest. `world_event_triggered`
  has no connection.
- **A boarded ship's loot is granted twice:** `BoardingSystem.gd:131-133`, then
  `mark_destroyed()` → `ShipController._spawn_loot()`.
- **Measured 18-27 FPS on a device** (`docs/05` §M13 Req 3).

**Already met, no work needed:**
- The 1046-test suite.
- Economy ticks, building chains and offline catch-up.
- Ch1-5 objective tracking off existing signals.
- `PortraitFallback` (falls back cleanly when a `portrait_path` file is missing).
- `OceanController` quality sync from `SettingsManager.graphics_quality`.
- The New Game reset snapshot in `SaveManager._NEW_GAME_RESET_MANAGERS`.

## Glossary

- **Lane:** a file-ownership group that can be implemented in parallel with the other lanes. Lanes
  are A-F. Shared files take additive edits only (see `tasks.md` Notes).
- **Free roam:** the state after the Ch5 epilogue. `CampaignManager.campaign_completed == true`,
  there is no current chapter, and the empire, economy, events and Maelstrom keep running. It is
  not a "game over".
- **Owner display:** the `{faction_id, name, color}` dictionary that
  `FactionManager.get_island_owner_display(island_data)` returns. The HUD uses it to say who holds
  an island.
- **Lint test:** a permanent GUT test that scans project files rather than exercising gameplay.
  Each one closes a whole class of silent-failure bug.

## Requirements

### Requirement A1: Boarding grants loot exactly once (C-003)

**User Story:** As a player, I want a boarding to pay out once, so the economy isn't inflated by a
double grant.

#### Acceptance Criteria
1. WHEN a boarding succeeds, THE game SHALL grant the boarding loot once and SHALL NOT also spawn
   the sink-loot crate for that ship.
2. WHEN a ship is sunk by gunfire, THE game SHALL spawn its loot crate exactly as today.
3. Notoriety from the kill SHALL be applied once in both cases.
4. `tests/test_ship_combat.gd` SHALL pass unmodified.

### Requirement A2: Crew loss weakens guns without locking them (M-002, C-004, M-001)

**User Story:** As a player, I want crew damage to matter, so a crippled ship fights worse, but the
fight never soft-locks.

#### Acceptance Criteria
1. WHEN a ship's crew is ≤ 0, THE ship SHALL NOT spawn cannonballs, on any firing path: manual,
   auto, ripple or chaser.
2. THE crew reload penalty SHALL be bounded by `ShipStats` fields:
   - `min_crew_fire_rate_mult` (default 0.25)
   - `max_reload_seconds` (default 40.0)

   No literal values in script.
3. WHEN a ship dies or respawns, pending reload callbacks from its previous life SHALL NOT
   re-enable or disable its guns.

### Requirement A3: Loot scaling is data-driven and capped (C-005, BALANCE-002)

#### Acceptance Criteria
1. A `LootScalingData` resource (`resources/combat/LootScaling.tres`) SHALL hold:
   - `notoriety_divisor` (100.0)
   - `class_multiplier_max` (3.0)
   - `max_multiplier` (5.0)
2. `ShipController._spawn_loot()` and `BoardingSystem` SHALL use one shared helper that reads it,
   and the product of the class and notoriety multipliers SHALL be clamped to `max_multiplier`.
3. IF the resource fails to load, THE helper SHALL `push_error` and use a multiplier of 1.0.

### Requirement A4: Encounters can never start unwinnable (C-006, C-015, C-019, M-005)

#### Acceptance Criteria
1. `EncounterManager.start_encounter()` SHALL validate before spawning. It SHALL reject:
   - a missing enemy composition or `enemy_scene`
   - `PROTECT_TARGET` without an escort that actually spawns
   - `SURVIVE_TIME` with `time_limit <= 0`
   - a count objective with `target <= 0`
2. ON a validation failure, THE manager SHALL `push_error` with the encounter id and field, restore
   ambient spawning, emit `encounter_failed(encounter_id, reason)`, and return `false`.
3. A lint test SHALL load every `EncounterData` `.tres` and assert that it validates.
4. `EncounterData.time_limit` SHALL be range-capped at 3600 seconds.

### Requirement A5: Deferred fire never touches a freed ship (C-008, C-014)

#### Acceptance Criteria
1. Ripple-fire callbacks SHALL no-op when the marker, the parent ship or its `ShipDamage` is freed
   or outside the tree.
2. A ship SHALL drop a target lock whose target is freed or destroyed.

### Requirement B1: Violence costs reputation (M001)

**User Story:** As a player, I want sinking or boarding a Spanish ship to anger Spain, so my choices
of target have consequences.

#### Acceptance Criteria
1. WHEN `EnemySpawner.enemy_destroyed(enemy)` fires in the campaign, AND the enemy has a `faction`,
   THEN `FactionManager` SHALL apply `-faction.sink_reputation_loss`.
2. WHEN `BoardingSystem.boarding_resolved` fires with `success == true`, THEN `FactionManager` SHALL
   apply `-boarding_reputation_loss` for `target_faction_id`.
3. The two paths SHALL NOT both apply for one boarded ship. A boarded ship gets the boarding loss
   only.
4. Outside the campaign (`SceneManager.is_campaign() == false`), there SHALL be no reputation change.
5. An unresolvable faction id SHALL `push_error`.
6. No Ch1-5 objective SHALL become unreachable because of this. This is asserted against every
   `CHANGE_REPUTATION` objective.

### Requirement B2: Factions respond to actions, not just thresholds (F012)

#### Acceptance Criteria
1. WHEN an island is captured from an empire faction, OR an empire ship is boarded, THEN that
   faction SHALL spawn one hunter, subject to a per-faction `hunter_cooldown_seconds`.
2. The existing reputation ≤ -50 hunter trigger SHALL remain.
3. The faction that lost the island SHALL be known exactly, not guessed from the region:
   - `Island.capture_island()` records the previous owner.
   - `EmpireManager` emits a new signal, `island_captured_from(island_id, previous_faction_id)`.
   - The existing `island_captured(island_id)` signature, which has 3 subscribers, is unchanged.

### Requirement B3: Per-faction tribute and raid pressure (F011, F015)

#### Acceptance Criteria
1. `FactionData` SHALL `@export` `tribute_cost_gold` and `tribute_cooldown_seconds`, with defaults
   equal to today's constants. `pay_tribute()` SHALL read them.
2. `FactionData` SHALL `@export` `raid_frequency_mult` (default 1.0). The raid-chance formula in
   `EmpireManager` SHALL multiply by it, and the existing clamp is kept.
3. Today's balance SHALL be unchanged for any faction whose `.tres` leaves out the new fields.

### Requirement B4: Island owner display data (M006, logic half)

#### Acceptance Criteria
1. `FactionManager.get_island_owner_display(island_data)` SHALL return
   `{faction_id, name, color}`:
   - **FRIENDLY / CAPITAL:** the player faction.
   - **ENEMY:** the owner's `faction_name` and `sail_color`.
   - **NEUTRAL:** "Unclaimed" in a neutral colour.
   - **LEGENDARY:** "Uncharted" in a neutral colour.
2. A null `island_data` or null owner SHALL return the neutral entry without erroring.

### Requirement C1: The campaign ends, then the game continues (CAMP-001, MISSED-004, CAMP-005)

**User Story:** As a player who finishes Chapter 5, I want a real ending and then my empire still
there, so finishing feels earned and is not a dead end.

#### Acceptance Criteria
1. WHEN the last enabled chapter completes, THE `CampaignManager` SHALL:
   - set `campaign_completed = true`
   - persist it via `get_save_data()` and `load_save_data()`
   - emit `campaign_completed_signal`
2. The epilogue SHALL be authored as data. It is the final chapter's closing beats, plus new
   epilogue beats in the existing voice, played by the existing `TutorialDialogue`. The beats:
   - close the Ch5 arc
   - give Marguerite's Ch3 warning a callback beat (MISSED-001)
   - turn Vane's chart into an explicit "the story continues" hook

   No new UI system.
3. After the epilogue, a one-time "Campaign complete" celebration SHALL show through the existing
   `CelebrationQueue`.
4. In free roam:
   - `_current_chapter()` SHALL return null.
   - The HUD objective panel and Captain's Log SHALL show a free-roam line instead of a stale or
     empty objective.
   - Economy, events, raids and Maelstrom SHALL be unaffected.
5. New Game SHALL reset `campaign_completed`. This comes from the existing fresh-state snapshot.

### Requirement C2: Every Ch1-5 objective is provably completable (golden-path test)

#### Acceptance Criteria
1. `tests/test_campaign_golden_path.gd` SHALL iterate every objective of every enabled chapter and
   assert, for each one:
   - its `Condition` has a live emitter wired in `CampaignManager`
   - its target id (island, building, boss, captain, ship class) resolves to content inside the
     5-island MVP scope
   - its `target_count` is ≥ 1
2. A failure SHALL name the chapter, the objective id and the unmet clause.

### Requirement C3: Story and text polish (CAMP-002, CAMP-003, MISSED-003, MISSED-005, MISSED_5, E7, CAMP-007)

#### Acceptance Criteria
1. Ch2 `Obj_2_4` SHALL say "Board two ships" (or equivalent), with hint text that matches
   `target_count = 2`.
2. Ch4 SHALL gain one opening beat that states its mechanical goals.
3. Ch4's Pelican Cay objective SHALL be retuned so it is not trivial at notoriety 110-150. The
   default: a follow-up "hold Pelican Cay through a raid" objective, using the existing
   `SURVIVE_RAID` condition.
4. Ch4 `Obj_4_8` (board HMS Intransigent) stays optional. It SHALL get one acknowledgment line in
   Ch4's closing beats, gated on whether it was completed, IF `DialogueBeatData` already supports a
   condition. Otherwise this is deferred, with a note.
5. Tortuga's codex SHALL stop promising a tavern, contracts and a market as present-day features.
   It frames them as rumours, which M34 will pay off.
6. Fortress and Watchtower descriptions SHALL describe their actual effect: raid defense score.
7. Every named story speaker in Ch1-5 beats SHALL have a `portrait_path` at the asset path listed in
   `docs/10`. `PortraitFallback` shows initials until the art lands.

### Requirement D1: World events reach the player (UNWIRED-003)

#### Acceptance Criteria
1. `WorldHUD` SHALL connect `EventManager.world_event_triggered` and show a non-modal announcement
   banner:
   - FIFO-queued, one banner at a time
   - auto-dismisses
   - never steals input
   - laid out in the existing HUD container, not at pixel offsets
2. Banner text SHALL come from a data table keyed by event name (an `EventAnnouncementData`
   resource or `tr()` keys), not from `match` strings in `WorldHUD`.
3. The banner SHALL also show `EncounterManager.encounter_failed` (A4) as a quiet notice.

### Requirement D2: Owner shown on approach (M006, HUD half)

#### Acceptance Criteria
1. The dock prompt and island label SHALL show the island name and owner, tinted with
   `get_island_owner_display()`.
2. This SHALL work on the phone (mobile utility-menu dock state) as well as on the desktop prompt.

### Requirement D3: Ocean-event schedule survives save/load (PERSISTENCE-003; reproduce first)

#### Acceptance Criteria
1. IF the repro shows that save/load causes duplicate or lost event timing, THEN `EventManager`
   SHALL persist `_timer` and `_next_event_time` via `get_save_data()` / `load_save_data()`.
   - The section is omitted when `_timer == 0`.
   - `EventManager` is added to `_NEW_GAME_RESET_MANAGERS`.
2. IF the repro only shows that the schedule restarts on load (a delay, not a duplicate), close it
   as stale and do not fix.

### Requirement D4: Three permanent lint tests

#### Acceptance Criteria
1. **Resource lint** (`tests/test_lint_resource_exports.gd`):
   - Parse every `res://resources/**/*.tres` as text: its `[resource]` and `[sub_resource]` property
     lines.
   - Assert each key is in the attached script's `get_script_property_list()`, or is a
     built-in/engine `Resource` property.
   - Text parsing is required. Godot silently drops unknown properties on load, so a runtime check
     cannot see them.
2. **Persistence lint** (`tests/test_lint_save_roundtrip.gd`):
   - For every autoload with `get_save_data`, run `get_save_data` → JSON → `load_save_data` →
     `get_save_data` and compare equal after normalising through JSON.
   - Assert every autoload with `load_save_data` is either in `_NEW_GAME_RESET_MANAGERS` or on a
     commented allowlist. The allowlist is for account-scoped data, for example `EntitlementManager`.
3. **Signal lint** (`tests/test_lint_signal_wiring.gd`):
   - Statically scan `res://scripts/**/*.gd` and `res://scenes/**/*.tscn`.
   - Every `signal` declaration must have an emit (`x.emit(` or `emit_signal("x"`) and a connection
     (`.x.connect(`, `connect("x"`, or a `.tscn` `[connection signal="x"`), or appear in a
     commented allowlist.
   - The allowlist starts as whatever the scan flags today, each entry with a reason.
4. Each lint SHALL print its counts (files scanned, violations) and name each violation's file.

### Requirement E1: Measure, then fix, frame rate (UI-1, C-020)

#### Acceptance Criteria
1. A repeatable desktop perf probe SHALL log `Performance` monitors (frame time, draw calls,
   objects, primitives, physics time) at fixed scenarios. The scenarios are open ocean, near an
   island, and mid-combat with 3 and with 6 hulls. The probe is `CaptureHarness` with a
   `--perf-log=` flag.
2. The top costs found SHALL each get a quality-tier response driven only by
   `SettingsManager.graphics_quality`. Candidates:
   - shadows and shadow distance
   - MSAA, SSAO and glow
   - ocean sparkle and ring density
   - ambient hull cap per tier, through data and not literals
3. Avoidance raycasts are measured only. `EnemyAI` logic is not changed (fragile area).
4. Device FPS is **owner-measured**. The spec reports it as unverified until the owner records a
   number in `docs/RELEASE_CHECKLIST.md` §6.
5. `project.godot` SHALL set `rendering/renderer/rendering_method.mobile="mobile"` explicitly. It is
   already Godot's default; setting it is for release clarity.

### Requirement E2: Release plumbing (UI-15)

#### Acceptance Criteria
1. The privacy and terms URLs used by `SettingsMenu` SHALL return HTTP 200 before M35.
   - Enabling GitHub Pages is an **owner action**, because it publishes something.
   - The step is documented in `docs/RELEASE_CHECKLIST.md`.

### Requirement F1: Asset requests for owner-supplied art

#### Acceptance Criteria
1. `docs/10_ASSET_REQUESTS.md` SHALL gain an "M29-M35 requests" section, grouped by the milestone
   that needs each asset. Each row gives:
   - id, purpose, exact `res://` path, format, and size or poly budget for mobile
   - the milestone that needs it
   - the placeholder used until then
2. It SHALL cover:
   - the story-cast portraits (every named Ch1-5 speaker)
   - the two untextured ship models (V7)
   - the figurehead (UI-4)
   - faction flags and sails for Britain, Spain, the Merchant Guild and the pirate clans
   - island owner banners
   - the 5 port-view island scenes (M32)
   - cannon, smoke, fire and splash VFX textures
   - retention UI icons (M30)
   - the app icon and store art
3. Seam fields SHALL exist so art drops in without code changes:
   - `FactionData.flag_texture_path` and `sail_texture_path` (added by Lane B)
   - `IslandData.port_scene_path` and `owner_banner_path`

   Each is commented. Nothing reads them yet, and an empty value is the default, so none is
   written into existing `.tres` files.

## Out of Scope

- **The full faction economy:** treasuries, convoys, treasure fleets and retaking islands are M31.
  B1-B3 are the minimal consequences that M31 builds on.
- **The retention layer:** streaks, goals, achievements and the offline-return story are M30.
- **Island material tinting and flag geometry:** these wait for the owner's art in M31 and M32. M29
  is HUD-only.
- **`EnemyAI` avoidance, buoyancy, stability torque, the yaw servo and the cannon-forward basis:**
  fragile areas, untouched.
- **C-009, C-011, M-003, C-010, C-012, C-013, C-016, C-017:** stale, by design, or polish. They are
  listed in `tasks.md` Notes.
- **Ocean vertex-density LOD and spatial partitioning:** these move to M33 or later, unless E1's
  probe shows they are the top cost.
- **Chapters 6-10:** they stay `content_enabled=false` and return post-launch.
- **Settings persistence in saves:** this is by design. See the introduction.
