> Raw design input for the MULTIPLAYER track (MP-0..MP-4), produced 2026-10-05 by a read-only design panel (workflow wf_95a5d2d8-2d0). NOT an approved spec: it gets its own planning pass after M31. Owner vision: CoC-style 5-12 island home base + global brawl; PvP loot/ship-power math managed.

# Multiplayer design for Pirate Empire: home archipelago, PvP math and rollout

## 0. Summary

1. **PvP loot is never a transfer of what the defender has stored.** The current economy fills storage in about 10 minutes, so a percentage of storage is too small to matter. The attacker's reward comes in two parts:
   - a capped amount actually taken from the defender;
   - a larger **Bounty** that the server creates, measured in minutes of the attacker's own production.

   Everything is measured in "minutes of production" (MoP), so the PvP numbers stay valid however M31 retunes the economy.
2. **PvP ship strength comes from a compressed, capped stat model, not the campaign numbers.**
   - Today a fresh Sloop and a fully upgraded Man O'War differ by about 84x in combat strength.
   - In PvP, each player's Admiralty Rank sets a cap on the upgrade bonus. Inside one rank, the gap between "fresh" and "maxed" becomes at most 1.4x to 2.1x.
   - Fleet size is limited by a Command Point budget. Matchmaking compares the attacker's fleet strength with the defender's defence strength.
3. **Ship async raids on islands first**, starting with "Phantom" raids where the loot is created and nobody loses anything.
   - The "global brawl" ships first as async **Ghost Fleet Duels** with fully standardised stats.
   - Real-time fleet battles are a later, gated option.
4. **The islands you own in the campaign are your PvP archipelago.** There is one empire, never a second base to build. PvP needs an opt-in ("Black Flag") and never damages the empire beyond the capped loot.
5. **Five problems in today's code break PvP and must be fixed first** (§1.3).

## 1. What the current numbers show

### 1.1 Ship strength spread

I measure combat strength as **Power Rating (PR) = √(EHP × broadside DPS)**.
- EHP is effective hit points; DPS is damage per second (cannon damage × cannons per side × fire rate).
- In a duel, A beats B when hp_A × dps_A > hp_B × dps_B, so the square root of that product is a fair single number.

| Hull | HP | DPS | PR | Gold cost |
|---|---|---|---|---|
| Dinghy | 50 | 9.0 | 21 | 150 |
| Sloop | 100 | 13.5 | 37 | 400 |
| Schooner | 120 | 16.4 | 44 | 1200 |
| Corvette | 140 | 21.8 | 55 | 1800 |
| Brigantine | 150 | 23.1 | 59 | 3000 |
| Frigate | 250 | 34.6 | 93 | 6500 |
| Galleon | 400 | 39.4 | 126 | 14000 |
| Man O'War | 600 | 60.0 | 190 | 28000 |

The upgrade layers multiply HP × DPS by these amounts at maximum:

| Layer | Max multiplier on HP × DPS | Where it comes from |
|---|---|---|
| Ship level 10 | 1.39 | `OwnedShipData.gd:21`, 2% per level |
| Components at level 10 | 4.0 (Man O'War) to 6.2 (Sloop) | Hull +54% HP, cannons ×1.36 damage, ×1.27 fire rate, **+4 guns per side** |
| Modules | 2.22 | Iron Hull 1.35, Swift Loaders 1.3, Master Gunners 1.265 |
| Techs | 4.29 | 2.07 HP × 2.07 damage |
| Captain | Unbounded | See below |

The captain layer has no ceiling. `CaptainData.gd:46-55` adds +0.1 damage and +0.1 health per level, with no level cap. Trade missions give 10 XP every 10-second tick (`FleetManager.gd:103`), which is 3,600 XP per hour. That puts a captain at about level 24 after 8 hours, and Constance's HP × damage at about 13x.

Result:
- A maxed Man O'War with a level-10 Constance reaches PR ≈ 3,100. A fresh Sloop is PR 37, a gap of about **84x**.
- The +4-guns rule more than doubles small hulls: a Sloop goes from 3 to 7 guns per side.

### 1.2 The economy is bound by storage, not production

At level 5, one island makes roughly:
- Market 21,600 gold/h and Tavern 16,200 gold/h;
- Mine 4,320 iron/h;
- Lumber Mill 16,200 wood/h.

Five islands with level-5 Warehouses can store only 27,500 gold, 9,200 wood and 4,600 iron. Gold fills in about 9 minutes and iron in about 13.

So stealing a share of storage is meaningless to both sides. **M31 should hold storage to about 3 hours of production (±1 hour).** That also stops the 4-hour offline catch-up from being wasted.

### 1.3 Problems to fix before any PvP

1. **Raids steal Eights and research.** `EmpireManager._resolve_raid` (`EmpireManager.gd:323-328`) takes a share of every key in `current_resources`, including `eights` and `research`. This breaks the rule in `docs/00_VISION.md` §19.2 that purchased currency is never destroyed.
2. **Storage techs do nothing.** `TechManager.global_storage_mod` is calculated (`TechManager.gd:106`) but nothing reads it. LargerStorage, DeepHold and GrandCargo have no effect.
3. **Some items can only be bought with Eights.** Shortfall cover in `ResourceManager.cover_shortfall_and_spend` ignores the storage cap, so these become reachable only by paying:
   - The Man O'War costs 28,000 gold against a maximum cap of 27,500.
   - Fortress L5 needs 9,000 iron against a cap of 4,600.
   - Fortress L4 needs 4,000 iron, which requires five level-5 Warehouses.

   In PvP this is pay-to-win.
4. **Captain level is uncapped**, and trade income (`10 × cap.level`, `FleetManager.gd:107`) grows with it. Recommendation: cap captains at level 20 and make each level worth +2%.
5. **Players cannot choose where buildings go.** `Island.gd:403` places each building in the next slot by build order. A Clash of Clans-style layout needs the player to pick the slot. Without that, the Harbour Plan battery sockets are the only real defensive choice.

Two further balance issues also need M31 work:
- The Brigantine is beaten by the Corvette on PR per cost.
- `DeathScreen.gd:41` hardcodes a 20% gold penalty.

## 2. Home archipelago (5–12 islands)

**Recommendation: the islands you own in the campaign are your PvP base.** There is no separate "home sea".
- A separate home sea would duplicate the island, building and economy systems (AGENTS.md: never duplicate a system). It would also make single-player players build twice.
- A raid targets **one island** of the defender. That island is loaded alone into a "Raid Arena": its terrain, its buildings in their slots, its Harbour Plan batteries, its guard ships, and a bounded sea.
- This keeps a raid to ≤10 hulls (4 attackers + up to 3 guards) plus ≤3 batteries.
- The scouting view is the campaign chart with the defender's islands highlighted. Each island shows its threat label and how much loot it holds.
- So 5 to 12 islands means 5 to 12 different defensive puzzles. The defender decides where to put Warehouses and Fortresses; the attacker decides which island to hit.

**Island cap by Admiralty Rank (AR): rank N lets you hold N islands.**
- AR1–4 is the campaign onramp (Chapters 1–2).
- PvP unlocks at **AR5** with the 5 launch islands.
- AR6–11 adds the other six authored islands: Blackwater Shoal, Fogbound Cay, Frozen Island, Isla del Rey, Volcano Island and Widow's Reach.
- AR12 adds one authored "Haven" capital island. Procedural generation is out of scope.
- AR goes up only through play: chapter completion, building-level thresholds and PvE "Admiralty Trials". Eights can never raise it.

## 3. PvP power model (how strong ships will be)

### 3.1 Compressed stats

PvP ships are built from the campaign stats, then compressed. All values are placeholders, kept in `.tres` files for M31.

- For each of HP, damage and fire rate: `m_pvp = min(m_total, StatCap[AR])`, where `m_total` is the product of the level, component, module, tech and captain multipliers.
- Extra guns from components are capped at `GunCap[AR]`.
- Captain base modifiers are reshaped so damage × HP = 1.0 (example: Redbeard's 1.2 damage / 0.8 HP becomes 1.12 / 0.89). Captain levels are ignored.
- `PVP_DAMAGE_SCALAR = 0.6`. This sets the time to sink a ship of equal PR under focused fire at about 25–40 seconds, which suits devices running at 18–27 FPS.

### 3.2 Command Points

A fleet has at most 4 ships, and their command cost must fit the rank's budget. Costs are set close to PR/16:

| Hull | Dinghy | Sloop | Schooner | Corvette | Brigantine | Frigate | Galleon | Man O'War |
|---|---|---|---|---|---|---|---|---|
| Command cost | 1 | 2 | 3 | 3 | 4 | 6 | 8 | 11 |

The balance check should require PR per point to stay within ±15% of 16.5. Today it fails for the Dinghy (21) and is borderline for the Schooner and Brigantine (about 14.7).

### 3.3 Rank bands (PvP happens at AR5–12)

| AR | Islands | Command budget | Max hull class | StatCap per stat | GunCap | Effective Fortress cap | Max Fleet Rating |
|---|---|---|---|---|---|---|---|
| 5 | 5 | 12 | 3 (Brig/Frigate) | 1.40 | +1 | L3 | ~277 |
| 6 | 6 | 14 | 3 | 1.50 | +1 | L3 | ~347 |
| 7 | 7 | 16 | 4 (Galleon) | 1.60 | +2 | L4 | ~422 |
| 8 | 8 | 19 | 4 | 1.70 | +2 | L4 | ~533 |
| 9 | 9 | 22 | 5 (Man O'War) | 1.80 | +2 | L5 | ~653 |
| 10 | 10 | 25 | 5 | 1.90 | +3 | L5 | ~784 |
| 11 | 11 | 28 | 5 | 2.00 | +3 | L5 | ~924 |
| 12 | 12 | 30 | 5 | 2.10 | +3 | L5 | ~1040 |

- **Fleet Rating (FR)** = sum of each ship's compressed PR. Its maximum is about budget × 16.5 × StatCap.
- Across the whole PvP range the gap is about 3.75x. Within one rank, fresh versus maxed is at most 1.4–2.1x.
- The Fortress cap only clamps the level used in PvP. Single-player is not gated.

### 3.4 Defence

Fortress level sets the batteries. Watchtower level adds +10% range per level and how much the scouting card reveals. Stone takes Round shot at ×0.5, so EHP is twice HP.

| Fortress | Batteries × guns | Damage | Fire rate | HP (EHP) | PR per battery | Total |
|---|---|---|---|---|---|---|
| L1 | 1 × 1 | 25 | 0.125 | 300 (600) | 43 | 43 |
| L2 | 2 × 1 | 30 | 0.125 | 400 (800) | 55 | 110 |
| L3 | 2 × 2 | 35 | 0.125 | 500 (1000) | 94 | 188 |
| L4 | 3 × 2 | 45 | 0.125 | 650 (1300) | 121 | 363 |
| L5 | 3 × 2 | 55 | 0.125 | 800 (1600) | 148 | 444 |

- **Guard ships:** up to 1 + floor(Fortress level / 2) ships, using 50% of the owner's command budget, with compressed stats. They are snapshot copies and are never actually damaged.
- **Defence Rating (DR)** = battery PR + guard PR. Guard ships may supply at most 40% of DR, so the base matters, not just the fleet.
- **Fair-match target:** match when FR_attacker / DR_defender is between 0.85 and 1.3. At about 1.1, a fair match should earn 2★ about 50–60% of the time.
- Calibrate this with `scripts/debug/SelfPlayHarness.gd` (statistical runs, since the physics is not deterministic) and then with telemetry.

## 4. Loot model (how much they can loot)

### 4.1 What can be looted

Lootable: gold, wood, iron and rum that have been banked on the server.

**Never lootable:**
- Eights;
- research;
- items in the Hold or relics;
- cosmetics;
- resources already committed to a build.

### 4.2 Formulas

```
Protected_r  = Cap_r × P[highest Warehouse]    P: none .30, L1 .35, L2 .40, L3 .45, L4 .50, L5 .55
Unprot_r     = max(0, Stored_r − Protected_r)
w_i          = (building levels on island i) / (building levels on all islands)
Transfer_r   = Unprot_r × w_i × TAKE(0.5) × Destruction(0..1) × LDF
               ≤ RaidCap_r(AR_def); defender daily loss ≤ 20% of Unprot at day start
LDF (level-difference factor), by AR_att − AR_def:
               ≤ −1 → ×1.15 per rank (max 1.3);  0 → 1.0;  +1 → 0.75;  ≥ +2 → 0.5 (revenge only)
Bounty_r     = MoP_r(attacker) × {0★: 0, 1★: 6, 2★: 12, 3★: 20 minutes} × LeagueMult(1.0 … 1.8)
               the first 6 wins each day get the full Bounty, later wins 25%; Transfer is always full
```

The daily Bounty taper limits rewards, not play: attacks stay unlimited, so it is not an energy system.

### 4.3 What the defender gets

- **Successful defence** (attacker earns ≤1★): `DefenseBounty = MoP(defender) × 8 minutes × LeagueMult`, created by the server.
- **Salvage:** 5% of the gold cost of each attacker hull sunk, paid as wood and iron.
- These are paid even when the defender is offline. The defence log opens with what you **earned**, in line with docs/19 "reward, never punish".

### 4.4 What the attacker pays

- **Provisioning:** 15 rum per Command Point, so rum gets a real use.
- **Lay-up repair:** sunk or damaged ships repair on a ScheduleManager timer at 0.5 seconds per point. Shipyard level shortens it. Eights cannot finish it.
- No ship is ever permanently lost on either side.

### 4.5 Worked example (AR8, after the M31 change to 3 hours of storage)

- The defender holds about 2.4P, where P is production per hour. Protection is 1.5P, so 0.9P is unprotected. The richest island has w = 0.15.
- A 3★ raid takes about **4 minutes** of the defender's production. A 2★ raid takes about 2.8 minutes.
- The attacker's 2★ total is about 2.8 + 12 × 1.3 ≈ **18 minutes of production** for roughly 5 minutes of play.
- The defender's worst day: about 3 defences, roughly 12 minutes of production lost, partly offset by defence bounties.

**Calibration rules to enforce:**
- PvP income per active hour should be 0.8–1.2x PvE income per active hour.
- PvP should supply at most 35% of an engaged player's daily resources.

### 4.6 Presets

- **"Gentle"** for leagues up to Gold: the values above.
- **"Cutthroat"** from the Captain league up: protection −10 points and TAKE = 0.8. Climbing the ladder is how a player chooses higher stakes.

## 5. Async raid flow

1. **Scout and match.** The attacker opens the scout view, the server issues an attack ticket, and the attacker picks one of the defender's islands.
2. **The raid lasts 3:00.**
   - ★1 = 50% weighted destruction (battery 3, landmark 2, building 1).
   - ★2 = Governor's Flagstaff taken by a landing party, using the boarding model.
   - ★3 = 100% destruction plus the Flagstaff.
   - Landmarks: Powder Magazine (chain explosion), Signal Tower (calls the guard ships early), Mortar Pit (minimum range), Culverin Tower (blind spot).
3. **Shields ("Truce"):**
   - After a defence: 8h for 1★ or ≥40% destruction, 12h for 2★, 14h for 3★.
   - A 30-minute Guard window follows each shield.
   - A player who first raises the Black Flag gets a 72h Truce.
   - Each real attack the player makes costs them 3h of their own shield. Phantom raids cost nothing.
   - **Shields can never be bought.**
4. **Revenge:** one attack back within 24h. It ignores the matchmaking band, but LDF still applies, and it gives a ×1.25 Bounty.
5. **Defence log and replays.**
   - Replays are an event log, not a re-simulation: positions sampled at 5 Hz plus shot events, about 40 KB compressed.
   - Keep the last 10 defences for 7 days.
6. **Matchmaking.**
   - Eligible defenders: Black Flag on, no shield or Guard, |AR difference| ≤ 1, not attacked by this attacker in the last 24h, and a snapshot published within the last 7 days.
   - Prefer FR/DR between 0.85 and 1.3 and a trophy gap ≤ 200, widening by 100 with each skip.
   - Skips: the first 3 are free, then AR × 100 gold.
   - **Fallback:** if no live target is found, serve a Phantom at 70% of the created loot. This matters for a small beta population.
   - Players inactive for more than 14 days move to the Phantom pool: their islands can still be raided, but nothing is taken from them.
7. **Trophies ("Infamy").**
   - Expected score E = 1/(1 + 10^((T_def − T_att)/400)).
   - Actual score S: 0★ = 0, 1★ = 0.4, 2★ = 0.75, 3★ = 1.
   - ΔT_attacker = round(40 × (S − E)). ΔT_defender = −0.75 × ΔT_attacker.
   - Leagues: Driftwood 0, Bronze 400, Silver 800, Gold 1200, Captain 1600, Commodore 2000, Admiral 2400, Pirate Lord 2800.
   - Players up to Silver cannot drop below their league floor.

## 6. Global brawl

| Option | Verdict |
|---|---|
| Real-time fleet vs fleet (Clash Royale style) | Defer to MP-5. The RigidBody buoyancy is not deterministic. Supabase Realtime only relays messages; it is not an authoritative game server. That leaves a headless Godot or Nakama server, or a second kinematic movement model, which would duplicate a system. Mobile latency and a small player pool mean long queues. |
| **Async Ghost Fleet Duels** | **Ship first (MP-3).** A defender publishes a fleet plus "Battle Orders": formation, target priority and when to fire the captain ability. The challenger fights it as EnemyAI using the role tactics. 3-minute matches with a separate trophy ladder. |
| Same-seed regatta (both players fight the same scenario and compare scores) | Good for weekly events. Low cost. |

Brawl uses the **"Articles of War" standard**:
- every hull and its components fixed at level 7;
- techs ignored;
- 2 modules chosen as sidegrades;
- captain passives reshaped to a product of 1.0, actives kept;
- 12 Command Points, at most 3 ships.

A player may only use hulls and captains they have unlocked. Unlocking is a collection, not a power advantage.

## 7. Protecting your fleet

- **Docked ships:** only appear as Harbour Guard copies. They are never sunk or lost.
- **Ships on trade missions:** MP-4 adds optional "Convoy Hunts". Tier-1 routes are safe lanes. Tier-2 and tier-3 routes pay their existing ×tier bonus but can be intercepted as a ghost convoy. The interceptor takes at most 25% of the trade income accrued since the last collection. Escorts can be assigned.
- **The ship you are sailing in the campaign can never be attacked by another player.** There is no open-world PvP.

## 8. Progression tracks

- **Admiralty Rank (AR) 1–12:** the island cap, the PvP band and the stat caps. Earned only through play.
- **Renown level 1–100:** account XP from all play. Cosmetic titles and flags only.
- **Infamy:** PvP trophies, by season.
- **Captains:** capped at level 20 with +2% per level (M31).

## 9. Single-player players and coexistence

- PvP needs the Black Flag opt-in. A player who never opts in is never attacked.
- Opting out has a 72h cooldown so nobody can raid and then hide. Trophies freeze while opted out.
- AI faction raids stay as they are, single-player only. Their losses are capped at 10% of unprotected storage, never Eights or research (per the existing W4.3 plan).
- Phantom raids are open to everyone without being raidable, and pay created loot only.
- Campaign difficulty depends on region and heat, never on PvP power. PvP never changes the campaign.
- PvP-only rewards are cosmetic.
- Rewards that matter must have a PvE route: Admiralty Trials and the M33 Living Rivals.

## 10. Seasons without FOMO ("Tides")

- Each season lasts 5 weeks. Rewards are based on the **peak** league reached, not the final standing, so there is no last-day grind.
- Soft reset: T = 1600 + 0.5 × (T − 1600) for players above 1600.
- Season-end chest: MoP × 60 × the league factor, capped.
- Season cosmetics can be earned again in later seasons (a "Tide Archive"). They are never sold if they were once earnable, and no season gives power.

## 11. Monetization rules for PvP (stricter than today)

Eights never:
- buy shields;
- finish lay-up repair or Fortress rebuild timers;
- buy hulls, troops or builder slots;
- raise AR.

**Decision for the owner: shortfall cover on PvP-relevant purchases.** This covers hulls, ship levels, components, modules, techs, Fortress, Watchtower and batteries.
- **Recommended:** turn it off for everyone. It has to be global because a player could buy power first and opt in later.
- **Alternative:** keep it, and accept that AR caps plus matchmaking by compressed power limit it to "reaching your cap sooner". That is the Clash of Clans model and borderline pay-to-win.

In either case, `docs/00_VISION.md` §19.2 "PvE-only power ceiling" must change. Premium captains must be excluded from PvP, or normalised as above, until they are proven to be sidegrades.

## 12. Proposed AGENTS.md amendment

This replaces "Future Multiplayer Philosophy", removes "Never introduce multiplayer", and removes PvP, Cloud Saves and Competitive Seasons from the out-of-scope list. Record it in `docs/DECISIONS.md`.

> **Multiplayer Charter (adopted 2026-10).** Pirate Empire is single-player first. PvP is an opt-in layer, and the campaign must stay completable and fair with PvP never touched.
> 1. PvP is opt-in. A player who has not raised the Black Flag can never be attacked by another player.
> 2. Async first. No real-time PvP ships without an authoritative server and an approved decision record.
> 3. The server is authoritative. No PvP feature ships until resources and Eights live in server-side rows, change only through server functions, and loot is computed on the server.
> 4. PvP never damages the empire. Losses are only capped amounts of unprotected gold, wood, iron and rum. Eights, research, Hold contents, ships, captains, buildings and cosmetics can never be lost.
> 5. PvP power is normalised: compressed stats capped by Admiralty Rank, a Command Point budget, and fully standardised stats in Brawl. Admiralty Rank is earned only through play.
> 6. No pay-to-win in any competitive context. Eights never buy shields, ships, troops, builder slots, PvP timers or Admiralty Rank. Competitive rewards are cosmetic or capped resources.
> 7. No energy, no FOMO: unlimited attacks, rewards based on peak standing, season cosmetics earnable again.
> 8. All PvP numbers live in `.tres` files and are checked by the balance-lint test.

## 13. Phased rollout

| Phase | Contents | Exit criteria |
|---|---|---|
| MP-0 Foundations | Server-authoritative wallet (dual-write migration); the §1.3 fixes; PR/FR/DR calculation and balance-lint; AR and Renown; Harbour Plan snapshot publishing; player-chosen building slots | Lint passes; no progress lost in migration |
| MP-1 Phantom Raids | Raid AI copies and authored rivals; created loot only; stars, replays, telemetry | 2★ rate 50–60% at FR/DR ≈ 1.1; median raid ≤ 4 minutes |
| MP-2 Live Raids (closed beta) | Black Flag, transfers at half the caps, shields, revenge, defence bounty, trophies | Fewer than 5% of defenders lose more than 15 minutes of production per day; no fraud flags |
| MP-3 Tides and Duels | Seasons and leagues; Ghost Fleet Duels | Duel queue under 10 seconds |
| MP-4 Convoys and crews | Convoy Hunts; possibly guilds | n/a |
| MP-5 Real-time gate | Only if there are enough concurrent players and a server budget exists | n/a |

**Balance-lint invariants:**
- PR is monotone within each hull class;
- PR per Command Point within ±15%;
- within-rank fresh/maxed gap ≤ StatCap²;
- Transfer + Bounty ≤ 25 minutes of production per raid;
- defender daily loss ≤ 20% of unprotected storage;
- no Eights or research in any loot path;
- every hull and Fortress level affordable within its storage cap.

**Open decisions for the owner:**
- shortfall cover in PvP categories (§11);
- whether the Gentle/Cutthroat split is acceptable;
- the AR12 Haven island;
- turning on player-chosen building slots.

### Critical Files for Implementation
- D:\Pirate-game\scripts\managers\EmpireManager.gd (raid resolution, steals Eights at lines 323–328)
- D:\Pirate-game\scripts\managers\ResourceManager.gd (storage caps, shortfall cover)
- D:\Pirate-game\scripts\managers\OwnedShipData.gd and D:\Pirate-game\scripts\world\CaptainData.gd (stat layers, uncapped captain level)
- D:\Pirate-game\scripts\managers\TechManager.gd (unused `global_storage_mod`)
- D:\Pirate-game\AGENTS.md and D:\Pirate-game\docs\00_VISION.md §19.2 (charter amendment)