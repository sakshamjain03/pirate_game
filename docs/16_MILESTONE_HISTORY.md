# 16_MILESTONE_HISTORY.md

> Version: 1.0
> Status: Living Document — condensed record of every completed milestone
> Owner: Project Lead

---

# Purpose

`.kiro/specs/milestone-m1-app-shell/` through `milestone-m7-campaign-spine/` — 8 directories,
requirements/design/tasks.md each, ~5,860 lines total of task-by-task checkboxes, dated audit
notes, and checkpoint reconciliation minutiae — were consolidated into this single doc on
2026-08-26 and removed from the working tree. Nothing is lost: full history is recoverable via
`git log`/`git show` on those paths if the play-by-play is ever genuinely needed. What follows is
what a future agent actually needs: what each milestone set out to do, what it shipped, and which
defects it produced or fixed, by D-number, cross-referenced to `docs/05_CURRENT_SYSTEMS.md` for
full technical detail.

**This doc is a historical record, not living documentation of current system behavior.** For
"what actually runs today," read `docs/05_CURRENT_SYSTEMS.md` and `docs/14_SYSTEM_INVENTORY.md`
instead — they supersede anything here that later changed. For "what's next," read
`docs/15_MASTER_PLAN.md`.

`.kiro/specs/milestone-m7.5-stabilization/` is the one milestone spec kept on disk, since it's
small, recent, and still useful as the live structural reference for scaffolding the next one
(see the `spec-new` skill).

---

## M1 — App Shell

**Goal:** the navigable skeleton before any gameplay exists — Boot → MainMenu → Settings/Credits,
and the three foundational autoloads (`SceneManager`, `AudioManager`, `SettingsManager`) every
later milestone depends on. No gameplay, combat, economy, or world systems in scope.

**Shipped:** scene transition/fade/back-navigation history; audio bus volume persistence;
display/audio settings via `user://settings.cfg`; Boot/MainMenu/SettingsMenu/CreditsScreen.

**Notable defects:** a folder-casing bug (`Scripts/` vs `scripts/`) broke Android builds and was
corrected during a 2026-08-02 bug-fix pass alongside a `ShipCombat.gd` duplicate-variable compile
error that cascaded into unrelated-looking parse errors project-wide. Integration tests (Boot→
MainMenu, button nav, `go_back()`, `ui_cancel`) were left unwritten at the time and closed later,
in the 2026-08-25 M1/M2 tail pass, as `tests/test_navigation_integration.gd`.

---

## M2 — Playable World

**Goal:** the first playable world — ocean, ship movement, camera, docking, islands — supporting
all three core pillars (Build/Explore/Conquer) for the first time.

**Shipped:** Gerstner-wave ocean (GPU shader + CPU `WaveGenerator` for buoyancy), `ShipController`/
`ShipMovement`/`BuoyancySimulator`, `CameraRig` (SpringArm3D follow), `InputManager` (touch/
gamepad/keyboard), `Island`/`DockingSystem`, `WorldManager`/`EventManager`, `WorldHUD`.

**Notable defects:** the 2026-08-02 bug-fix pass found docking entirely dead (nothing wired
`DockArea` signals to the shared `DockingSystem`), a `KenneyMaterialApplier` texture-loading path
that broke in exported builds, and a stale script-class cache masking real compile errors as
unrelated ones. A later 2026-08-09 pass found and fixed genuinely wrong original defect claims
(D9's camera-collision claim, D11's ocean-sync claim — see `docs/05_CURRENT_SYSTEMS.md` §2) by
re-checking actual scene-file wiring instead of trusting the original static-read audit. Property
tests (25 correctness properties from the design doc) were initially 0 bytes; implemented in M3.
Remaining tail items (event-system property tests, frame-time/quality settings, save/load error
signaling, real navigation integration tests) closed in the 2026-08-25 M1/M2 tail pass. Two items
remain permanently unclosed by design, not oversight: full audio integration (no audio assets
exist in the repo at all — a real M10 asset-pipeline dependency) and mobile-hardware-specific
tuning (touch target sizing, battery/thermal — needs real hardware, M12).

---

## M3 — Stabilization

**Goal:** fix the concrete defects D1–D12 recorded in `docs/05_CURRENT_SYSTEMS.md` before
M4 built the Empire Threat system on top of a broken foundation. No new gameplay features —
every task either fixed a broken behavior, removed dead code, or filled a missing test file.

**Shipped:** removed the `ScreenshotHarness` production autoload; deleted the duplicate scene-
local `EventManager`; created the real `PlayerFaction.tres` (fixing colonize/capture); rewrote
`GhostShipStats.tres`'s wrong property names; deleted dead code (`ScenePaths`/`UIConstants`) and
orphaned resources; added gamepad input bindings; fixed camera spring-arm collision and the
permanent-sunset fog bug; implemented the 5 previously-empty property test files.

**Closed:** D1–D11. **Left open, tracked forward:** D12 (no test coverage for combat/economy/
fleet/tech/factions — closed the same milestone it was flagged, actually, once the audit caught
up; see D12's entry in `docs/05_CURRENT_SYSTEMS.md` §2 for the exact resolution and the real bug
it caught: `FleetManager.get_save_data()` returning a live Dictionary by reference).

**Verification:** 48 tests / 49 passing at close (later baselines superseded this number as more
milestones added tests — see `docs/14_SYSTEM_INVENTORY.md` §0 for the full history of baseline
figures).

---

## M4 — Empire Escalation

**Goal:** the mechanic missing from every prior milestone — your empire draws attention as it
grows, and larger powers raid you back. Single continuous open world, no discrete mission maps,
no multiplayer.

**Shipped:** `EmpireManager` autoload (notoriety, decay, region activation); `RegionData` (3
regions: Beginner/Contested/Imperial Waters, tiered thresholds); a 5th faction (Spanish Empire)
and a 2nd Imperial-tier island (Cartagena Outpost); `EnemySpawner.compute_spawn_multiplier()`
(region+notoriety difficulty scaling, applied to duplicated `ShipStats` only); home-island raid
simulation (defense score from Fortress/Watchtower + Defend-Home ships, attack score from region
tier + notoriety) and `RaidReportScreen` UI; full save/load round-trip for all of it.

**Notable defects found and fixed during this milestone's own checkpoints:** the raid's resource-
theft path was dead code (gated on a `ResourceManager` method that never existed — every
unrepelled raid silently stole nothing until fixed); a day/night-cycle test flaked on the ±180°
wrap boundary; two null-deref crashes in `EnemySpawner`/`WorldHUD` surfaced by the new test suite
(D13); stale/missing doc headers across every M4-touched file, corrected (D14 class).

**Verification:** 100 tests / 101 passing at close.

---

## M5 — Launch Readiness

**Goal:** close the two remaining gaps against `AGENTS.md`'s MVP launch checklist — offline
gameplay and a 20-captain roster (everything else on that checklist was already met).

**Shipped:** `last_saved_unix` persistence + capped (4h) offline-tick replay on load, calling
`Island._on_economy_tick()`/`FleetManager._on_economy_tick()` directly rather than re-emitting the
shared `global_economy_tick` signal (which `FactionManager` also subscribes to, for hunter-ship
dispatch — replaying it hundreds of times would have spawned hunters at an absurd rate); a
one-time "while you were away" HUD notice; `hire_cost_gold` on `CaptainData`; 15 new captain
`.tres` files (20 total) with ramped hire costs; the Tavern UI updated to show real per-captain
costs instead of a hardcoded 500.

**Verification:** 102 tests / 103 passing at close. One checkpoint task (interactive offline-gap
playthrough) was correctly left as a deferred/non-automatable manual check rather than falsely
marked passed; a duplicated copy of that same checkpoint entry in the tasks doc was found and
merged during the 2026-08-25 tail pass.

---

## M6 — Black Flag Combat & Island Economy

**Goal:** the first retention-focused milestone. M1–M5 built a world that works; M6 makes it worth
returning to, modeled primarily on *Assassin's Creed IV: Black Flag*'s naval combat feel and
island economy, with *Pirates of the Caribbean* for tone and *Clash of Clans* for the "your port
is a place you're proud of" shape.

**Shipped:** `AmmoData` (round/chain/grape shot) and the full firing path; `ShipDamage` (hull/
sails/crew pools, stern-arc crits, sail-damage → speed coupling); boarding (`BoardingSystem`,
crew strength checks, loot); crew recruitment at Taverns; 5-level building upgrade chains (10
building types × 5 levels) with island tiers gating construction; `AIProfileData` (3 initial
profiles); docked camera transitions (closing an M2 gap); an input-rebinding UI (closing another
M2 gap, though it shipped silently broken — see D57 below).

**Notable defects:** the damage-model migration (`ShipCombat` → `ShipDamage`) was verified not to
break `ShipCombat`'s existing public API, guarded by requiring `test_ship_combat.gd` to pass
**unmodified**. A real process failure occurred at this milestone's own final checkpoint: it was
ticked complete with the note "Skipped local execution of GUT since binary is unavailable" — the
binary was, in fact, available the entire time at the path this project's tooling docs already
recorded. This is the specific incident `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8 (blocking,
independently-verified checkpoints) exist to prevent from recurring.

**Verification:** baseline moved 103 → 117/118 tests across the milestone; later re-measured and
corrected to **118 tests / 117 passing** on 2026-08-14 (the milestone's own recorded `103` figure
had been stale by 15 tests).

---

## M8 — Combat Identity Rework (no `.kiro/specs/` directory)

Not part of the M1–M7 spec set — implemented ad hoc, ahead of M7 in real execution order, and
tracked entirely in `docs/05_CURRENT_SYSTEMS.md`'s "M8 Combat Identity Rework" / "— Phase 2"
sections rather than as a milestone spec. Delivered the auto-fire-on-arc-alignment combat model
from `docs/navalCombat.md`, captain active abilities, temporary in-battle upgrade offers, ship
modules + ship-level progression, bow/stern chasers, enemy role differentiation, AI support ships,
and the economy correction (D53/D54/D56) M7's own Wave 1 depended on. Baseline moved
126 → 214/213 (Phase 1) → 249/248 (Phase 2). Mentioned here only so the M7 entry below makes
sense — full detail lives in `docs/05_CURRENT_SYSTEMS.md`, not here.

---

## M7 — Campaign Spine & Economy Correction

**Goal:** give the world a reason, and fix the economy that reason depends on. M1–M6 (plus M8,
completed first) built systems that work in isolation; nothing told the player why any of it
mattered, and D53 made M6's own headline "combat funds the empire, the empire funds a better
ship" requirement untestable.

**Shipped:** the economy correction (D53/D54/D55/D56 — ship identity/cost fields, captain
boarding modifier + hire cost, all authored); D57 (`InputManager` promoted to an autoload,
fixing rebinding); D58 (Port Royal seeded as owned home on a genuinely new game); the campaign
data model (`ChapterData`/`ObjectiveData`/`DialogueBeatData` + `CampaignManager` autoload,
reusing `TutorialManager`'s condition-dispatch pattern rather than duplicating it); `TutorialManager`
reduced to a thin wrapper (UI-unlock tracking + the completion-flag file only); all 5 chapters
authored with dedicated bosses for Chapters 4/5 (HMS Intransigent, Cárdenas' flagship); a
Captain's Log UI + HUD objective feedback.

**Notable defects fixed:** D53–D59, closed across M7/M8 (see each D-number in
`docs/05_CURRENT_SYSTEMS.md` for which milestone actually closed it — the M8-before-M7 execution
swap means several were closed "early"). Two test-isolation bugs were found and fixed while
writing this milestone's own tests: a real `World.gd` boot in a test picks up whatever save
happens to exist on disk, and region activation is sticky (never reverts to dormant), so a stale
save could permanently and silently activate a region for every later test in the same run.

**Verification:** 249 → 320 tests / 319 passing across the milestone. Independently
checkpoint-verified (not self-reported) on 2026-08-25.

**Left open at close, closed by M7.5 immediately after:** Chapter 4/5's dedicated bosses had no
in-world trigger (D65) — honestly disclosed as a known gap in the milestone's own tasks doc
rather than silently shipped broken.

---

## M7.5 — Stabilization Pass

**Goal:** catch what a tasks.md/checkbox audit and a green test suite cannot — real runtime
defects only visible by actually running the game and looking at the rendered output — plus close
the one gap M7 itself flagged as unresolved.

**Shipped:** D64 (a save missing player position data defaulted the ship to `Vector3(0,1,0)` —
Port Royal's own island origin post-M7 — silently teleporting it into the home island's collision
and collapsing the camera into the terrain on load; found via a headful `CaptureHarness` capture,
not code reading); D65 (Chapter 4/5 bosses gated into the ambient encounter pool by a new
`EncounterData.required_chapter_id`, making them reachable through normal play for the first
time).

**Verification:** 320 → 323 tests / 322 passing. Full technical detail, the three disproved
theories tried before finding D64's real cause, and the fix: `docs/05_CURRENT_SYSTEMS.md`'s "M7.5
Stabilization Pass" section and `docs/09_VISUAL_BUG_TRACKER.md` V12. Spec kept on disk at
`.kiro/specs/milestone-m7.5-stabilization/` as the current structural reference for the next one.

---

# Test count history

| Milestone | Baseline at close |
|---|---|
| M3 | 48 / 49 |
| M4 | 100 / 101 |
| M5 | 102 / 103 |
| M6 | 118 / 117 (corrected; originally recorded as 103) |
| M8 Phase 1 | 214 / 213 |
| M8 Phase 2 | 249 / 248 |
| M7 | 320 / 319 |
| M7.5 | 323 / 322 |

One test has failed consistently since M2 and is an accepted, tracked gap rather than a
regression: `test_property_21_lod_distance_transitions` — no ocean LOD system exists yet (M9
scope).
