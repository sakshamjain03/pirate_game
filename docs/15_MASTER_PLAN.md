# 15_MASTER_PLAN.md

> Version: 2.0
> Status: Living Document — forward-looking plan post-M15.5
> Owner: Project Lead
>
> **Executed milestone history lives in `docs/16_MILESTONE_HISTORY.md`** — a condensed record of
> every completed milestone (M1–M15.5) with shipped features, notable defects, and verification
> baselines. This document contains the future roadmap (M16 onward), the gap register, and
> planning material.
>
> Reads on top of: `AGENTS.md` (constitution) → `docs/05_CURRENT_SYSTEMS.md` (what runs, what's
> missing, system status, content volume) → this document (the order to build what remains).

---

# 1. Project Status (as of 2026-08-29 — post-M15.5)

**Completion baseline:** 434 tests, 434 passing. Chapters 1–5 complete with all five bosses
reachable in-world; 6+ islands across 5 regions (Beginner, Contested, Imperial Waters, Ancient
Ocean, Ghost Reaches); 20 captains with identity; 8 ships with correct cost ladder; 6 factions;
3+ building chains at 5 levels each; auto-fire combat with captain abilities and in-battle
upgrades; wind/sail/armor mechanics; world map with discovery/fog; remote config and optional
cloud saves; contemporary UI theme; analytics, crash reporting, save versioning, and offline
notifications.

**What comes next:** Chapters 6–10 (M14 complete), Cosmetics (M16), Freemium Launch (M17),
Retention (M18), Accessibility (M19), iOS (M20), Performance & Debt (M21). See `docs/16_MILESTONE_HISTORY.md`
for the complete record of what shipped through M15.5 and its per-milestone breakdown.

---

# 2. Thesis

> A player should be able to open this game, understand within 60 seconds what they are building
> and who objects, and still be finding out what is past the fog eight hours later.

Everything sequenced below serves that sentence. Anything that does not is deferred.

---

# 3. Forward-Looking Roadmap — M16 through M21

**All milestones M7–M15.5 are complete.** See `docs/16_MILESTONE_HISTORY.md` for the full
record. What follows is the forward plan to v1 completion and beyond.

> **Constitutional context:** Until 2026-08-27 `AGENTS.md` read "Never introduce paid features"
> and "Never introduce new currencies", which directly contradicted `docs/00_VISION.md` §19's
> monetization philosophy. Those rules are now scoped: **no paid feature ships before the M13
> launch build** (already happened), and monetization afterwards is bounded by `docs/00_VISION.md`
> §19.1 and `docs/17_MONETIZATION.md`. The §19 never-list — pay-to-win, energy systems, forced
> ads, artificial waiting — remains absolute and unamendable.

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
| **Checkpoints keep being accepted on self-reports** | Compounding invisible breakage — already produced D15, D42, D57, and two tasks ticked with zero file changes | **High** — it happened again at M6 Task 29 | Every checkpoint runs the GUT suite and pastes real totals; the binary path is documented in `CLAUDE.md` |
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

# 7. Immediate next actions (M16 onward)

All milestones M1–M15.5 are complete. Next immediate actions:

1. **M13 Export Gap:** The Android export is blocked by a consistent engine error. Requires either
   a Godot version audit (engine 4.3 vs. local 4.7.1 mismatch) or permission to test on a real
   device. Does not block M16–M18 planning/design work.

2. **Scaffold `.kiro/specs/milestone-m16-cosmetics-entitlements/`** per the `spec-new` skill and
   the `milestone-m7.5-stabilization/` structural reference (the only spec kept on disk). Cosmetics
   ship free first, proving the entitlement system before billing touches it.

3. **Work each wave directly** in Claude Code, one task at a time, per
   `docs/07_AI_AGENT_WORKFLOW.md`'s rules — strictly sequential milestones, independent checkpoint
   review before advancing to the next task wave.

---

# 8. Document map

| Doc | Answers |
|---|---|
| `AGENTS.md` | What are the rules? (constitution — wins every conflict) |
| `docs/00_VISION.md` | What are we making and why? |
| `docs/01_ARCHITECTURE.md` | How is it structured, and what's it built with? |
| `docs/03_ART_DIRECTION.md` | What does it look like? |
| `docs/04_GAME_LOOP.md` | What does the player do, minute to minute? |
| `docs/05_CURRENT_SYSTEMS.md` | **What actually runs today, and what's broken?** |
| `docs/06_NARRATIVE_AND_WORLD.md` | What is the story, who is in it, and how is it data? |
| `docs/navalCombat.md` | What does a single fight feel like, and how does it change (M8)? |
| `docs/07_AI_AGENT_WORKFLOW.md` | How does implementation actually happen, and how is it verified? |
| `docs/09_VISUAL_BUG_TRACKER.md` | What did the screenshots reveal? |
| `docs/10_ASSET_REQUESTS.md` | What art do we need? |
| `docs/11_WORLD_MAP.md` | Where is everything, and why there? |
| `docs/13_CAMPAIGN_LEVELS_1-5.md` | What happens in the first five chapters? |
| `docs/05_CURRENT_SYSTEMS.md` | **Ground truth: what exists, its status, content volume targets.** |
| `docs/15_MASTER_PLAN.md` | What are the plans post-v1? |
| `docs/16_MILESTONE_HISTORY.md` | What happened in each completed milestone (M1–M15.5)? |
| `docs/17_MONETIZATION.md` | **What is sold, what is never sold, and how ownership works.** |
| `docs/18_ACCESSIBILITY.md` | Who can play it, and the checklist every screen must pass. |
| `docs/19_RETENTION_AND_LIVEOPS.md` | Why does a player come back tomorrow, without dark patterns? |
| `docs/20_PLATFORM_MATRIX.md` | Which platforms, which engine version, which store obligations? |

(`08` is intentionally absent and always has been.)
