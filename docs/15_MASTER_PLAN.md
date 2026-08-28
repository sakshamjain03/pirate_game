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

**Test baseline (measured, not reported):** 323 tests, 322 passing, 1 known LOD failure — after
the M7.5 stabilization pass (D64/D65, `docs/05_CURRENT_SYSTEMS.md`), which found and fixed two
defects the GUT suite could not see: a save/load bug that could silently teleport the player ship
into Port Royal's own collision (found only by rendering the game and looking at the result), and
Chapters 4/5's bosses having no in-world trigger at all.

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
making every screen look finished, M10 on the world's size and legibility, and M11–M14 on volume,
polish, and shipping.** (Updated 2026-08-26 — see §8 for why M9 was inserted and everything after
it renumbered.)

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
- Chapters 2–5 are completable, with every objective resolved by an existing signal. — **Met**.
  One disclosed simplification remains: Ch3 objective 3.5 checks `OWN_SHIP_CLASS` only, not also
  a "Defend Home" flag. The Ch4/Ch5 boss encounters originally had no in-world trigger at all
  (D65) — fixed in the 2026-08-25 M7.5 stabilization pass via a chapter-gated ambient-pool entry,
  so both are now reachable through normal play, not just a manual `start_encounter()` call.
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

## M9 — Presentation Pass

**Goal:** every screen the player actually looks at reads as one finished game, not systems work
wearing a partial coat of theme.

**Why here, ahead of world size:** found by actually running the game
(`scenes/debug/CaptureHarness.tscn`) and looking at the rendered output on 2026-08-26 — not by
reading code, the same discipline M7.5 used. Two defects this document already records as
"Resolved" (D32, D36) reproduced on a fresh run today; see the audit in §9 for full evidence. A
bigger, better-populated world sitting behind a HUD that visibly overlaps its own text does not
read as "in progress" to a new player — it reads as broken, on the very first screen, every
session. That is a worse first impression than a small world, and it is less total engineering
effort to fix than M10's ocean LOD + world map UI. Same prioritization logic that inserted M7.5
ahead of its own plan.

**Scope**
- Fix the reproduced D36 regression for real — `WorldHUD._create_notoriety_label()`'s hardcoded
  `offset_top = 52.0` does not reliably clear the `ResourceBar` panel; needs a layout approach
  that can't silently drift out of alignment with a sibling panel again (e.g. anchor beneath the
  `ResourceBar` node directly rather than a magic-number offset).
- Re-verify the reproduced D32 regression (4× `Parameter "material" is null"` at startup) and
  close it for real, or document why it's expected and harmless.
- Theme `SettingsMenu.tscn` and `CreditsScreen.gd` — currently the only two screens in
  `scenes/ui/` that never call `PirateThemeBuilder.build()`, so they render as raw default-grey
  Godot UI against every other screen's gold/navy pirate theme.
- `MainMenu.tscn` typography pass: give `TitleLabel`/`SubtitleLabel` real font sizing (currently
  inherit the 15px body-text default — the game's own title is the same size as a tooltip);
  make `CreditsButton`/`QuitButton` consistent with the other three buttons in the same
  `VBoxContainer` (currently the only two without the `28px` override and the only two with an
  emoji prefix); remove or actually wire the dead `VignetteOverlay` (authored at alpha 0, never
  referenced by `MainMenu.gd`).
- HUD panel arbitration: tutorial dialogue, the combat cannon-cooldown panel, and event
  announcements currently draw simultaneously with no coordination — reproduced stacking the
  Higgins tutorial box directly over a live "STARBOARD CANNONS RELOADING" panel during an
  unacknowledged ambient encounter. Needs an explicit priority/exclusivity rule.
- Replace `announce_event()`'s bare, unframed `Label` (currently large red text drawn raw over
  the 3D world) with a themed, panelled notification consistent with the rest of the HUD.
- `IslandMenu.tscn`'s core panel is a hardcoded `custom_minimum_size = Vector2(600, 400)` — convert
  to responsive anchoring with a mobile-safe minimum; this is the game's most-used screen in a
  mobile-first project.
- A portrait-fallback treatment that reads as an intentional design choice (a stylised silhouette
  or flag icon) rather than the current generic purple skull-and-crossbones, until real portraits
  land in M11.

**Exit criteria:** every screen in `scenes/ui/` applies the same theme; no HUD element overlaps
another under both a fresh `CaptureHarness` run *and* a human playthrough (this project has now
twice shipped a headless-only "Resolved" that didn't hold up — this milestone's checkpoint
requires the second kind of verification, not just the first); the MainMenu reads as a considered
first impression, not a placeholder.

**Results (2026-08-28):** All nine requirements closed. D32 (material-null startup errors) traced
to its real cause for the first time — not the camera spring arm (D31's fix confirmed still
correct and still not the explanation), but a save-triggered second `ShipVisuals._rebuild_model()`
call racing the renderer's first-frame sync; conclusively harmless (every capture frame shows the
ship correctly modeled), documented rather than restructured, per Requirement 2 AC2. D36 (HUD
overlap) fixed via a `TopRightPanel` `VBoxContainer` replacing two independently-hardcoded offsets;
a second overlap the first fix attempt introduced (notoriety label vs. the Captain's Log button)
was caught by a follow-up capture and closed too — `tests/test_world_hud_layout.gd` now checks all
three elements pairwise, not just the pair the original bug named. Every screen in `scenes/ui/` now
applies `PirateThemeBuilder` (Settings/Credits were the gap). MainMenu has a real title > subtitle >
button hierarchy. `IslandMenu`'s main panel is responsive (removed a `CenterContainer` that had been
silently defeating any anchor-based fix). Requirement 8's premise (a "purple skull" fallback) didn't
match the codebase — no such icon existed; fixed the real problem instead (a static emoji for every
speaker) with a themed monogram fallback. GUT suite: 391 tests, 391 passing (M10/M11 landed
concurrently during this milestone and both closed the project's one standing pre-existing failure
and a pre-existing test-suite crash this milestone found and fixed — D73, a fourth instance of the
D67 test-isolation defect class, affecting 15 files). Full detail: `docs/05_CURRENT_SYSTEMS.md`'s
presentation-audit section, `docs/09_VISUAL_BUG_TRACKER.md` V5/V9/V13–V17,
`.kiro/specs/milestone-m9-presentation-pass/tasks.md`.

---

## M10 — The Legible World

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
- **Building-model art**: source and integrate real per-level building models (`docs/10_ASSET_REQUESTS.md`'s
  54-model ask, 0 delivered since M6). Investigate existing Kenney-style stock packs first — the
  same playbook that closed the ship-model gap (D40) — before assuming custom art is required;
  this is the mechanical expression of `docs/03_ART_DIRECTION.md`'s "every upgrade should read as
  visible investment from a distance," currently faked by uniform scaling only.
- A minimal save-schema version stamp (not the full backup/migration path — that's M12), so the
  substantial new persisted state this milestone adds (world position, region id, discovery
  flags, weather) doesn't grow M12's eventual migration surface any further than necessary.

**Exit criteria:** the Expanded map holds 60 fps on a mid-range Android device; a player can
open a map and know where they are and where they have not been.

**Exit criteria results (2026-08-27):** all 10 scope items implemented and engine-verified — see
`docs/05_CURRENT_SYSTEMS.md`'s "M10 — The Legible World" section for the full per-requirement
breakdown, and `docs/11_WORLD_MAP.md` §7 for the closed gap list. A real Godot 4.3 was installed
(the implementing environment initially had only a WinGet 4.7.1, which fails to even parse this
project) and used to run both required checks: GUT suite **326/326 passing, 0 failures** — the
project's first 0-known-failures result — and a headful `CaptureHarness` capture, reviewed. **The
60fps-on-mid-range-Android half of this exit criterion remains unverified and likely to stay
that way** — this project has never had device-profiling access at any milestone
(`docs/14_SYSTEM_INVENTORY.md` §5), and M13 is still the first milestone with guaranteed hardware.
The "player can see where they are/haven't been" half is implemented and its HUD entry point
confirmed on screen (the new "Map" button, correctly positioned, no overlap), but the
`WorldMapScreen` itself (rings/markers/player-heading rendering) was not opened during the
reviewed capture — see `.kiro/specs/milestone-m10-legible-world/tasks.md` task 29 for exactly
what was and wasn't visually confirmed, and what a follow-up manual playthrough should still check.

---

## M11 — Depth

**Goal:** the systems that are one-note become choices.

**Scope:** tech tree 2 → 12–15 techs · wind and sail trim · cannonball arcing · hull-facing armour
variance · 2 more bosses · diplomacy (treaties/tribute, PRD §16) · trade routes as objects rather
than abstract missions · world events 3 → 8–10 · full SFX pass (`AGENTS.md`: "no silent
interactions" is currently unmet) and music · portrait sourcing/integration (27 needed — 20
captains + 7 named cast; non-blocking but currently 0 delivered and, per the M9 audit, visibly
absent as a generic fallback in actual play).

**Exit criteria:** every faction can be engaged in more than one way; combat has a skill ceiling
a returning player can still be climbing.

**Exit criteria results (2026-08-28):** all 10 scope items implemented and engine-verified — see
`docs/05_CURRENT_SYSTEMS.md`'s "M11 — Depth" section for the full per-requirement breakdown. GUT
suite **391/391 passing, 0 failures**, up from M10's 326/326 baseline, plus a headful
`CaptureHarness` capture reviewed. "Every faction engageable more than one way" is real: tribute
(`FactionManager.pay_tribute()`) and trade routes now sit alongside combat as ways to move a
faction relationship, and 2 new bosses (The Iron Vulture, Fortune's Toll) give the "combat skill
ceiling" half genuinely different mechanical identities to learn (outranging artillery vs. a
bow-chaser positioning threat), not just bigger numbers on the same fight. **What this exit
criterion does not cover**: whether the wind/arcing/armor changes actually *feel* right in live
play — verified by unit test (direction math, flight-time-to-splash, facing-multiplier
composition) and a passing headful boot capture, but not by a human playing an actual fight, since
this environment has no way to drive input into a running game. Audio (SFX + music, 0 → 25 cues)
is real and wired but likewise unconfirmed by ear — both are explicitly flagged as needing a human
pass in `.kiro/specs/milestone-m11-depth/tasks.md`'s checkpoint, not silently assumed fine.
Portraits landed for 20 of 27 characters (captains; the 7 named cast keep M9's fallback) as
originally-generated flat-color icon busts rather than sourced character art, since no free
pirate-portrait asset pack was found — Requirement 9.2's own sanctioned substitute for exactly
this situation, not an improvised shortcut.

---

## M12 — Playtest & Instrumentation

**Goal:** find out what is actually wrong from someone who is not us.

**Scope:** analytics/funnel telemetry · crash reporting · save schema versioning + backup +
migration path · localisation-ready strings · a playtest protocol · a balance spreadsheet that
*owns* every economy number (the missing artefact behind D53) · codex/lore browser · **local push
notifications for offline-completion events** (raid resolved / building complete / fleet
returned) — new scope, genre-standard for this kind of mobile empire builder, distinct from the
energy-systems/paid-features `AGENTS.md` forbids, serving `docs/00_VISION.md`'s own "something
meaningful happened" daily-open goal where today nothing tells the player it did.

**Exit criteria:** ≥ 10 external players have reached Chapter 3; drop-off is measured, not
guessed; every economy constant traces to a model.

**Status (2026-08-28):** implemented, built concurrently with M11 in the same working tree (same
caveat as M9/M10's overlap — check `git status`/`git diff` before assuming file state).
Analytics, crash reporting, save versioning/backup/migration, localization infrastructure, the
Codex/lore browser, and push notifications (re-scoped to raid-resolution only, the only event
that genuinely resolves whether or not the player is watching — see
`docs/05_CURRENT_SYSTEMS.md`'s "M12 — Playtest & Instrumentation" section for the full per-
requirement breakdown) are all implemented and covered by GUT tests (396/396 passing, up from
M11's 391/391). The balance spreadsheet (`docs/BALANCE_MODEL.md`) now covers every resource/
encounter category with a cost or reward field.

**Exit criteria not met, honestly:** the playtest round has not been run — `docs/PLAYTEST_PROTOCOL.md`
exists and is ready, but real participant count is **0**, not ≥10. Running it requires a human to
actually recruit and observe external players; no AI session working on this repo has a channel to
do that. Push-notification device verification (real Android permission-dialog behavior) is
similarly not done — no Android export/device was available in this environment. Both are flagged
here rather than asserted, per this project's established discipline; see M11 Task 13 (human audio
listening pass) for the same category of gap.

---

## M13 — Ship It

**Goal:** an Android build on a store.

**Scope:** install export templates (not present on the dev machine today) · Android export +
signing · device performance profiling · touch-control verification on real hardware · store
listing, icon, screenshots, description · release checklist · resolve the engine version question
(`project.godot` declares 4.3; the dev machine runs 4.7.1; nothing has audited the gap) if not
already closed earlier.

**Exit criteria:** a signed build a stranger can install and play to Chapter 3.

**Status (2026-08-29): partial, honestly.** The engine-version question was already resolved by
`docs/20_PLATFORM_MATRIX.md` §2 before this milestone even started (stay on 4.3) — this milestone's
own original text above, guessing 4.7, predates that decision and is stale. Android SDK, JDK,
export templates, and both a debug and release signing keystore are installed and configured.
**A successful `.apk`/`.aab` export could not be produced** — extensively bisected against a
consistent, unhelpful blank error from the engine itself; full reproduction record in
`docs/05_CURRENT_SYSTEMS.md`'s M13 section and `docs/RELEASE_CHECKLIST.md` step 4. Device
performance profiling and touch-control verification are consequently blocked (no installable
build exists yet), though `MobileControls.tscn`/`.gd` were fixed independently of hardware access
(it was wiring only 5 of ~8 expected actions, and two of those drove a deprecated combat path).
Store listing copy, the release checklist, and the privacy policy + account-deletion page (content
sourced from M15's now-landed Supabase auth work, not guessed) are all done — the privacy page is
pushed to `gh-pages` but GitHub Pages itself still needs enabling in repo Settings, a step only the
repo owner can take. Play Console Data Safety submission needs real account access this environment
doesn't have. **This is not the "signed build a stranger can install" exit criterion** — it's
real, verified progress with an honestly-scoped remainder, not a completed milestone.

---

## M14 — Live Operations

**Goal:** the world keeps growing without rewrites.

**Scope:** Chapters 6–10 per `docs/13_CAMPAIGN_LEVELS_1-5.md` §9 · region 4 (Ancient Ocean) and
region 5 (Ghost Reaches), both id-reserved already · seasonal repeatable events (the spring
crossing) via a new `SeasonalEventData`/`SeasonalEventManager` (not `ChapterData` — that model is
permanent-completion-only) · the Ghost Fleet gets real mechanical presence in Region 5 while its
supernatural nature stays deliberately unconfirmed · content-authoring guide so a non-coder can
add a chapter · a "What's New" panel for returning players · a thin `LiveOpsConfig` wrapper
consuming M15's remote config for seasonal-window scheduling and a live kill-switch — **soft
dependency only**: this milestone is fully startable and shippable with M15 not yet landed,
running entirely on authored local fallbacks.

**Exit criteria:** a content update ships without a code change.

Full spec, now at full depth including `tasks.md` (previously outline-only):
`.kiro/specs/milestone-m14-live-operations/`.

---

## M15 — Backend & Cloud Services

**Goal:** an optional account lets a player carry their empire across devices, without the game
ever requiring one.

**Why here, and why separate from M14:** `docs/02_TECH_STACK.md` has named Supabase as "Backend
(Future)" since early in the project; `AGENTS.md` lists Cloud Saves under "Out of Scope (Version
1)... these are future milestones. Do not implement unless instructed" — explicitly instructed
2026-08-27. Scoped as its own milestone rather than folded into M14 because it's a genuinely new
architectural surface (the game's first network dependency, first user-identity concept, first
server-authoritative data store), not more content on existing systems. M14 and M15 touch largely
disjoint systems (content data vs. account/network plumbing) and can run in either order or in
parallel — M14 gained one small soft dependency on M15's remote config (seasonal-event scheduling,
a live kill-switch) when M14 was fleshed out 2026-08-27, but it's designed to degrade gracefully
to authored local fallbacks if M15 hasn't landed yet, so the "either order" relationship still
holds in practice, unlike a hard dependency would.

**Scope:** Supabase Auth (email/password + Google Sign-In) via direct REST calls, no third-party
SDK · account creation and sign-in are **optional and opt-in, permanently** — the game stays fully
playable offline forever, per `AGENTS.md`'s single-player-first design · a `player_saves` Postgres
table with Row Level Security scoping every row to its owning account · cloud sync extending
`SaveManager`'s existing save/load path, with an explicit keep-local/keep-cloud prompt on any
conflict, never a silent overwrite · Google Sign-In's Android deep-link handling is flagged as the
milestone's one genuinely uncertain item and is explicitly allowed to ship after, or without,
email/password if the Android platform work proves disproportionate · **password reset** (shares
the deep-link machinery Google Sign-In needs, but with a fully-functional browser-only fallback if
that machinery is deferred) · **account deletion** via a `service_role`-gated Supabase Edge
Function (the one place this milestone's design touches that key at all, and only server-side) ·
**terms-of-service acceptance + a precise data-collection enumeration** that becomes the literal
source for `.kiro/specs/milestone-m13-ship-it/`'s privacy policy · **Supabase auth hardening**
(leaked-password protection, a dashboard toggle) · **a minimal remote-config table** consumed by
M14's live-ops scheduling and kill-switch.

**Exit criteria:** a player can sign in on a second device and find their empire waiting, a player
who never signs in notices nothing different, a player can permanently delete their account and
data both in-app and without the app installed, and no secret key capable of bypassing another
player's data — or the `service_role` key itself — ever ships in the client.

Full spec: `.kiro/specs/milestone-m15-backend-cloud-services/`.

---

## Post-v1 — M16 through M21 (added 2026-08-27)

> **These six were scaffolded as a forward-planning pass, not as a queue jump.** M9 has open
> tasks and M11–M15 are entirely unstarted. `docs/07_AI_AGENT_WORKFLOW.md` Rule 8 (milestones are
> strictly sequential) still governs — nothing below starts before its predecessors finish.
>
> **The constitutional change that made them possible.** Until 2026-08-27 `AGENTS.md` read
> "Never introduce paid features" and "Never introduce new currencies", which directly
> contradicted `docs/00_VISION.md` §19's monetization philosophy and was inherited into every
> M9–M15 spec's Non-Goals. Those rules are now scoped: no paid feature ships before the M13
> launch build, and monetization afterwards is bounded by `docs/00_VISION.md` §19.1 and
> `docs/17_MONETIZATION.md`. The §19 never-list — pay-to-win, energy systems, forced ads,
> artificial waiting — remains absolute and unamendable.

## M16 — Cosmetics & Entitlements

Build what will later be sold, and ship it **free** first, so the entitlement system is proven
before billing touches it. `EntitlementManager` autoload with account-scoped (not save-scoped)
persistence, `CosmeticData` resources, a wardrobe screen, ≥10 cosmetics across ≥4 slots, and
three play-earned grant paths. No money, no prices, no store — a disabled buy button is still a
paid feature in the tree. Not gated on M13.

**Exit:** entitlements survive a new game and a full save deletion; a cosmetic survives a
damage-and-repair cycle (the `ShipVisuals` albedo-cache hazard); zero money references in the diff.

## M17 — Freemium Launch

**Hard-gated on M13 having shipped.** Google Play Billing behind a platform-agnostic
`IStoreBackend` seam, the Pirate King Supporter Pack, paid cosmetics, restore-purchases, the
age-gate/consent state machine, three opt-in rewarded-ad surfaces with hard caps, refund
revocation, and the legal artifacts (privacy, terms, Data Safety) that shipping any of it
requires.

**Exit:** a real purchase, restore, refund and revoke on a device; every baseline reward
byte-identical with ads disabled; the ten-question reviewer checklist in `docs/17_MONETIZATION.md`
§7 answered "no" throughout.

## M18 — Retention & Re-engagement

The layer that makes freemium actually earn: the Captain's Log streak (a broken streak steps back
**one tier**, never to zero), weekly goals resolved from existing signals, comeback bonuses, an
upgraded offline-return panel (closing **V13**), a one-per-day notification budget with quiet
hours, an in-game feedback channel, and finally *acting* on M12's funnel data rather than only
collecting it. Governed by `docs/19_RETENTION_AND_LIVEOPS.md`, whose rule 8 keeps retention
surfaces and purchase prompts physically apart.

**Exit:** nothing decays as a function of time away, asserted by test; a playthrough ignoring
every retention feature still reaches the final chapter.

## M19 — Accessibility & Inclusive Play

Colourblind palettes, non-colour redundancy for every colour-coded state, text scaling to 200%
with real reflow, captions for speech and meaningful non-speech audio, reduced motion (**camera
only** — touching the wave simulation would re-open the D11 sync defect), one-handed layout, and
48dp touch targets. Plus the tests that stop it regressing across M20 and M21.

**Sequencing:** cheapest before the UI grows, and a Play Store quality-listing factor. **If M13's
date has slack, pull this ahead of M13.**

**Exit:** `docs/18_ACCESSIBILITY.md` §6's twelve points walked against every screen, with the
headful-only items reported as unverified rather than claimed.

## M20 — iOS & Second Platform

StoreKit as an *implementation of M17's existing seam*, never a second storefront. ATT folded into
M17's consent machine as one more state. iOS export, App Review, parity audit — plus the ASO
assets neither M13 nor M17 covered: trailer, a repeatable `ScreenshotHarness`-driven screenshot
pipeline, press kit, localized listing copy. The engine-version decision
(`docs/20_PLATFORM_MATRIX.md` §2) is revisited here, before iOS work begins.

**Hard logistical blocker:** iOS builds require macOS; this project develops on Windows.

**Exit:** one billing interface with two implementations and no duplicated storefront logic; every
parity deviation recorded rather than merely known.

## M21 — Performance, Security & Debt Zero

The milestone that owns what nobody else does: spatial partitioning and culling (marked "M11+" in
doc 14 and never actually specced — "M11+" is not an owner), save tamper-*detection* (explicitly
not anti-cheat), and the standing defects — **V5** material nulls (closed once, reopened), **V8**
ship beaching, the undecided `CurrentHealth`-on-upgrade question, and region mixed-role enemy
compositions.

**Exit:** before-and-after frame numbers from the *reference device*, not a desktop; V5 closed at
a named root cause rather than a suppressed warning; no gameplay features added and no unrelated
refactors.

---

# 3.1 Gap register (audit of 2026-08-27)

Nineteen items that had no owning milestone when the audit ran. Recorded here so the roadmap
cannot look complete while they are open.

| # | Gap | Owner |
|---|---|---|
| 1 | Cosmetic system (skins, sails, flags, figureheads) + equip/preview | M16 |
| 2 | Entitlement model — ownership, persistence, reinstall survival | M16 |
| 3 | Cosmetic art pipeline — doc 10 had no cosmetic category | M16 |
| 4 | Google Play Billing + restore purchases | M17 |
| 5 | Rewarded ads SDK, opt-in surfaces, UMP consent, frequency caps | M17 |
| 6 | Age gating / COPPA / Play Families — mandatory once ads ship | M17 |
| 7 | Refund, purchase-support, and "I paid and lost it" flows | M17 |
| 8 | Terms/Privacy update for ads + purchase data (M15's predate both) | M17 |
| 9 | Entitlement verification — light, client-side, deliberately not server-authoritative | M17 |
| 10 | Retention loop — daily streak, weekly goals, comeback bonus | M18 |
| 11 | In-game feedback / bug-report channel | M18 |
| 12 | FTUE funnel tuning — M12 collects analytics, nothing acted on them | M18 |
| 13 | Accessibility — zero coverage anywhere in M9–M15 | M19 |
| 14 | iOS export, App Review, StoreKit, App Store listing | M20 |
| 15 | ASO — trailer, screenshot pipeline, press kit (M13 had listing text only) | M20 |
| 16 | Spatial partitioning / culling — deferred to "M11+", never specced | M21 |
| 17 | Save tamper-resistance — matters once entitlements have money value | M21 |
| 18 | Standing debt: V5, V8, `CurrentHealth` rescale decision, mixed-role compositions | M21 |
| 19 | **Multi-slot saves — still unowned.** `SaveManager` writes one hardcoded `user://save_data.json` with no slot concept. Found while auditing the Supporter Pack, which had promised "extra save slots"; that promise was removed rather than left unbuildable (`docs/17_MONETIZATION.md` §2.2). | **none** |

---

# 4. Critical path

```
D53 economy correction ─┬─► M7 campaign spine ──► M8 combat rework ──► M9 presentation ──► M11 depth ──┐
                        └─► M7 map correction                                                          ├─► M12 playtest ──► M13 ship ──┬─► M14 live ops
                                    │                                                                   │                               └─► M15 backend ┄┄┄┄┄┐
              Ocean LOD ──────────────────────────────────────► M10 Expanded map + world map UI ───────┘                                                     ┆
                                                                                                          M15 Req 9 (data enumeration) ┄┄┄┄► M13 Req 7 (privacy policy)
                                                                                                          M15 Req 11 (remote config) ┄┄┄┄┄► M14 Req 6 (soft, degrades gracefully)
```

M15 (backend/cloud services) has no *hard* dependency on M14 or vice versa — either can run first,
or in parallel, once M13 exists (M15's Google Sign-In work specifically wants M13's real Android
package id; M15's email/password path doesn't even need that). Placed after M13 in the diagram
because cloud save is meaningfully post-v1-launch scope, not because anything blocks it earlier.
Two dotted (soft) dependencies were added 2026-08-27: **M15 Requirement 9 → M13 Requirement 7** —
M13's privacy policy is written more accurately once M15's exact data-collection enumeration
exists, but M13's own spec explicitly handles the "M15 hasn't landed yet" case by describing only
what's genuinely collected at that point (possibly nothing) rather than blocking; and **M15
Requirement 11 → M14 Requirement 6** — M14's seasonal-event scheduling and kill-switch use it if
present, fall back to authored local defaults if not. Neither dotted arrow can silently waste a
milestone the way the four hard ones below can — that's the point of designing them to degrade.

Four hard dependencies, and they are the only ones that can silently waste a milestone:

1. **D53 before any chapter tuning.** Every economy target in
   `docs/13_CAMPAIGN_LEVELS_1-5.md` is written against the corrected ladder. Authoring chapters
   against today's prices would need redoing.
2. **M9 (presentation) before M10 grows the world.** Found 2026-08-26 by actually running the
   game: two defects this document already recorded as "Resolved" (D32, D36) reproduced on a
   fresh run. Shipping a bigger world on top of a HUD that visibly breaks itself wastes M10's
   work on a worse first impression, not a better one — same logic as dependency 2 below, applied
   to polish instead of performance.
3. **Ocean LOD before the Expanded map.** A 1350-unit ocean span on a uniform wave mesh is a
   mobile framerate problem. The "accepted" failing test is the gate.
4. **Analytics before balance tuning.** Tuning retention without funnel data is guessing.

M8 (combat rework) and M10 (the legible world) touch disjoint systems — input/combat vs.
ocean/map — and could run in either order or overlap if two implementation tracks are available.
M9 (presentation) touches UI/theme code across nearly every screen and is cheapest to land before
either, so it isn't a candidate for parallelizing against them. The order above is a default for
M10/M11 onward, not a hard dependency.

---

# 5. Risk register

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| **Checkpoints keep being accepted on self-reports** | Compounding invisible breakage — already produced D15, D42, D57, and two tasks ticked with zero file changes | **High** — it happened again at M6 Task 29 | Every checkpoint runs the GUT suite and pastes real totals; the binary path is now recorded in `docs/14_SYSTEM_INVENTORY.md` §6 |
| Ocean LOD proves hard, blocking the world's size | The AC-IV "long voyage" feel never lands | Medium | Compact map is playable and shipped in M7; Expanded is upside, not a dependency of the campaign |
| Engine version drift (declared 4.3, running 4.7.1) | Rendering/behaviour differences discovered late | Medium | Audit in M13 at the latest (Requirement 1 there); note it in every visual finding until then |
| No balance model | More D53s | **High** | Started as an M11 deliverable, completed in M12 — but D53's fix should keep informing it now |
| Content bottleneck — one writer for chapters, techs, events, SFX | M11/M14 stall | Medium | Data-driven schemas are the mitigation; `.tres` authoring must never require a programmer |
| Never run on a real device | Mobile-first game that has never been mobile | **High** | M13 is the first milestone with guaranteed device access (Requirements 3/4 there); pull forward into M10 if hardware is available sooner |
| Combat rework (M8) touches the core input loop and regresses feel | A player-facing regression in the game's most-played moment | Medium | `docs/navalCombat.md` keeps the manual-fire path working until auto-fire is verified; ship behind a flag if needed |
| Scope creep back toward multiplayer/monetisation | Architectural churn | Low | `AGENTS.md` forbids it; keep it forbidden |
| Story becomes a blocker rather than a frame | Players stuck behind objectives | Medium | The 7 anti-softlock rules in `docs/06_NARRATIVE_AND_WORLD.md` §7, each with a test |
| A Supabase secret (`service_role` key) ends up in the client or version control (M15) | Every player's save data readable/writable by anyone | Low likelihood, **critical if it happens** | Design uses only the anon/public key client-side, gated entirely by Row Level Security; M15's checkpoint explicitly greps the exported build for secrets before sign-off |
| Google Sign-In's Android deep-link plumbing (M15) proves disproportionately complex | M15 stalls waiting on unfamiliar native-Android work | Medium | Explicitly allowed to ship email/password-only and defer Google Sign-In, per that milestone's own Requirement 2.4 |
| A free-tier Supabase project pauses after 7 days idle (M15) | Cold-start delay or a confusing failure the first time a dormant project is hit | Low | Documented in M15's prerequisites; sync failures already retry non-blockingly (Requirement 4.4) rather than hard-failing |

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
8. Rebind their controls and have it actually work *(D57 — fixed in M7)*.
9. Play it on an Android phone at a stable frame rate.
10. Explain their empire to a friend in one sentence.

---

# 7. Immediate next actions

All of the original list here (baseline verification, docs 06/11-15, map repositioning,
scaffolding and completing M7, the M7.5 stabilization pass closing D64/D65) is done — condensed
in `docs/16_MILESTONE_HISTORY.md`. Current next actions, updated 2026-08-26 after the presentation
audit in §9 reprioritized the roadmap:

1. **Implement `.kiro/specs/milestone-m9-presentation-pass/`** — already fully scaffolded
   (requirements/design/tasks). Fixes the reproduced D32/D36 regressions and the HUD/theme
   consistency gaps found by actually running the game on 2026-08-26. Goes first: it's cheaper
   than M10 and fixes what's visibly broken on every screen today, ahead of making the world
   bigger.
2. **Then `.kiro/specs/milestone-m10-legible-world/`** (also scaffolded) — ocean LOD first within
   it, since it gates the Expanded map per §4's critical path.
3. **Work each wave directly** in Claude Code, one task at a time, per
   `docs/07_AI_AGENT_WORKFLOW.md`'s rules — this project no longer hands implementation to a
   second agent (see that document's "What this replaced" section).

---

# 8. Pre-M9 Shippability & Presentation Audit (2026-08-26)

Found by two independent passes: a full read of every `docs/*.md` file against the actual repo
state (autoload list, test count, resource counts, and asset directories all spot-checked and
matched exactly), followed by **actually running the game** — `scenes/debug/CaptureHarness.tscn`,
headful, zero player input — and looking at the rendered screenshots plus the UI scene/script
source behind them. The second pass is the one that mattered: this document and
`docs/05_CURRENT_SYSTEMS.md` have repeatedly noted that automated-screenshot verification and
human verification are not the same bar, and this pass is the first time anyone actually crossed
into the second one for the HUD/menu layer specifically.

## 9.1 Reproduced regressions — two "Resolved" defects are not fixed

- **D36 (HUD layout, `docs/05_CURRENT_SYSTEMS.md`) reproduced.** The Notoriety/next-escalation
  label still visibly overlaps the `ResourceBar` panel's gold/wood/iron/rum counters on a fresh
  run today, despite the code comment in `WorldHUD._create_notoriety_label()` explicitly
  describing the fix this document already credits. The hardcoded `offset_top = 52.0` does not
  reliably clear the sibling panel.
- **D32 (`Parameter "material" is null"` ×4 at startup, `docs/05_CURRENT_SYSTEMS.md`) reproduced.**
  All 4 errors fired at startup on the same run. This document's D31 entry claims "a full capture
  run now reports 0 errors" — not true as of this run.
- **Both are reopened** — see the corresponding entries in `docs/14_SYSTEM_INVENTORY.md` and
  `docs/09_VISUAL_BUG_TRACKER.md`, and are now M9 (Presentation Pass) scope.

## 9.2 New findings — UI/UX execution, not systems

1. `announce_event()`'s banner (e.g. "While you were away: your empire kept running (N ticks)")
   renders as large, unframed, raw red `Label` text directly over the 3D world — no panel, no
   styling consistent with the rest of the HUD.
2. Tutorial dialogue, the combat cannon-cooldown panel, and ambient encounters render
   simultaneously with no arbitration — reproduced the Higgins tutorial box sitting directly on
   top of a live "STARBOARD CANNONS RELOADING" panel during an unacknowledged encounter.
3. `SettingsMenu.tscn`/`CreditsScreen.gd` never call `PirateThemeBuilder.build()` — confirmed by
   grep the only two screens in `scenes/ui/` that don't, so they render as raw default Godot UI
   against every themed screen.
4. `MainMenu.tscn`'s `TitleLabel`/`SubtitleLabel` ("PIRATE EMPIRE") have no font-size override —
   the game's own title renders at the theme's 15px body-text default. `CreditsButton`/
   `QuitButton` lack the `28px` size override and emoji-free styling the other three buttons in
   the same `VBoxContainer` have. A `VignetteOverlay` is authored at alpha 0 and never referenced.
5. Higgins' dialogue portrait renders as a generic purple skull-and-crossbones — the in-game face
   of the already-known "0 portraits authored" gap.
6. `IslandMenu.tscn`'s main panel is a hardcoded `custom_minimum_size = Vector2(600, 400)` —
   fixed-pixel, not responsive, on the game's most-used screen in a mobile-first project.
7. **Not a regression — a real strength worth preserving:** `PirateThemeBuilder.gd` itself is a
   competent, intentional theme (gold/navy palette matching the concept art, `Cinzel`/`PirataOne`
   fonts, bordered `StyleBoxFlat` panels with shadows) already applied to most screens. The
   problem above is composition/consistency/regression, not the underlying visual language —
   fixing 9.1/9.2 is a bounded, well-scoped pass, not a redesign.

## 9.3 Roadmap change

Inserted **M9 — Presentation Pass** ahead of the world-expansion work (previously M9, now M10),
renumbering M10–M13 to M11–M14. Full scope in §3's M9 entry. This is the same prioritization
discipline that inserted M7.5 ahead of its own plan: running the game surfaced defects nothing
else could, and they're cheaper to fix now than to build more world on top of.

## 9.4 Content-volume gaps needing an explicit owner (from the docs-only pass, still valid)

- Building-model art (0 of 54 delivered since M6) — now owned by M10, sourcing stock assets first.
- Portraits (0 of 27) — now owned by M11.
- Audio (0 files) — already M11-scoped; flagged here as more severe than a one-line treatment
  suggested, given `AGENTS.md`'s explicit "no silent interactions" rule.
- No human-facing balance model — recurring risk category (D53-class), not just an M12 process
  note; M11 alone adds 10-13 techs, 2 bosses, 5-7 world events with nothing pricing them.
- Save fragility — M10/M11 both add persisted state before M12's versioning/backup pass; a
  minimal version stamp is pulled into M10 to limit the eventual migration surface.
- No CI/CD until M13 — nothing guards the Android export path from silently breaking before then.

---

# 9. Document map

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
| `docs/07_AI_AGENT_WORKFLOW.md` | How does implementation actually happen, and how is it verified? |
| `docs/09_VISUAL_BUG_TRACKER.md` | What did the screenshots reveal? |
| `docs/10_ASSET_REQUESTS.md` | What art do we need? |
| `docs/11_WORLD_MAP.md` | Where is everything, and why there? |
| `docs/12_CHARACTER_BIBLE.md` | Who is in it? |
| `docs/13_CAMPAIGN_LEVELS_1-5.md` | What happens in the first five chapters? |
| `docs/14_SYSTEM_INVENTORY.md` | **Everything that must exist, and its status.** |
| `docs/15_MASTER_PLAN.md` | In what order do we build the rest? |
| `docs/16_MILESTONE_HISTORY.md` | What happened in each completed milestone, condensed? |
| `docs/17_MONETIZATION.md` | **What is sold, what is never sold, and how ownership works.** |
| `docs/18_ACCESSIBILITY.md` | Who can play it, and the checklist every screen must pass. |
| `docs/19_RETENTION_AND_LIVEOPS.md` | Why does a player come back tomorrow, without dark patterns? |
| `docs/20_PLATFORM_MATRIX.md` | Which platforms, which engine version, which store obligations? |

(`08` is intentionally absent and always has been.)
