# 12_CHARACTER_BIBLE.md

> Version: 1.0
> Status: Living Document — character bible
> Owner: Project Lead
>
> Story context: `docs/06_NARRATIVE_AND_WORLD.md`. Geography: `docs/11_WORLD_MAP.md`.
> Chapters: `docs/13_CAMPAIGN_LEVELS_1-5.md`.
>
> **Every captain in §4 already exists** as a `resources/captains/*.tres` file with authored
> stats. This document does not invent a roster — it gives the roster that exists a place in the
> world. Where a name, stat, or id appears below, it is copied from the real resource file.

---

# 1. Casting rules

1. **One loud trait each.** A player must be able to describe any character in six words. If a
   character needs a paragraph to be legible, the design is wrong.
2. **Flavour must match mechanics.** A captain described as fast must have a high
   `base_speed_modifier`. This is not decoration — it is how the player learns to read the
   roster without opening a stat sheet. (§4 audits every captain against this rule.)
3. **Antagonists believe they are right.** No cackling. The admiral hunting the player thinks he
   is preventing another drowned city, and he has a point.
4. **The player has no dialogue.** The empire is the player (`AGENTS.md`). Everyone speaks *to*
   the player; the player answers by doing things.
5. **No character is required.** Every named character is content. If a chapter's captain is
   never hired, nothing breaks.
6. **Names are pronounceable and distinct at a glance.** No two important characters share an
   initial letter or a silhouette.

---

# 2. The player

**Identity:** unnamed, unvoiced, never shown. The player is *the flag*.

The player names their **empire**, not a person. That name appears on the harbour board at Port
Royal, in raid reports, and in how factions refer to the player ("the outfit in the dead
harbour"). Everything the player is, is visible in the port they built — which is the entire
premise of `AGENTS.md`'s "the empire is the player".

**Design consequence:** no player portrait, no player barks, no customisation screen. One text
field at new-game, defaulted so it can be skipped.

---

# 3. Named cast

## Quartermaster Higgins — mentor
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

## Factor Cornelius Hale — Merchant Guild
- **Trait:** will invoice a hurricane.
- **Role:** the economy's human face. Appears at Tortuga. Explains trade, storage caps, and why
  robbing his convoys is a *choice with a price* — the diegetic tutorial for faction reputation.
- **Voice:** courteous, unbothered, faintly threatening in accounting terms.
- **Mechanics tie-in:** `merchant_guild` is the only faction with
  `is_hostile_to_player = false` at start. Hale is what the player loses by farming convoys.

## "Blackjaw" Morrow — Pirate Clans · Chapter 2 antagonist
- **Trait:** collects a tithe from every pirate in the shallows, on principle.
- **Home:** Skull Cove (`skull_cove`).
- **Role:** the first enemy who *wants something* rather than merely spawning. Sends three
  sloops to tax the player, then comes himself.
- **Voice:** genial menace. Talks to the player like a colleague right up to the broadside.
- **Why he is right:** the clans survived the Navy by never letting one pirate get big. The
  player is exactly what he has spent twenty years preventing.
- **Unresolved on purpose:** his clan seat is never formally inherited (Ch6+ hook).

## Commander Hollis — Royal Navy · Chapter 3 antagonist
- **Trait:** by the book, and the book is working.
- **Role:** the blockade. Not a boss — a *condition*. Hollis is the face on the first home raid.
- **Voice:** clipped, procedural, reads charges aloud before firing.
- **Function:** teaches the player that the world now pushes back, without a boss fight.

## Admiral Sir Edmund Vance — Royal Navy · Chapter 4 antagonist · **boss**
- **Trait:** has never lost, because he has never been in a hurry.
- **Ship:** HMS *Intransigent*, berthed at Frostbite Reef (`frozen_island`).
- **Role:** the first true boss with mechanics. The chapter is a pursuit; he chose the ground.
- **Voice:** courteous, immovable, addresses the player as an equal for the first time in the
  game — which lands harder than any threat.
- **Why he is right:** he watched Port Royal drown and believes lawless ports end one way. He
  is trying to prevent a repeat, and he is not wrong about what pirates do to a harbour.
- **Survives Ch4** (Ch6+ hook: reluctant alliance against Spain).

## Almirante Beatriz de Cárdenas — Spanish Empire · Chapter 5 antagonist · **boss**
- **Trait:** guards a crossing, not a country.
- **Home:** Cartagena Outpost (`cartagena_outpost`).
- **Role:** the v1 finale. Commands the escort of the treasure fleet.
- **Voice:** economical, unimpressed, speaks of the player as a weather event to be routed
  around. Only loses composure once, and not about the treasure.
- **Why she is right:** the crossing feeds a nation. She has calculated exactly what the player
  costs in ships and considers it acceptable — which is its own kind of insult.

## The Cartographer — Ghost Fleet · **rumour only in v1**
- **Trait:** his charts are wrong in the same way twice.
- **Role:** never appears in Chapters 1–5. Named in flavour text, wrecks, and one line of
  Vance's dialogue. The Ghost Fleet (`ghost_fleet`) already exists as a faction with a boss
  ship; this gives that boss a name for later.
- **Rule:** **never confirmed as supernatural in v1.** That option must stay open.

---

# 4. The captain roster (all 20, as authored)

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

## Distribution check

| Chapter | New hires | Archetypes introduced |
|---|---|---|
| 1 | 4 | balanced, scout |
| 2 | 5 | boarder, gunner, first tank |
| 3 | 5 | veteran, support-tank, tactician, story captain |
| 4 | 3 | heavy tanks, heaviest gunner |
| 5 | 3 | elite speed, elite mixed |

Every chapter delivers at least three hires, so the Tavern always has something new.

## Story captains (recruited by chapter, not bought)

- **Marguerite the Merciless** (Ch3) — arrives at the player's port, unhired, after Vance's
  blockade. Her own port was burned by the same admiral and has never been retaken (Ch6+ hook).
  She is the game's argument that the player is building something worth defending.
- **Isabela** (Ch3) — defects from the Navy after Frostbite Reef. Gives the player their first
  read on how the Navy actually thinks.
- **Ophelia** (Ch5) — recruited *inside* Cartagena. Her `base_damage_modifier` of 1.40 with
  `base_health_modifier` 1.15 makes her the best all-round captain in v1, which is the correct
  reward for the last chapter.

---

# 5. Two authoring defects found in the existing roster

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

---

# 6. `CaptainData` fields to add (M7)

The roster in §4 assigns each captain a home port, allegiance, and unlock chapter — none of
which the schema can currently store. Add to `scripts/world/CaptainData.gd`:

```gdscript
@export_group("Identity")
@export var home_island_id: String = ""          # must match an IslandData.island_id
@export var allegiance_faction_id: String = ""   # must match a FactionData.faction_id
@export var unlock_chapter_id: String = ""       # "" = available from the start
@export var portrait_path: String = ""
```

**Authoring warning (`docs/05_CURRENT_SYSTEMS.md` D3/D14):** a `.tres` that sets a property the
script does not `@export` fails *silently*. Add the fields to the script **first**, then author
the 20 files, then verify by loading each resource and printing the values back.

Gating rule: `IslandMenu`'s Tavern tab filters the hire list by
`CampaignManager.is_chapter_completed(unlock_chapter_id)`. A captain whose chapter is not
reached is not shown — not shown-but-disabled, since a locked list of 20 is noise on a phone.

---

# 7. Portraits

- 20 captains + 7 named cast = **27 portraits**, plus one generic fallback.
- Style per `docs/03_ART_DIRECTION.md`: stylised low-poly / flat, readable at 96×96 on a phone.
- Path convention: `assets/art/portraits/<id>.png`; fallback
  `assets/art/portraits/_unknown.png`.
- **Not a blocker.** `portrait_path` defaults to `""` and the dialogue panel must render
  name-only when empty. Ship the spine with no portraits, add art later.
- Add the request to `docs/10_ASSET_REQUESTS.md` rather than blocking M7.
