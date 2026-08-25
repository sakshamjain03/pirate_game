# 15_MASTER_PLAN.md

> Version: 1.0
> Status: Living Document — end-to-end plan from here to v1
> Owner: Project Lead
>
> Reads on top of: `AGENTS.md` (constitution) → `docs/05_CURRENT_SYSTEMS.md` (what runs) →
> `docs/14_SYSTEM_INVENTORY.md` (what's missing) → this document (the order to build it in).
>
> **Note on `Prd.md` §21.** The PRD's milestone roadmap (M1 Foundation … M10 Polish) has diverged
> from the milestones actually executed in `.kiro/specs/` (M1 app-shell, M2 playable-world,
> M3 stabilization, M4 empire-escalation, M5 launch-readiness, M6 black-flag-combat-economy).
> **`.kiro/specs/` is the real history; `Prd.md` §21 is stale.** This document continues from the
> real one.

---

# 1. Where the project actually is (updated 2026-08-25 — M7 campaign spine complete)

**Built and working:** ocean with GPU waves and CPU buoyancy · ship physics that no longer
capsizes · combat with three ammunition types, hull/sails/crew damage pools, stern crits, and
boarding · 10 building chains at 5 levels each · island tiers · 5 resources with storage caps ·
20 captains (now with home/allegiance/unlock-chapter identity) · 8 ships with an authored cost
ladder · 6 factions · 3 regions gated by notoriety · home-island raids · save/load with offline
catch-up · a real 5-chapter campaign (replacing the old hardcoded tutorial steps) · 13 UI screens.

**Test baseline (measured, not reported):** 320 tests, 319 passing, 1 known LOD failure.

**Execution note:** M8 (Combat Identity Rework) was actually completed *before* M7 in this
project's real history, reversing the sequencing this document originally proposed below. Combat
identity landed first because it was the immediately-requested work at the time; the campaign
spine's chapter objectives were then written and tested against the post-M8 combat model rather
than the pre-M8 manual-fire model this section originally assumed. Both are complete as of
2026-08-25 — see `docs/05_CURRENT_SYSTEMS.md`'s "M8 Combat Identity Rework — Phase 2" and
"M7 — Campaign Spine" sections for the real implementation record.

**What it is missing is not features. It is *reasons*.** Six islands sit on an ocean with no
geography logic; 20 captains are stat blocks with no home; the economy's ship ladder is
mispriced by roughly 100× (D53); and nothing in the game tells the player why any of it matters.

**The plan below spends M7 on meaning and correctness, M8 on the identity of a single fight, M9 on
the world's size and legibility, and M10–M13 on volume, polish, and shipping.**

---

# 2. Thesis

> A player should be able to open this game, understand within 60 seconds what they are building
> and who objects, and still be finding out what is past the fog eight hours later.

Everything sequenced below serves that sentence. Anything that does not is deferred.

---

# 3. Roadmap

## M7 — Campaign Spine & Economy Correction

**Status: COMPLETE (2026-08-25).** See `docs/05_CURRENT_SYSTEMS.md`'s "M7 — Campaign Spine"
section for the full implementation record and the exit-criteria results below.

**Goal:** the game acquires a reason and a working economy.
**Why first:** D53 makes every economy number downstream of it meaningless, and the campaign is
the cheapest possible retention intervention — it is content on top of systems that already work.

**Scope**

1. **Economy correction (do before anything else):**
   - D53 — `cost_gold`/`cost_wood`/`cost_iron`/`cost_rum` + `ship_class` on `ShipStats`, authored
     per hull to the ladder in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2; delete the `mass / 100`
     formula from `IslandMenu.gd`.
   - D54 — `ship_id` + `display_name` on `ShipStats`; stop deriving names from filenames.
   - D55/D56 — author `base_boarding_modifier` and `hire_cost_gold` on all 20 captains.
   - D57 — fix `SettingsMenu`'s `InputManager` lookup (group lookup, or promote to autoload).
   - D58 — seed Port Royal as owned home on new game.
2. **Campaign spine:** `ChapterData` / `ObjectiveData` / `DialogueBeatData` + `CampaignManager`
   autoload; generalise `TutorialManager`'s content out of GDScript into `.tres`; author
   Chapters 1–5; Captain's Log panel; objective progress in `WorldHUD`.
3. **Map correction (D59):** reposition all six islands to the Compact layout in
   `docs/11_WORLD_MAP.md` §4a, move the player spawn and the three authored enemies with them,
   add `world_position` + `region_id` to `IslandData`, and promote `EnemySpawner`'s hardcoded
   ±100 fallback box to an export.
4. **Captain identity fields:** `home_island_id`, `allegiance_faction_id`, `unlock_chapter_id`,
   `portrait_path`, authored per `docs/12_CHARACTER_BIBLE.md` §4.
5. **Small enablers the chapters need:** a boss id on the boss-death signal; a write path for
   `IslandData.discovered`; verify Cartagena works as a second buildable island.

**Exit criteria — results (2026-08-25)**
- A new player can complete Chapter 1 in one session without touching a wiki. — **Not verified.**
  Mechanically wired and testable (`tests/test_chapter1_playthrough.gd`), but "without touching a
  wiki" is a human-legibility judgment this pass cannot make headlessly.
- Chapters 2–5 are completable, with every objective resolved by an existing signal. — **Met**,
  with two disclosed simplifications: Ch3 objective 3.5 checks `OWN_SHIP_CLASS` only (not also a
  "Defend Home" flag), and the two boss encounters (Ch4/Ch5) have no in-world trigger yet — reachable
  only via a manual `EncounterManager.start_encounter()` call, not through normal play.
- A Man O'War costs more than a level-5 Farm, and reaching island tier 5 provably requires
  combat loot (M6 Req 7.4, finally testable). — **Met**, closed in M8 Phase 2 (D53/D54), ahead of
  M7 due to the M8-before-M7 execution-order swap noted above.
- Adding a hypothetical Chapter 6 requires **zero** script changes — proven by writing one
  throwaway `.tres` and loading it. — **Met and verified**: `Ch6_Throwaway.tres` loaded and was
  picked up by `CampaignManager._load_chapters()` with no script edits, then deleted.
- 118 → ~140 tests, all passing except the known LOD failure. — **Exceeded**: 320 tests / 319
  passing (the jump past ~140 reflects M8's own test growth plus M1/M2 tail work done in the same
  pass, not scope creep within M7 itself).

**Deliberately not in M7:** ocean LOD, fog/discovery UI, the world map, weather, new islands, and
the combat-identity rework below — M7's chapter objectives are written against today's
manual-fire model and do not depend on it changing.

---

## M8 — Combat Identity Rework

**Goal:** combat becomes what `docs/navalCombat.md` locks in — auto-fire on arc alignment, a
positioning-first skill model, captain active abilities, and a roguelite in-battle upgrade layer.
**Why here:** this touches the core input loop (`ShipController`/`ShipCombat`), so it needs its
own spec rather than riding inside another milestone; M7's chapter objectives resolve from
signals (`DESTROY_SHIPS`, `BOARD_SHIPS`, `DEFEAT_BOSS`) that don't care how firing is triggered,
so this can follow M7 without reworking it.

**Scope:** full detail in `docs/navalCombat.md` §15 — arc-alignment auto-fire replacing the manual
`fire_port`/`fire_starboard` trigger (plus an optional player-timed full-broadside special) · bow/
stern/special weapon slots · captain active abilities, one per captain · temporary in-battle
upgrade offers · ship modules (Hull/Cannon/Sail/Utility/Special) + a ship Level distinct from
captain Level · AI-controlled support ships fighting alongside the player · enemy role
differentiation (Raider/Artillery/Tank/Support/Boss) extending `AIProfileData` · an `EventData`-
backed encounter-type framework (Encounter/Convoy/Ambush/Elite/Boss/Defense).

**Exit criteria:** a player wins a fight primarily by positioning, not by tap speed; every
captain has a distinct in-battle verb, not just a passive number; a normal encounter offers at
least one in-battle build choice.

---

## M9 — The Legible World

**Goal:** the player can see the world, and the world is big enough to be worth seeing.

**Scope**
- **Ocean LOD** — closes the project's one standing test failure and unblocks the Expanded map
  (all Compact coordinates × 2.5, per `docs/11_WORLD_MAP.md` §4b). This is the gate on the whole
  milestone; do it first.
- Discovery / fog: `IslandData.discovered` becomes real, with a reveal on approach.
- **World map UI** — the single largest missing player-facing feature. Region rings, known
  islands, current heading, active objectives.
- Per-region weather and per-region enemy *types* (not just stat multipliers) — closes the
  documented `EnemySpawner` gap.
- `EventData` as a resource so world events stop being hardcoded in `EventManager`.
- Ship damage *visuals* — the Black Flag "hull shows what it survived" beat. Pools already exist.
- 2–4 new islands in the existing three regions.

**Exit criteria:** the Expanded map holds 60 fps on a mid-range Android device; a player can
open a map and know where they are and where they have not been.

---

## M10 — Depth

**Goal:** the systems that are one-note become choices.

**Scope:** tech tree 2 → 12–15 techs · wind and sail trim · cannonball arcing · hull-facing armour
variance · 2 more bosses · diplomacy (treaties/tribute, PRD §16) · trade routes as objects rather
than abstract missions · world events 3 → 8–10 · full SFX pass (`AGENTS.md`: "no silent
interactions" is currently unmet) and music.

**Exit criteria:** every faction can be engaged in more than one way; combat has a skill ceiling
a returning player can still be climbing.

---

## M11 — Playtest & Instrumentation

**Goal:** find out what is actually wrong from someone who is not us.

**Scope:** analytics/funnel telemetry · crash reporting · save schema versioning + backup +
migration path · localisation-ready strings · a playtest protocol · a balance spreadsheet that
*owns* every economy number (the missing artefact behind D53) · codex/lore browser.

**Exit criteria:** ≥ 10 external players have reached Chapter 3; drop-off is measured, not
guessed; every economy constant traces to a model.

---

## M12 — Ship It

**Goal:** an Android build on a store.

**Scope:** install export templates (not present on the dev machine today) · Android export +
signing · device performance profiling · touch-control verification on real hardware · store
listing, icon, screenshots, description · release checklist · resolve the engine version question
(`project.godot` declares 4.3; the dev machine runs 4.7.1; nothing has audited the gap).

**Exit criteria:** a signed build a stranger can install and play to Chapter 3.

---

## M13 — Live Operations

**Goal:** the world keeps growing without rewrites.

**Scope:** Chapters 6–10 per `docs/13_CAMPAIGN_LEVELS_1-5.md` §9 · region 4 (Ancient Ocean) and
region 5 (Ghost Reaches), both id-reserved already · seasonal repeatable events (the spring
crossing) · the Ghost Fleet / Cartographer arc · content-authoring guide so a non-coder can add a
chapter.

**Exit criteria:** a content update ships without a code change.

---

# 4. Critical path

```
D53 economy correction ─┬─► M7 campaign spine ──► M8 combat rework ──► M10 depth ──┐
                        └─► M7 map correction                                     ├─► M11 playtest ──► M12 ship ──► M13 live ops
                                    │                                             │
              Ocean LOD ──────────────► M9 Expanded map + world map UI ──────────┘
```

Three hard dependencies, and they are the only ones that can silently waste a milestone:

1. **D53 before any chapter tuning.** Every economy target in
   `docs/13_CAMPAIGN_LEVELS_1-5.md` is written against the corrected ladder. Authoring chapters
   against today's prices would need redoing.
2. **Ocean LOD before the Expanded map.** A 1350-unit ocean span on a uniform wave mesh is a
   mobile framerate problem. The "accepted" failing test is the gate.
3. **Analytics before balance tuning.** Tuning retention without funnel data is guessing.

M8 (combat rework) and M9 (the legible world) touch disjoint systems — input/combat vs. ocean/map
— and could run in either order or overlap if two implementation tracks are available. The order
above is a default, not a hard dependency.

---

# 5. Risk register

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| **Checkpoints keep being accepted on self-reports** | Compounding invisible breakage — already produced D15, D42, D57, and two tasks ticked with zero file changes | **High** — it happened again at M6 Task 29 | Every checkpoint runs the GUT suite and pastes real totals; the binary path is now recorded in `docs/14_SYSTEM_INVENTORY.md` §6 |
| Ocean LOD proves hard, blocking the world's size | The AC-IV "long voyage" feel never lands | Medium | Compact map is playable and shipped in M7; Expanded is upside, not a dependency of the campaign |
| Engine version drift (declared 4.3, running 4.7.1) | Rendering/behaviour differences discovered late | Medium | Audit in M12 at the latest; note it in every visual finding until then |
| No balance model | More D53s | **High** | The spreadsheet is an M11 deliverable, but D53's fix should start it now |
| Content bottleneck — one writer for chapters, techs, events, SFX | M10/M13 stall | Medium | Data-driven schemas are the mitigation; `.tres` authoring must never require a programmer |
| Never run on a real device | Mobile-first game that has never been mobile | **High** | Pull device profiling forward into M9 if any hardware is available |
| Combat rework (M8) touches the core input loop and regresses feel | A player-facing regression in the game's most-played moment | Medium | `docs/navalCombat.md` keeps the manual-fire path working until auto-fire is verified; ship behind a flag if needed |
| Scope creep back toward multiplayer/monetisation | Architectural churn | Low | `AGENTS.md` forbids it; keep it forbidden |
| Story becomes a blocker rather than a frame | Players stuck behind objectives | Medium | The 7 anti-softlock rules in `docs/06_NARRATIVE_AND_WORLD.md` §7, each with a test |

---

# 6. Definition of done for v1

Extends `Prd.md` §22 with what that list omits. A player must be able to:

1. Start a new game and, within 60 seconds, know what they are building and who objects.
2. Complete Chapters 1–5 (≈ 5–8 hours) without a wiki and without softlocking.
3. Reach island tier 5 on Port Royal, and be unable to do it without fighting.
4. See a map of the world and tell where they have not been.
5. Lose a fight, and want another go.
6. Close the game, return the next day, and find something meaningful happened.
7. Own a second developable island (Cartagena).
8. Rebind their controls and have it actually work *(currently D57 — dead)*.
9. Play it on an Android phone at a stable frame rate.
10. Explain their empire to a friend in one sentence.

---

# 7. Immediate next actions

1. ✅ **Baseline verified** — 118/117, binary located. Correct the `103` figure everywhere it
   appears (M6 spec header, `docs/05_CURRENT_SYSTEMS.md`).
2. ✅ Docs 06, 11–15 written; `AGENTS.md` carve-out applied; D53–D59 logged.
3. **Reposition the map** in `scenes/world/World.tscn` and re-run the suite.
4. **Scaffold `.kiro/specs/milestone-m7-campaign-spine/`** with the M7 scope above, task waves
   separated by blocking checkpoints, and the economy correction as Wave 1 — because everything
   else is tuned against it.
5. **Hand Wave 1 to Gemini** via `docs/08_PROMPT_LIBRARY.md` prompts.

---

# 8. Document map

| Doc | Answers |
|---|---|
| `AGENTS.md` | What are the rules? (constitution — wins every conflict) |
| `docs/00_VISION.md` | What are we making and why? |
| `docs/01_ARCHITECTURE.md` | How is it structured? |
| `docs/02_TECH_STACK.md` | What are we building it with? |
| `docs/03_ART_DIRECTION.md` | What does it look like? |
| `docs/04_GAME_LOOP.md` | What does the player do, minute to minute? |
| `docs/05_CURRENT_SYSTEMS.md` | **What actually runs today, and what's broken?** |
| `docs/06_NARRATIVE_AND_WORLD.md` | What is the story, and how is it data? |
| `docs/navalCombat.md` | What does a single fight feel like, and how does it change (M8)? |
| `docs/07_AI_AGENT_WORKFLOW.md` | Who does which work? |
| `docs/08_PROMPT_LIBRARY.md` | How do we brief Gemini? |
| `docs/09_VISUAL_BUG_TRACKER.md` | What did the screenshots reveal? |
| `docs/10_ASSET_REQUESTS.md` | What art do we need? |
| `docs/11_WORLD_MAP.md` | Where is everything, and why there? |
| `docs/12_CHARACTER_BIBLE.md` | Who is in it? |
| `docs/13_CAMPAIGN_LEVELS_1-5.md` | What happens in the first five chapters? |
| `docs/14_SYSTEM_INVENTORY.md` | **Everything that must exist, and its status.** |
| `docs/15_MASTER_PLAN.md` | In what order do we build the rest? |
