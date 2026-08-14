# 06_NARRATIVE_AND_WORLD.md

> Version: 1.0
> Status: Living Document — narrative bible
> Owner: Project Lead
>
> Companion documents: `docs/11_WORLD_MAP.md` (geography), `docs/12_CHARACTER_BIBLE.md`
> (people), `docs/13_CAMPAIGN_LEVELS_1-5.md` (the playable chapters),
> `docs/14_SYSTEM_INVENTORY.md` (what must be built), `docs/15_MASTER_PLAN.md` (sequencing).

---

# 0. Scope note — this is a *spine*, not a campaign

`AGENTS.md` lists "Large Story Campaign" as out of scope for Version 1, and that stays true.
What this document defines is deliberately smaller:

- **A spine, not a script.** Five chapters, each with an opening beat, a closing beat, and
  3–5 objectives. No branching, no dialogue trees, no cutscenes, no voice acting.
- **Objectives that are already gameplay.** Every objective in this plan resolves against a
  signal that already exists or is already planned (`island_captured`, `structure_changed`,
  `notoriety_changed`, `enemy_destroyed`, `boarding_resolved`). The campaign layer *reads*
  the simulation; it never becomes a second, parallel game.
- **Content, not code, per chapter.** Chapters 6…N must be authorable as `.tres` files by a
  designer with zero script changes. If adding Chapter 6 requires touching GDScript, the
  system was built wrong.

Everything below is written so that it can be deleted or ignored and the game still works.
The story is a **frame around the loop**, giving the player a reason for the next upgrade.
It is never a gate that blocks the loop.

`AGENTS.md` has been amended to reflect this distinction (lightweight chapter spine = in
scope; large branching narrative campaign = still out).

---

# 1. Premise

**1692. Port Royal has drowned.**

The richest, wickedest port in the New World slid into the harbour in a single afternoon when
the earth shook. Two thousand dead. The Royal Navy declared the site cursed and sailed away.
The Merchant Guild wrote the loss off its ledgers. The pirate clans moved on to Tortuga and
Skull Cove and forgot the place existed.

The player did not forget.

The player arrives at the drowned port with one leaking sloop, one loyal quartermaster, and
the only thing worth salvaging from the wreck of the old world: **the harbour is empty, and
nobody is watching it.**

The fantasy is not "I survived." The fantasy is: *this ruin is going to be the capital of
something, and everyone who sailed away is going to have to come back and deal with it.*

## Why this premise

It earns every system the game already has:

| System that exists | What the premise makes it mean |
|---|---|
| Empty home island with build slots | Ruins to clear and rebuild — the Clash of Clans base, motivated |
| Notoriety rising with player action | The world *noticing* that the drowned port isn't dead |
| Regions activating at notoriety thresholds | The powers that wrote you off, coming back to look |
| Raids on the home island | They want the harbour back |
| Faction reputation | Who you rob decides who hunts you |
| Offline production | The port grows while you sleep — a town, not a barracks |

---

# 2. Tone

**Adventure, not grimdark. Consequence, not cruelty.**

Reference stack, in priority order (matches `.kiro/specs/milestone-m6-.../requirements.md`):

1. **AC IV: Black Flag** — the *feel*. Wind, weather, a hull that shows what it has survived,
   a shanty on the way home. Piracy as a working trade with a ledger.
2. **Pirates of the Caribbean** — the *voice*. Named characters with one loud trait, legendary
   ships, a world where a rumour might be literally true.
3. **Clash of Clans** — the *shape*. Your port is a place you are proud of. Coming back to it
   is the reward.

Rules of tone:

- Nobody is purely evil. The Navy admiral genuinely believes he is preventing another Port
  Royal. The Spanish admiral is protecting a treasure fleet that feeds a nation.
- Violence has weight but no gore. Crew are lost, not butchered.
- The supernatural is **rumoured, never confirmed** in Chapters 1–5. The Ghost Fleet is a
  thread, not a reveal. That keeps it available for post-launch content.
- Text is short. Every beat is ≤ 3 sentences per speaker. This is a mobile game read with one
  thumb on a bus.

---

# 3. The world in one page

The sea is **the Shattered Main** — the Caribbean of this world, a bowl of warm water fenced
by three powers who all pretend the others do not exist.

- **The Pirate Clans** hold the shallow inner waters by force of habit. They are not an
  organisation; they are a truce that has never been written down. Skull Cove is where the
  truce goes to be argued about.
- **The Royal Navy** holds the trade lanes and calls them law. They are competent, funded,
  and slow. They do not lose battles; they lose *time*, and they know it.
- **The Spanish Empire** does not patrol the Main. It *crosses* it, twice a year, with a
  treasure fleet so valuable that the crossing is the only thing that matters. Everything
  else — Cartagena, Mount Brimstone, the garrisons — exists to protect that crossing.
- **The Merchant Guild** sells to all three and belongs to none. It is the only faction that
  will trade with the player from day one, and the only one that can be *lost* by being
  robbed.
- **The Ghost Fleet** is a story sailors tell. Charts that are wrong in the same way twice.
  Ships with no wake. Not a faction yet — a rumour with a hostility flag.

The player is the fifth power, and starts at zero.

---

# 4. The narrative spine — Chapters 1–5

Full playable detail is in `docs/13_CAMPAIGN_LEVELS_1-5.md`. This is the story shape.

| # | Title | Region | Antagonist | The question it asks |
|---|---|---|---|---|
| 1 | **The Drowned Port** | Beginner Waters | The ruin itself | Can you make this place stand up? |
| 2 | **Blood in the Shallows** | Beginner Waters | "Blackjaw" Morrow (Pirate Clans) | Can you hold it against your own kind? |
| 3 | **The King's Answer** | Contested Waters | Cdr. Hollis / the blockade (Royal Navy) | Can you survive being *noticed*? |
| 4 | **The Admiral's Gambit** | Contested Waters | Adm. Sir Edmund Vance, HMS *Intransigent* | Can you beat a professional? |
| 5 | **The Silver Fleet** | Imperial Waters | Almirante Beatriz de Cárdenas | Can you rob an empire? |

## The through-line

Each chapter escalates *who is looking at you*, which is exactly what the notoriety system
already models. The story is the diegetic readout of `EmpireManager.notoriety`.

```
Ch1   nobody knows you exist                 notoriety ~0–20
Ch2   the pirates know                       notoriety ~20–60   → Contested Waters activates
Ch3   the Navy knows                         notoriety ~60–110
Ch4   the Navy sends its best                notoriety ~110–150 → Imperial Waters activates
Ch5   an empire knows                        notoriety ~150+
```

**Design rule:** the chapter gate is *the notoriety threshold that already exists in
`resources/world/regions/*.tres`*. The campaign does not invent a second progression currency.
Chapter 3 begins because Contested Waters activated, not because a script said so.

## Chapter one-liners

**Ch1 — The Drowned Port.** Higgins wants to leave. The player builds a Farm instead. By the
end there is a dock, a warehouse, smoke from a chimney, and a name on the harbour board.
*Closing beat:* a Guild factor rows in to ask who, exactly, he is supposed to invoice.

**Ch2 — Blood in the Shallows.** Word travels. "Blackjaw" Morrow out of Skull Cove sends
three sloops to collect a tithe from the "new lad in the dead harbour." The player refuses.
*Closing beat:* Morrow's flag burns; the smoke is visible from the trade lane, and the trade
lane is Navy.

**Ch3 — The King's Answer.** The Navy declares the drowned port an unlawful settlement and
blockades the approaches. This is the chapter where the player is first *raided at home* —
the moment the base stops being a menu and becomes something to defend.
*Closing beat:* Marguerite arrives, having lost her own port to the same admiral, and asks a
question the player has been avoiding: *what are you actually building here?*

**Ch4 — The Admiral's Gambit.** Vance stops sending ships and comes himself. A pursuit across
Contested Waters ending at Frostbite Reef, where HMS *Intransigent* is a boss fight, not a
patrol. *Closing beat:* Vance, defeated, tells the player the truth — he was never the real
threat. The Spanish treasure fleet crosses in six weeks and it does not care who owns the
Main.

**Ch5 — The Silver Fleet.** Cartagena, Mount Brimstone, and the crossing itself. The largest
prize in the game, defended by an admiral who has never lost one.
*Closing beat:* the player's flag flies over a capital. In the last frame, a chart in the
captured strongbox shows an island that is not on any map — and the handwriting matches a
ship that sank forty years ago. **Hook for post-launch content; no answer given.**

---

# 5. How story is delivered (and what we refuse to build)

## Delivery channels — all four already exist or are trivial

| Channel | Vehicle | Status |
|---|---|---|
| Chapter beats (open/close) | `TutorialDialogue.tscn` — speaker + portrait + text + Continue | **Exists** (used by TutorialManager) |
| Objective nudges | `WorldHUD.announce_event()` banner | **Exists** |
| World flavour | `EventManager` random ocean events, re-skinned with chapter-aware text | **Exists, needs text pass** |
| Ledger / recap | New "Captain's Log" panel: chapters completed, current objectives | **To build (small)** |

## Explicitly refused

- Cutscenes, camera-scripted sequences, voice acting.
- Dialogue trees or player dialogue choices.
- Branching outcomes. One spine, same for everyone.
- Any objective that cannot be satisfied by normal play. (No "sail to this exact spot and
  wait" fetch quests.)
- Story that blocks the economy loop. If the player ignores the campaign entirely, they can
  still build, fight, and expand — they just do it without the frame.

---

# 6. The narrative data model

Per `AGENTS.md` ("Hardcoded values are forbidden", "Game balance belongs inside Resources"),
chapters are **data**, not code.

**Note for implementers:** `scripts/managers/TutorialManager.gd` currently holds its 8 steps
as a hardcoded `Array[Dictionary]` with a `wait_for` condition string and a generic
`_check_condition()` dispatcher. That dispatcher pattern is *correct and should be reused* —
what is wrong is that the content is in the script. The campaign system **generalises
TutorialManager**; it does not sit beside it. The existing tutorial becomes Chapter 1's
opening objectives, authored as `.tres`.

```gdscript
# scripts/world/ChapterData.gd
class_name ChapterData extends Resource

@export var chapter_id: String                  # "ch2_blood_in_the_shallows"
@export var chapter_number: int                 # 2
@export var title: String
@export_multiline var log_summary: String       # Captain's Log one-paragraph recap

@export_group("Gating")
@export var required_region_id: String          # "" = no region gate
@export var required_notoriety: float = 0.0
@export var required_previous_chapter: String

@export_group("Content")
@export var opening_beats: Array[Resource]      # DialogueBeatData
@export var objectives: Array[Resource]         # ObjectiveData
@export var closing_beats: Array[Resource]

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""      # unlocks a captain for hire
@export var reward_ship_id: String = ""
@export var reward_tech_id: String = ""
```

```gdscript
# scripts/world/ObjectiveData.gd
class_name ObjectiveData extends Resource

enum Condition {
    BUILD_STRUCTURE, UPGRADE_STRUCTURE_TO_LEVEL, REACH_ISLAND_TIER,
    DESTROY_SHIPS, BOARD_SHIPS, DEFEAT_BOSS,
    CAPTURE_ISLAND, DISCOVER_ISLAND, DOCK_AT_ISLAND,
    RECRUIT_CAPTAIN, OWN_SHIP_CLASS, UNLOCK_TECH,
    ACCUMULATE_RESOURCE, REACH_NOTORIETY, SURVIVE_RAID,
}

@export var objective_id: String
@export var description: String                 # "Sink 3 Pirate Clan sloops"
@export var condition: Condition
@export var target_id: String = ""              # building_id / island_id / faction_id / ...
@export var target_count: int = 1
@export var target_value: float = 0.0           # for tier / notoriety / resource amounts
@export var is_optional: bool = false           # optional objectives grant bonus reward only
@export var hint_text: String = ""              # shown if the objective stalls (see §7)
```

```gdscript
# scripts/world/DialogueBeatData.gd
class_name DialogueBeatData extends Resource

@export var speaker_id: String                  # "higgins", "morrow", "vance"
@export var speaker_name: String
@export var portrait_path: String
@export_multiline var text: String
enum Mood { NEUTRAL, WARM, GRIM, ANGRY, AMUSED }
@export var mood: Mood = Mood.NEUTRAL
```

**Authoring warning, from `docs/05_CURRENT_SYSTEMS.md` D3/D14:** a `.tres` that sets a
property the script does not actually `@export` fails *silently*. Before authoring any
chapter file, confirm every property against the real script.

## `CampaignManager` (new autoload)

- Registered **after** `EmpireManager` in `project.godot` (it reads notoriety and region state
  on `_ready()`).
- Loads all `resources/campaign/chapters/*.tres`, ordered by `chapter_number`.
- Subscribes to existing signals only — the same set `TutorialManager` already connects to,
  plus `ShipDamage.destroyed`, `BoardingSystem.boarding_resolved`,
  `EmpireManager.notoriety_changed` / `region_activated` / `raid_resolved`,
  `Island.tier_changed`, `ResourceManager` tick.
- Signals out: `chapter_started(ChapterData)`, `objective_progressed(id, current, target)`,
  `objective_completed(id)`, `chapter_completed(ChapterData)`.
- `get_save_data()` / `load_save_data()` following the established convention:
  `{current_chapter_id, completed_chapter_ids, objective_progress: {id: count}}`.
- **Never** calls into gameplay to *make* something happen except through existing public
  APIs (e.g. `EnemySpawner.spawn_hunter()`, exactly as TutorialManager already does).

---

# 7. Anti-softlock rules (non-negotiable)

An empire game must never leave a player stuck. These are requirements, not suggestions.

1. **No objective may require a resource the player cannot still earn.** Every chapter's
   resource targets must be reachable from Beginner Waters production + Beginner Waters
   combat loot alone, even if the player has lost every ship.
2. **The player can never lose their last ship permanently.** A destroyed player ship
   respawns at the home island with a repair cost, never a game over. (`DeathScreen.tscn`
   already exists — confirm it routes here.)
3. **The home island can never be lost.** Raids steal resources; they do not take the port.
4. **Objectives stall out loud.** If an objective shows no progress for a configured time,
   `hint_text` is surfaced through `WorldHUD.announce_event()`.
5. **Chapters can be skipped by overshooting.** A player who ignores the story and blasts
   notoriety to 200 completes Chapters 1–4's gates retroactively on load; the campaign
   catches up rather than blocking.
6. **Every chapter is completable in ≤ 3 sessions** at the target session lengths in
   `docs/00_VISION.md` §16.

---

# 8. Expansion hooks (deliberately left open)

Written now so post-launch content does not require retconning:

| Hook | Planted in | Pays off in |
|---|---|---|
| The unmapped chart in Cárdenas' strongbox | Ch5 closing beat | Region 4 — the Ancient Ocean |
| The Ghost Fleet's identical wrong charts | Ch3/Ch4 world flavour | The Cartographer arc |
| Higgins knows more about the quake than he says | Ch1 & Ch5 asides | Chapter 6 |
| Marguerite's lost port has never been retaken | Ch3 arrival | A rescue/retake chapter |
| Vance survives Ch4 | Ch4 closing | A reluctant-alliance chapter vs. Spain |
| Morrow's clan seat at Skull Cove is never formally inherited | Ch2 | Pirate-Clan politics arc |
| The treasure fleet crosses *twice a year* | Ch4 dialogue | A repeatable seasonal event |

None of these require new systems — each is a new `ChapterData` file plus content.

---

# 9. Naming conventions for narrative content

- Chapter resources: `resources/campaign/chapters/Ch<N>_<PascalSlug>.tres`
- Objectives: `resources/campaign/objectives/<chapter_id>_<objective_slug>.tres`
- Dialogue beats: `resources/campaign/dialogue/<chapter_id>_<open|close>_<NN>.tres`
- Speaker ids are lowercase snake_case and must match a character in
  `docs/12_CHARACTER_BIBLE.md`.
- Island and faction ids referenced by objectives **must** match existing `.tres` ids exactly
  (`port_royal`, `tortuga`, `skull_cove`, `frozen_island`, `volcano_island`,
  `cartagena_outpost`; `pirate_clans`, `royal_navy`, `merchant_guild`, `spanish_empire`,
  `ghost_fleet`, `player`).
