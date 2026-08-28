# Balance Model

> Version: 1.0 — created M11 ("Depth"), Requirement 10.
> Purpose: every new economy number M11 introduces (tech costs/effects, boss rewards, event
> outcomes) traces back to this document instead of being an isolated guess. This is the exact
> discipline `docs/13_CAMPAIGN_LEVELS_1-5.md`'s D53 defect (ship prices derived from hull mass,
> making the best warship in the game cost less than a quarter of one farm) skipped. Whoever
> authors M12+/M13+ content should extend this doc rather than starting a new one — see
> `docs/14_SYSTEM_INVENTORY.md` §6.

---

## 1. Reference scale — the ship-cost ladder

The one balance ladder this project has real, shipped numbers for
(`docs/13_CAMPAIGN_LEVELS_1-5.md` §2, confirmed live in `resources/ships/*.tres` — `cost_gold`/
`cost_wood`/`cost_iron` match this table exactly):

| Ship | Class | Gold | Wood | Iron | Available from |
|---|---|---|---|---|---|
| Dinghy | 1 | 150 | 40 | 10 | start |
| Sloop | 1 | 400 | 90 | 25 | start (player's first hull) |
| Schooner | 2 | 1,200 | 200 | 60 | Ch2 |
| Corvette | 2 | 1,800 | 280 | 90 | Ch2 |
| Brigantine | 3 | 3,000 | 420 | 150 | Ch3 |
| Frigate | 3 | 6,500 | 700 | 300 | Ch4 |
| Galleon | 4 | 14,000 | 1,300 | 650 | Ch5 |
| Man O'War | 5 | 28,000 | 2,400 | 1,200 | Ch5 (endgame) |

Every new number below is expressed as "roughly N% of the ship a player owns at that point in the
campaign" — never an isolated figure.

### Per-chapter economy snapshot (from `docs/13`'s own per-chapter "Economy targets" sections)

| Chapter | Island tier | Player ship | Chapter gold turnover | Notes |
|---|---|---|---|---|
| 1 | 1→2 | Sloop (already owned) | ≈600–900 | No ship purchase required |
| 2 | 2→3 | → Schooner (1,200g) | first real "must save" purchase | 7–8 buildings, avg level 3 |
| 3 | 3→4 | → Brigantine/Corvette | storage caps become binding | all 10 building types, avg level 4 |
| 4 | 4 | → Frigate (6,500g) | Academy built, `reinforced_hulls` researched (Objective 4.3/4.4) | HMS Intransigent boss |
| 5 | 4→5 | → Galleon/Man O'War | level-5 tiers across the board | Cárdenas' escort boss |

This is the affordability ladder new tech/boss/event costs must respect — a tech gated at island
tier N should cost roughly what a player at that tier can plausibly save toward, not what a
tier-5 player could shrug off.

---

## 2. Tech costing formula

Two existing techs are the only real reference points already in the game — use them, don't
invent a ratio from scratch:

| Tech | Cost (G/W/I) | Modifier |
|---|---|---|
| `reinforced_hulls` | 1,000 / 500 / 200 | health ×1.20 |
| `advanced_cannons` | 1,500 / 200 / 600 | damage ×1.25 |

Both are unlocked from game start (no gate) and both are required or strongly implied by Ch4
objectives (`UNLOCK_TECH reinforced_hulls` is Objective 4.4) — so despite having no formal tier
gate today, they function as roughly "Tier 1, affordable well before Ch4."

**New tech tier bands** (gold anchor; wood/iron follow each existing tech's own gold:wood:iron
ratio for its dominant modifier — health-leaning techs skew wood-heavy like `reinforced_hulls`
[1,000:500:200 ≈ 5:2.5:1], damage-leaning techs skew iron-heavy like `advanced_cannons`
[1,500:200:600 ≈ 7.5:1:3]):

| Tier | Gold anchor | Gate | Roughly | Chapter fit |
|---|---|---|---|---|
| T1 (existing) | 1,000–1,500 | none | ~2–3× starting purse (200g) | Ch1–2 |
| T2 | 250–600 | island tier 2–3 | ~20–40% of Schooner (1,200g) | Ch2 |
| T3 | 800–1,300 | island tier 3–4, may chain off a T1/T2 tech | ~25–40% of Brigantine (3,000g) | Ch3 |
| T4 | 2,000–2,800 | island tier 4, chains off a T2/T3 tech | ~30–40% of Frigate (6,500g) | Ch4 |
| T5 | 4,000–6,500 | island tier 5, capstone chaining off a T4 tech | ~15–25% of Galleon (14,000g) | Ch5 |

Rationale for T2 being *cheaper* than T1 in absolute gold: T1's two techs were authored (correctly,
per this same discipline) against a Ch1–2 purse; T2 techs need to be reachable earlier in the
tier-2/Ch2 window than the existing T1 pair currently sit, since Requirement 1.2 wants a real
gated progression, not a flat unlock-anything-anytime list. T3–T5 then climb with the ship ladder.

**Modifier magnitude**: stay in the 1.10–1.30× range per tech (matching the two existing techs'
1.20×/1.25×) so multiple stacked techs compound meaningfully without any single tech trivializing a
stat. A capstone T5 tech may go slightly higher (up to ~1.30×) since it's gated behind a full
prerequisite chain.

---

## 3. Boss reward tiers

Existing anchors (`resources/combat/encounters/*.tres`, read directly):

| Boss | bonus_gold | captain_xp | notoriety_reward | Tier |
|---|---|---|---|---|
| Ghost Ship (ambient, T1-ish) | 500 | 300 | 25 | low gate, high reward — rewards seeking it out |
| HMS Intransigent (Ch4) | 800 | 250 | 20 | chapter-gated, ~13% of a Frigate in gold |
| Cárdenas' Escort (Ch5) | (multi-stage — read at implementation time; treat as the ceiling) | — | — | endgame |

**New boss reward bands** (2 new bosses, Wave 4):
- **Tier 2 ambient boss** (Contested Waters, below Intransigent): bonus_gold ≈ 250–350 (roughly
  30–40% of Intransigent's), captain_xp ≈ 120–180, notoriety_reward ≈ 12–18. Positioned between
  Ghost Ship's low-gate/ambient reward and Intransigent's chapter-gated one.
- **Tier 4 boss** (late-Ch4/early-Ch5, between Intransigent and Cárdenas): bonus_gold ≈ 900–1,100
  (slightly above Intransigent, since it's later/harder), captain_xp ≈ 280–320, notoriety_reward
  ≈ 22–28.

---

## 4. World event outcome bands

Existing `EventData` resources (`resources/world/events/*.tres`) carry `weight`/`min_region_tier`
but the actual gold/loot outcome is resolved wherever `EventManager` applies the event (check at
implementation time). Anchor new events' outcomes the same way as boss rewards — express as a
fraction of the region-tier-appropriate ship cost:

| Region tier | Reference ship | Small event outcome (~2–4%) | Large event outcome (~8–12%) |
|---|---|---|---|
| 1 (Beginner) | Sloop (400g) | 8–16g | 32–48g |
| 2 (Contested) | Brigantine (3,000g) | 60–120g | 240–360g |
| 3 (Imperial) | Galleon (14,000g) | 280–560g | 1,120–1,680g |

A "small" event is a passive discovery (floating treasure); a "large" event is a real
risk/combat-gated payout (a convoy raid, a boss-adjacent event). This mirrors the existing
`MerchantConvoy`/`FloatingTreasure`/`GhostShipBoss` weight spread (0.3 weight on the boss-tier
event, implying it's rarer and higher-value).

---

## 5. Buildings

Read directly from `resources/buildings/*.tres` (`BuildingData.gd`: `cost_gold`/`cost_wood`/
`cost_iron`, 10 building types × 5 levels each = 50 files). Buildings carry no
`required_island_tier` field of their own — gating is by island tier elsewhere, not authored
per-building — so this section only covers per-level cost scaling, not a chapter gate.

| Building (L1) | Gold | Wood | Iron | Produces |
|---|---|---|---|---|
| Rum Distillery (Farm) | 75 | 15 | 5 | 3 rum/tick |
| Iron Mine | 100 | 20 | 0 | 2 iron/tick |
| Warehouse | 100 | 50 | 10 | (storage) |
| Shipyard | 200 | 150 | 100 | (unlocks ship purchase) |
| Academy | 500 | 100 | 20 | research |
| Market | 0 | 100 | 50 | 10 gold/tick |
| Tavern | 0 | 100 | 0 | gold (crew) |
| Watchtower | 0 | 200 | 100 | (defense) |
| Fortress | 1,000 | 500 | 500 | (defense) |

**Per-level scaling is a single uniform curve applied to every building type's own L1 base cost** —
confirmed identical ratios across Academy, Farm, Fortress, and Market despite very different
absolute L1 costs:

| Level | Cost relative to L1 |
|---|---|
| L1 | 1× (base) |
| L3 | ~3.5× |
| L5 | ~18× |

A new building type should pick a fair L1 cost against the table above (by comparing what it
produces/unlocks to an existing building's role), then apply this same 3.5×/18× curve for L3/L5
rather than inventing a new one — L2/L4 sit between these two checkpoints on the same curve.

---

## 6. Ship modules

Read directly from `resources/modules/*.tres` (`ShipModuleData.gd`: `cost_gold`/`cost_wood`/
`cost_iron` plus one or two `*_mult` fields; 10 modules across 5 slots — Hull, Cannon, Sail,
Utility, Special):

| Module | Slot | Gold | Effect |
|---|---|---|---|
| Reinforced Planking | Hull | 900 | health ×1.20 |
| Reinforced Rigging | Sail | 900 | sails ×1.30 |
| Extra Berths | Utility | 900 | crew ×1.25 |
| Full Canvas | Sail | 1,000 | speed ×1.20 |
| Long Glass | Utility | 1,100 | cannon range ×1.20 |
| Heavy Cannons | Cannon | 1,800 | damage ×1.25 |
| Swift Loaders | Cannon | 1,600 | fire rate ×1.30 |
| Master Gunners | Special | 2,600 | damage ×1.15 **+** fire rate ×1.10 |
| Copper Bottom | Special | 2,400 | speed ×1.15 **+** sails ×1.15 |
| Iron Hull | Hull | 3,200 | health ×1.35 |

Two clean price bands: a **single ~1.20–1.30× modifier costs ~900–1,800g** scaled to the
modifier's own strength (900g ≈1.20–1.30×, 1,600–1,800g ≈1.25–1.30×); a module that either stacks
**two** modifiers or pushes a single one past ~1.30× costs **2,400–3,200g** (the Special slot's two
modules are both dual-effect at this tier; Iron Hull is the one single-effect outlier, priced for
its unusually high 1.35×). A new module should be priced by which band its effect(s) land in, not
by slot.

---

## 7. Captains

Read directly from `resources/captains/*.tres` (`CaptainData.gd`: `hire_cost_gold`, 20 captains).
Grouped by `unlock_chapter_id` (captains with no `unlock_chapter_id` are hireable from game start):

| Gate | Captains (gold) | Range |
|---|---|---|
| Start (no gate) | Jack 500, Anne 700, Mary 900, Redbeard 1,100 | 500–1,100 |
| Ch1 (`ch1_the_drowned_port`) | Diego 850, Fiona 1,230, Bartholomew 1,350, Cutlass 1,390, Whistler 1,575 | 850–1,575 |
| Ch2 (`ch2_blood_in_the_shallows`) | Isabela 750, Grace 960, OldTom 1,085, Marguerite 1,780, Rook 2,280 | 750–2,280 |
| Ch3 (`ch3_the_kings_answer`) | Ezra 2,015, Barnaby 2,920, Constance 3,300 | 2,015–3,300 |
| Ch4 (`ch4_the_admirals_gambit`) | Selene 2,580, Yusuf 3,730, Ophelia 4,000 | 2,580–4,000 |

Expressed against §1's chapter ship purchase (the other big-ticket spend at that point in the
campaign): a Ch1 captain runs ~70–130% of the Schooner (1,200g); a Ch4 captain runs ~40–62% of the
Frigate (6,500g) — hiring gets cheaper *relative to* the ship ladder as chapters progress, which
tracks with a player having more simultaneous demands on gold later (fleet size, modules, techs).
Note Isabela (750g, Ch2) already undercuts the Ch1 range — an existing outlier, not something this
pass corrects (renumbering it would ripple into save-compatible balance elsewhere); flag rather
than silently fix if it's revisited.

A new captain's cost should land inside its unlock chapter's range above, or explicitly explain
why it's an outlier (a themed reward captain, a joke/easter-egg discount, etc.).

---

## 8. Raid theft fraction

`EmpireManager._resolve_raid()` (scripts/managers/EmpireManager.gd) — not a `.tres`-authored value,
computed at raid-resolution time:

```
steal_fraction = clamp((attack_score - defense_score) / attack_score, 0.05, 0.25)
defense_score  = (has fortress ? 20 : 0) + (has watchtower ? 15 : 0) + (10 × ships defending home)
attack_score   = (highest active region tier × 25) + (notoriety × 0.3)
```

A raid that isn't repelled steals **5–25% of every current resource stockpile** (gold/wood/iron/
rum alike — not a fixed amount, and not scoped to a single resource). The 5% floor means even a
maxed-out defense against a low-tier attacker still loses something on a failed defense; the 25%
ceiling caps how much a single raid can hurt regardless of how far behind defense falls. This
range is already tuned and bounded — a future change should adjust the score weights (fortress/
watchtower/ship values, region-tier multiplier) rather than the 5–25% clamp itself, since that
clamp is what keeps a raid from ever being a full wipeout or a total non-event.

---

## 9. Loot tables → encounter mapping

`resources/loot/*.tres` (`LootTableData.gd`: `min_x`/`max_x` per resource) are referenced by
`resources/combat/encounters/*.tres` (`EncounterData.gd`: `loot_table` + `bonus_gold`/
`captain_xp`/`notoriety_reward` on top of the loot roll):

| Loot table | Gold | Wood | Iron | Rum | Used by |
|---|---|---|---|---|---|
| `StandardEnemyLoot` | 20–60 | 5–15 | 2–8 | 0–2 | Skirmish, Ambush, Defense |
| `MerchantLoot` | 100–250 | 20–50 | 10–25 | 5–15 | ConvoyRaid, EliteHunters |
| `BossLoot` | 500–1,000 | 100–200 | 50–100 | 20–40 | GhostShipBoss, IntransigentBoss, CardenasBoss |

Each encounter's fixed `bonus_gold`/`captain_xp`/`notoriety_reward` scales with the same three-tier
split (ambient skirmish → merchant-adjacent → boss), already covered for the boss row in §3. A new
ambient/merchant-tier encounter should reuse `StandardEnemyLoot`/`MerchantLoot` rather than
authoring a fourth loot table, unless it's introducing a genuinely new resource type.

---

## 10. Maintenance note

When M12/M13 add further content, extend the tables above rather than re-deriving the anchor —
the ship-cost ladder in §1 is the one number set this project has actually playtested pricing
against (per the D53 postmortem). If the ship ladder itself changes, every table here needs
re-deriving against the new numbers, not just the newest addition.

_2026-08-28 (M12 Task 8): added §5–§9 (buildings, modules, captains, raid theft fraction, loot
tables) — every remaining resource/encounter category with a cost or reward field is now modeled.
Ammo, battle upgrades, and AI profiles have no cost/reward fields (ammo isn't purchasable, battle
upgrades are free in-battle picks, AI profiles are pure behavior tuning) and are out of scope for
an economy balance model._
