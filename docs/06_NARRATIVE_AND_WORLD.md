# 06_NARRATIVE_AND_WORLD.md

> Version: 1.1 — merged with the former `docs/12_CHARACTER_BIBLE.md` during the 2026-09-20 docs
> consolidation pass (world/story and its cast are one narrative bible, not two documents).
> Status: Living Document — narrative bible
> Owner: Project Lead
>
> Companion documents: `docs/11_WORLD_MAP.md` (geography), `docs/13_CAMPAIGN_LEVELS_1-5.md` (the
> playable chapters), `docs/05_CURRENT_SYSTEMS.md` (ground truth: what's built and its status),
> `docs/15_MASTER_PLAN.md` (sequencing). Characters now live in this document, §10 below.

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

Reference stack, in priority order (matches M6's own requirements, per
`docs/16_MILESTONE_HISTORY.md`):

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
- Speaker ids are lowercase snake_case and must match a character in §10 above.
- Island and faction ids referenced by objectives **must** match existing `.tres` ids exactly
  (`port_royal`, `tortuga`, `skull_cove`, `frozen_island`, `volcano_island`,
  `cartagena_outpost`; `pirate_clans`, `royal_navy`, `merchant_guild`, `spanish_empire`,
  `ghost_fleet`, `player`).

---

# 10. Character bible

> Folded in from `docs/12_CHARACTER_BIBLE.md` during the 2026-09-20 docs consolidation pass.
>
> **Every captain in §10.4 already exists** as a `resources/captains/*.tres` file with authored
> stats. This section does not invent a roster — it gives the roster that exists a place in the
> world. Where a name, stat, or id appears below, it is copied from the real resource file.

## 10.1 Casting rules

1. **One loud trait each.** A player must be able to describe any character in six words. If a
   character needs a paragraph to be legible, the design is wrong.
2. **Flavour must match mechanics.** A captain described as fast must have a high
   `base_speed_modifier`. This is not decoration — it is how the player learns to read the
   roster without opening a stat sheet. (§10.4 audits every captain against this rule.)
3. **Antagonists believe they are right.** No cackling. The admiral hunting the player thinks he
   is preventing another drowned city, and he has a point.
4. **The player has no dialogue.** The empire is the player (`AGENTS.md`). Everyone speaks *to*
   the player; the player answers by doing things.
5. **No character is required.** Every named character is content. If a chapter's captain is
   never hired, nothing breaks.
6. **Names are pronounceable and distinct at a glance.** No two important characters share an
   initial letter or a silhouette.

## 10.2 The player

**Identity:** unnamed, unvoiced, never shown. The player is *the flag*.

The player names their **empire**, not a person. That name appears on the harbour board at Port
Royal, in raid reports, and in how factions refer to the player ("the outfit in the dead
harbour"). Everything the player is, is visible in the port they built — which is the entire
premise of `AGENTS.md`'s "the empire is the player".

**Design consequence:** no player portrait, no player barks, no customisation screen. One text
field at new-game, defaulted so it can be skipped.

## 10.3 Named cast

### Quartermaster Higgins — mentor
> **Exists already** as the tutorial mentor in `scripts/managers/TutorialManager.gd`
> (`"mentor": "Quartermaster Higgins"`). Reuse this name. Do not invent a second mentor.

- **Trait:** wants to leave, never does.
- **Role:** the voice of the campaign. Delivers the opening and closing beat of every chapter.
  He is the player's ledger, conscience, and weather report.
- **Voice:** dry, practical, undercuts every triumph with a cost. *"Grand. Now who's paying the
  masons?"* Never sarcastic about the player personally.
- **Arc across Ch1–5:** starts trying to talk the player out of it → starts giving advice
  unprompted → starts making plans of his own. By Ch5 he is the one who wants Cartagena.
- **Secret (unpaid, Ch6+ hook):** he was in Port Royal the day it sank and has never said what
  he was doing there.
- **Screen presence:** `TutorialDialogue.tscn`, portrait + name + ≤ 3 sentences.

### Factor Cornelius Hale — Merchant Guild
- **Trait:** will invoice a hurricane.
- **Role:** the economy's human face. Appears at Tortuga. Explains trade, storage caps, and why
  robbing his convoys is a *choice with a price* — the diegetic tutorial for faction reputation.
- **Voice:** courteous, unbothered, faintly threatening in accounting terms.
- **Mechanics tie-in:** `merchant_guild` is the only faction with
  `is_hostile_to_player = false` at start. Hale is what the player loses by farming convoys.

### "Blackjaw" Morrow — Pirate Clans · Chapter 2 antagonist
- **Trait:** collects a tithe from every pirate in the shallows, on principle.
- **Home:** Skull Cove (`skull_cove`).
- **Role:** the first enemy who *wants something* rather than merely spawning. Sends three
  sloops to tax the player, then comes himself.
- **Voice:** genial menace. Talks to the player like a colleague right up to the broadside.
- **Why he is right:** the clans survived the Navy by never letting one pirate get big. The
  player is exactly what he has spent twenty years preventing.
- **Unresolved on purpose:** his clan seat is never formally inherited (Ch6+ hook).

### Commander Hollis — Royal Navy · Chapter 3 antagonist
- **Trait:** by the book, and the book is working.
- **Role:** the blockade. Not a boss — a *condition*. Hollis is the face on the first home raid.
- **Voice:** clipped, procedural, reads charges aloud before firing.
- **Function:** teaches the player that the world now pushes back, without a boss fight.

### Admiral Sir Edmund Vance — Royal Navy · Chapter 4 antagonist · **boss**
- **Trait:** has never lost, because he has never been in a hurry.
- **Ship:** HMS *Intransigent*, berthed at Frostbite Reef (`frozen_island`).
- **Role:** the first true boss with mechanics. The chapter is a pursuit; he chose the ground.
- **Voice:** courteous, immovable, addresses the player as an equal for the first time in the
  game — which lands harder than any threat.
- **Why he is right:** he watched Port Royal drown and believes lawless ports end one way. He
  is trying to prevent a repeat, and he is not wrong about what pirates do to a harbour.
- **Survives Ch4** (Ch6+ hook: reluctant alliance against Spain).

### Almirante Beatriz de Cárdenas — Spanish Empire · Chapter 5 antagonist · **boss**
- **Trait:** guards a crossing, not a country.
- **Home:** Cartagena Outpost (`cartagena_outpost`).
- **Role:** the v1 finale. Commands the escort of the treasure fleet.
- **Voice:** economical, unimpressed, speaks of the player as a weather event to be routed
  around. Only loses composure once, and not about the treasure.
- **Why she is right:** the crossing feeds a nation. She has calculated exactly what the player
  costs in ships and considers it acceptable — which is its own kind of insult.

### The Cartographer — Ghost Fleet · **rumour only in v1**
- **Trait:** his charts are wrong in the same way twice.
- **Role:** never appears in Chapters 1–5. Named in flavour text, wrecks, and one line of
  Vance's dialogue. The Ghost Fleet (`ghost_fleet`) already exists as a faction with a boss
  ship; this gives that boss a name for later.
- **Rule:** **never confirmed as supernatural in v1.** That option must stay open.

## 10.4 The captain roster (all 20, as authored)

Stat columns are the **real `base_*_modifier` values** from `resources/captains/*.tres`.
`Ch` is the chapter at which the captain becomes available to hire.

| Captain | id | Spd | Turn | Dmg | HP | Home port | Allegiance | Ch | Six-word read |
|---|---|---|---|---|---|---|---|---|---|
| "Steady" Jack | `jack` | 1.05 | 1.05 | 1.05 | 1.05 | Port Royal | player | **1** | Good at everything, best at nothing |
| "Swift" Anne | `anne` | 1.15 | 1.20 | 1.0 | 1.0 | Port Royal | player | **1** | Nobody has ever caught her |
| "Reckless" Redbeard | `redbeard` | 1.0 | 1.0 | 1.20 | 0.80 | Tortuga | pirate_clans | **1** | Fights hard, dies fast, returns anyway |
| "Lucky" Mary | `mary` | 1.10 | 1.10 | 1.10 | 0.90 | Tortuga | pirate_clans | **1** | Fast, sharp, ruined if cornered |
| "Lucky" Diego | `diego` | 1.20 | 1.10 | 0.85 | 0.90 | Tortuga | pirate_clans | **2** | Three wrecks survived, expects a fourth |
| "Cutlass" Kane | `cutlass` | 1.30 | 1.25 | 1.10 | 0.75 | Skull Cove | pirate_clans | **2** | Boards first, asks questions never |
| "Flint" Fiona | `fiona` | 1.0 | 0.90 | 1.40 | 0.85 | Skull Cove | pirate_clans | **2** | Reloads blind, in the dark |
| "Iron" Bartholomew | `bartholomew` | 0.85 | 0.90 | 1.0 | 1.30 | Port Royal | player | **2** | Ships like fortresses, moves like them |
| "Whistler" Wade | `whistler` | 1.40 | 1.15 | 0.80 | 0.90 | Tortuga | player | **2** | Reads wind better than charts |
| "Old" Tom | `oldtom` | 0.75 | 0.80 | 1.35 | 1.40 | Port Royal | player | **3** | Decades taught him never to rush |
| "Gentle" Grace | `grace` | 0.80 | 1.30 | 0.90 | 1.30 | Port Royal | player | **3** | Calm crew, even taking water |
| "Iron" Isabela | `isabela` | 0.90 | 0.85 | 1.30 | 1.10 | Frostbite Reef | ex-royal_navy | **3** | Former privateer, never loses nerve |
| "Rook" Ramirez | `rook` | 1.10 | 1.40 | 1.0 | 0.95 | Skull Cove | pirate_clans | **3** | Plots every raid three moves ahead |
| "Marguerite" the Merciless | `marguerite` | 0.95 | 0.95 | 1.45 | 1.0 | *(port destroyed)* | player | **3** | No quarter to the Royal Navy |
| "Bruiser" Barnaby | `barnaby` | 0.85 | 0.90 | 1.50 | 1.20 | Skull Cove | pirate_clans | **4** | Won his ship in a bet |
| "Constance" the Unyielding | `constance` | 0.80 | 0.85 | 1.25 | 1.45 | Frostbite Reef | player | **4** | Has never ordered a retreat |
| "Anchor" Ezra | `ezra` | 0.70 | 0.75 | 1.15 | 1.50 | Frostbite Reef | player | **4** | Slow, unshakeable, never abandons a fight |
| "Moonlit" Selene | `selene` | 1.35 | 1.30 | 0.90 | 0.80 | Mount Brimstone | ghost_fleet? | **5** | Raids only under a new moon |
| "Windrunner" Yusuf | `yusuf` | 1.45 | 1.35 | 0.85 | 0.75 | Cartagena | merchant_guild | **5** | Trained on the fastest southern dhows |
| "Siren" Ophelia | `ophelia` | 1.05 | 1.05 | 1.40 | 1.15 | Cartagena | player | **5** | Talks crews into fortunes or cliffs |

### Distribution check

| Chapter | New hires | Archetypes introduced |
|---|---|---|
| 1 | 4 | balanced, scout |
| 2 | 5 | boarder, gunner, first tank |
| 3 | 5 | veteran, support-tank, tactician, story captain |
| 4 | 3 | heavy tanks, heaviest gunner |
| 5 | 3 | elite speed, elite mixed |

Every chapter delivers at least three hires, so the Tavern always has something new.

### Story captains (recruited by chapter, not bought)

- **Marguerite the Merciless** (Ch3) — arrives at the player's port, unhired, after Vance's
  blockade. Her own port was burned by the same admiral and has never been retaken (Ch6+ hook).
  She is the game's argument that the player is building something worth defending.
- **Isabela** (Ch3) — defects from the Navy after Frostbite Reef. Gives the player their first
  read on how the Navy actually thinks.
- **Ophelia** (Ch5) — recruited *inside* Cartagena. Her `base_damage_modifier` of 1.40 with
  `base_health_modifier` 1.15 makes her the best all-round captain in v1, which is the correct
  reward for the last chapter.

## 10.5 Two authoring defects found in the existing roster

Both are the **D3/D14 class**: schema exists, data was never authored, so the feature is
silently inert. Verified 2026-08-14 by direct inspection of all 20 `.tres` files.

### C1 — `base_boarding_modifier` is set on **zero** of the 20 captains

`CaptainData.gd:21` exports `base_boarding_modifier`, and
`scripts/combat/BoardingSystem.gd:80` reads `boarding_modifier` from the active captain. But no
captain file sets it, so every captain returns the `1.0` default and **captain choice has no
effect on boarding whatsoever**.

This makes M6 Requirement 3.2 ("boarding resolves as a comparison of crew counts *modified by
captain traits*") only half-implemented — the code path is there, the data is not. It is also a
direct flavour/mechanics mismatch under rule 2: `"Cutlass" Kane`'s entire authored personality
is *"Prefers boarding actions to broadsides"* and he is mechanically no better at boarding than
"Gentle" Grace.

**Fix (M7):** author `base_boarding_modifier` on all 20, keyed to the six-word read. Suggested:
Cutlass 1.50, Barnaby 1.35, Ophelia 1.30, Constance 1.25, Marguerite 1.20, Redbeard 1.15,
Bartholomew/Ezra/Isabela/OldTom 1.10, Jack 1.05, Fiona/Grace/Mary/Rook/Diego 1.0,
Anne/Whistler 0.90, Selene/Yusuf 0.85. Fast captains trade boarding for speed — that is the
tension that makes the roster a *choice*.

### C2 — 5 of 20 captains never set `hire_cost_gold`

15 files set it; 5 fall through to the `500` default. Since M5 added the field specifically so
recruitment cost scales with roster depth, those five are mispriced relative to their stats.

**Fix (M7):** author `hire_cost_gold` on all 20, scaled by chapter tier (Ch1 ≈ 400–600,
Ch5 ≈ 2500–4000) so the Tavern reads as a ladder.

## 10.6 `CaptainData` fields added (M7)

The roster in §10.4 assigns each captain a home port, allegiance, and unlock chapter — fields
added to `scripts/world/CaptainData.gd`:

```gdscript
@export_group("Identity")
@export var home_island_id: String = ""          # must match an IslandData.island_id
@export var allegiance_faction_id: String = ""   # must match a FactionData.faction_id
@export var unlock_chapter_id: String = ""       # "" = available from the start
@export var portrait_path: String = ""
```

**Authoring warning (`docs/05_CURRENT_SYSTEMS.md` D3/D14):** a `.tres` that sets a property the
script does not `@export` fails *silently*. Add fields to the script **first**, then author the
`.tres` files, then verify by loading each resource and printing the values back.

Gating rule: `IslandMenu`'s Tavern tab filters the hire list by
`CampaignManager.is_chapter_completed(unlock_chapter_id)`. A captain whose chapter is not
reached is not shown — not shown-but-disabled, since a locked list of 20 is noise on a phone.

## 10.7 Portraits

- 20 captains + 7 named cast = **27 portraits**, plus one generic fallback.
- Style per `docs/03_ART_DIRECTION.md`: stylised low-poly / flat, readable at 96×96 on a phone.
- Path convention: `assets/art/portraits/<id>.png`; fallback
  `assets/art/portraits/_unknown.png`.
- **Not a blocker.** `portrait_path` defaults to `""` and the dialogue panel must render
  name-only when empty. Ship the spine with no portraits, add art later.
- Requests tracked in `docs/10_ASSET_REQUESTS.md`, not a blocker for any chapter's completion.
