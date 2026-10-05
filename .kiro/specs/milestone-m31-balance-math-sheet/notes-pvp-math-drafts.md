> PvP loot/ship-strength math drafts (2026-10-05) — produced by auditors that picked up the owner's 'inter-player mode math' request. Input for M31's PvP section alongside .kiro/specs/track-multiplayer/03-pvp-math.md.

# Plan: loot and ship-strength math for the "intern player mode"

## 0. Scope, what I assumed, and what to ask the user

- **Mismatch with the task I was given.** The computed task was a Supabase schema/RLS audit. The user asked for loot and ship-strength math for the "intern player mode". The user's request takes priority, so I did not do the schema audit. The few server points below come up only because PvP needs them.
- **No such mode exists in the code.** Searching for `intern` only finds "internal" and "internationalization". I read "intern player mode" as **inter-player mode, meaning asynchronous PvP raids**. The user should confirm this. If they meant a beginner ("intern") difficulty, the power score in §2 and the loot multiplier in §3 still apply. The change would be an extra `loot_mult` field on `AIDifficultyData` (`scripts/combat/AIDifficultyData.gd`). Today the Relaxed/Normal/Hard/Brutal profiles change only enemy combat, never loot.
- **PvP is currently banned by the project's own rules.** See `AGENTS.md:224-228`, `:785` ("Never introduce multiplayer"), `:830`, `docs/00_VISION.md:590`, and `docs/17_MONETIZATION.md:203` (paid power is banned in any competitive mode; premium captains would be excluded). The owner has to amend these before any code is written. `docs/navalCombat.md:332-338` already describes the intended async shape: "A's fleet → AI-controlled battle → B's defence fleet".

## 1. What the current numbers look like

**Hull baselines** (`resources/ships/*.tres`). Power is PS = sqrt(HP × broadside DPS), where DPS = `cannon_damage × cannons_per_side × fire_rate`.

| Hull | Class | Gold | HP | DPS | PS (stock) |
|---|---|---|---|---|---|
| Dinghy | 1 | 150 | 50 | 9.0 | 21 |
| Sloop | 1 | 400 | 100 | 13.5 | 37 |
| Schooner | 2 | 1200 | 120 | 16.4 | 44 |
| Corvette | 2 | 1800 | 140 | 21.8 | 55 |
| Brigantine | 3 | 3000 | 150 | 23.1 | 59 |
| Frigate | 3 | 6500 | 250 | 34.6 | 93 (+ chaser) |
| Galleon | 4 | 14000 | 400 | 39.4 | 126 (+ chaser) |
| Man O'War | 5 | 28000 | 600 | 60.0 | 190 (+ 2 chasers) |

**Maxed multipliers** (from `OwnedShipData.gd:120-151`, `ShipComponentData.gd:47-77`, and the component and module `.tres` files):
- **HP:** ship level 10 (×1.18) × Hull component L10 (×1.54) × IronHull (×1.35) = **×2.45**.
- **DPS:** level (×1.18) × Cannons damage (×1.36) × Cannons fire rate (×1.27) × SwiftLoaders (×1.30) × MasterGunners in the Special slot (×1.265) = **×3.35**. On top of that, `guns_at_levels [3,5,7,9]` adds **+4 guns per side**. Because that is a flat addition, it helps small hulls far more: a Sloop goes from 3 to 7 guns (×2.33), a Man O'War from 8 to 12 (×1.5).
- **Result:** a maxed Sloop reaches PS ≈ 161, close to a stock Man O'War (190). A maxed Man O'War reaches PS ≈ 666. The full spread, maxed Man O'War against a stock Dinghy, is about **31×**. Raw-stat PvP between those two is not a fight. Captain base modifiers (range 0.1–3.0, `CaptainData.gd:31-35`), active abilities and in-battle upgrade offers stack on top of this.

**Economy limits:**
- Base storage is gold 5000, wood 200, iron 100, rum 50 (`ResourceManager.gd:33-43`). A Warehouse L5 adds +4500 gold / +1800 wood / +900 iron / +450 rum.
- A Market L5 produces 90 gold per 15 s, about 21.6k gold/hour, so it fills a 9.5k gold cap in roughly 26 minutes.
- **Storage, not production, is the binding limit.** Loot math has to be pegged to storage.
- Eights buy resource shortfalls at 1 Eight = 50 gold / 10 wood / 5 iron (`resources/balance/EconomyPricing.tres`). That makes Eights a direct path to paid power.

**Existing bugs that PvP would make worse:**
1. **NPC raids steal Eights and research.** `EmpireManager.gd:323-329` loops over every key in `ResourceManager.current_resources`, including `eights` (premium, paid) and `research`. `spend_resource` (`ResourceManager.gd:78-88`) has no premium guard. Paid currency can be stolen by an NPC raid today.
2. **Defence ignores ship strength.** `EmpireManager.gd:238-246`: fortress and watchtower count as 1.0 at any level, and each defending ship is a flat 10 points. A Dinghy defends as well as a Man O'War, and upgrading a Fortress from L1 to L5 (18k gold) adds no defence.

## 2. Ship-strength model (shared by PvP and PvE)

New static helper `scripts/combat/PowerScore.gd`, data-driven, with no hard-coded balance:

```
ship_PS  = sqrt(EHP * DPS)
EHP      = eff.max_health * captain.base_health_modifier
DPS      = eff.cannon_damage * captain.base_damage_modifier * eff.fire_rate
           * (eff.cannons_per_side + chaser_weight * (has_bow + has_stern))
fleet_PS = sqrt( (sum of EHP_i) * (sum of DPS_i) )
```

- `eff` is `OwnedShipData.get_effective_stats()`, so level, components and modules are already applied.
- The fleet formula follows Lanchester's square law and stays linear in fleet size. One ship equals its own `ship_PS`.
- Defence side: a fortress becomes a static battery with EHP = `fort_hp_per_level × L` and DPS = `fort_dps_per_level × L`. A watchtower adds `+watch_acc_per_level × L` to defender accuracy. `_compute_defense_score()` should be rewritten on the same PS basis.

**PvP power compression** keeps progression meaningful without allowing stomps. Let G = sqrt(PS_A × PS_D). Scale each side's HP and DPS by `c_side = (G / PS_side)^(1 − γ)`, using the existing duplicate-never-mutate pattern (`EncounterManager._apply_strength`, `:456-467`). Because PS scales linearly with c, the effective ratio becomes `ratio^γ`. With γ = 0.5, a 4× fleet plays as 2× and 31× plays as about 5.6×. This also shrinks the gold/Eights advantage, which is how the "no paid power" rule can be met.

**Matchmaking and auto-resolve:**
- Only offer defenders with PS_D / PS_A in [0.70, 1.40].
- For the AI-vs-AI simulation, P(win) = 1 / (1 + ratio_eff^(−k)), with k fitted from headless sims (start with k = 4).
- In PvP, turn off in-battle upgrade offers. Captain abilities stay, because captains are earned, not bought.

## 3. Loot model (pegged to storage)

New `scripts/world/PvpBalanceData.gd` and `resources/balance/PvpBalance.tres`:

```
lootable_types   = [gold, wood, iron, rum]        # NEVER eights, NEVER research
protected_r      = stored_r * min(prot_base + prot_per_wh_level * WH_L, prot_max)
                   (0.30 + 0.05*L, max 0.55)
pool_r           = stored_r - protected_r
steal_r          = pool_r * s_base(0.35) * outcome(destruction%, 0.3..1.0) * bully(R)
bully(R)         = clamp(R^2, 0.10, 1.25), where R = PS_D / PS_A  # punishes hitting down
cap_r            = attacker.max_storage_r * cap_frac(0.15)        # one win <= 15% of own cap
gain_r           = min(steal_r, cap_r, attacker free storage)     # defender loses gain_r only (conservative)
attack_cost      = rum: rum_per_class * sum(ship_class) + repair (repair_seconds_per_point 0.5)
```

**Worked example.** Both players at equal power, Warehouse L5 (gold cap 9500), defender holding 6650 gold:
- Protection 55% leaves a pool of 2993. Stolen = 2993 × 0.35 = 1047 gold.
- The attacker gains about 11% of their own cap, roughly 3 minutes of one L5 Market. That is a supplement, not a replacement for production.
- The defender loses 15.7% of their stored gold.

**Defender safety:**
- An 8 h shield after any loss of 10% or more.
- At most 3 losses per 24 h.
- A per-day loss ceiling of 40% of each resource's stored value at the first attack.
- A successful defence pays the defender 50% of the attacker's attack cost.

**Expected-value check:** at R = 1, EV = P × gain − cost should land at about 0.5 × 1047 − about 150 ≈ +370 gold. At R = 0.7, bully(R) = 0.49, which roughly halves the gain, so farming weak players doesn't pay. Encode this as a test.

## 4. Implementation steps

1. **Fix the existing NPC raid bug**, independent of PvP. Add a lootable-types whitelist in `_resolve_raid` and exclude `ResourceManager.is_premium_currency()` and research. Add a GUT test that a raid never touches `eights` or `research`.
2. **Add `PowerScore.gd` and unit tests.** The stock PS values in the §1 table and the maxed-Sloop ≈ 161 / maxed-MoW ≈ 666 figures become golden assertions.
3. **Rebase NPC raid defence on PS**: `EmpireManager._compute_defense_score()` and `_compute_attack_score()` (`:221-253`). This retunes PvE first and proves the formula before PvP exists.
4. **Add `PvpBalanceData` and its `.tres`.** Every constant above goes there. Add a pure function `PvpMath.resolve(attacker_snapshot, defender_snapshot, rng) -> {won, destruction, loot}` so tests and the server can share it.
5. **Write a headless simulation test** (`tests/test_pvp_balance.gd`). Run about 10k simulated fights across hull and upgrade combinations to fit k and γ. Assert:
   - P(win) at R = 1 is between 0.45 and 0.55.
   - After compression, a 4× fleet wins at most 90% of fights.
   - EV is above 0 only inside the matchmaking band.
   - The per-day defender loss never exceeds 40%.
6. **Build the compression hook** in the battle setup, applied to duplicated `ShipStats` only.
7. **Server side.** This is required, because saves are client-authoritative: `SaveManager` cloud-syncs a client-written `save_data` and resolves conflicts by last write via `client_updated_at`. Without a server step:
   - a client could upload a fake 31× fleet;
   - an offline defender's next sync would overwrite their own loss.

   Needed: an edge function that recomputes PS from the snapshot with the same tables and rejects stats above authored bounds; a `pvp_snapshots` table; and a `pvp_ledger` table of pending debits, which the client must apply on login before its next upload. That function also enforces the shields, daily caps and Eights exclusion. A full schema/RLS design is a separate task.
8. **Update the docs.** Add a section to `docs/05_CURRENT_SYSTEMS.md` and amend `AGENTS.md` and `docs/17_MONETIZATION.md` once the owner approves PvP.

**Risks to flag:**
- Late component upgrade costs are larger than a single island's storage cap. For example, Cannons L10 on a Man O'War costs 200 × 5 × 1.5⁸ ≈ 25.6k gold against a 9.5k cap. Players will hit this regardless of PvP; check whether caps add up across islands.
- The flat +4 guns per side makes upgraded small hulls the best value per gold. Either move to a percentage gun bonus or count guns in PS so matchmaking accounts for it.

### Critical Files for Implementation
- D:\Pirate-game\scripts\managers\EmpireManager.gd
- D:\Pirate-game\scripts\managers\OwnedShipData.gd
- D:\Pirate-game\scripts\world\ShipComponentData.gd
- D:\Pirate-game\scripts\managers\ResourceManager.gd
- D:\Pirate-game\scripts\combat\EncounterManager.gd
---

I found no "intern player mode" anywhere in the code or docs. The closest fit for "how much they can loot" and "how strong ships will be" is an **inter-player (async PvP raid) mode**: player A's fleet attacks player B's AI-defended home. `docs/navalCombat.md:332-337` already sketches that shape. This plan assumes that reading. If you meant a beginner or relaxed mode instead, the same levers apply (the soft-cap formula and the loot fractions), with PvE numbers.

The workflow script also asked for a save-sync data-loss audit. That is off-topic for your request, so I didn't run it. The few sync points that affect raid loot are in section 4.

**Blocker, your call:** `AGENTS.md:224-228` and `AGENTS.md:785` say "No PvP" and "Never introduce multiplayer" for v1. `docs/17_MONETIZATION.md:203` says premium captains must be excluded from any PvP. This mode needs you to sign off a change to those rules first.

---

## 1. Why the current numbers can't support PvP

**Base hull strength** is rating = sqrt(HP × DPS), where DPS = `cannon_damage × cannons_per_side × fire_rate`, from `resources/ships/*.tres`:

| Hull | HP | DPS | Rating |
|---|---|---|---|
| Dinghy | 50 | 9.0 | 21 |
| Sloop | 100 | 13.5 | 37 |
| Schooner | 120 | 16.4 | 44 |
| Corvette | 140 | 21.8 | 55 |
| Brigantine | 150 | 23.1 | 59 |
| Frigate | 250 | 34.6 | 93 |
| Galleon | 400 | 39.4 | 126 |
| Man O'War | 600 | 60.0 | 190 |

**Progression on top of the hull**, all multiplicative:
- Ship level 10: ×1.18 HP and damage (`OwnedShipData.gd:21,129-132`).
- Parts at level 10: Hull ×1.54 HP, Cannons ×1.36 damage, ×1.27 fire rate, +4 guns per side (Frigate 5→9 = ×1.8) (`ShipComponentData.gd:47-68`).
- Best modules: Iron Hull ×1.35, Heavy Cannons ×1.25 with Master Gunners ×1.15 damage and ×1.1 fire rate.
- Tech (`TechManager.gd:103-104`): about ×2.07 HP and ×2.07 damage.
- Captain: +0.1 damage and HP per level with **no level cap** (`CaptainData.gd:49-52`; the `add_xp` loop has no max). At level 10 that is ×1.9 / ×1.9.

**Totals:** a maxed Frigate gets HP ×9.65 and DPS ×22.8. That is HP×DPS ×220, or rating ×14.8. A maxed Frigate (rating about 1,378) beats a fresh Man O'War (190) by about 7×. On top of that, notoriety can multiply loot up to ×5 (`LootScalingData.gd:16-28`). Raw stats can't be used in PvP.

## 2. Ship strength math (PvP stats)

**Soft cap on each axis.** Apply this separately to the HP and DPS multipliers:

`f(x) = 1 + A·(1 − 1/x)`, with A = 0.6

- x = 1.18 → 1.09
- x = 2 → 1.30
- x = 9.65 → 1.54
- x = 22.8 → 1.57
- The ceiling is 1.6, so a fully maxed ship is at most 1.6× a fresh ship of the same hull.
- Every upgrade still helps, it just helps less each time. Players keep the reason to upgrade, and skill decides close fights.

**Fleet Power Rating (FPR):**

`FPR = Σ_i hull_rating_i × sqrt(f(HPx_i) × f(DPSx_i)) × w_i`

- w = 1.0 for the flagship.
- w = 0.6 for AI escorts.
- Fleet size: 1 flagship + up to 2 escorts on either side.

**Matchmaking:**
- Offer defenders whose FPR is 0.85–1.20× the attacker's.
- Widen by 5% per refresh, up to 0.70–1.40×.
- This keeps hull-class gaps playable. Within the band, a Man O'War only meets fleets that are ≥0.7× its rating.

**Win-rate target:** use Lanchester's square law (fleet strength scales with rating squared):

`P_att = s·R_a² / (s·R_a² + h·R_d²)`

- s ≈ 1.5 is the human-vs-AI skill edge.
- h = 1 + 0.04·fortress_lvl + 0.02·watchtower_lvl, so at most 1.3.
- At equal FPR, the attacker wins about 60% against an undefended port and about 54% against Fortress L5.
- Tune s and h from playtests.

**PvP mode rules** (new `SceneManager.GameMode.PVP_RAID`, `SceneManager.gd:32`):
- Defender AI is pinned to the Hard profile (×1.0). Today `AIDifficultyData.for_ship()` (`AIDifficultyData.gd:28-36`) applies the *attacker's* setting to every hostile ship, so an attacker on Relaxed would face defenders doing 0.55× damage.
- No mid-battle upgrade offers, no notoriety or heat gain, no `LootScalingData`.
- Captain level is clamped to 10 when computing PvP stats.
- Captain active abilities stay.

## 3. Loot math

Storage, not production, limits stockpiles:
- Market L5 makes 21,600 gold/h, but base gold storage is 5,000 (+4,500 per Warehouse L5).
- Wood, iron and rum caps are only 200–2,000 (`ResourceManager.gd:34-44`).

So loot is a share of storage. It only applies to gold, wood, iron and rum. **Eights and research can never be looted.**

**Formulas** (per resource r):
- `protected_r = 0.40 × max_storage_r(defender)` (a locked hold)
- `exposed_r = max(0, stored_r − protected_r)`
- `raw_r = exposed_r × 0.20 × outcome`, where outcome ∈ [0,1] is the share of the defender's fleet and fortress HP destroyed; sinking the flagship counts as 1.0.
- `gain_r = min(raw_r, 0.10 × max_storage_r(attacker)) × clamp(FPR_d/FPR_a, 0.5, 1.25)`
  - Attacking a weaker player pays less, attacking a stronger one pays more.
  - The cap on the attacker's own storage stops small accounts hitting jackpots.
- `defender_loss_r = 0.7 × gain_r` (30% is newly created, to soften losses).

**Caps:**
- A defender loses at most 25% of max storage per resource per 24h, across all raids.
- A defender is never taken below `protected_r`.
- 6h shield after any raid with outcome ≥ 0.5. Attacking someone breaks your own shield.
- An attacker's first 5 raids per day pay full value, then 25%. Players can still raid as much as they like, only the payout drops, so this doesn't break the "no energy gating" rule (`17_MONETIZATION.md:199`).

**Worked example:** the defender has one Warehouse L5 (gold cap 9,500) and is full.
- 3,800 protected, 5,700 exposed, raw = 1,140.
- The attacker's cap is 950, so the attacker gains 950 gold and the defender loses 665.
- Wood: gain 200.

That is about one merchant convoy's worth of loot (`MerchantLoot.tres` 100–250 × up to ×5 ≈ 500–1,250), so PvP pays about the same as PvE and doesn't become the best farm.

**PvP raids grant 0 Eights.** `00_VISION.md` §19.2 doesn't list PvP as an Eights source.

## 4. Backend and sync

- **The save is fully client-writable** (`schema.sql:30` lets each user update their own `save_data`). So:
  - An Edge Function builds the defense snapshot and computes FPR and loot server-side from the save's ship ids and levels.
  - It clamps levels (ship ≤ 10, captain ≤ 10) and stored amounts (≤ the storage the buildings allow).
  - Battle results get basic plausibility checks: damage ≤ DPS × duration, and a minimum duration.
- **Defender losses go through a `pvp_raids` ledger.**
  - The defender's client applies them idempotently using `applied_raid_ids` in `save_data`.
  - It deducts `min(loss, current exposed)` at apply time.
  - It re-applies the ledger after `SaveManager._apply_cloud_save` (`SaveManager.gd:819`) and conflict resolution (`:788`). Otherwise picking an older cloud copy could bring back stolen resources or deduct twice.

## 5. Bugs to fix first (these affect today's NPC raids too)

1. **NPC raids steal Eights and research.** `EmpireManager.gd:323-329` loops over every key in `current_resources`, including `"eights"`. This breaks the premium-currency rule (`ResourceManager.gd:8-13`). Skip `is_premium_currency()` and research, and apply the protected share.
2. **Fortress and watchtower levels don't count.** `EmpireManager.gd:238-239` scores only whether one exists, so an 18k-gold Fortress L5 defends the same as L1.
3. **Captain level has no cap.** `CaptainData.gd:62-68`; add a cap.
4. **The AI difficulty setting applies to defenders** (section 2). Pin a profile for this mode.

## 6. Implementation steps

1. Fix the bugs in section 5, each with a GUT test.
2. Add `scripts/modes/PvpBalanceData.gd` with `resources/balance/PvpBalance.tres` holding every constant above: A, loot fractions, caps, shield, band, escort weight, AI profile. This follows the `HeatCurve` / `MaelstromCurve` pattern.
3. Add `scripts/modes/PvpMath.gd` with pure static functions:
   - `soft_cap`, `hull_rating`
   - `ship_pvp_multipliers(owned, captain)`, which divides `get_effective_stats()` by the base template to get HPx and DPSx
   - `fleet_power`, `win_probability`, `loot_for`, `defender_loss`, `in_match_band`
   - A TypeScript copy of the same functions goes in the Edge Function.
4. Add `GameMode.PVP_RAID` and guards in `ShipController.gd:478`, `BoardingSystem.gd:123`, `EncounterManager` (upgrade offers) and `AIDifficultyData.for_ship`.
5. Add `tests/test_pvp_math.gd`:
   - f(x) < 1.6 and only ever increases.
   - Maxed vs fresh of the same hull ≤ 1.6×.
   - Eights and research are never in loot.
   - gain ≤ the attacker's cap.
   - The defender never drops below protected.
   - The 24h loss cap holds.
   - The match band is respected.
   - Equal FPR gives `win_probability` in 0.5–0.65.
6. Add a balance table to `docs/05_CURRENT_SYSTEMS.md`. Re-tune s and h after playtests.

### Critical Files for Implementation
- D:\Pirate-game\scripts\managers\EmpireManager.gd
- D:\Pirate-game\scripts\managers\OwnedShipData.gd
- D:\Pirate-game\scripts\world\CaptainData.gd
- D:\Pirate-game\scripts\combat\AIDifficultyData.gd
- D:\Pirate-game\scripts\managers\ResourceManager.gd