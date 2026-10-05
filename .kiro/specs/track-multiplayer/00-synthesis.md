> Raw design input for the MULTIPLAYER track (MP-0..MP-4), produced 2026-10-05 by a read-only design panel (workflow wf_95a5d2d8-2d0). NOT an approved spec: it gets its own planning pass after M31. Owner vision: CoC-style 5-12 island home base + global brawl; PvP loot/ship-power math managed.

# Pirate Empire: Multiplayer Plan (Harbour realm, PvP raids, Brawl)

**Short answer to the owner's question (how much players can loot, and how strong ships can be):**

- **Loot comes in two parts.** A fair 2-star raid pays about **38 minutes of the attacker's own production**:
  - about 14 minutes is taken from the defender;
  - about 24 minutes is a Bounty the server creates, so nobody loses it.
- **Defenders have hard limits.** A defender can never lose more than **20% of their storage cap per day**. Their protected vault and shields always apply.
- **Ship strength is capped.**
  - A Power Rating (PR) makes fleets of different ships comparable (§5.2).
  - A Fleet Point (FP) budget caps fleet size, and a stat cap is set by each player's Harbour Level (HL), the PvP equivalent of a town-hall level.
  - Players of the same HL differ by **at most 1.3x to 2.0x** in fleet strength. Today's spread between a fresh Sloop and a maxed Man O'War is about 84x.
  - Matchmaking only pairs fleets and bases that are within about ±25% of each other in strength.

All numbers below are placeholders. They go in `resources/balance/PvpBalance.tres`, are exported to a server-side `balance_tables` row, and are checked by `tests/test_pvp_balance.gd`.

## Where the three specialist reports disagreed, and what this plan picks

| Question | Options | Decision |
|---|---|---|
| What is the PvP base? | Use the campaign islands ("one empire", from game-design) **or** a separate server-owned **Harbour** realm (from architecture) | **A separate Harbour realm.** The campaign stays offline and on the device. The Harbour is a 5–12 island archipelago built from the same island scenes, buildings and hulls, and it is server-authoritative from day one. Making one shared empire stays possible later as MP-6. |
| How is ship power normalised? | Shrink campaign stats by rank (game-design), match on raw progression (pvp-math), or a berth system (architecture) | **Harbour progression plus a stat cap per HL plus an FP budget.** The Harbour has its own progression curve, so the campaign's 84x spread never reaches PvP. |
| What is the loot model? | Three different formulas | **One formula in minutes of production (MoP):** a capped amount taken from the defender plus a larger Bounty the server creates (§5.1). |
| Does the raid fight need a new deterministic combat engine first? | Required before any raid (architecture) | **No.** Raids use the existing combat with server-side plausibility checks and hard loot caps. The deterministic engine is required only for real-time Brawl and for re-running replays to verify them. |
| Can Eights cover resource shortfalls? | Turn it off everywhere, or keep it | **The Harbour has no Eights path at all.** Campaign shortfall cover stays. It can't leak into PvP, because campaign progress reaches the Harbour only through one-time grants with a fixed total. |

---

## 1. The design on one page

**Home archipelago (the Harbour)**
- Each player who raises the "Black Flag" opt-in gets a Harbour.
- Islands = 4 + HL, so 5 islands at HL1 and 12 at HL8. The templates are the 11 authored islands plus one new "Haven" capital (owner art).
- Players choose which named socket each building goes in. They also choose battery types and facings for each island (the "Harbour Plan").
- It uses the same 10 building types and the same hulls. The data comes from the same `.tres` files, and a parity test checks the server copy matches.
- Production is worked out lazily on the server each time the player makes a request. Timers run on the server clock.
- Builder count comes from HL only: 2, then 3 at HL3, then 4 at HL6. Builders can never be bought.
- The Harbour is online-only, and the UI says so.

**Moving between campaign and Harbour**
- Harbour rewards may flow into the campaign.
- Campaign progress reaches the Harbour only through fixed one-time grants per milestone (table `campaign_milestone_claims`). Examples: `chapter_2_complete` gives a 60-minute resource pack and a hull blueprint; recruited captains join the Harbour roster with normalised stats.
- A cheater who edits their campaign save gets exactly what an honest finisher gets.

**Async island raids (the core mode, ships first)**
1. Scout the defender's chart and pick one island. The scout card shows the defender's strength estimate and the lootable amount.
2. The server issues a signed attack ticket. Inside it, the attacker's ship stats are the server-computed, capped values.
3. The fight lasts 3 minutes, with at most 4 attacking hulls, 3 guard ships (snapshot copies) and up to 6 shore batteries.
4. Stars: 1★ = 50% weighted destruction; 2★ = the Governor's Flagstaff taken by a landing party (uses the boarding system); 3★ = 100% destruction.
5. The client submits its result. The server checks plausibility, settles the raid in one transaction, and notifies the defender over Supabase Realtime.
6. **Phantom raids ship first.** They attack authored or AI snapshots, loot is created only, and nobody loses anything. They are also the fallback whenever matchmaking finds no live target. A beta-sized player base cannot work without them.

**Global brawl**
- **Ships second, as async Ghost Fleet Duels.** A player publishes a fleet plus "Battle Orders" (formation, target priority, when to fire the captain ability). The challenger fights it as AI.
- Stats are fully standardised ("Articles of War"). It has its own trophy ladder. Prizes are trophies, a small created Bounty and cosmetics, never resources taken from a player.
- Real-time 1v1 is MP-5, gated on a deterministic combat engine and enough concurrent players.

**Fleet protection**
- Ships are never permanently lost in PvP. Sunk ships repair on a timer.
- Guard ships are copies and never take real damage.
- The ship you sail in the campaign can never be attacked. There is no open-world PvP.
- Convoy Hunts are optional and come later.

---

## 2. Proposed AGENTS.md amendment

Replace the "No Multiplayer / No PvP" lines (224–228), the "Future Multiplayer Philosophy" section (674–682), "Never introduce multiplayer." (785), and PvP / Real-time Multiplayer in the out-of-scope list (830–842). Record the change in `docs/DECISIONS.md`.

> **Multiplayer Charter (Amendment 1, adopted 2026-10).**
> The single-player campaign stays offline-first, playable forever without an account, and completable and fair without ever touching PvP. Multiplayer exists only inside the separately scoped **Harbour** realm, under these rules:
> 1. **Opt-in.** A player who has not raised the Black Flag can never be attacked by another player. Opting out has a 72-hour cooldown.
> 2. **Server authority.** Every value another player can take, see or be matched against (Harbour resources, buildings, sockets, timers, fleet, batteries, trophies, shields) is stored in Postgres and changed only by server functions. The client never writes it. Loot is computed only on the server.
> 3. **Isolation.** Campaign state reaches the Harbour only through enumerated one-time grants with a known total. Harbour rewards may flow into the campaign.
> 4. **Bounded loss.** PvP can only take capped amounts of unprotected gold, wood, iron and rum. It can never take Eights, research, Hold contents, ships, captains, buildings or cosmetics. A protected vault and a daily loss cap always apply, so no player can be raided to zero.
> 5. **Normalised power.** PvP strength is limited by a Harbour Level stat cap and a Fleet Point budget, and matchmaking is banded by power and trophies. Brawl uses fully standardised stats. Harbour Level is earned only through play.
> 6. **No paid advantage.** Pieces of Eight and ads buy nothing in the Harbour except cosmetics: no shields, ships, troops, resources, builder slots, timer finishes, repairs, provisions, skips or rank. Premium captains are excluded from Harbour rosters.
> 7. **No pressure mechanics.** No energy or attack charges. Season rewards are based on the peak league reached. Season cosmetics can be earned again later.
> 8. **Adjudication.** Async results are claims that the server checks against plausibility bounds and caps. Real-time PvP needs a deterministic combat engine or an authoritative server, plus an approved decision record.
> 9. **Data-driven.** Every PvP number lives in `.tres` files and `balance_tables`, and must pass `tests/test_pvp_balance.gd`.
>
> Replace "Never introduce multiplayer." with "Never introduce multiplayer outside the Multiplayer Charter."

**Other documents to amend at the same time:**
- `docs/17_MONETIZATION.md`:
  - §4.4: the "not server-authoritative / no anti-cheat" stance applies to the campaign only.
  - The "paid power in any competitive context" row now covers the Harbour.
- `docs/00_VISION.md` §19.2: state that the PvE power ceiling does not apply in the Harbour, because the Harbour has no Eights path.
- `docs/15_MASTER_PLAN.md`: update the risk row and the out-of-scope list.
- `docs/05_CURRENT_SYSTEMS.md`: add a Harbour section when MP-1 lands.

---

## 3. Prerequisites (single-player and backend work before MP-1)

Some of these are bugs, which can go into the current stabilisation milestone (M29). The rest go in MP-0.

| # | Item | Where | Why PvP needs it |
|---|---|---|---|
| P1 | AI raids must stop stealing `eights` and `research` | `scripts/managers/EmpireManager.gd:323-328` (loops every key of `ResourceManager.current_resources`) | Breaks the "purchases never destroyed" rule today. It is also the pattern a PvP loot path would copy. |
| P2 | Wire `TechManager.global_storage_mod` into `ResourceManager.recalculate_storage_capacity()` | `TechManager.gd:106`, `ResourceManager.gd` | Protected and exposed loot are both computed from the storage cap. |
| P3 | Economy pass: storage ≈ 3 hours of production (±1h); every cost ≤ the reachable cap | M33 balance pass; `resources/buildings/*.tres`, `ResourceManager.gd:33`, `Island.gd:222` | Today gold fills in about 9 minutes, and the Man O'War costs 28,000 against a 27,500 cap. Loot measured in minutes of production needs a sane storage-to-production ratio. The Harbour reads the same building data. |
| P4 | Brigantine HP 150 → 190 (PR 59 → 66) | `resources/ships/Brigantine.tres` | Today it is strictly worse than the Corvette, so nobody would field it. |
| P5 | Named, stable building sockets plus player-chosen placement | Each authored island's `Buildings/BuildingSlots` Marker3Ds; `Island.gd:403/440/513` (slot = array index today); save `_migrate` step mapping old index → socket name | The server stores `socket_id`. Layout choice is the base-building game. |
| P6 | Shore batteries, Fortress/Watchtower batteries and the Harbour Plan (from the single-player depth plan) | ShipDamage + ShipCombat + FiringSolver StaticBody | The Raid Arena reuses these directly. |
| P7 | `PowerRating.gd` (pure static: ship PR, fleet strength FR, defence strength D) plus balance lint | `scripts/systems/PowerRating.gd`, `tests/test_pvp_balance.gd` | Matchmaking, scout cards, plausibility checks and lint all depend on it. |
| P8 | Inject a seeded `RandomNumberGenerator` into ShipCombat spread and misfire (replacing global `randf/randfn`) | `scripts/world/ShipCombat.gd` | Cheap. Makes raids reproducible on one device, and is a stepping stone to the deterministic engine. |
| P9 | Shared `scripts/net/SupabaseHttp.gd` (one request function, retry on 401, test hook) | Dedupe `_send_cloud_request` in SaveManager, EntitlementManager, RemoteConfigManager | The "no duplicate systems" rule. HarbourService would otherwise be a 4th copy. |
| P10 | Cascading account deletion | `supabase/schema.sql` (FKs `on delete cascade`), `supabase/functions/delete-account/index.ts` | Every new table must be removed when an account is deleted. |
| P11 | Balance export tool (`.tres` → JSON) plus a parity test that `OwnedShipData.get_effective_stats()` matches the export | `tools/export_balance.gd`, `tests/test_balance_parity.gd` | The server needs one source of truth for stats. |
| P12 | SelfPlayHarness headless batch mode with star-rate statistics | `scripts/debug/SelfPlayHarness.gd` | The physics isn't deterministic, so tuning has to be statistical. |
| P13 (optional) | Cap captain level at 20 and make levels worth +2% | `scripts/world/CaptainData.gd:46-55` (uncapped, +0.1 per level) | Not blocking, because Harbour captains are normalised and captain level is ignored. Fixes campaign runaway. |

**What is deliberately not a prerequisite:** moving the campaign wallet or economy to the server.
- Under the Harbour design, the campaign `player_saves` row, `SAVE_SCHEMA_VERSION` and Eights stay exactly as they are.
- Nothing migrates, so no player progress can be lost.
- Eights can't affect PvP, because the Harbour accepts no Eights.

---

## 4. Phased milestones

Scaffold each with the `spec-new` skill as `.kiro/specs/milestone-mpN-<slug>/`. These run after the M35 Launch Gate unless the owner reorders. P1, P2 and P4 can land now.

### MP-0: Charter and foundations (1–2 weeks)
- [ ] Charter amendment in AGENTS.md, a DECISIONS.md entry, and edits to docs 17, 00 and 15. **Owner signs off.**
- [ ] P1–P2 and P4–P12 from §3, each with GUT tests:
  - `test_raid_never_takes_premium.gd`
  - `test_storage_tech_applies.gd`
  - `test_socket_migration.gd`
  - `test_power_rating.gd`
  - `test_pvp_balance.gd` (invariants in §5.8)
  - `test_balance_parity.gd`
- [ ] Create `resources/balance/PvpBalance.tres` (script `scripts/balance/PvpBalanceData.gd`) holding every table in §5.
- [ ] Supabase: move to the Pro plan before MP-2 (see risks). Create the `balance_tables` and `profiles` tables.
- **Exit:** tests green; lint passes; old saves load and migrate to named sockets with nothing lost.

### MP-1: Home archipelago on the server (4–6 weeks)
- [ ] **Tables** (RLS on; players can read only their own rows; no client write policies; FKs cascade):
  - `harbour_state`
  - `harbour_ledger` (`check stash >= 0`)
  - `harbour_islands`
  - `harbour_buildings` (unique `user_id, island_slot, socket_id`)
  - `harbour_jobs`
  - `harbour_ships`
  - `harbour_battery_plan`
  - `economy_tx` (append-only)
  - `campaign_milestone_claims`
  - `rate_limits`
- [ ] **Public RPCs** (`SECURITY DEFINER`, `auth.uid()`, `set search_path = public`, idempotency key, rate limit):
  - `harbour_bootstrap`, `harbour_sync`
  - `harbour_start_build(island_slot, socket_id, type)`, `harbour_start_upgrade`
  - `harbour_unlock_island`, `harbour_upgrade_hl`
  - `harbour_set_battery_plan`
  - `harbour_build_ship`, `harbour_upgrade_ship`, `harbour_assign_fleet`
  - `harbour_claim_milestone`
- [ ] **Internal function** `_harbour_resolve(uid)`, run at the start of every RPC: complete due jobs, then `stash += min(cap − stash, rate × Δt)`.
- [ ] `_publish_defense_snapshot(uid)`: immutable, versioned jsonb; a trigger blocks UPDATE and DELETE.
- [ ] **Client:**
  - `HarbourService` autoload (typed RPC wrappers over SupabaseHttp, server-clock offset from the `Date` header, read-only `HarbourState` cache).
  - `scenes/modes/HarbourWorld.tscn` plus `scripts/modes/Harbour*.gd`, following the Maelstrom precedent.
  - The scene is not named "World" (so SaveManager doesn't autosave), and its islands **never join the `"islands"` group**, which would change the player's storage caps.
  - Reuse the building and IslandMenu panels through an `EconomyBackend` interface: `LocalBackend` for the campaign, `HarbourBackend` for RPCs. This avoids a second UI.
- [ ] Update `delete-account`.
- **Exit:**
  - Editing local files changes nothing in the Harbour.
  - A pgTAP or SQL test suite passes on a local Supabase stack.
  - The online-only UX is clear.

### MP-2: Raid Arena and Phantom raids (4–6 weeks)
- [ ] **`SnapshotIsland.build(payload)`:**
  - Instances the island template and places buildings by named socket (display only, no `Island.gd` economy).
  - Spawns batteries from the battery plan and guard ships with ticket stats.
  - Applies `PVP_DAMAGE_SCALAR`.
- [ ] **`RaidArena.tscn`:** a bounded sea with a 3:00 timer, star tracking, the Flagstaff objective (boarding/landing) and landmarks.
- [ ] **Edge Function `raid-start`:**
  - Verify the JWT and rate limit (20 tickets per hour).
  - Matchmake (this phase: Phantom only).
  - Insert an `attack_tickets` row (seed, snapshot_id, server-computed attacker stats, loot cap, `expires_at = now()+240s`).
  - Return an HMAC-signed ticket.
- [ ] **Edge Function `raid-submit`:** verify the signature and that the ticket is unused, then call `_settle_raid`. It returns a signed URL for uploading the replay to the private `replays` bucket. Replays are event logs: 5 Hz positions plus shots, ≤40 KB.
- [ ] **`_settle_raid` transaction:**
  - Consume the ticket.
  - Plausibility checks (§6 R1).
  - Lock both ledgers in fixed order with `FOR UPDATE`.
  - Apply the §5.1 formulas.
  - Write `economy_tx`, then `raid_results`.
- [ ] Create `phantom_harbours` with authored snapshots per HL and a daily cap on created loot.
- [ ] Telemetry views: star rate per (HL, x) bucket, MoP earned per raid, created resources per day.
- **Exit:**
  - At x ≈ 1.0, ≥2★ happens 50–60% of the time (SelfPlayHarness first, then beta telemetry).
  - Median raid ≤ 4 minutes.
  - 7 hulls plus 6 batteries run at ≥ 20 FPS on the reference device.

### MP-3: Live raids, shields, trophies, defence log, revenge (3–5 weeks, closed beta of 50–200)
- [ ] **Black Flag.**
  - Toggle: `harbour_set_black_flag`, with a 72h truce when first raised and a 72h opt-out cooldown.
  - New-player protection: 72h or HL < 2.
- [ ] **Matchmaking:** `_find_raid_target` using §5.6 with `for update skip locked`; widening steps, then Phantom fallback.
  - Index on `(harbour_level, trophies, shield_until)`.
  - Skips: 3 free, then 50 × HL gold.
- [ ] **Locks and cleanup:** `attack_lock_until`; a pg_cron job every minute to expire tickets and release locks.
- [ ] **Loot:** transfers with the defender's daily room, defence bounty and salvage. Shields per §5.4; trophies and leagues per §5.7.
- [ ] **Defence log and revenge.**
  - Defence log: `harbour_defense_log(limit)`. The log screen opens with what the defender **earned**.
  - Revenge: one revenge ticket per incoming raid.
  - Realtime Postgres Changes on `raid_results`, filtered by `defender_id`.
- [ ] **Anti-cheat records:** a `cheat_flags` table; `profiles.shadow_pool` (flagged accounts only matched with each other); client build allowlist in `remote_config`.
- **Exit:**
  - Fewer than 5% of defenders lose more than 15 minutes of production per day.
  - Loot ÷ production per raid stays in band.
  - No unexplained jumps in the `economy_tx` totals.

### MP-4: Leagues (seasons), Ghost Fleet Duels, verification (4–6 weeks)
- [ ] **Seasons ("Tides"):** 5 weeks; peak-league rewards; soft reset; Tide Archive so cosmetics can be earned again.
- [ ] **Ghost Fleet Duels:** `duel_publish(fleet, battle_orders)`, `duel-start` and `duel-submit` Edge Functions, a separate trophy column, Articles of War stats (§5.5).
- [ ] **Deterministic combat engine `scripts/pvp/sim/`:**
  - Pure RefCounted classes: `SimWorld`, `SimShip`, `SimBattery`, `SimProjectile`, `SimRng` (PCG32), `FixedMath` (int64, 1/1000 m units), `SimInputFrame`, `ReplayCodec`.
  - `SimPresenter` maps the engine's state onto the existing hull visuals, with buoyancy as visuals only.
  - Used first for duels, where AI vs AI can be re-run on the server.
- [ ] **Headless verifier** (Godot on Fly.io). It re-runs every 3★ raid, the top 5% by loot and all flagged accounts, then calls `raid-verify`. Mismatches trigger `_reverse_raid`.
- [ ] **Push notifications:** FCM for defences.
- **Exit:** duel queue under 10 seconds; verifier mismatch rate under 0.5% on honest builds.

### MP-5: Real-time Brawl (gated, 6+ weeks)
- **Gate:**
  - The deterministic engine gives the same hash on 3+ ARM and x86 devices.
  - Enough concurrent players to fill queues.
  - A server budget is approved.
  - A DECISIONS.md record exists.
- [ ] Delay-based lockstep at a 10 Hz input rate over Supabase Realtime broadcast, with a state hash exchanged every second. Move to a WebSocket relay on Fly.io when volume justifies it.
- [ ] Tables and functions: `brawl_matches`, `brawl-queue`, `brawl-result` (hashes must agree; otherwise the verifier decides).
- **Exit:** desync rate under 1%; p95 input delay under 250 ms.

### MP-6 (optional): one shared empire
Make the campaign islands the PvP base by moving one data area at a time: a shadow ledger first, then writing to both, then moving authority for resources, then buildings and timers, then fleet. Keep originals in `migration_archive`. Only do this if the owner wants it.

---

## 5. PvP balance sheet (what goes in PvpBalance.tres)

### 5.1 Loot (per resource r ∈ {gold, wood, iron, rum})

```
MoP_r(HL)    = reference production per minute at that HL (exported from building .tres at expected levels)
Cap_r        target ≈ 180 MoP (3h), lint band 120–240
Vault(WL)    = no Warehouse .30, L1 .35, L2 .40, L3 .45, L4 .50, L5 .55   (best Warehouse in the Harbour)
Protected_r  = min(Stored_r, Vault × Cap_r)
Exposed_r    = Stored_r − Protected_r
w_i          = StorageCap_on_island_i / Σ StorageCap   (base cap split evenly; Warehouses add to their own island)
σ(stars)     = 0★: min(0.10, 0.25 × destruction), 1★ .40, 2★ .70, 3★ 1.00
LDF(ΔHL)     = HL_att − HL_def: ≤−1 → 1.15 ; 0 → 1.00 ; +1 → 0.70 ; ≥+2 → revenge only, 0.40
Transfer_r   = min( Exposed_r × w_i × σ × LDF ,  RaidCap_r = 30 × MoP_r(HL_def) ,  DailyRoom_r )
DailyRoom_r  = max(0, 0.20 × Cap_r(def) − losses_r in rolling 24h)
Bounty_r     = MoP_r(HL_att) × B(★) × League × Taper × LDF          (created by the server)
               B: 0★ 0, 1★ 10, 2★ 20, 3★ 30 minutes; Taper: first 8 wins/day 1.0, later 0.25; revenge ×1.25
Attacker credit is limited to free storage (overflow is lost)
DefenseBounty = MoP(HL_def) × 10 min × League when the attacker gets ≤1★ (created; max 3 per day)
Salvage      = 5% of the gold cost of each attacker hull sunk, paid to the defender as wood and iron (created)
Provisions   = 6 rum per FP fielded, paid at launch, kept even on failure
Repairs      = 10% × hull gold cost × damage fraction; timer 0.5 s per HP lost, −8% per Shipyard level; never Eights
Phantom raid = Bounty × 0.70, Transfer 0
Never lootable: eights, research, Hold/relics, cosmetics, ships, captains, resources committed to running jobs
```

**Worked example at HL5, equal HL, Silver league (×1.2).** Placeholders: gold MoP = 100 g/min; Cap 18,000; Stored 16,000; Warehouse L3 (vault 0.45).

| Line | Amount |
|---|---|
| Protected | 8,100 |
| Exposed | 7,900 |
| Share held by the target island (w) | 0.25 |
| 2★ Transfer | 1,383 g (≈14 MoP; below the 3,000 raid cap) |
| 2★ Bounty | 2,400 |
| **2★ gross** | **≈3,780 g ≈ 38 MoP** |
| Costs (38 FP: 228 rum and about 1,000 g repairs) | net ≈ **+28 MoP** |
| 0★ | ≈ −10 MoP net |
| 3★ gross | ≈ 56 MoP |
| Defender's worst day | ≤ 3,600 g (36 MoP), partly offset by defence bounties |

**Calibration targets:**
- Fair 2★ net is between +20 and +35 MoP.
- 0★ net is negative.
- PvP supplies 20–40% of an engaged player's Harbour income.
- Created resources are ≤ 40% of total Harbour income.
- **Optional "Cutthroat" preset** from Captain league up: Vault −0.10, σ ×1.25. This is an owner decision.

### 5.2 Ship strength (Power Rating)

- Ship PR: `r = √(EHP × DPS_side)`, where `DPS_side = guns_per_side × damage × volleys per second`. This follows Lanchester's square law, so the r values of a fleet's ships simply add up.
- Fleet strength: `FR = Σ r_i`.
- Fleet Point cost: `FP ≈ r / 7.34`.
- Harbour stats: `m_hp = min(Π HP multipliers, StatCap[HL])` and `m_dps = min(Π DPS multipliers including guns_eff/guns_base, StatCap[HL])`.
  - The multipliers come from ship level, components, modules and Harbour techs (≤ 1.25 total).
  - Captains are reshaped so damage × HP = 1.0, and captain level is ignored.
  - Small hulls with the +4-gun bonus reach the cap sooner but can never exceed it.
- `PVP_DAMAGE_SCALAR = 0.6`. Target time-to-kill against a ship of equal strength is 20–40 seconds (Sloop vs Sloop ≈ 31 s).

| Hull | Dinghy | Sloop | Schooner | Corvette | Brigantine (fixed) | Frigate | Galleon | Man O'War |
|---|---|---|---|---|---|---|---|---|
| Base r | 21.2 | 36.7 | 44.3 | 55.3 | 66.2 | 93.0 | 125.5 | 189.7 |
| FP | 3 | 5 | 6 | 8 | 9 | 13 | 17 | 26 |
| r per FP | 7.07 | 7.34 | 7.38 | 6.91 | 7.36 | 7.15 | 7.38 | 7.30 |

### 5.3 Harbour Level bands

| HL | Islands | FP budget | Max attack hulls | Largest hull | StatCap per stat | Fortress cap | Guards (max hulls / FP) | FR fresh → max | D_target |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 14 | 3 | Corvette | 1.30 | L1 | 1 / 7 | 103 → 134 | 118 |
| 2 | 6 | 18 | 3 | Brigantine | 1.40 | L2 | 1 / 9 | 132 → 185 | 159 |
| 3 | 7 | 24 | 4 | Frigate | 1.50 | L2 | 2 / 12 | 176 → 264 | 220 |
| 4 | 8 | 30 | 4 | Frigate | 1.60 | L3 | 2 / 15 | 220 → 352 | 286 |
| 5 | 9 | 38 | 4 | Galleon | 1.70 | L3 | 2 / 19 | 279 → 474 | 377 |
| 6 | 10 | 46 | 4 | Galleon | 1.80 | L4 | 3 / 23 | 338 → 608 | 473 |
| 7 | 11 | 56 | 4 | Man O'War | 1.90 | L5 | 3 / 28 | 411 → 781 | 596 |
| 8 | 12 | 66 | 4 | Man O'War | 2.00 | L5 | 3 / 33 | 484 → 969 | 727 |

**Defence strength:** `D = Σ r_battery + 0.8 × Σ r_guard`. Guards may supply at most 40% of D. Target `D_target = FP × 7.34 × (1 + StatCap) / 2`.

**Batteries:**
- Batteries per island = Fortress level + 1, from 2 up to 6 sockets.
- Base r per battery by Fortress level: F1 30, F2 34, F3 40, F4 48, F5 56. Upgrades multiply this, up to ×StatCap.
- Battery types are sidegrades with equal r at each level: Culverin (long range, low DPS), Mortar (high DPS, minimum range), Carronade (short range).
- Stone takes Round shot at ×0.5.
- Watchtower: +10% range per level, and more detail on the scout card.

**Harbour Plan facing (used for the scout card estimate):** `D_face = D × (s_face + 0.5 × Σ s_adjacent + 0.25 × s_opposite) / 0.5625`, where s is the share of batteries facing each way. A balanced plan scores 1.0 on every face. Stacking every battery on one face scores 1.78 / 0.89 / 0.44. The weakest face must stay ≥ 0.35 × D.

**Target star rates by x = FR_att / D_def:**

| x | ≥1★ | ≥2★ | 3★ |
|---|---|---|---|
| 0.6 | 35% | 10% | 1% |
| 0.8 | 65% | 30% | 4% |
| 1.0 | 85% | 55% | 12% |
| 1.2 | 95% | 75% | 30% |
| 1.5 | 99% | 90% | 55% |

Tolerance is ±7 percentage points. Fair raids should last 60–150 seconds.

### 5.4 Shields and protection

| Rule | Value |
|---|---|
| Shield after a defence | <40% destruction and 0★: none, plus a 30-minute guard against the same attacker. 1★ or ≥40%: 8h. 2★: 12h. 3★: 14h. |
| Guard window | 30 minutes after each shield ends |
| First Black Flag | 72h truce |
| Attacking a live target while shielded | costs 3h of your own shield (Phantom raids cost nothing) |
| Incoming raid limit | at most 3 per rolling 24h (backstop) |
| Same attacker/defender pair | 1 raid per 24h |
| Inactive more than 14 days | moved to the Phantom pool (can be raided, loses nothing) |
| Buying shields | **never possible** |

### 5.5 Brawl ("Articles of War" standard)

- Every hull is set to fixed stat multipliers of 1.50 HP and 1.50 DPS. Techs are off.
- Each ship takes 2 modules, chosen from a list of sidegrades.
- Captain passives are reshaped so damage × HP = 1.0; abilities are kept.
- Budget: 40 FP, at most 3 hulls.
- Only hulls and captains the player has unlocked can be used. Unlocks are a collection, not extra power.
- Rewards: trophies, a created Bounty of MoP × 8 × League (8 wins per day at full value), and cosmetics.

### 5.6 Matchmaking

- **Eligible defender:** Black Flag on; no shield, guard or lock; offline for 3 minutes or more; past new-player protection; same shadow-pool status as the attacker; not raided by this attacker in the last 24h; snapshot no older than 7 days.
- **Band:** |ΔHL| ≤ 1, x ∈ [0.85, 1.25], |ΔT| ≤ 200.
- **Widening:** each step adds ±100 trophies and ±0.05 on x. Hard limits are x ∈ [0.6, 1.6] and 3 steps. After that, serve a Phantom raid.

### 5.7 Trophies ("Infamy")

- Expected score: `E = 1 / (1 + 10^((T_d − T_a) / 400))`.
- Actual score S: 0★ = 0, 1★ = 0.4, 2★ = 0.75, 3★ = 1.
- Attacker change: `ΔT_a = round(40 × (S − E))`. Defender change: `ΔT_d = −0.75 × ΔT_a`.
- Leagues:

  | League | Driftwood | Bronze | Silver | Gold | Captain | Commodore | Admiral | Pirate Lord |
  |---|---|---|---|---|---|---|---|---|
  | Trophy floor | 0 | 400 | 800 | 1200 | 1600 | 2000 | 2400 | 2800 |
  | Loot multiplier | 1.0 | 1.1 | 1.2 | 1.3 | 1.4 | 1.45 | 1.5 | 1.6 |

- Players at Silver or below can't drop below their league floor.
- Season soft reset: above 1600, `T = 1600 + 0.5 × (T − 1600)`.
- Revenge trophies count at 50%.

### 5.8 Balance-lint invariants (`tests/test_pvp_balance.gd`)

1. r per FP is within ±10% of the median for every hull, at base stats and at the cap.
2. r rises strictly with hull class, and each step is at least ×1.15.
3. Within one HL, fresh vs capped FR ≤ StatCap.
4. Transfer per raid ≤ 30 MoP. Transfer + Bounty ≤ 80 MoP. Defender daily loss ≤ 20% of Cap. This holds for every Warehouse level and HL.
5. Vault never decreases with Warehouse level and never exceeds 0.55.
6. LDF never increases as ΔHL grows.
7. Expected net of a fair 2★ > 0; expected net of a 0★ < 0.
8. Full-budget provisions ≤ 50% of the rum cap for every HL.
9. D_target / FR_typical ∈ [0.9, 1.1]. Any Harbour Plan leaves its weakest face ≥ 0.35 × D.
10. Attack hulls + guard hulls ≤ 7 and batteries ≤ 6 for every HL.
11. No loot path contains `eights` or `research`. No store product, Eights path or ad reward reaches any Harbour RPC.
12. Shield length never decreases with destruction, and no shield source can be bought.
13. Every Brawl captain has damage × HP = 1.0.
14. Every Harbour cost ≤ the reachable cap at its HL.

---

## 6. Top risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | **Cheating.** The client reports raid results, and campaign saves are editable. | Harbour state is written only by the server, and RLS allows no client writes. Tickets are signed, single-use and expire after 240 s. Ship stats come from the server, not the client. **Plausibility checks:** `duration ≤ ttl`; destroyed HP ≤ Σ DPS × duration × 1.1; per-building earliest kill time; stars consistent with destruction; lost ships ⊆ roster; build allowlist. Every raid is capped by the per-raid limit and the defender's daily room, so even a perfect cheat is bounded to about 30 MoP per raid. Further layers: shadow pool, reversal transactions, the MP-4 verifier, optional Play Integrity. Campaign edits only matter through fixed one-time grants. |
| R2 | **Physics is not deterministic** (RigidBody, buoyancy, global RNG, raycast AI). | Async raids don't need determinism; checks are by plausibility. The seeded RNG (P8) makes runs reproducible on one device. The deterministic engine (MP-4) is a hard gate for real-time Brawl and for re-running replays. A determinism canary compares hashes of a bundled replay on beta devices. |
| R3 | **Server cost.** | Production is computed lazily, with no cron tick. Replays are event logs of ≤40 KB. The verifier samples raids rather than re-running all of them (one shared-CPU machine). Real-time Brawl is gated. Watch Edge Function invocations and Realtime message counts. Figures are estimates; check current pricing. |
| R4 | **Supabase free tier pauses** an inactive project after about a week, and has small database, storage and Realtime quotas. | Move to the Pro plan before MP-2 live tests. Budget for it in MP-0. The client shows a friendly "Harbour unavailable" screen, and the campaign is unaffected. |
| R5 | **Player progress lost in migration.** | The Harbour design migrates no campaign data. The only campaign change is the named-socket `_migrate` step (P5), with a round-trip test on fixture saves. Account deletion cascades. If MP-6 ever happens, keep a `migration_archive` and log every clamp. |
| R6 | **Monetization creep** (shields, timer skips, paid builders). | Charter rules 6 and 7. Lint invariant 11 statically checks that StoreManager, ScheduleManager Eights paths and ad rewards never reach Harbour RPCs. Harbour RPCs have no Eights parameter at all. Owner sign-off is needed for any change. |
| R7 | **Too few beta players to match.** | Phantom raids, the matchmaking fallback, a pool for inactive players, and authored rival snapshots. Ghost Duels against published fleets don't need anyone online. |
| R8 | **Loot or production imbalance** kills either building or raiding. | All numbers sit in `balance_tables`, so they can be tuned without an app release. Dashboards on `economy_tx` show MoP per raid, the share of created resources, and the defender-loss distribution. Gentle tuning comes before Cutthroat. |
| R9 | **Raid Arena performance** at 18–27 FPS. | Hard limits: ≤7 hulls and ≤6 static batteries. Measured on the reference device in the MP-2 exit criteria. |
| R10 | **The server economy rules duplicate the client's** (no-duplicate rule). | One data source (`.tres` → export → `balance_tables`), a parity test, and one shared UI through the `EconomyBackend` interface. |

---

## 7. What can be checked here vs what needs devices, accounts or a server

**Checkable in this repo with headless GUT** (see the `godot-verify` skill; nothing was run during planning):
- Balance lint and PvpBalance data
- PowerRating maths, loot formulas (a GDScript mirror of the SQL, with shared test vectors), shield and trophy formulas
- Socket save migration and parity between `.tres` stats and the export
- The P1 and P2 fixes
- That Harbour scenes never join the `"islands"` group
- That no Eights path reaches Harbour code (static test)
- SelfPlayHarness star-rate statistics, as a first-pass calibration only
- Deterministic engine hash equality on one machine

**Needs a local Supabase stack** (Docker plus Supabase CLI on the developer machine; not done in this session):
- Schema, RLS and RPC tests (pgTAP or `supabase test db`)
- Settlement transaction, locking and deadlock order
- Ticket HMAC, expiry and re-use rejection
- Rate limits and the matchmaking query
- Cascade deletion
- Edge Functions via `supabase functions serve`
- RLS isolation using two test JWTs

**Needs real devices:**
- Raid Arena FPS with 7 hulls and 6 batteries
- Game feel and time-to-kill
- Deterministic engine hashes across ARM and x86 (3+ devices)
- Server-clock offset and the online/offline UX
- FCM push and the Play Integrity verdict
- Realtime latency from the target region

**Needs two or more real accounts, or a closed beta:**
- A live raid end to end (attacker device and defender device)
- Realtime notification to the defender, shields, the guard window and revenge
- Opt-in and opt-out cooldowns
- Matchmaking behaviour with a real population
- Star distribution per (HL, x) and loot ÷ production in the field
- The share of created resources and the defender-loss distribution (MP-3 exit criteria)
- Duel queue time
- Lockstep desync rate and input delay (MP-5)

**Decisions only the owner can make:**
1. Separate Harbour realm (recommended) or one shared empire (MP-6).
2. Sign the Charter wording.
3. Gentle only, or Gentle plus Cutthroat.
4. Art for the 12th "Haven" island.
5. Supabase Pro budget before MP-2.
6. Which campaign milestones grant what in the Harbour.
7. Whether captain level is capped at 20 in the campaign (P13).

### Critical Files for Implementation
- D:\Pirate-game\AGENTS.md (Charter; lines 224–228, 674–682, 785, 830–842)
- D:\Pirate-game\scripts\managers\EmpireManager.gd (raid steals Eights and research at lines 323–328; defence score at line 221)
- D:\Pirate-game\scripts\managers\ResourceManager.gd and D:\Pirate-game\scripts\managers\TechManager.gd (storage caps; unused `global_storage_mod`)
- D:\Pirate-game\scripts\managers\OwnedShipData.gd and D:\Pirate-game\scripts\world\ShipCombat.gd (stats used by PowerRating; global RNG)
- D:\Pirate-game\scripts\world\Island.gd (building slot = array index at lines 403, 440, 513; needs named sockets)
- D:\Pirate-game\supabase\schema.sql and D:\Pirate-game\supabase\functions\delete-account\index.ts (Harbour tables, RPCs, cascades)
- D:\Pirate-game\scripts\managers\SaveManager.gd (HTTP refactor into SupabaseHttp; socket `_migrate` step)
- D:\Pirate-game\docs\17_MONETIZATION.md (§4.4 amendment)