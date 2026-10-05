> Raw design input for the MULTIPLAYER track (MP-0..MP-4), produced 2026-10-05 by a read-only design panel (workflow wf_95a5d2d8-2d0). NOT an approved spec: it gets its own planning pass after M31. Owner vision: CoC-style 5-12 island home base + global brawl; PvP loot/ship-power math managed.

# PvP Balance Model: Pirate Empire (loot and power math)

All numbers come from the repo data: `resources/ships`, `resources/techs`, `resources/modules`, `resources/ship_components`, `resources/buildings` and `OwnedShipData.gd`. Values marked "proposed" are new tunables. They belong in a new `resources/balance/PvpBalance.tres` and should be overridable from RemoteConfig.

## 0. Problems in the current data that PvP math depends on

| # | Problem | Evidence | PvP impact |
|---|---|---|---|
| F1 | Production is far faster than storage. Storage, not income, is what limits players. | Market L5 = 90 gold per 10 s tick, about 32k gold/h. Base gold cap is 5,000, and a Warehouse L5 adds only +4,500 per island (`ResourceManager.gd:33`, `Island.gd:222`). | Defenders' storage is nearly always full, so loot has to be sized to storage, not to hours of production. Rum, iron and wood caps (50/100/200 base) are too small to fuel raids. An economy pass is a prerequisite. |
| F2 | Storage techs do nothing. | `TechManager.global_storage_mod` is computed but `ResourceManager` never reads it. | Fix this before PvP, because protected and exposed loot depend on storage cap. |
| F3 | Brigantine is strictly dominated. | It costs +67% over the Corvette for +6% power, and is slower (28 vs 32) at the same range. | Nobody will field it. Proposed fix: HP 150 → 190 (r 58.8 → 66.2), or give it a boarding role. |
| F4 | Flat +4 guns from the Cannons component (`guns_at_levels [3,5,7,9]`). | Sloop guns go ×2.33, Man O'War guns go ×1.5. | A maxed Sloop gets 25% more power per fleet point than a maxed MoW (see §2). Make the gun bonus proportional: extra = round(base × 0.125 × milestones). |
| F5 | Eights can cover resource shortfalls (`cover_shortfall_and_spend`) and finish timers (`ScheduleManager.finish_cost_eights`). | M27 | Once PvP exists, this is pay-to-win for ships, components, techs, modules and Fortress/Watchtower. These paths must be disabled for every power-bearing cost. |
| F6 | The raid defense score uses Fortress/Watchtower presence only (×20 / ×15), not their level. | `EmpireManager._compute_defense_score` | Replace it with the Defense Rating D from §2. |

## 1. Loot

**Harbour Tier (HT 1–10), the town-hall equivalent:** HT = clamp(round(2 × mean over the 10 building types of the empire's highest level of that type), 1, 10). A type that hasn't been built counts as 0. HT drives only the loot penalty and the fleet budget. Matchmaking uses power (§5), so a player who keeps HT low while maxing military ("sandbagging") still faces opponents of equal power.

**Per resource k ∈ {gold, wood, iron, rum}:**
```
Protected_k = max(0.15 × Cap_k, p(WL) × Stored_k)        p = 0.30/0.38/0.46/0.54/0.60 for best Warehouse L1..L5
Exposed_k   = max(0, Stored_k − Protected_k)
Steal_k     = min(Exposed_k × α × σ(stars) × m(ΔHT),  0.12 × Cap_k,  DailyLossLeft_k)     α = 0.20
Bounty_gold = 250 × HT_att × σ × m(ΔHT) × League(1.0 Bronze … 2.0 Legend)   (minted by the server, not taken from the defender)
```
σ by result: 0★ = 0.2 × destruction%, max 0.10. 1★ = 0.50. 2★ = 0.80. 3★ = 1.00.
m(ΔHT), where Δ = HT_att − HT_def: Δ ≤ −2 → 1.20, −1 → 1.10, 0 → 1.00, +1 → 0.80, +2 → 0.50, +3 → 0.20, ≥ +4 → 0.05. This is the anti-farming curve. Bounty is multiplied by m too.

**What can never be looted:** Eights, research, resources already spent on a running timer, and items, cosmetics or captains.
**Plunder Hold decision:** loot still in a ship's Plunder Hold at sea is PvE-only and can't be raided. Once banked in port it is ordinary stored resources and follows the protection rules. Brawl never touches resources.

**Protecting defenders:**
- A defender can lose at most 30% of each resource's Cap in any rolling 24 h. This is tracked in a server ledger.
- At most 3 incoming raids per 24 h.
- Shield length depends on destruction: under 30% gives none (30-minute guard against the same attacker); 30–59% gives 4 h; 60–89% gives 8 h; 90% or 3★ gives 12 h.
- Attacking while shielded removes 3 h of shield.
- New players are protected for 72 h or until HT 3.
- Shields are never purchasable, with Eights, ads or anything else.

**Revenge:** each incoming raid allows one revenge within 24 h. It ignores the trophy band but not the target's shield. m is floored at 0.5. Trophies from revenge count at 50%.

**Attacker cost (raiding must cost something):**
- Provisions on launch: 6 rum per fleet point (FP) used. This is lost even if the attack fails.
- Repairs: 0.6 × RewardRef(HT) × (FP_used / FP_budget) × average damage fraction, where RewardRef is the fair 2★ reward below.
- Lay-up: sunk hulls are in dry-dock for 10 min × hull class. This can be shortened by Shipyard level only, never by Eights or ads.
- Attacker PvP income cap: 1.5 × gold Cap per 24 h. After that, attacks earn trophies only.

Targets: a fair 2★ nets about +60–70% of RewardRef. A 0★ loss nets about −0.5 × RewardRef.

**Worked examples.** Defenders are at about 90% of cap. Attacker and defender HT are equal unless noted.

| | Early (HT 2) | Mid (HT 5) | Late (HT 9) |
|---|---|---|---|
| Defender setup | 1 island, Warehouse L1 | 3 islands, Warehouse L3 | 5 islands, Warehouse L5 |
| Gold Cap / Stored | 5,500 / 5,000 | 9,800 / 9,000 | 27,500 / 25,000 |
| Protected (gold) | max(825, 1,500) = 1,500 | max(1,470, 4,140) = 4,140 | max(4,125, 15,000) = 15,000 |
| Exposed → available (×α) | 3,500 → 700 | 4,860 → 972 | 10,000 → 2,000 |
| 2★ steal | 560 | 778 (622 if attacker is HT 6, m = 0.8) | 1,600 |
| 3★ steal | 660 (hits the 12% cap) | 972 | 2,000 |
| 2★ bounty (league) | 400 (Bronze) | 1,200 (Silver 1.2) | 2,880 (Gold 1.6) |
| **RewardRef (fair 2★ gold)** | **960 (17% of own cap)** | **≈2,000 (20%)** | **4,480 (16%)** |
| Attacker cost (full budget, 50% damage) | 90 rum + 288 g | 216 rum + 600 g | 468 rum + 1,344 g |
| Net 2★ / net 0★ | +670 / −430 | +1,400 / −1,000 | +3,140 / −2,400 |
| Defender's worst single raid | −14% of stored (shield after) | −11% | −8% |
| Same raid by HT 9 on HT 5 | — | steal 39 g, bounty 54 (m = 0.05) | — |

Loot barely grows from early to mid (5.5k to 9.8k cap) because the 5,000 base cap dominates. This is F1/F2 again, and the economy pass should make caps grow roughly in line with costs.

## 2. Power Rating

Under Lanchester's square law, two fleets are even when Σ√(HP·DPS) is equal. So the linear rating is:

- **Ship rating:** r = √(EHP × DPS)
- **Fleet:** R = Σ r_i
- **Base:** D = Σ r_battery + Σ r_guard

Definitions:
- DPS = guns/side × damage × volleys/s.
- EHP = max_health × health multipliers.
- An optional range term ×(range/100)^0.25 can be added later. It is left out below.

**Base hulls:**

| Hull | Gold | HP | DPS/side | P = HP·DPS | r | Gold per r | Marginal (cost× / r×) | FP (r/7.34) | Max-progress r | r per FP (maxed) |
|---|---|---|---|---|---|---|---|---|---|---|
| Dinghy | 150 | 50 | 9.0 | 450 | 21.2 | 7.1 | — | 3 | 264 | 88 |
| Sloop | 400 | 100 | 13.5 | 1,350 | 36.7 | 10.9 | 2.67 / 1.73 | 5 | 458 | 92 |
| Schooner | 1,200 | 120 | 16.4 | 1,963 | 44.3 | 27.1 | **3.00 / 1.21** | 6 | 511 | 85 |
| Corvette | 1,800 | 140 | 21.8 | 3,055 | 55.3 | 32.6 | 1.50 / 1.25 | 8 | 638 | 80 |
| Brigantine | 3,000 | 150 | 23.1 | 3,461 | 58.8 | 51.0 | **1.67 / 1.06** | 8 | 644 | 81 |
| Frigate | 6,500 | 250 | 34.6 | 8,652 | 93.0 | 69.9 | 2.17 / 1.58 | 13 | 1,018 | 78 |
| Galleon | 14,000 | 400 | 39.4 | 15,750 | 125.5 | 111.6 | 2.15 / 1.35 | 17 | 1,323 | 78 |
| Man O'War | 28,000 | 600 | 60.0 | 36,000 | 189.7 | 147.6 | 2.00 / 1.51 | 26 | 1,897 | 73 |

**Where the gold curve breaks:**
- Gold per r rises 21× from Dinghy to MoW. A gold budget would make Dinghy swarms dominant.
- Sloop → Schooner and Corvette → Brigantine are the worst value steps.
- Conclusion: PvP must not limit fleets by gold. Limit them by fleet points (FP ∝ r) plus a hull-slot cap.

**Progression multipliers.** g = √(HP mult × DPS mult); the maxed values in the table above are base r × g.

| Source | HP × | DPS × | g |
|---|---|---|---|
| Ship level 10 (2%/level) | 1.18 | 1.18 | 1.18 |
| Components L10 (Hull +6%, Cannons +4% damage / +3% rate per level) | 1.54 | 1.727 | 1.63 |
| +4 guns (F4) | — | Sloop 2.33 / MoW 1.50 | 1.53 / 1.22 |
| Best modules (Iron Hull; Swift Loaders + Master Gunners) | 1.35 | 1.645 | 1.49 |
| All techs | 2.07 | 2.07 | 2.07 |
| Captain (Whistler 0.8/0.8 to Ophelia 1.4/1.35) | 0.8–1.40 | 0.8–1.35 | 0.80–1.375 |
| **Total (best captain)** | **7.11** | **9.37 × guns** | **Sloop 12.5, MoW 10.0** |

Consequences:
- A fresh Dinghy (21) and a maxed MoW (1,897) differ by 90× in r.
- A maxed Sloop (458) beats 2.4 fresh Men O'War.
- Techs are the largest single source of power, and captains are a 1.7× gold-buyable spread.
- In raids this is accepted and measured through R. In Brawl it is normalized (§3).

**Fleet budget by HT (proposed).** Slot caps keep battles at 10 hulls or fewer (6 attackers + 4 guards).

| HT | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| FP budget | 10 | 15 | 20 | 28 | 36 | 45 | 55 | 66 | 78 | 90 |
| Hull slots | 3 | 3 | 4 | 4 | 5 | 5 | 5 | 6 | 6 | 6 |
| Typical g | 1.0 | 1.2 | 1.6 | 2.2 | 2.8 | 3.5 | 4.5 | 5.6 | 7.0 | 9.0 |
| R_typical = FP × 7.34 × g | 73 | 132 | 235 | 452 | 740 | 1,156 | 1,817 | 2,713 | 4,008 | 5,946 |

## 3. How to normalize power in each mode

| Option | Async base raids | Real-time Brawl |
|---|---|---|
| Raw progression, matched by R/D (Clash of Clans) | **Use.** Progression matters, and the FP budget plus R-band matchmaking keeps fights fair. | Reject. A 90× spread makes it pay-to-progress. |
| Stat-normalized "Tournament Standard" (Clash Royale) | Reject. It removes the reason to build a base. | **Use.** Every hull is set to the league cap (e.g. ship and components L5). Techs are a fixed standard bundle. Modules are free picks. Captain damage × HP is clamped to 1.0–1.2, so captains become sidegrades. |
| Fleet-point budget | **Use** (on top of raw progression). | **Use**: fixed 40 FP and 4 slots. |

What Brawl players carry over: breadth (hulls and captains unlocked), never depth. Brawl balance assumes the networking design solves the physics problem (RigidBody plus BuoyancySimulator is not deterministic). The balance numbers don't depend on how that is solved.

## 4. Defender vs attacker targets

Let x = R_att / D_def. D_target(HT) = R_typical(HT). It is split about 55% batteries and 45% guards. Guards are limited to 50% of the HT FP budget and 4 hulls.

| x | P(≥1★) | P(≥2★) | P(3★) |
|---|---|---|---|
| 0.6 | 35% | 10% | 1% |
| 0.8 | 65% | 30% | 4% |
| **1.0 (fair)** | **85%** | **55%** | **12%** |
| 1.2 | 95% | 75% | 30% |
| 1.5 | 99% | 90% | 55% |

- **Stars:** 1★ = 50% of structures destroyed. 2★ = 50% destroyed plus the Harbour keep or treasury taken (boarding or landing). 3★ = 100%.
- **Battery r targets:** Fortress L sockets = 2L. Per-battery r should be about 0.55 × R_typical / sockets. For example, HT 5 has 6 sockets × r 68, and HT 9 has 10 × r 220. Example HT 5 battery stats: HP 800, DPS 5.8 per battery.
- **Harbour Plan:** the attacker picks an approach after scouting. Effective D = D_facing + 0.5 × D_adjacent + 0.25 × D_opposite.
  - A balanced plan gives roughly 0.9 × D on every face.
  - Stacking every battery on one face leaves the weak face at 0.4 × D or less. This makes the plan a skill choice, not something that can be stacked to dominate.
- **Calibration:** run `scripts/debug/SelfPlayHarness.gd` headless against D_target bases and adjust battery stats until each x row is within ±7 percentage points.
- **Battle length:** fair raids should take about 60–150 s. Hull-vs-hull time-to-kill should stay within 20–40 s at a 40% hit rate (currently a Sloop vs Sloop takes 7.4 s of contact ÷ 0.4 ≈ 18 s).

## 5. Matchmaking and trophies

- **Search:** |T_att − T_def| ≤ 200 AND x ∈ [0.80, 1.25] AND |ΔHT| ≤ 2.
- **Widening:** every 10 s, widen by ±50 trophies and ±0.05 on x. Hard limits are x ∈ [0.6, 1.6] and ΔHT ≤ 3.
- **Excluded targets:** shielded, online, attacked by the same player in the last 24 h, under new-player protection, or not opted in.
- **Elo:** E = 1 / (1 + 10^((T_def − T_att)/400)). Score s = {0, 0.40, 0.75, 1.0} for 0–3★.
  - Attacker ΔT = round(40 × (s − E)).
  - Defender ΔT = −0.8 × attacker ΔT.
  - A successful defense (0★) gives the defender +32 × E.
- **Loss floors:** trophies never drop below the floor of the current league. Leagues are Bronze 0, Silver 800, Gold 1,600, Pirate Lord 2,400, Legend 3,200. A season reset compresses trophies 50% toward the league floor.

## 6. How PvE progression feeds PvP

- **Opt-in, and symmetric:** raising the "Black Flag" puts your base into the pool, and only flagged players can raid. Players who never opt in are never attacked and miss nothing that gives power.
- **PvP-exclusive rewards** are limited to cosmetics, titles, trophies and leaderboards. There are no PvP-only ships, modules, techs or captains, and loot is ordinary resources.
- Everything earned in PvE counts toward R and D, but matchmaking by R means progression buys access to bigger loot pools, not easy wins.
- **Eights:** with PvP live, shortfall cover and timer finishing are disabled for every power-bearing cost (hulls, components, levels, modules, techs, Fortress/Watchtower/Shipyard, captains). Eights also can't buy shields, repairs, lay-up skips, provisions or extra slots.
- **Anti-cheat:** the current save is client-authoritative. R, D, HT and storage used in PvP must be recomputed server-side from validated state, and loot and bounty transfers go through an Edge Function ledger.
- **Proposed AGENTS.md amendment:** "Version 1.x may add opt-in asynchronous PvP raids and a stat-normalized Brawl. PvP must never be required for PvE progression or rewards. Nothing purchasable with real money or Eights may increase PvP power, protection or attack frequency. All PvP outcomes and transfers are server-authoritative and must pass the PvP balance-lint suite."

## 7. Balance-lint invariants (proposed `tests/test_pvp_balance.gd`)

1. For every hull, maxed r per FP is within ±10% of the median (fails today at 25% because of F4). Base r per FP is within ±12%.
2. Hull r is strictly increasing by class. Every marginal step gives r× ≥ 1.15 (fails today for Brigantine).
3. Lanchester check: two equal-FP fleets of different compositions have R within ±10%.
4. Worst-case single-raid loss is ≤ 15% of stored, and worst-case 24 h loss is ≤ 30% of Cap, for every Warehouse level and HT.
5. p(WL) never decreases and never exceeds 0.60, and the 15% Cap floor is always protected.
6. m(ΔHT) never increases as Δ grows, and m(+4) ≤ 0.05.
7. RewardRef(HT) as a share of the attacker's gold Cap is within 12–25% for all HT. Fair-match expected net is above 0, and expected net of a 0★ is below 0.
8. Full-budget provisions are ≤ 50% of rum Cap for every HT (fails today early on: HT 2 needs 90 rum against a cap of 100).
9. D_target(HT) / R_typical(HT) is within [0.9, 1.1]. Any Harbour Plan leaves its weakest face ≥ 0.35 × D.
10. Brawl Tournament Standard: every captain's damage × HP is within [1.0, 1.2], and no normalized ship differs from its standard r.
11. Premium never-list: loot keys never include `eights` or `research`. No store product, Eights path or ad reward touches shields, lay-up, repairs, provisions, FP, slots or power-bearing costs. `can_cover_shortfall` is false for all of these.
12. Shield duration never decreases with destruction %, and no shield source is purchasable.
13. Hull count = attack slots + guard cap ≤ 10 for every HT.

### Critical Files for Implementation
- D:\Pirate-game\scripts\managers\OwnedShipData.gd
- D:\Pirate-game\scripts\world\ShipComponentData.gd
- D:\Pirate-game\resources\ship_components\Cannons.tres
- D:\Pirate-game\scripts\managers\ResourceManager.gd
- D:\Pirate-game\scripts\managers\EmpireManager.gd
- D:\Pirate-game\scripts\managers\TechManager.gd
- D:\Pirate-game\resources\ships\Brigantine.tres
- D:\Pirate-game\AGENTS.md