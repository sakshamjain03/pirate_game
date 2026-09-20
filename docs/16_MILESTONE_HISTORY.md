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
"what actually runs today," read `docs/05_CURRENT_SYSTEMS.md` (which includes system status and
content volume targets) — it supersedes anything here that later changed. For "what's next," read
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
milestones added tests — see `docs/05_CURRENT_SYSTEMS.md` §0 for the full history of baseline
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
Stabilization Pass" section and this doc's own resolved bug archive appendix (V12), below. Spec
kept on disk at `.kiro/specs/milestone-m7.5-stabilization/` as the current structural reference for
the next one.

---

## M9 — Presentation Pass

**Goal:** every screen the player actually looks at reads as one finished game, not systems work
wearing a partial coat of theme.

**Why here, ahead of world size:** found by actually running the game
(`scenes/debug/CaptureHarness.tscn`) and looking at the rendered output on 2026-08-26 — not by
reading code, the same discipline M7.5 used. Two defects this document already records as
"Resolved" (D32, D36) reproduced on a fresh run today. A bigger, better-populated world sitting
behind a HUD that visibly overlaps its own text does not read as "in progress" to a new player —
it reads as broken on the very first screen, every session.

**Shipped:** D36 (HUD layout, notoriety label overlapping ResourceBar) fixed via TopRightPanel
VBoxContainer replacing two independently-hardcoded offsets; D32 (material-null startup errors)
traced to a save-triggered second `ShipVisuals._rebuild_model()` call racing the renderer,
documented as harmless. Themed `SettingsMenu`/`CreditsScreen`; rebuilt `MainMenu` typography
hierarchy; fixed `IslandMenu` panel to be responsive; implemented themed portrait fallback
(monogram vs. the prior generic purple skull); added HUD panel arbitration and consistent
notification styling; updated `announce_event()` with themed notification panel.

**Verification:** 323 → 391 tests / 391 passing. Full technical detail in
`docs/05_CURRENT_SYSTEMS.md`'s "M9 — Presentation Pass" section. M10/M11 landed concurrently
and closed the project's one standing pre-existing test failure plus a pre-existing test-suite
crash (D73).

---

## M10 — The Legible World

**Goal:** the player can see the world, and the world is big enough to be worth seeing.

**Shipped:** Ocean LOD (closing the project's standing test failure and unblocking the Expanded
map at 2.5× Compact coordinates); Discovery/fog with IslandData.discovered reveal on approach;
World map UI with region rings, known islands, current heading, active objectives; Per-region
weather and enemy types (closing EnemySpawner gap); EventData as a resource (world events
no longer hardcoded); Ship damage visuals (hulls show what they've survived); 2–4 new islands
across the three regions; Per-level building models sourced from Kenney stock packs; Minimal
save-schema version stamp.

**Verification:** 326 tests / 326 passing (the project's first 0-known-failures result after
fixing the one standing pre-existing failure). Full technical detail in
`docs/05_CURRENT_SYSTEMS.md`'s "M10 — The Legible World" section. 60fps-on-mid-range-Android
half of exit criterion remains unverified (no device access at the time); player-heading/map-UI
rendering confirmed on CaptureHarness but not opened during the reviewed capture — follow-up
manual playthrough flagged in task spec.

---

## M11 — Depth

**Goal:** the systems that are one-note become choices.

**Shipped:** Tech tree expanded 2 → 12–15 techs; wind and sail trim; cannonball arcing;
hull-facing armour variance; 2 more bosses (The Iron Vulture, Fortune's Toll); diplomacy
(treaties/tribute); trade routes as objects; 8–10 world events; full SFX pass (25 cues); portrait
integration for 20 captains (flat-color icon busts, as no free pirate-portrait pack was sourced).

**Notable work:** Every faction now engageable in more than one way (tribute + trade routes +
combat); combat has a genuine skill ceiling with meaningfully different boss identities
(outranging artillery vs. positioning threat). Wind/arcing/armor changes verified by unit test
and passing headful capture, but human audio listening pass and live-combat feel verification
flagged as needing manual confirmation (environment limitations).

**Verification:** 391 tests / 391 passing (up from M10's 326/326 baseline). Full technical detail
in `docs/05_CURRENT_SYSTEMS.md`'s "M11 — Depth" section.

---

## M12 — Playtest & Instrumentation

**Goal:** find out what is actually wrong from someone who is not us.

**Shipped:** Analytics/funnel telemetry; crash reporting; save schema versioning + backup + migration
path; localisation-ready strings; playtest protocol (documented but not executed — 0 external
players recruited in this environment); balance spreadsheet (`docs/BALANCE_MODEL.md` covering every
resource/encounter category); codex/lore browser; local push notifications (raid-resolution only,
the one event that genuinely resolves whether the player is watching).

**Verification:** 396 tests / 396 passing (up from M11's 391/391). Exit criterion "≥10 external
players reached Chapter 3" was not met — playtest protocol exists but recruitment requires human
action unavailable in this environment. Remote-config code path fully unit-tested against a faked
cache; real Supabase end-to-end verification would require MCP access not available at milestone
start.

---

## M13 — Ship It

**Goal:** an Android build on a store.

**Status:** partial and honestly disclosed. Engine-version question already resolved by
`docs/20_PLATFORM_MATRIX.md` (stay on 4.3). Android SDK, JDK, export templates, and signing
keystores installed and configured. **A successful `.apk`/`.aab` export could not be produced** —
extensively bisected against a consistent, unhelpful blank error from the engine. Device performance
profiling and touch-control verification consequently blocked (no installable build exists yet);
`MobileControls.tscn`/`.gd` fixed independently (was wiring only 5 of ~8 actions). Store listing
copy, release checklist, and privacy policy + account-deletion page (sourced from M15's landed
Supabase auth work) are complete. GitHub Pages and Play Console Data Safety submission need
access only repo owner can take. **This is not the "signed build a stranger can install" exit
criterion** — it is real, verified progress with an honestly-scoped remainder.

---

## M14 — Live Operations

**Goal:** the world keeps growing without rewrites.

**Shipped:** Chapters 6–10 per `docs/13_CAMPAIGN_LEVELS_1-5.md`; Region 4 (Ancient Ocean) and
Region 5 (Ghost Reaches), each with one island; Seasonal repeatable events (Spring Crossing) via
`SeasonalEventData`/`SeasonalEventManager` (permanent-completion-only, distinct from
`ChapterData`); Ghost Fleet real mechanical presence in Region 5 (ambient hulls + region-gated
boss, alongside pre-existing rare global ambient); `docs/CONTENT_AUTHORING_GUIDE.md` (validated
by authoring Ch6–10 against it); What's New panel (one-time auto-show); `LiveOpsConfig` wrapper.

**Notable achievement:** Chapter 6 required zero script changes — the literal proof case for "a
content update ships without a code change."

**Verification:** 419 → 464 tests / 464 passing (baseline re-verified fresh at milestone start
rather than trusted from prior stale figures — see `docs/05_CURRENT_SYSTEMS.md`'s note on this).
Remote-config unit testing comprehensive (fake cache, all paths); real Supabase end-to-end and
Regions 4/5 headful visual review flagged, not claimed (environment limitations).

---

## M15 — Backend & Cloud Services

**Goal:** an optional account lets a player carry their empire across devices, without the game
ever requiring one.

**Shipped:** Supabase Auth (email/password + optional Google Sign-In deferred) via direct REST
calls, no third-party SDK; account creation/sign-in **optional and opt-in, permanently** — game
stays fully playable offline forever per AGENTS.md; `player_saves` Postgres table with Row Level
Security scoping every row to owning account; cloud sync extending SaveManager's existing path
with explicit keep-local/keep-cloud conflict prompt (never silent overwrite); **password reset**
(browser-only fallback if Android deep-link machinery is deferred); **account deletion** via
Supabase Edge Function (service_role key server-side only); **terms-of-service acceptance** +
precise data-collection enumeration becoming M13's privacy policy source; **Supabase auth hardening**
(leaked-password protection, dashboard toggle); **minimal remote-config table** consumed by M14's
live-ops scheduling and kill-switch.

**Notable achievement:** Two real signed-in test accounts verified RLS cross-account isolation;
real end-to-end account-deletion test confirmed row deletion via direct SQL. `service_role` key
appears nowhere except Supabase's own Edge Function secrets store — never in repo, client, or
any commit.

**Verification:** 417 tests / 417 passing (up from M13's 411/411 baseline). Full technical detail
in `docs/05_CURRENT_SYSTEMS.md`'s "M15 — Backend & Cloud Services" section. **Google Sign-In
explicitly deferred, not shipped** — Godot 4.3 has no native Android deep-link API and M13
hasn't produced a working export to build a plugin against; logged as documented follow-up per
Requirement 2.4.

---

## M15.5 — UI Visual Modernization

**An unplanned insertion, not a renumbering.** Same role the M7.5 stabilization pass played:
work surfacing after M15 closed and needing doing before the next planned milestone.

**Goal:** the existing theme renders with contemporary mobile-game production values — gradient
buttons, soft-shadowed rounded panels, icon-led readouts — without touching what any screen
actually shows or how it behaves.

**Shipped:** Two sourced CC0 asset packs (Kenney UI Pack + Board Game Icons) into `assets/ui_icons/`;
`PirateThemeBuilder`'s Button styles rebuilt as `StyleBoxTexture` (real gradient/gloss art);
panels/bars enhanced `StyleBoxFlat` (bigger radius, real shadow, anti-aliasing); WorldHUD resource
counters became icon chips with fill animation and low-health pulse; reusable `ButtonJuice.gd`
press/hover animation swept onto every screen via single recursive `apply_button_juice()` call;
every menu screen's duplicated panel-background style centralized (except distinct colors like
death/raid red, which were enhanced instead of deleted).

**Notable achievement:** Independent checkpoint review caught two real defects mid-milestone (a
missed Starboard-side icon conversion; a missing disabled-state Button style) that self-report
alone had not.

**Verification:** 434 tests / 434 passing. Full technical detail in
`docs/05_CURRENT_SYSTEMS.md`'s "M15.5" section. Only MainMenu and PauseMenu confirmed via live
headful screenshot; further screens' correctness rests on code-level verification (simulated
keyboard navigation proved unreliable in multi-window desktop environment).

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
| M9 | 391 / 391 |
| M10 | 326 / 326 |
| M11 | 391 / 391 |
| M12 | 396 / 396 |
| M13 | 411 / 411 |
| M14 | 464 / 464 |
| M15 | 417 / 417 |
| M15.5 | 434 / 434 |

Note: `test_property_21_lod_distance_transitions` failed consistently through M8 and is an
accepted, tracked gap (no ocean LOD system existed until M10). M10's implementation of ocean LOD
closed this standing failure — the project achieved its first 0-known-failures result at M10.

---

# Appendix — resolved visual/physics bug ledger

> Folded in from `docs/09_VISUAL_BUG_TRACKER.md` during the 2026-09-20 docs consolidation pass.
> That file remains the **active** tracker (open items, methodology, how to run the capture
> harness); this appendix is the closed history, kept here because this is the doc for "what
> happened," not "what's outstanding." Each entry was characterised from an actual rendered frame
> before any code was changed, then re-captured afterwards to validate — see "Wrong turns" at the
> end of this appendix for the diagnoses that measurement disproved.

## V1 — Ships capsize and tumble `[~]`

**Symptom (user):** ship is not floating on water correctly, turning around and around.

This had **four** independent causes stacked on top of each other. Each fix was real but only
partial, which is why the bug kept surviving a "fix".

**1. Sign-inverted restoring torque** (`BuoyancySimulator.gd`). The old expression
`right * up.dot(forward) - forward * up.dot(right)` has a negative dot product with the true
restoring torque `body_up × world_up` for a tilt in any direction. "Stability" actively drove the
hull away from upright. Fixed to `up.cross(Vector3.UP)`.

**2. Inverted pendulum — the big one** (`PlayerShip/EnemyShip/BossShip.tscn`). No ship declared
`center_of_mass`, so Godot computed it at the collision shape's centre, `y = +1.0`. Every float
point sits at `y = 0.0`. Buoyancy therefore pushed up from a metre *below* the centre of mass, so
any small tilt generated **more** tilting torque — textbook inverted pendulum. No amount of
restoring torque can beat that. Fixed by ballasting `center_of_mass` below the float points, which
is what makes a real hull self-righting.

**3. Steering clobbered self-righting** (`ShipMovement.gd`). The turn servo did
`body.angular_velocity.y = lerp(...)`, overwriting the whole world-Y component every frame —
precisely the component the restoring torque needs to accumulate to right a heeled hull. Ships
that steer continuously (i.e. every AI enemy) had their self-righting cancelled on every physics
tick, while the player ship, steered only on input, recovered. This is why it read as "*other*
ships spinning around". Fixed by servoing only the yaw component and preserving roll/pitch.

**4. `sin(tilt)` gain falls away past 90°** (`BuoyancySimulator.gd`). `up.cross(Vector3.UP)` has
magnitude `sin(tilt)`, which peaks at 90° and then *decreases*. At 175° the gain is 0.087 —
essentially zero. So a hull knocked past horizontal got weaker correction the further it went and
stayed capsized forever. Added a backstop past 60° using a `1 - cos(tilt)` gain, which is 1.996 at
175°. Verified numerically.

Also fixed on the way: `EnemySpawner` set `enemy.global_rotation.y = randf()` *after* `add_child`.
Assigning one Euler component to a RigidBody3D decomposes and recomposes the whole basis, folding
any existing roll/pitch back in instead of clearing it. Replaced with a single explicit
`Transform3D(Basis(UP, yaw), pos)` assignment plus a velocity reset. `BossShip` was also missing
`can_sleep = false`, so a settled boss would stop receiving buoyancy entirely.

**Validation:** all ships upright and level through t=12s, both player ship and open-water enemies.

**Remaining:** ships that sail into island terrain still end up beached and tipped. That is AI
navigation (no obstacle avoidance), not buoyancy — tracked separately as V8 (still open, see the
active tracker).

## V2 — Camera clips inside the hull `[~]`

**Found by screenshot, not reported.** By t=12s the camera ended up *inside* the player ship's
hull, frame filled with backfaces.

**Root cause:** `CameraRig.tscn`'s `SpringArm3D` had `collision_mask = 3` — layers 1 (player ship)
**and** 2 (enemy ships). The rig rides at the target's origin (`EYE_HEIGHT = 0.0`), so the arm's
1.5-radius sphere starts *inside* the followed ship's own collision shape, collides immediately,
and collapses the arm to ~0.

The mask was 3 because someone wanted the camera to avoid islands — but `Island.tscn`'s
`StaticBody3D` declared no `collision_layer` at all and so defaulted to layer 1, indistinguishable
from the player ship.

**Fix:** islands moved to `collision_layer = 17` (layer 1 so ships still collide with them, plus
layer 5 "terrain"); spring arm masks layer 5 only. Plus
`CameraRig._exclude_target_from_spring_arm()` excludes the followed body by RID, so the fix
survives a ship changing layers later.

**Validation:** camera outside the hull, full ocean view at t=12s. Collision matrix re-checked:
ships still collide with islands, camera collides with terrain only.

## V3 — Island / ship colours `[x, not a bug]`

**Ruled out by screenshot.** Islands and ships render with correct, consistent Kenney palette
colours — sand, green palms, wood hulls, white sails. There is no random-colour problem in the
current build. The earlier "completely random colours" report appears to have been the frame-2
capture, seen against an empty sky before the ocean is in view — alarming, but a camera timing
artefact, not a colour bug. Also ruled out: `KHR_texture_transform` on the Kenney models is
identity and the raw mesh UVs already address the correct atlas swatch — texture sampling was
never broken.

## V4 — Sky is a permanent sunset `[~]`

**Confirmed by screenshot**, but the cause was **not** what source-reading suggested. The initial
diagnosis — "`EnvironmentController` overwrites the sky every frame, and `sky_horizon_noon` is
orange" — was only half right; correcting those colours alone left the horizon just as orange.

**The actual dominant cause was fog.** `World.tscn` authored `fog_light_color = Color(0.9, 0.72,
0.52)` — a warm sunset orange — and nothing ever updated it, so it tinted the entire distance at
every time of day regardless of what the sky did. `ground_horizon_color` had the same problem.

**Fix:** `sky_horizon_noon` → pale daylight blue; `sky_horizon_morning` → soft warm grey (was
peach). All sky/ambient keyframes pinned explicitly in `EnvironmentSettings.tres`, so the resource
is the single source of truth. `EnvironmentController` now also drives `ground_horizon_color` and
`fog_light_color` from the same computed horizon colour, so the three can no longer disagree.

**Decision recorded:** `EnvironmentController` + `EnvironmentSettings.tres` win. `World.tscn`'s
authored sky values are only the frame-0 seed.

## V5 — `Parameter "material" is null` at startup (×4) `[x]` RESOLVED (M9, real root cause traced)

Four of these were emitted during startup from the renderer. **Previously recorded as resolved as
a side effect of V2** — believed to be the camera spring arm's shape cast querying ship hull
geometry.

**Reopened 2026-08-26,** then **resolved for real in M9.** The V2/camera fix was confirmed still
correctly in place and was never the actual explanation. Traced via ~15 fast headful
reproductions, disabling/removing whole subsystems one at a time from a live scene — the 4 errors
persisted through every removal except `Ocean` + `PlayerShip`, and even that pairing only
reproduced when loaded through the real `World.tscn`. **Actual cause:** `World.gd` calls
`SaveManager.call_deferred("load_game")`; when a save exists, `load_game()` reassigns
`player.ship_stats` to the saved active ship, re-triggering `ShipVisuals._rebuild_model()` a second
time — freeing and rebuilding the hull model on a frame after its first, correctly-materialed build
has already been submitted for that frame's render. The renderer's dirty-material sync catches the
old/new model mid-swap during that one transition. **Confirmed harmless:** every captured frame
shows the ship correctly modeled; no test failure, no visible glitch. Documented rather than fixed
— restructuring the rebuild timing for a one-time cosmetic log line is disproportionate. Full
detail: `docs/05_CURRENT_SYSTEMS.md` D32.

The earlier guard added in `KenneyMaterialApplier` against assigning a null override was already
measured as **not** what fixed this the first time (count unchanged at 4 with the guard alone) —
now fully explained: the null material was never inside `KenneyMaterialApplier` at all. Left in
place as defensive-only, with a comment saying so.

## V6 — `ManOWar.tres` exceeds its authored export range `[x]`

`resources/ships/ManOWar.tres` set `stability_torque_multiplier = 25.0` against
`@export_range(0.0, 20.0)`. The authored ships form a deliberate ladder scaling with hull size
(Dinghy 8 → Sloop/Schooner 10 → Corvette 11 → Brigantine 12 → Frigate 15 → Galleon 20 → ManOWar
25), so 25 is intentional design and the **range** was what was wrong. Widened to `0.0, 30.0`.
Out-of-range values load fine at runtime, so this was never silently dropped — but the inspector
would have snapped it to 20 the first time anyone opened ManOWar in the editor.

## V9 — HUD layout defects `[x]` RESOLVED (M9)

Both found by screenshot, neither reported.

**Overlapping top-right text.** `_create_notoriety_label()` used `PRESET_TOP_RIGHT` plus a manual
`position.x -= 300` nudge, which anchored only the label's *left* edge to the screen edge — so the
text both ran off the right of the screen and printed on top of the resource bar. Replaced with a
right-aligned, explicitly-offset rect that grows leftwards, positioned below the bar.

**Reopened 2026-08-26,** then **resolved for real in M9.** The hardcoded-offset fix above never
reliably cleared `ResourceBar`. Replaced with a `TopRightPanel` `VBoxContainer` (`WorldHUD.tscn`)
holding `ResourceBar`, the notoriety label, the Captain's Log button, and the World Map button as
siblings — Godot's own container layout, not a second hand-typed constant, now guarantees none of
them can overlap regardless of `ResourceBar`'s actual rendered height. A first version of this fix
cleared the original overlap but introduced a *new* one (notoriety label vs. the Log button, still
on its own independent hardcoded offset) — caught by a follow-up fresh capture, not by the new GUT
test alone (`tests/test_world_hud_layout.gd` originally only checked the one pair the bug report
named). Fixed by moving the Log button into the same container; the test now checks all three
pairwise. Full detail: `docs/05_CURRENT_SYSTEMS.md` D36.

**Announcement banner ran off screen.** `announce_event()` used `PRESET_CENTER`, which anchors a
zero-width rect at the centre, so a 42px message grew rightwards off the frame. Replaced with a
full-width wrapping rect. Its tween also faded `modulate:a` from 1.0 *to* 1.0 (a no-op "fade in");
it now starts transparent and actually fades. **Still true today, no regression** — but see V13:
at full width and no panel it renders as a giant unframed red wall of text over the 3D world.
Fixing "off-screen" wasn't the same as fixing "looks designed."

## V10 — Missing `icon.svg` `[x]`

`project.godot` set `config/icon="res://icon.svg"` but the file did not exist, so every launch
logged `ERROR: Error opening file 'res://icon.svg'`. Added a project icon rather than removing the
setting, since an exported build needs one.

## V11 — Double-click launcher never worked `[x]`

`Play Pirate Empire.cmd` was added earlier in the session but **never actually verified to
launch** — it was assumed working. It had two separate defects, and it failed silently on both:

**1. Unix line endings.** The file was written with LF only. `cmd.exe` cannot parse an LF-only
batch file — it eats the first character of every line, so `setlocal` ran as `etlocal`, `REM` as
`M`, and so on. Fixed by rewriting as CRLF, and a `.gitattributes` now pins `*.cmd`/`*.bat` to
`eol=crlf` so a future checkout cannot silently reintroduce it.

**2. Trailing backslash swallowed the closing quote.** `%~dp0` always ends in `\`, so
`--path "%PROJECT%"` expanded to `"D:\Pirate-game\"` — the `\"` escapes the quote and Godot
reported `Invalid project path specified: "D:\Pirate-game""`. Fixed by stripping the trailing
backslash before use.

**Validation:** launcher run from its double-click path starts the engine cleanly, gameplay
running, no errors.

## V12 — Ship spawns black on load, no error anywhere `[~]`

**Found by screenshot, not reported.** A fresh headful run (M7.5 stabilization pass, 2026-08-25)
rendered correctly at t=0/1/3s, then the entire 3D viewport went solid black from ~t=4s onward and
stayed black through t=12s — while the HUD kept updating normally the whole time, proving the game
logic was still running fine underneath.

**Wrong theories, disproved by measurement, in order tried:** (1) day/night cycle running too
fast — disproved, the sun was getting *brighter*, not dimmer; (2) camera lost its active flag or
WorldEnvironment broke — disproved, both stayed valid/unchanged every frame; (3) an ambient
encounter or upgrade screen paused the game — disproved, `EncounterManager.is_active()` stayed
false and the HUD kept advancing.

**Actual root cause:** printing the camera's own `global_position` showed it collapsing toward the
tracked ship's height and staying there — the `SpringArm3D` had collided with something close and
stayed collapsed. Printing the *ship's* `global_position` showed it sitting at almost exactly
`(0, -2.49, 0)` — the game's authored spawn is `(0, 0.3, 40)`. A stale `user://save_data.json`
(left over from a prior session's verification run, with `"player": {}` — no position ever
recorded) explained it: `SaveManager.load_game()` defaulted a missing position to
`Vector3(0, 1, 0)`, which is Port Royal's own island origin now that M7 made it the home island.
The ship loaded embedded in the island's terrain; the camera's spring arm (collision mask includes
terrain, V2) collapsed into that same terrain from point-blank range.

**Fix:** `SaveManager.gd` — `save_game()` no longer writes a `"player"` key at all when no
`player_ship` exists to read from; `load_game()` only restores position/rotation when the save
actually recorded `pos_x`. Full detail: `docs/05_CURRENT_SYSTEMS.md` D64,
`.kiro/specs/milestone-m7.5-stabilization/`.

## V13 — "While you were away" banner has no frame `[x]` RESOLVED (M9)

**Found by screenshot, 2026-08-26.** `announce_event()`'s label renders as large, raw red text
with no background panel, no border, no styling consistent with the rest of the HUD — it cuts
directly across the 3D world and the island geometry behind it. V9 fixed the banner running
off-screen; it never addressed how it actually looks once on-screen. **Resolved (M9):**
`announce_event()` now wraps its label in a themed `PanelContainer` (dark-navy `StyleBoxFlat`, gold
border, matching `PauseMenu`/`DeathScreen`), with a new `is_warning` parameter defaulting the color
to gold/cream — the original alarm-red is now opt-in for genuine warnings only. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D68.

## V14 — Tutorial dialogue and the combat HUD render stacked, uncoordinated `[x]` RESOLVED (M9)

**Found by screenshot, 2026-08-26.** The Higgins tutorial dialogue box sits directly on top of the
"STARBOARD CANNONS / RELOADING 48%" combat panel, visibly bleeding through underneath it, while
actual cannonfire is happening in the background. Nothing in `WorldHUD.gd` arbitrated which of
tutorial dialogue / combat HUD / ambient-encounter feedback should have visual priority.
**Resolved (M9):** `WorldHUD.gd` dims `CannonsContainer` (`modulate.a = 0.35`) while
`TutorialDialogue` is visible, via its `visibility_changed` signal. `EncounterManager` now checks a
new `TutorialDialogue.is_blocking()` gate and returns early while a tutorial dialogue is open. Full
detail: `docs/05_CURRENT_SYSTEMS.md` D69.

## V15 — Settings and Credits screens are unthemed `[x]` RESOLVED (M9)

**Found by source read, confirmed by grep, 2026-08-26.** Every other screen in `scenes/ui/` called
`PirateThemeBuilder.build()`; `SettingsMenu.gd` and `CreditsScreen.gd` did not, rendering as raw
default-grey Godot UI. **Resolved (M9):** both scripts now apply
`root_control.theme = PirateThemeBuilder.build()` in `_ready()`, and both `.tscn`s gained a
`ColorRect(0,0,0,0.7)` background overlay. No functionality regressions. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D70.

## V16 — MainMenu has no typographic hierarchy `[x]` RESOLVED (M9)

**Found by source read, 2026-08-26.** `TitleLabel`/`SubtitleLabel` had no font-size overrides,
rendering at tooltip size for the game's own title. Separately, of five main-menu buttons, two
carried an emoji prefix and mismatched sizing the other three didn't. **Resolved (M9):**
`TitleLabel` → 56px, `SubtitleLabel` → 20px; all five buttons now share the same 28px override with
emoji prefixes stripped; a dead, fully-transparent `VignetteOverlay` decoration was deleted. Full
detail: `docs/05_CURRENT_SYSTEMS.md` D71.

## V17 — IslandMenu's main panel is a fixed 600×400px box `[x]` RESOLVED (M9)

**Found by source read, 2026-08-26.** `IslandMenu.tscn`'s `Panel` node set
`custom_minimum_size = Vector2(600, 400)` — a hardcoded pixel size, not responsive anchoring, on a
mobile-first project's single most-used management screen. **Resolved (M9):** removed the
`CenterContainer` wrapper (which ignored its child's anchors, silently defeating any anchor-based
fix) and reparented `Panel` directly under the root `Control`, with responsive anchors and a
`Vector2(480, 320)` minimum-size floor for narrow viewports. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D72.

## Wrong turns (kept deliberately, so they are not repeated)

1. **"The stability torque axes are swapped."** Wrong — only the sign was inverted. Caught by
   deriving the torque numerically.
2. **"The shader ignores `uv1_scale`/`uv1_offset`."** Wrong — `KHR_texture_transform` was identity
   and the UVs were already correct. Caught by parsing the GLB binary.
3. **"The null material comes from `KenneyMaterialApplier` assigning null."** Wrong — guarding it
   left the error count unchanged at 4; it was actually the camera spring arm (V2), and even that
   explanation later turned out wrong too (see #8).
4. **"The permanent sunset is the sky colours."** Half right, and the half that was wrong was the
   half that mattered — the real cause was an un-animated orange `fog_light_color`. Caught by
   re-capturing instead of trusting the edit.
5. **"The launcher works."** It never did — written and reported as done without once being run
   (V11). Caught only by actually executing it and reading the output.
6. **"The world went black because of the day/night cycle / camera state / an encounter
   starting."** All three (V12) were disproved by printing the actual values instead of reasoning
   about what a plausible cause would look like. The real cause only surfaced once the *ship's and
   camera's own position* were printed, not just whether the systems around them looked healthy.
7. **"V5 and V9 are fixed."** Both were marked resolved on the strength of one validating capture
   each, then reproduced cleanly nine days later with no intervening code change — meaning the
   original "fix" probably never fully held. One passing screenshot is not the same claim as
   "always passes." Re-verify on every subsequent capture run that touches anything nearby.
8. **Wrong turn #3 above, itself wrong.** "It was actually the camera spring arm" was believed
   correct for months. M9's re-diagnosis of the reopened V5 removed `CameraRig` entirely from a
   live `World.tscn` load — the 4 errors persisted unchanged. The real cause, found only by
   systematically removing whole subsystems one at a time until the error disappeared: a
   save-triggered second `ShipVisuals._rebuild_model()` call racing the renderer's first-frame sync
   (`docs/05_CURRENT_SYSTEMS.md` D32). A "fix" that correlates with a symptom going away is not the
   same claim as "explains why it happened."
9. **"The resource-bar/notoriety-label fix is done" (M9, first pass).** Verified by a new GUT
   property test and looked correct in isolation — but a follow-up headful capture showed the
   notoriety label now overlapping the Captain's Log button instead, because the Log button still
   used an independently hardcoded offset. The GUT test only asserted the pair the original bug
   report named. Caught by re-capturing after the fix, not by trusting the passing test.

The pattern in all nine: a plausible story that a two-minute measurement disproved. **Measure
first, and re-measure after the fix.**

A note on how V11 stayed hidden: two earlier attempts to verify it used `Start-Process` and
concluded "FAILED — no Godot process", a false negative from process timing. Only running the
command synchronously and reading its **stdout** revealed the actual errors. When a check reports
failure, confirm the check itself works before trusting or dismissing the result.

Also worth recording: V1 had **four** independent causes. Each fix was correct and each one alone
left the bug fully visible. A symptom that survives a verified-correct fix is evidence of an
additional cause, not of a wrong fix.
