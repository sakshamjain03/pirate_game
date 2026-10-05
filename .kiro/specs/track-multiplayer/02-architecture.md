> Raw design input for the MULTIPLAYER track (MP-0..MP-4), produced 2026-10-05 by a read-only design panel (workflow wf_95a5d2d8-2d0). NOT an approved spec: it gets its own planning pass after M31. Owner vision: CoC-style 5-12 island home base + global brawl; PvP loot/ship-power math managed.

# Pirate Empire PvP: network, backend and loot math plan

## 0. What the code does today

- **Saves.** `SaveManager._sync_to_cloud()` (`scripts/managers/SaveManager.gd:666`) upserts the whole local save dict to `player_saves` through PostgREST. RLS limits each user to their own row, but that row can hold any value. Conflicts are settled by comparing `client_updated_at` and asking the player which save to keep. The client is fully authoritative.
- **Eights.** The balance is `economy.eights` inside that same jsonb. `StoreManager._grant_consumable()` checks the receipt on the device only. `ScheduleManager.finish_cost_eights()/finish_now()` lets Eights finish timers. `_apply_cloud_save` keeps whichever wallet is higher.
- **Duplicated HTTP code.** The same `_send_cloud_request` with a retry on 401 is copied in SaveManager, EntitlementManager and RemoteConfigManager.
- **Building slots.** `Island.gd` saves only `get_built_building_ids()`. A building's slot is just its position in that array (`slot_index % slots.size()`), so there are no stable socket IDs. `ResourceManager.recalculate_storage_capacity()` adds up every node in the group `"islands"`. A PvP base loaded into the scene must stay out of that group, or it changes the player's storage caps.
- **The combat sim can't be replayed.** `Cannonball` is a `RigidBody3D`. `ShipCombat` calls the global `randf()/randfn()` for spread and misfires. `BuoyancySimulator` reads `Time.get_ticks_msec()`. `EnemyAI` steers with physics raycasts. The same inputs can give different results across devices, so a server can't check a fight by re-running it.
- **Ship stats are a pure function, which helps.** `OwnedShipData.get_effective_stats()` is template × (1 + 0.02·(level−1)) × module multipliers. The server can compute it from exported tables.
- **Existing docs conflict with PvP.** `docs/17_MONETIZATION.md` §4.4 says the wallet is deliberately not server-authoritative, the game is "playable offline forever", and there is no anti-cheat. AGENTS.md lines 224–228, 674–682, 785 and 830–842 ban PvP. All of these need amending.
- **Account deletion.** `delete-account/index.ts` deletes `player_saves` and then the auth user. None of the foreign keys cascade.

## 1. Main decision: a separate "Harbour" realm with server authority

There are two options.

- **Option U: one empire, server-authoritative.** The Clash of Clans model: the campaign islands are also your PvP base. Every economy action needs the server: the 10s tick, ScheduleManager, the 4h offline catch-up, the Shipyard. That breaks the offline-forever promise and means rewriting about 15 managers. Migration risk is high and the beta would stall.
- **Option S: split ledgers (recommended).**
  - The campaign stays offline and client-authoritative. If someone cheats there, nobody else is affected.
  - PvP lives in a new **Harbour** realm: each player's own archipelago of 5–12 islands, built from the existing authored island scenes as templates, with the same 10 building types and the same hulls.
  - Anything another player can take, see or be matched against lives only in Postgres and is changed only by RPCs.
  - Harbour rewards can flow into the campaign (harmless).
  - Campaign progress can flow into the Harbour only through a list of one-time grants with a known total, keyed per milestone (for example `chapter_3_complete` → a fixed charter grant). A cheater gets exactly what an honest player who finished the campaign gets, and no more.

**Why Eights don't need to be on the server for PvP.** If Eights buy nothing in the Harbour except cosmetics, a client-side wallet can't affect PvP. That avoids server-side Play receipt checks for now.

**Migrating without losing progress (Option S).** Nothing in the campaign changes: same `SAVE_SCHEMA_VERSION`, same `player_saves`, so no save compatibility breaks. Opting in calls `harbour_bootstrap()`, which creates new rows. Progress cannot be lost because none is moved.

**If the owner later wants Option U**, migrate one domain at a time:
1. **Shadow phase.** The server derives a shadow ledger from each jsonb upload and logs diffs. The client is still authoritative.
2. **Dual-write.** The client calls RPCs for each action and also uploads jsonb. A version number on each domain (`harbour_state.version`) catches lost updates.
3. **Flip authority per domain, in order:** resources, then buildings and timers, then fleet. On each flip, clamp values to plausible limits (storage caps; levels no higher than account age × build-time math), keep the original jsonb in a `migration_archive` table, and log every clamp so support can restore it.
4. Each step is a new `save_schema_version` with a `_migrate()` step, following the existing `SaveManager._migrate` pattern.

## 2. What must live on the server (Harbour realm)

**Server-only state:**
- Stash per resource (gold, wood, iron, rum)
- Building placement and level per island and named socket
- Job `started_at/completes_at`, set from the server clock
- Production `last_collected_at`
- Fleet roster (hull, level, component levels, modules)
- Battery plan (socket → battery type and facing)
- Trophies, shields, attack locks
- Harbour Level (HL), defense and fleet power

**Production is computed lazily.** Each RPC first calls `_harbour_resolve(uid)`: complete due jobs, then for each producer `accrued = min(collector_cap, rate × (now − last_collected_at))`. No cron tick is needed. This mirrors ScheduleManager plus offline catch-up, done in SQL.

**Clock.** The Harbour client must use the server clock, not `ScheduleManager.now()`. Compute the offset from the response `Date` header.

**Never allowed in the Harbour:**
- Eights or ads for timer finishes, shields, ships, resources, builders, repairs, matchmaking re-rolls or revives
- Premium captains (excluded from Harbour rosters)
- Builder slots for sale; they come from HL only

## 3. Loot and ship-strength math (the owner's question)

These numbers live in a server-side `balance_tables` row. Attack tickets carry the stat blocks, so balance can be tuned on the server without an app release.

### 3.1 Ship strength: Combat Power

Under Lanchester's square law, a fleet's fighting strength grows with N²·HP·DPS. So a single ship's additive value is:

`CP = sqrt(EHP × DPS_side)`, where `DPS_side = cannons_per_side × cannon_damage × fire_rate`

Values from `resources/ships/*.tres`:

| Hull | HP | DPS/side | CP | Proposed berths |
|---|---|---|---|---|
| Dinghy | 50 | 9.0 | 21 | 1 |
| Sloop | 100 | 13.5 | 37 | 1 |
| Schooner | 120 | 16.4 | 44 | 2 |
| Corvette | 140 | 21.8 | 55 | 2 |
| Brigantine | 150 | 23.1 | 59 | 3 |
| Frigate | 250 | 34.6 | 93 | 4 |
| Galleon | 400 | 39.4 | 126 | 5 |
| Man O'War | 600 | 60.0 | 190 | 6 |

- **Level and modules.** Level scales both HP and damage, so CP × (1 + 0.02(L−1)): +18% at level 10. Modules multiply into EHP and DPS before the square root.
- **Fleet Power** = Σ CP_i. One Man O'War ≈ 5.2 Sloops. It costs 70× the gold, which is very cost-inefficient, so the cap has to be on berths, not on gold.
- **Attack berths(HL) = 3 + HL**, with at most 4 attacking hulls. That fits the ≤10-hull render budget: 4 attackers, up to 3 defending ships, and static batteries. A Man O'War first fits at HL3.
- **Defense Power** = Σ battery CP + 0.8 × defending-fleet CP (the AI is weaker than a human) + structure term. Tune so that DP ≈ FP at the same HL gives about 1.5–2.0 stars on average. The server measures this from `raid_results` per HL pair.
- **Harbour techs** are tracked on the server, capped per HL, with a total multiplier ≤ 1.25.
- **Brawl mode is level-normalized.** Every ship is clamped to the league level cap, with techs off and standard components, so it's skill plus composition.

### 3.2 Loot, computed only on the server from the defender's server-side stash

```
P_h(HL)        = reference hourly production at that HL (balance table, per resource)
protected[r]   = min(stash[r], vault_pct(HL_d) × capacity[r]);  vault_pct 0.25 → 0.50 with Warehouse level
s(HL_d)        = 0.20 − 0.015·(HL_d − 1)        # share of unprotected stash: 20% at HL1, ~9.5% at HL8
pool[r]        = 0.50 × uncollected[r] + s × max(0, stash[r] − protected[r])
cap[r]         = 2.0 × P_h(HL_d)[r]             # per-raid ceiling (also written into the ticket)
m_lvl          = 1.0 (HL_a ≤ HL_d), 0.75 (+1), 0.40 (+2), 0.10 (≥+3)   # anti-bullying
award[r]       = min(pool[r], cap[r]) × (destroyed loot-building weight / total weight) × m_lvl
award[r]       = min(award[r], current_available_now[r], defender_daily_room[r])
defender_daily_room = 0.30 × stash at start of the rolling 24h − losses in that 24h
star_bonus     = stars × 0.10 × P_h(HL_a).gold  # minted, attacker daily bonus cap ~10 raids
defense_bounty = 0.25 × P_h(HL_d).gold + trophies, minted, if the attacker scores 0 stars
repair_cost    = 10–20% of attacker fleet build cost × damage fraction  # resource sink, never Eights
```

- **Invariant that makes the mode work:** an average successful raid ≈ 1.0–1.5 × the attacker's hourly production.
  - Much more than that and nobody builds; much less and nobody raids.
  - A defender can lose at most about 30% of stash per day and can never be zeroed.
  - Minted bonuses come to roughly 20% of transferred loot. Track total minting per day in a view to watch inflation.
- **Shields:** ≥40% destruction or 1 star → 8h, 2 stars → 12h, 3 stars → 14h. The shield breaks if the defender starts an attack. Shields can never be bought.
- **Trophies:** Elo. `E = 1/(1 + 10^((T_d − T_a)/400))`, `ΔT = round(32 × (stars/3 − E))`. The defender gets the negative.

## 4. Async raid flow on Supabase

1. **The server publishes the defense snapshot, not the client.** Any RPC that changes layout or defense (job completion, battery-plan change, fleet assignment) calls `_publish_defense_snapshot(uid)`. That builds an immutable, versioned jsonb (islands, templates, socket → building type/level/HP, batteries, defending fleet stat blocks, DP, HL), inserts a `defense_snapshots` row and updates `harbour_state.current_snapshot_id`. A trigger blocks any UPDATE or DELETE on snapshots.
2. **`raid-start` Edge Function:**
   - Verify the JWT; check the rate limit (e.g. ≤ 20 tickets per hour).
   - Pick a target with the matchmaking query (§7), with no "next" re-roll fee in Eights.
   - Set `attack_lock_until = now() + 240s` on the defender.
   - Insert an `attack_tickets` row with a 64-bit seed, snapshot ID, `loot_cap`, the attacker's server-computed fleet stat blocks, and `expires_at = now() + 240s`.
   - Return the snapshot payload, the stat blocks, and a ticket signed with HMAC-SHA256 over `{ticket_id, seed, snapshot_id, exp}` (secret held in an Edge Function env var).
   - **Small-population fallback:** if no real target matches, return a **Phantom Harbour**: an authored NPC snapshot for that HL, with minted loot under a daily cap. Without this, a beta-sized player base can't play.
3. **The client simulates locally** on the deterministic combat core (§6), using only the ticket's stats and seed. It records inputs.
4. **`raid-submit` Edge Function:**
   - Verify the signature and that the ticket hasn't been used.
   - Read `{ticket_id, destroyed_building_ids[], ships_lost[], stars, duration_ms, final_state_hash, client_build}`.
   - Return a signed Storage upload URL for the replay (`replays/{attacker}/{ticket}.bin`, typically under 5 KB of delta-encoded inputs).
   - Call `_settle_raid()` with the service role.
5. **`_settle_raid(ticket, report)` is one Postgres transaction:**
   - `UPDATE attack_tickets SET consumed_at = now() WHERE id = $1 AND consumed_at IS NULL AND expires_at > now() RETURNING *`. Zero rows means reject.
   - Plausibility checks (§5). Failing them means 0 loot and a `cheat_flags` row.
   - `SELECT … FROM harbour_ledger WHERE user_id IN (att, def) ORDER BY user_id FOR UPDATE`. The fixed order prevents deadlocks.
   - Compute the award with §3.2, using current stash so the defender spending mid-attack can't drive it negative. Credit the attacker up to their storage capacity; the overflow is lost.
   - Write `economy_tx` rows for both sides, then update stashes, trophies, shield, and release the lock.
   - Insert `raid_results` with `verify_status = 'plausible'`.
6. **Notify the defender.**
   - Online: Realtime Postgres Changes on `raid_results`, filtered `defender_id=eq.<uid>`. RLS lets the defender read their own rows.
   - Offline: an FCM push, Phase 3+. Keep the local notification text as-is.
   - The defense log is `raid_results` read by the defender, with "revenge" (one free ticket against that attacker, which skips matchmaking but not the shield).
7. **Settle first, then verify.** Loot is credited right away. The verifier (§5, tier 2) re-runs selected replays asynchronously. On a mismatch, a reversal transaction refunds the defender, debits the attacker (stash can't go below zero; any remainder becomes a debt column) and raises the attacker's cheat score.

## 5. Anti-cheat posture (realistic for an indie)

- **Tier 0 (required):**
  - Clients cannot INSERT, UPDATE or DELETE any `harbour_*`, ticket or result table. Every mutation goes through `SECURITY DEFINER` RPCs that use `auth.uid()` and `set search_path = public`.
  - Idempotency keys on mutating RPCs.
  - A `rate_limits` table checked in each RPC.
  - Tickets are single-use, expiring and signed.
- **Tier 1 (plausibility checks at settle time):**
  - `duration_ms ≤ ttl`.
  - Destroyed HP ≤ Σ DPS_i × duration × max ammo/buff multiplier × 1.1 tolerance.
  - Each building's earliest possible kill time is ≥ its HP ÷ fleet DPS.
  - Stars are consistent with destruction and objectives.
  - Ships reported lost are ⊆ roster.
  - A pair cooldown: 1 raid per 24h per attacker/defender pair.
  - The client build must be in the `remote_config` allowlist.
  - Daily outlier flags: 3-star rate against power gap, p99 destruction.
- **Tier 2 (re-simulation):** a headless Godot verifier running the exact combat-core scripts on Fly.io (one shared-cpu machine, a few USD a month). It polls `raid_results`, re-runs the replay with the ticket's seed and stats, compares the hash, and posts the verdict to the `raid-verify` Edge Function using a service secret. Sampling: every 3-star raid, the top 5% by loot, every flagged account, and 10% of the rest. Edge Functions' per-request CPU budget is too small for re-simulation; check current limits.
- **Tier 3 (enforcement):** `shadow_pool` (cheaters only matched with each other), reversals, `banned_at`.
- **Alt-account farming:**
  - Novice protection: 72h and below HL3, the account can't be matched.
  - `m_lvl` penalty and the defender's daily loss cap reduce how much a feeder account can give.
  - The same-pair cooldown applies.
- **Optional:** Play Integrity verdicts checked in `raid-start`.
- **Not doing:** obfuscation, root detection, kernel-level anything.

## 6. Real-time brawl feasibility

- **Problem.** The current sim (RigidBody ships, buoyancy, global RNG, raycast AI) can't decide a PvP outcome. It can't be replayed, so it can't be checked, and it can't run in lockstep. A **deterministic simplified kinematic combat core (KCC)** is needed for async raids anyway (for tier-2 verification), and it is also what makes a real-time brawl affordable.
- **KCC spec:**
  - Fixed 20 Hz step.
  - 2D state `(x, z, heading, speed, rudder)` in int64 fixed-point (1/1000 m).
  - Trig from a 4096-entry lookup table.
  - Analytic ballistics: hit decided at fire time from spread rolled on a PCG32 `SimRng`, with impact scheduled after time of flight.
  - Batteries are static points; buildings are HP pools.
  - Entities live in arrays sorted by ID. No Nodes, physics, `Time` or global `randf`.
  - Buoyancy and waves stay as **visual-only** bobbing on presentation nodes.
- **Brawl options:**
  - **A. Godot headless authoritative server on Fly.io or Edgegap**, with client prediction. Most secure. About $0.01–0.05 per match-hour, plus real netcode (ENet/WebSocket MultiplayerAPI, prediction) and ops work.
  - **B. Nakama.** The combat core would have to be ported to TS/Go, which doubles the sim and duplicates Supabase's auth and storage. Managed hosting is expensive. Reject.
  - **C. Delay-based deterministic lockstep (recommended).**
    - Clients send only quantized input frames at 10 Hz. Naval combat (5–10s reloads, slow turns) tolerates 150–250 ms of input delay, so rollback isn't needed.
    - Transport: Supabase Realtime **broadcast** for the beta. Relay latency is roughly 50–150 ms within a region, so the project region must be near the players.
    - Every second, clients exchange state hashes; a mismatch means a desync.
    - At the end, both clients submit the result hash. If they agree, `brawl-result` settles. If they disagree, the tier-2 verifier re-runs the input log and decides.
    - Lockstep can't stop "map hacks", but there is no fog in naval combat, so that doesn't matter.
    - Cost estimate (check current pricing): about 7k Realtime messages per 3-minute 1v1, roughly $0.02 per match beyond the plan quota.
    - Move to a small WebSocket relay on Fly.io when volume justifies it.
- **Brawl prizes** are trophies plus a minted bounty. They are not taken from either player's stash, and there are no wagers.

## 7. Schema list

All `user_id` foreign keys use `references auth.users(id) on delete cascade`. History tables use `on delete set null` instead. RLS is on everywhere: own-row SELECT only, no client write policies.

| Table | Key columns |
|---|---|
| `profiles` | user_id PK, display_name, created_at, novice_until, banned_at, shadow_pool bool, cheat_score |
| `harbour_state` | user_id PK, harbour_level, trophies, shield_until, attack_lock_until, last_seen_at, builders, current_snapshot_id, defense_power, fleet_power, version |
| `harbour_ledger` | (user_id, resource) PK, stash bigint `check (stash >= 0)` |
| `harbour_islands` | (user_id, island_slot 0–11) PK, template_id, unlocked_at |
| `harbour_buildings` | id, user_id, island_slot, socket_id, building_type, level, last_collected_at; unique (user_id, island_slot, socket_id) |
| `harbour_jobs` | id, user_id, kind, target_id, to_level, cost jsonb, started_at, completes_at, resolved_at |
| `harbour_ships` | id, user_id, hull_id, level, component_levels jsonb, modules jsonb, captain_id, role, repaired_at |
| `harbour_battery_plan` | (user_id, island_slot, socket_id) PK, battery_type, facing (N/E/S/W) |
| `defense_snapshots` | id bigserial, user_id, version, payload jsonb, defense_power, harbour_level, created_at. Immutable by trigger. SELECT only through a ticket. |
| `attack_tickets` | id uuid, attacker_id, defender_id (null for a Phantom Harbour), snapshot_id, seed bigint, loot_cap jsonb, attacker_stats jsonb, issued_at, expires_at, consumed_at |
| `raid_results` | id, ticket_id unique, attacker_id, defender_id, stars, destruction_pct, destroyed jsonb, duration_ms, loot jsonb, minted jsonb, trophy_delta_a/d, verify_status, replay_path, client_build, created_at. SELECT allowed if attacker or defender. |
| `economy_tx` | append-only: id, user_id, resource, delta, reason, ref_id, created_at. Index (user_id, created_at) for the 24h loss cap. |
| `campaign_milestone_claims` | (user_id, milestone_id) PK, claimed_at |
| `balance_tables` | key, version, payload jsonb. Exported from `.tres`. |
| `rate_limits` | user_id, bucket, window_start, count |
| `cheat_flags` | user_id, reason, ref_id, score, created_at |
| `phantom_harbours` | id, harbour_level, payload jsonb, daily_mint_cap |
| `brawl_matches` (Phase 5) | id, a_id, b_id, channel, seed, status, inputs_path, hash_a, hash_b, result |

**Matchmaking index:** `(harbour_level, trophies) where shield_until < now()`. Expressions containing `now()` aren't allowed in a partial index, so index `(harbour_level, trophies, shield_until)` instead.

**Public RPCs:**
- `harbour_bootstrap()`, `harbour_sync()`
- `harbour_start_build(island_slot, socket_id, type)`, `harbour_start_upgrade(building_id)`, `harbour_collect(building_id?)`
- `harbour_unlock_island(slot, template_id)` (islands = 4 + HL, so 5–12)
- `harbour_set_battery_plan(jsonb)`
- `harbour_build_ship(hull_id)`, `harbour_upgrade_ship(id, component?)`, `harbour_assign_fleet(jsonb)`
- `harbour_claim_milestone(id)`
- `pvp_heartbeat()`, `harbour_defense_log(limit)`

**Internal RPCs (service role only):** `_harbour_resolve`, `_publish_defense_snapshot`, `_find_raid_target`, `_settle_raid`, `_reverse_raid`.

**Matchmaking query core:**
```sql
select user_id, current_snapshot_id from harbour_state hs
where user_id <> p_att and shield_until < now() and attack_lock_until < now()
  and last_seen_at < now() - interval '3 minutes'
  and harbour_level between p_hl-1 and p_hl+1
  and trophies between p_tr - p_band and p_tr + p_band
  and defense_power between p_fp*0.6 and p_fp*1.5
  and (select shadow_pool from profiles where user_id = hs.user_id) = p_shadow
  and (select novice_until from profiles where user_id = hs.user_id) < now()
  and not exists (select 1 from raid_results r where r.attacker_id=p_att
                  and r.defender_id=hs.user_id and r.created_at > now()-interval '24 hours')
order by abs(trophies - p_tr) + (random()*100) limit 1
for update skip locked;
```
If nothing is found, widen `p_band` (200, then 400, then 800), then fall back to a Phantom Harbour.

**Edge Functions:**
- `raid-start`, `raid-submit` (returns the signed replay upload URL), `raid-verify` (verifier callback, service secret)
- `delete-account`: switch to cascades, or add the new tables explicitly
- Phase 5: `brawl-queue`, `brawl-result`

**pg_cron:** every minute, expire tickets and release locks.

**Storage:** private bucket `replays`.

## 8. Client architecture (Godot)

- **Shared HTTP helper.** Write `scripts/net/SupabaseHttp.gd`: one request function with the retry-on-401 and the test override hook. Have SaveManager, EntitlementManager and RemoteConfigManager use it; per AGENTS' "no duplicate systems" rule, that refactor comes first.
- **`HarbourService` autoload.** Typed RPC wrappers, a server-clock offset, and a read-only `HarbourState` cache. It never mutates anything locally beyond optimistic UI.
- **Separate mode scenes,** following the Maelstrom precedent (`scripts/modes/`, `SceneManager.is_campaign()`): `scenes/modes/HarbourWorld.tscn` and `RaidArena.tscn`, not `World.tscn`. SaveManager autosaves only when the scene is named `"World"`, and the campaign economy tick must not run in these scenes.
- **`scripts/pvp/sim/`** is pure RefCounted code: `SimWorld`, `SimShip`, `SimBattery`, `SimBuilding`, `SimProjectile`, `SimRng` (PCG32), `SimDefenseAI` (a port of the role tactics and broadside telegraphs that steers from sim state, not raycasts), `FixedMath`, `SimInputFrame`, `ReplayCodec`.
- **`SimRunner`** runs the fixed 20 Hz step with an accumulator. **`SimPresenter`** interpolates sim state onto the existing hull scenes and `ShipVisuals`, with buoyancy as visuals only.
- **Input.** InputManager and ShipController intents are quantized into `SimInputFrame` (throttle step, rudder step, fire L/R, brace, ability). That is the simulation/input/presentation split `docs/navalCombat.md` asks for.
- **`SnapshotIsland.build(payload) -> Node3D`:**
  - Instance the island template by `template_id`.
  - Resolve **named** `Marker3D` sockets. This needs stable socket names added to the BuildingSlots markers on the authored islands; today slots are positional.
  - Place building models from `resources/buildings/<Type>_L<n>.tres`, display only. Don't attach `Island.gd` economy behavior and **never join the `"islands"` group**.
  - Register a `SimBuilding` (HP from the snapshot) and a `SimBattery` per battery-plan entry.
- **Determinism checks:**
  - A GUT test that runs a recorded replay twice in a headless run and asserts the hash matches.
  - A "determinism canary": at Harbour entry, beta clients simulate a bundled replay and upload the hash, so ARM-vs-x86 drift shows up early.
- **Balance export.** A tool script exports `.tres` balance data to JSON for `balance_tables`. A parity test asserts `get_effective_stats()` matches the exported numbers.

## 9. Constitution amendment (proposed AGENTS.md wording)

> **Multiplayer Charter (Amendment 1).** The single-player campaign stays offline-first and playable forever without an account; nothing in it ever requires a connection. Multiplayer is allowed only inside the separately scoped **Harbour** realm (async raids, brawls), under these rules:
> 1. **Server authority.** Every value another player can take, see or be matched against (Harbour resources, buildings, timers, fleet, trophies, shields) is stored and changed only by server code. The client never writes it.
> 2. **Isolation.** Campaign state enters the Harbour only through enumerated, one-time grants with a known total. Harbour rewards may flow into the campaign.
> 3. **No paid advantage.** Pieces of Eight and ads buy nothing in the Harbour except cosmetics: no shields, ships, troops, resources, builder slots, timer finishes, repairs, revives or matchmaking advantages. Premium captains are excluded.
> 4. **No pressure mechanics.** No energy or refilling attack charges, no time-limited exclusive rewards. A player can never be raided to zero: protected storage and a daily loss cap always apply.
> 5. **Fair power.** Matchmaking is banded by Harbour Level, trophies and power. Real-time modes are level-normalized.
> 6. **Deterministic adjudication.** PvP outcomes are decided only by the deterministic combat core, never by the campaign's physics sim.
>
> Replace "No Multiplayer / No PvP / Never introduce multiplayer" with: "Never introduce multiplayer outside the Multiplayer Charter."

Also amend `docs/17_MONETIZATION.md`:
- §4.4: the no-anti-cheat stance applies to the campaign only.
- The "Paid power in any competitive context" row now applies to the Harbour.

Update the risk row in `docs/15_MASTER_PLAN.md` and the "Out of Scope (Version 1)" list.

## 10. Phased delivery

| Phase | Scope | Exit criterion | Risk |
|---|---|---|---|
| 0 (1–2 wk) | Charter amendment; SupabaseHttp refactor; balance export and parity test; named island sockets; cascade foreign keys; decide Option S | Tests green; owner signs the charter | Low |
| 1 (4–6 wk) | Harbour tables and RPCs (build, upgrade, collect, jobs, islands, fleet); `HarbourWorld` scene reading server state | Editing local files changes nothing in the Harbour; online-only UX is clear | Medium (server clock, offline messaging) |
| 2 (5–7 wk) | Combat core sim, presenter, `SimDefenseAI`, `SnapshotIsland`; raids against Phantom Harbours with tickets, settle and minted loot | Same hash on 3+ devices across ARM and x86; feel is close to campaign combat | **High** (sim rewrite, game-feel parity) |
| 3 (3–4 wk) | Real async PvP: matchmaking, loot transfer, shields, trophies, defense log, Realtime notify, plausibility checks, rate limits, revenge | Closed beta of 50–200; star distribution per HL pair within target; loot/production ratio 1.0–1.5 | Medium (population size → Phantom fallback) |
| 4 (2–3 wk) | Headless verifier on Fly.io, reversals, shadow pool, FCM push | Mismatch rate < 0.5% on honest builds | Medium |
| 5 (6+ wk, gated) | Real-time 1v1 brawl over Realtime broadcast in lockstep; dedicated relay later | Desync rate < 1%; p95 input delay < 250 ms | High |
| 6 (optional) | Option U unified empire via the shadow, dual-write, per-domain flip migration | Only if the owner wants campaign islands to be the PvP base | High |

**Top risks:**
1. Getting the combat core to feel like the RigidBody combat.
2. Beta population too small for real matchmaking (Phantom Harbours are mandatory).
3. Fixed-point determinism in GDScript (avoid floats in the sim entirely).
4. A loot/production imbalance that kills either building or raiding (watch the `economy_tx` dashboards and tune via `balance_tables`).
5. Players misreading online-only Harbour as breaking the offline promise (state it clearly in the UI).

### Critical Files for Implementation
- D:\Pirate-game\supabase\schema.sql
- D:\Pirate-game\scripts\managers\SaveManager.gd
- D:\Pirate-game\scripts\managers\OwnedShipData.gd
- D:\Pirate-game\scripts\world\Island.gd
- D:\Pirate-game\scripts\world\ShipCombat.gd
- D:\Pirate-game\AGENTS.md
- D:\Pirate-game\docs\17_MONETIZATION.md
- D:\Pirate-game\supabase\functions\delete-account\index.ts