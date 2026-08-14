# 13_CAMPAIGN_LEVELS_1-5.md

> Version: 1.0
> Status: Living Document — playable chapter design
> Owner: Project Lead
>
> Story: `docs/06_NARRATIVE_AND_WORLD.md` · Map: `docs/11_WORLD_MAP.md` ·
> Cast: `docs/12_CHARACTER_BIBLE.md` · What exists: `docs/05_CURRENT_SYSTEMS.md`

---

# 1. What a "level" is in this game

There are no levels in the arcade sense. A **chapter** is a bundle of objectives with a gate in
front of it and a reward behind it. The player's actual "level" is three numbers that already
exist in code:

| Reads as | Backed by | Range in v1 |
|---|---|---|
| How developed is my port? | `Island.get_island_tier()` (floor of average building level) | 1–5 |
| How famous/hunted am I? | `EmpireManager.notoriety` | 0–200+ |
| How far can I sail safely? | highest active `RegionData.tier` | 1–3 |

The campaign layer adds **no fourth number**. A chapter is complete when the simulation says its
objectives are satisfied.

## Alignment table

| Ch | Title | Gate | Region | Home tier at start→end | Notoriety band | Player ship class |
|---|---|---|---|---|---|---|
| 1 | The Drowned Port | new game | Beginner | 1 → 2 | 0–20 | Sloop |
| 2 | Blood in the Shallows | Ch1 done | Beginner | 2 → 3 | 20–60 | Sloop → Schooner |
| 3 | The King's Answer | notoriety ≥ 60 (Contested activates) | Contested | 3 → 4 | 60–110 | Brigantine / Corvette |
| 4 | The Admiral's Gambit | Ch3 done | Contested | 4 | 110–150 | Frigate |
| 5 | The Silver Fleet | notoriety ≥ 150 (Imperial activates) | Imperial | 4 → 5 | 150+ | Galleon → Man O'War |

**The gates for Ch3 and Ch5 are the notoriety thresholds already authored in
`resources/world/regions/*.tres` (60 and 150).** The campaign does not add its own thresholds;
it reacts to `EmpireManager.region_activated`.

## Pacing budget

| Ch | Target play time | Sessions | New captains | New buildings unlocked | Boss |
|---|---|---|---|---|---|
| 1 | 25–40 min | 1–2 | 4 | Farm, LumberMill, Warehouse, Tavern | — |
| 2 | 45–70 min | 2–3 | 5 | Shipyard, Mine, Market | — |
| 3 | 60–90 min | 3 | 5 | Watchtower, Fortress | — (a raid, not a boss) |
| 4 | 45–70 min | 2 | 3 | Academy | **HMS *Intransigent*** |
| 5 | 90–150 min | 3–4 | 3 | (level-5 tiers of all) | **Cárdenas' escort** |

Cumulative: **≈ 5–8 hours** to complete Chapter 5. That is the v1 campaign length, in line with
`AGENTS.md`'s "Version 1.0 is intentionally small."

---

# 2. Three economy defects that must be fixed before this pacing is real

All three found by direct inspection on 2026-08-14. Every number in §3–§7 assumes these are
fixed; without them the pacing above is fiction.

### E1 — 🔴 **The ship ladder is nearly free, and priced off a physics value**

`scripts/ui/IslandMenu.gd:357-359` computes ship price from hull **mass**:

```gdscript
var cost_gold = int(ship.mass / 100)
var cost_wood = int(ship.mass / 200)
var cost_iron = int(ship.mass / 400)
```

Actual resulting prices, against a starting purse of **200 gold** and a level-5 Farm at
**1350 gold**:

| Ship | mass | Price (gold / wood / iron) | HP | Dmg |
|---|---|---|---|---|
| Dinghy | 2 000 | **20** / 10 / 5 | 50 | 10 |
| Sloop | 5 000 | **50** / 25 / 12 | 100 | 15 |
| Schooner | 6 000 | **60** / 30 / 15 | 120 | 15 |
| Corvette | 7 000 | **70** / 35 / 17 | 140 | 20 |
| Brigantine | 8 000 | **80** / 40 / 20 | 150 | 20 |
| Frigate | 12 000 | **120** / 60 / 30 | 250 | 30 |
| Galleon | 20 000 | **200** / 100 / 50 | 400 | 35 |
| **Man O'War** | 30 000 | **300** / 150 / 75 | **600** | **50** |

The best warship in the game costs **300 gold** — less than a quarter of one level-5 Farm, and
affordable within the first few minutes. Every wood/iron cost also sits under the starting
storage caps (200 wood / 100 iron), so nothing gates it.

This defeats **M6 Requirement 8 in full** — the circular economy that combat loot is supposed to
fund. It also violates `AGENTS.md` ("Hardcoded values are forbidden… balance belongs inside
Resources") *and* couples game balance to buoyancy tuning: any future change to a hull's `mass`
silently re-prices it.

**Fix (M7, priority 1):** add `cost_gold` / `cost_wood` / `cost_iron` / `cost_rum` and
`ship_class: int` to `ShipStats`, author them per hull, and delete the mass formula. Target
ladder, roughly one chapter apart:

| Ship | Class | Gold | Wood | Iron | Available from |
|---|---|---|---|---|---|
| Dinghy | 1 | 150 | 40 | 10 | start |
| Sloop | 1 | 400 | 90 | 25 | start (player's first hull) |
| Schooner | 2 | 1 200 | 200 | 60 | Ch2 |
| Corvette | 2 | 1 800 | 280 | 90 | Ch2 |
| Brigantine | 3 | 3 000 | 420 | 150 | Ch3 |
| Frigate | 3 | 6 500 | 700 | 300 | Ch4 |
| Galleon | 4 | 14 000 | 1 300 | 650 | Ch5 |
| Man O'War | 5 | 28 000 | 2 400 | 1 200 | Ch5 (endgame purchase) |

Wood/iron figures deliberately exceed the base storage caps (200 wood / 100 iron), so a
Warehouse upgrade becomes a *prerequisite* for a bigger hull. That is the storage pressure
Requirement 7.2 asks for, made load-bearing.

### E2 — 🟡 Ship display names come from filenames

`IslandMenu._create_ship_entry()` derives the shown name via
`ship.resource_path.get_file().split(".")`. `ShipStats` has no `display_name` and no `ship_id`,
so the Shipyard reads "ManOWar" and nothing can localise or re-skin a hull.
**Fix (M7):** add `ship_id` and `display_name` to `ShipStats`.

### E3 — 🟡 No ship class field, so "bigger enemies as notoriety rises" has nothing to sort on

M6 Requirement 8.4 requires enemy ship classes to trend larger with notoriety. `ShipStats`
carries no class/tier, so `EnemySpawner` cannot rank hulls. It currently approximates via
`max_crew`. The `ship_class` field in E1's fix resolves this too.

**Consequence for this document:** the "Player ship class" column in §1 and every "expected
hull" line below are written against the E1 target ladder, not against current prices.

---

# 3. Chapter 1 — The Drowned Port

**Gate:** new game. **Region:** Beginner Waters. **Target:** 25–40 min.

## Cold start — resolved

`ResourceManager` starts the player on **200 gold**; `IslandMenu`'s colonize button costs
**1000**; and `EmpireManager.home_island_id` is only ever set by `Island.gd:124` on a successful
capture. A new player therefore cannot own *any* island, has no production, and must grind 800
gold from combat before the game's central verb becomes available.

**Resolution:** a new game **starts with Port Royal already owned and set as home.**
`island_type` becomes `CAPITAL`, `owner_faction` is `PlayerFaction.tres`, and
`EmpireManager.home_island_id = "port_royal"` is seeded on new-game.

Story-justified: it is a drowned ruin that three empires wrote off. Nobody is charging for it.
The 1000-gold colonise cost still applies to every *additional* island, so the mechanic keeps
its teeth from Chapter 2 onward — and this matches Clash of Clans, where you never have to earn
the right to have a base.

## Opening beat — Higgins

> "That's it, then. That's Port Royal. Half of it's under the water and the other half wishes it
> was."
>
> "Two thousand souls in one afternoon, and the King's men sailed off and called it cursed. So
> did everyone else, which is the only reason it's ours."
>
> "Say the word and I'll turn us about. …No? Right. Then we'd best start with something that
> makes rum, because I'm not doing this sober."

## Objectives

| # | Objective | `ObjectiveData.condition` | Target | Count |
|---|---|---|---|---|
| 1.1 | Come alongside the drowned port | `DOCK_AT_ISLAND` | `port_royal` | 1 |
| 1.2 | Raise a distillery from the rubble | `BUILD_STRUCTURE` | `farm` | 1 |
| 1.3 | Get the timber flowing | `BUILD_STRUCTURE` | `lumber_mill` | 1 |
| 1.4 | Somewhere to put it all | `BUILD_STRUCTURE` | `warehouse` | 1 |
| 1.5 | Sink whatever comes sniffing | `DESTROY_SHIPS` | `pirate_clans` | 3 |
| 1.6 | A roof for the crew | `BUILD_STRUCTURE` | `tavern` | 1 |
| 1.7 | Sign your first captain | `RECRUIT_CAPTAIN` | — | 1 |
| 1.8 *(optional)* | Raise the port to tier 2 | `REACH_ISLAND_TIER` | `port_royal` | 2 |

The existing 8 `TutorialManager` steps map onto 1.1–1.7 almost exactly — sail, dock, build,
recruit, fight, capture. **They become this chapter's data.** The one step that changes is
`capture`: the player already owns Port Royal, so the capture beat moves to Chapter 2 where it
is a real decision.

## What it teaches
Sailing and docking · the build menu · the economy tick · that broadsides must be *aimed* ·
storage caps as a reason to spend.

## Enemies
Pirate Clan Sloops and Dinghies only, `HarassingSloop` profile, one at a time, spawned within
the Beginner ring. No Navy, no boarding, no raids.

## Economy targets
Reach ~4 buildings at level 1–2. Gold turnover across the chapter ≈ 600–900. First Sloop is
already owned; no ship purchase required.

## Rewards
4 captains become hirable (Jack, Anne, Redbeard, Mary) · Warehouse unlocked ·
notoriety lands ~15–20 from the three kills and nothing else.

## Closing beat — Factor Hale arrives
> "Good afternoon. Cornelius Hale, Merchant Guild. I represent every cargo that passes this
> water, which until last month included nothing at all bound for *here*."
>
> "There is smoke coming from a harbour that has been dead for four years. My ledger requires a
> name for it. Whom, precisely, am I invoicing?"

*(This is the empire-naming prompt.)*

## Softlock guards
- Objectives 1.2–1.4 cost 75/50/100 gold against a 200 start plus production and kill loot —
  reachable even if the player never fires a shot, because 1.5's enemies come to *them*.
- If the player's ship is destroyed, respawn at Port Royal with a repair cost, never a loss.
- If 1.5 stalls (no spawns), `EnemySpawner.spawn_hunter()` is called on the objective's stall
  timer — the same escape hatch `TutorialManager._spawn_tutorial_hunter()` already uses.

---

# 4. Chapter 2 — Blood in the Shallows

**Gate:** Chapter 1 complete. **Region:** Beginner Waters (Skull Cove visible but in Contested).
**Target:** 45–70 min.

## Opening beat — Morrow's messenger
> "Compliments of Blackjaw Morrow, out of Skull Cove. He's pleased for you, truly. New port,
> new flag, all very stirring."
>
> "The shallows run on a tithe. One part in five, collected quarterly, and in exchange nobody
> burns your distillery. Blackjaw kept this water free of the King's men for twenty years by
> making sure no single outfit ever got fat enough to be worth the King's attention."
>
> "He'll have your answer now, and he's sent three sloops to carry it."

## Objectives

| # | Objective | `ObjectiveData.condition` | Target | Count |
|---|---|---|---|---|
| 2.1 | Refuse the tithe | `DESTROY_SHIPS` | `pirate_clans` | 3 |
| 2.2 | Build a shipyard | `BUILD_STRUCTURE` | `shipyard` | 1 |
| 2.3 | Buy a hull that can take a hit | `OWN_SHIP_CLASS` | class 2 | 1 |
| 2.4 | Take one alive | `BOARD_SHIPS` | any | 2 |
| 2.5 | Open the mines | `BUILD_STRUCTURE` | `mine` | 1 |
| 2.6 | Raise the port to tier 3 | `REACH_ISLAND_TIER` | `port_royal` | 3 |
| 2.7 | Take Blackjaw's cove | `CAPTURE_ISLAND` | `skull_cove` | 1 |
| 2.8 *(optional)* | Keep Hale sweet | `ACCUMULATE_RESOURCE` | trade income | — |

**2.7 is the chapter's spine and its cost.** Capturing Skull Cove requires Contested Waters to
be active (`Island._should_be_active()` gates capture on region activation), which requires
notoriety ≥ 60 — which objectives 2.1–2.6 supply naturally (+1/kill, +15/capture, boarding
loot). The chapter therefore ends *by* crossing the Ch3 gate. The story and the system agree
without either being told to.

## What it teaches
Boarding (the M6 climax mechanic) · ammunition choice — chain shot to cripple a runner, grape to
strip a boarding target · that capturing an island costs you a faction · that a bigger hull is
something you save for.

## Enemies
Pirate Clan Sloops → Schooners → Morrow's Brigantine escort at the cove. First `StandardEnemy`
profiles. Pirate Clan reputation goes permanently hostile after 2.7.

## Economy targets
7–8 buildings, average level 3. First real ship purchase (Schooner ≈ 1 200 gold under the E1
ladder) — the first time the player must *save*.

## Rewards
Skull Cove's rum production (the best in the game) · 5 captains (Diego, Cutlass, Fiona,
Bartholomew, Whistler) · Shipyard/Mine/Market unlocked.

## Closing beat — Higgins
> "Blackjaw's flag is off the pole and the cove is ours. I'd enjoy it more if the smoke wasn't
> visible from the trade lane."
>
> "That lane is the King's."

## Softlock guards
- If the player cannot afford a class-2 hull, 2.3 stalls with a hint pointing at trade and
  boarding loot; it never blocks 2.5–2.7.
- Skull Cove's defenders scale off region tier 2 only — they do not scale with notoriety past
  the Contested multiplier, so a player who over-farms notoriety cannot lock themselves out.
- If the player captures Skull Cove *before* completing 2.1–2.6 (possible), those objectives
  retro-complete on load per anti-softlock rule 5.

---

# 5. Chapter 3 — The King's Answer

**Gate:** `EmpireManager.region_activated("contested_waters")` — notoriety ≥ 60.
**Region:** Contested Waters. **Target:** 60–90 min. **This is the difficulty step.**

## Opening beat — Commander Hollis, by megaphone
> "By order of the Admiralty. The settlement at Port Royal is declared an unlawful occupation of
> Crown ground. Its harbour is closed. Its trade is contraband."
>
> "You have no charter, no letters, and no standing. You have a fortnight to disperse."
>
> "I am required to read that aloud before we begin. It is read."

## Objectives

| # | Objective | `ObjectiveData.condition` | Target | Count |
|---|---|---|---|---|
| 3.1 | Break the blockade | `DESTROY_SHIPS` | `royal_navy` | 6 |
| 3.2 | Build a watchtower | `BUILD_STRUCTURE` | `watchtower` | 1 |
| 3.3 | Build a fortress | `BUILD_STRUCTURE` | `fortress` | 1 |
| 3.4 | Survive a raid on your port | `SURVIVE_RAID` | — | 1 |
| 3.5 | Assign a ship to defend home | `OWN_SHIP_CLASS` + Defend Home flag | class 3 | 1 |
| 3.6 | Raise the port to tier 4 | `REACH_ISLAND_TIER` | `port_royal` | 4 |
| 3.7 *(optional)* | Cripple a Navy ship without sinking it | `BOARD_SHIPS` | `royal_navy` | 1 |

**3.4 is the most important objective in the campaign.** It is the first time the base is
attacked, which is the moment a Clash-of-Clans base stops being a menu. `EmpireManager` already
rolls a raid every 15 real minutes at probability `clamp(notoriety/200, 0.05, 0.25)`, resolves
defence from Fortress/Watchtower presence plus Defend-Home ships, and renders
`RaidReportScreen.tscn`. Chapter 3 exists to make the player *meet* that system while they still
have time to build defences — 3.2/3.3/3.5 are the answer to 3.4, handed over before the exam.

> **Tuning note:** at notoriety ~60–110 the raid chance is 0.30→0.25 clamped to **0.25** per
> 15 min, i.e. an expected first raid ~1 hour in. Chapter 3's target length is 60–90 min, so this
> lines up — but it is probabilistic. `SURVIVE_RAID` must accept *either* outcome (repelled or
> looted) as satisfying the objective; being robbed is a lesson, not a fail state. Consider a
> guaranteed scripted first raid on 3.3's completion so no player misses the beat.

## What it teaches
The world pushes back · defence buildings have a purpose · fleet assignment matters · Navy ships
fight in pairs and shoot better · stern crits (Navy hulls are tanky from the front).

## Enemies
Royal Navy Schooners, Brigantines, Corvettes in pairs. `is_empire = true`, so
`EnemySpawner.compute_spawn_multiplier()` applies ×1.3 + notoriety scaling for the first time.
Plus Pirate Clans, now permanently hostile from Ch2.

## Economy targets
All 10 building types present, average level 4. Brigantine or Corvette owned. Storage caps
become the binding constraint — Warehouse upgrades stop being optional.

## Rewards
5 captains, including two story recruits: **Marguerite** (arrives unhired at the player's port;
Vance burned her port too) and **Isabela** (Navy defector) · Watchtower/Fortress unlocked.

## Closing beat — Marguerite
> "They read you the same speech they read me. Mine ended with the harbour on fire and the
> Admiralty calling it a lawful action."
>
> "So I'll ask what nobody else will. Are you building a *port*, or are you just building
> something bigger to lose?"

## Softlock guards
- Raids can never take the island, only stored resources (`EmpireManager._resolve_raid()` only
  calls `spend_resource`). Guard this with a test.
- Raid theft is a *fraction* of stored resources, so it can never drop the player below the cost
  of rebuilding.
- If the player has no Fortress/Watchtower when the first raid fires, the loss is capped so 3.6
  stays reachable.

---

# 6. Chapter 4 — The Admiral's Gambit

**Gate:** Chapter 3 complete. **Region:** Contested Waters. **Target:** 45–70 min.
**The first real boss.**

## Opening beat — Admiral Vance
> "Commander Hollis followed his orders correctly and lost, which tells me the orders were
> wrong, not the man."
>
> "I was at anchor when Port Royal went into the sea. I watched two thousand people drown in a
> town that had no law in it, and I have spent every year since making certain no other harbour
> gets the chance."
>
> "You are not a criminal to me. You are a *repetition*. I will be at Frostbite Reef."

## Objectives

| # | Objective | `ObjectiveData.condition` | Target | Count |
|---|---|---|---|---|
| 4.1 | Follow him into the cold | `DISCOVER_ISLAND` | `frozen_island` | 1 |
| 4.2 | Strip the escort | `DESTROY_SHIPS` | `royal_navy` | 8 |
| 4.3 | Build the Academy | `BUILD_STRUCTURE` | `academy` | 1 |
| 4.4 | Research a hull upgrade | `UNLOCK_TECH` | `reinforced_hulls` | 1 |
| 4.5 | Buy a frigate | `OWN_SHIP_CLASS` | class 3 | 1 |
| 4.6 | **Sink HMS *Intransigent*** | `DEFEAT_BOSS` | `intransigent` | 1 |
| 4.7 | Take the reef | `CAPTURE_ISLAND` | `frozen_island` | 1 |
| 4.8 *(optional)* | Board the *Intransigent* instead of sinking her | `BOARD_SHIPS` | `intransigent` | 1 |

## Boss design — HMS *Intransigent*
Built on the existing `BossShip.tscn` + `AIProfileData` + `LootTableData` (`BossLoot.tres`), so
this needs **content, not a new system**:

- Hull ≈ Man O'War tier (600 HP), heavy front armour, slow turn — beatable only by out-turning
  her and working the stern arc. This is what teaches `stern_crit_multiplier`.
- Two escort Corvettes that must be dealt with or they chain-shot the player's sails.
- She uses chain shot herself: sails drop, `get_speed_multiplier()` bites, and the player learns
  that mobility *is* health.
- Ash/spray weather is not needed; the cold reef fog is enough.
- Boarding her (4.8) requires crew, which requires the Tavern crew-recruit flow from M6 — the
  optional objective that finally makes crew feel like a resource.

## What it teaches
That a fight can be *lost* · positioning over volume of fire · tech research as preparation ·
that the optional harder path (boarding) pays better.

## Economy targets
Average building level 4, Frigate owned, first tech unlocked. Gold turnover ≈ 8 000–12 000.

## Rewards
3 heavy captains (Barnaby, Constance, Ezra) · Academy/tech line · Frostbite Reef's iron ·
**Navy raid frequency drops** (their forward base is gone — a defensive reward, which is a kind
this game does not otherwise have).

## Closing beat — Vance, defeated, not dead
> "Well. That is that, and I find I mind less than I expected to."
>
> "You should know what you have actually won. I was the fence, not the wolf. In six weeks the
> Spanish treasure fleet crosses this water — a hundred and twenty thousand in silver behind
> Beatriz de Cárdenas, who has never lost a crossing and does not care whose flag is on your
> harbour."
>
> "I was trying to keep this water *boring*, Captain. You have made it interesting. I hope you
> enjoy that."

## Softlock guards
- The boss is optional to *approach* — she never sails to the player's port.
- On player death, respawn at home with the boss reset to full. No progress consumed, no
  attempt limit.
- 4.5's Frigate (≈ 6 500 gold under the E1 ladder) must be affordable from Ch3's economy alone;
  verify in tuning, and if not, drop the objective to class 2.

---

# 7. Chapter 5 — The Silver Fleet

**Gate:** `EmpireManager.region_activated("imperial_waters")` — notoriety ≥ 150.
**Region:** Imperial Waters. **Target:** 90–150 min. **The v1 finale.**

## Opening beat — Higgins
> "Six weeks, the Admiral said. It's been five."
>
> "Cárdenas stages out of Cartagena and coals at Mount Brimstone — that volcano's the whole
> reason the crossing works. Cut the mountain and the fleet crosses thirsty."
>
> "I've never in my life advised anyone to attack an empire. I'm advising it now. I'd like the
> record to show I've changed."

## Objectives

| # | Objective | `ObjectiveData.condition` | Target | Count |
|---|---|---|---|---|
| 5.1 | Cut the supply | `CAPTURE_ISLAND` | `volcano_island` | 1 |
| 5.2 | Sink the escort screen | `DESTROY_SHIPS` | `spanish_empire` | 12 |
| 5.3 | Buy a ship of the line | `OWN_SHIP_CLASS` | class 4 | 1 |
| 5.4 | Raise the port to tier 5 | `REACH_ISLAND_TIER` | `port_royal` | 5 |
| 5.5 | **Break Cárdenas' escort** | `DEFEAT_BOSS` | `cardenas_escort` | 1 |
| 5.6 | Take Cartagena | `CAPTURE_ISLAND` | `cartagena_outpost` | 1 |
| 5.7 *(optional)* | Board the flagship | `BOARD_SHIPS` | `cardenas_escort` | 1 |
| 5.8 *(optional)* | Own a Man O'War | `OWN_SHIP_CLASS` | class 5 | 1 |

**5.4 is the real wall.** Island tier 5 means every building on Port Royal at level 5 —
under the authored chains that is roughly 30 000 gold, 6 000 wood, 2 000 iron in cumulative
upgrade cost, against a level-5-warehouse gold cap. It is *not* reachable from production alone,
which is precisely what M6 Requirement 7.4 demands. Chapter 5 is where the circular economy
either works or is exposed.

## Boss design — Cárdenas' escort
A **multi-stage fight**, distinct from Ch4's duel, reusing the same components:
1. **Screen** — four Frigates in line abreast; the player must break the line, not brawl it.
2. **Flagship** — Galleon-class with the longest `cannon_range` in the game, so closing costs
   hull the whole way in.
3. **Cartagena's shore guns** — reuse the island-defender spawn path; the fight has *terrain*.

## What it teaches
Everything at once, under pressure. No new mechanic — Chapter 5's job is mastery, not tuition.

## Economy targets
Island tier 5. Galleon owned, Man O'War affordable-but-painful. Cartagena becomes the player's
**second buildable island** — the design already supports it (`Island.gd` is per-instance) but
no UI flow has ever proven it. **Verify explicitly in M7.**

## Rewards
3 elite captains (Selene, Yusuf, **Ophelia** — recruited inside Cartagena, the best all-rounder
in v1) · the largest single loot payout in the game · a second developable island.

## Closing beat — Cárdenas, then the chart
> **Cárdenas:** "You imagine you have taken something from Spain. You have taken one crossing.
> There will be another in the spring, and I will be commanding it."
>
> "Enjoy your harbour, Captain. It is a very small piece of a very large ocean."
>
> **Higgins, later, in the strongbox:** "Captain. There's a chart in here that shouldn't be.
> There's an island on it that isn't on anything else I've ever seen — and I know this hand.
> This is Solomon Vane's hand, and Vane went down with the *Wandering Widow* forty years back."
>
> "…I'd very much like you to tell me I'm wrong."

**No answer is given. v1 ends here.** The unmapped chart is the seed for the Ancient Ocean
(region tier 4, reserved in `docs/11_WORLD_MAP.md` §5).

## Softlock guards
- 5.4's tier-5 requirement must be verified against the *actual* authored upgrade costs before
  ship. If it exceeds ~4 hours of grind, split it into "tier 4 required / tier 5 optional".
- Imperial defenders scale with notoriety (`compute_spawn_multiplier`). Cap the effective
  multiplier so a notoriety-300 player does not face unwinnable garrisons.
- Cartagena's capture must not depend on Mount Brimstone (5.1) being held, or losing it to a
  counter-raid would soft-block the finale.

---

# 8. Objective-condition coverage audit

Every condition in `ObjectiveData.Condition` used above, against the signal that resolves it.
**Nothing in this design needs a signal that does not already exist or is not already planned.**

| Condition | Resolved by | Status |
|---|---|---|
| `DOCK_AT_ISLAND` | `WorldManager.player_docked(island_id)` | ✅ exists |
| `BUILD_STRUCTURE` | `IslandMenu.structure_changed(building_id, is_upgrade)` | ✅ exists |
| `UPGRADE_STRUCTURE_TO_LEVEL` | same signal + `BuildingData.level` | ✅ exists (M6) |
| `REACH_ISLAND_TIER` | `Island.tier_changed` | ✅ exists (M6) |
| `DESTROY_SHIPS` | `EnemySpawner.enemy_destroyed` / `ShipDamage.destroyed` | ✅ exists |
| `BOARD_SHIPS` | `BoardingSystem` boarding-resolved signal | ✅ exists (M6) |
| `DEFEAT_BOSS` | `WorldEventManager` boss death | 🟡 needs a boss id on the signal |
| `CAPTURE_ISLAND` | `EmpireManager.island_captured(island_id)` | ✅ exists |
| `DISCOVER_ISLAND` | — `IslandData.discovered` is authored but **never set** | ❌ M7 |
| `RECRUIT_CAPTAIN` | `FleetManager.captain_recruited(CaptainData)` | ✅ exists |
| `OWN_SHIP_CLASS` | `FleetManager.owned_ships` + new `ShipStats.ship_class` | 🟡 needs E1 |
| `UNLOCK_TECH` | `TechManager` unlock | ✅ exists |
| `ACCUMULATE_RESOURCE` | `ResourceManager.resources_changed` | ✅ exists |
| `REACH_NOTORIETY` | `EmpireManager.notoriety_changed` | ✅ exists |
| `SURVIVE_RAID` | `EmpireManager.raid_resolved` | ✅ exists (M4) |

Three gaps, all small: a boss id on the boss-death signal, a `discovered` write path, and the
E1 ship-class field. All are M7 tasks.

---

# 9. Chapter 6+ (not built — shape only)

So the spine is provably extensible without a rewrite:

| Ch | Working title | Gate | Hook it pays off |
|---|---|---|---|
| 6 | The Wandering Widow | notoriety ≥ 300 (Ancient Ocean) | Vane's chart; Higgins' secret |
| 7 | Marguerite's Harbour | Ch6 | Her port has never been retaken |
| 8 | The Spring Crossing | seasonal, repeatable | "There will be another in the spring" |
| 9 | An Unwelcome Ally | Ch8 | Vance survived Ch4 |
| 10 | The Cove Without a King | Ch7 | Morrow's seat was never inherited |

Each is **one `ChapterData` file plus content**. If any of them needs a new script, the M7
implementation got the data model wrong.
