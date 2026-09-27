# Requirements Document

## Introduction

**Status: COMPLETE (2026-09-28).** Commits `6c8c820` and `a137563`.

The project's identity was ambiguous between a premium PC game and a mobile one. It is now locked:
**Pirate Empire is a freemium mobile game shipping as a five-chapter, five-island MVP.**

That decision cannot be implemented as written, because the repo forbids it. `AGENTS.md` says
*"Never introduce a hard or premium currency"*; `docs/00_VISION.md` §19 calls its never-list
(pay-to-win, energy, forced ads, artificial waiting) *"absolute and unamendable"*;
`docs/17_MONETIZATION.md:26` says *"There is no timer whose removal is for sale."* The PR checklist
mechanically rejects the entire roadmap. So the first requirement of this milestone is to **amend
the constitution deliberately and on the record**, rather than let later milestones quietly violate
documents nobody re-read.

The second problem is the opposite of the usual one: the repo carries **more** content than the MVP
ships — 9 chapters, 11 islands, 5 regions, 20 captains. Scope has to be cut, not added, and cut in
a way that preserves authored work for the day each level launches.

The third is tooling. Later milestones add multi-day timers and island sieges, which are close to
untestable by hand. A developer cheat console is needed — and it must be **impossible** for it to
reach a player's build.

**Already met, no work needed:** `ResourceLookup` already exists as the shared "find a resource by
id" helper, so the content gate extends it rather than adding a parallel system.
`scenes/debug/CaptureHarness.tscn` already establishes the "debug scene instances the real World"
pattern, so the dev console reuses it instead of inventing an entry point.

## Glossary

- **Pieces of Eight** (UI: *Eights*) — the single premium currency. Deliberately silver so it never
  reads as the existing `gold` gameplay resource.
- **Content gate** — `content_enabled: bool` on a data resource, read through
  `ResourceLookup.is_content_enabled()`. False = authored, preserved, not shipped.
- **Tracked tech debt** — gated content scheduled to be built out properly, one island per level.
- **Shipping / deferred** — inside vs outside the five-chapter, five-island MVP.
- **Dev-tools one-way dependency** — debug code may call shipping code; shipping code may never
  reference debug code.

## Requirements

### Requirement 1: The constitution permits the chosen business model

**User Story:** As the project owner, I want the engineering rules to match the business model I
chose, so that work is not blocked by documents that contradict it.

#### Acceptance Criteria

1. `AGENTS.md`, `docs/00_VISION.md` §19 and `docs/17_MONETIZATION.md` SHALL be rewritten to permit
   one premium currency and skippable timers, and SHALL state plainly that they supersede the
   previous cosmetics-only model and the date of the change.
2. THE replacement rules SHALL be narrower and testable, not merely permissive. Specifically they
   SHALL still forbid: a second premium currency; Eights granted by production or the economy tick;
   any energy/stamina/fuel meter or any gate on sailing, combat or boarding; a timer with no
   gameplay path to shortening it; skip pricing off total rather than remaining duration; campaign
   content behind money or an ad; forced or unskippable advertisements; and randomized purchases
   without disclosed odds.
3. "Chapters 1-5 completable with zero spend" SHALL be recorded as a **release gate**, not a goal.
4. `AGENTS.md`'s PR checklist SHALL carry a rewritten monetization gate matching 1.2, plus a
   dev-tools gate enforcing Requirement 3.
5. The three documents SHALL NOT contradict each other after the change.

### Requirement 2: MVP scope is cut to five chapters and five islands

**User Story:** As a developer, I want out-of-scope content unreachable but preserved, so that the
MVP can be tuned against what ships and each deferred island can be built properly later.

#### Acceptance Criteria

1. `ChapterData`, `CaptainData`, `RegionData` and `IslandData` SHALL each gain
   `content_enabled: bool = true`. THE default SHALL be true so every existing `.tres` is
   unaffected until explicitly disabled.
2. ONE shared filter SHALL decide enablement for all four types, and SHALL return true for any
   resource lacking the field.
3. EVERY loader of those four types SHALL filter through it — chapters, regions, captains (tavern
   and codex), world map.
4. A gated island SHALL remove itself **before** joining the `islands` group, so docking, defender
   spawning, the economy tick and the world map never observe it.
5. `World.tscn` SHALL NOT be edited, so re-enabling an island is a single bool in its `.tres`.
6. Shipping content: chapters 1-5; regions Beginner/Contested/Imperial; islands Port Royal,
   Tortuga, Pelican Cay, Cartagena Outpost, Skull Cove; twelve captains.
7. NO shipping chapter SHALL depend on gated content — not via objective `target_id`, region or
   prior-chapter gate, or reward id. Boss encounters SHALL remain reachable.
8. A regression test SHALL fail whenever 2.7 is violated, and its failure message SHALL name the
   chapter, objective, target and whether the objective is mandatory.
9. Layout data for **deferred** islands SHALL remain under test, so it cannot rot while gated.

### Requirement 3: A dev console that cannot reach a shipping build

**User Story:** As a developer, I want to reach any game state instantly for testing, and I want it
to be structurally impossible for that tooling to cause a bug in the real game.

#### Acceptance Criteria

1. THE console SHALL call only public manager APIs and public fields. IF a cheat would require a
   new hook inside a manager, THEN that hook SHALL be an API the game itself uses, or the cheat
   SHALL NOT be built.
2. NO shipping script SHALL reference the debug folders, and NO gameplay file SHALL contain a
   dev-mode branch.
3. THE console SHALL be reachable only by explicitly launching a debug harness scene. It SHALL NOT
   be an autoload and SHALL NOT be referenced from `project.godot`.
4. THE console SHALL free itself when `OS.is_debug_build()` is false.
5. `export_presets.cfg` SHALL exclude `scripts/debug/*` and `scenes/debug/*`. BECAUSE that file is
   gitignored, this SHALL also be documented as a per-machine release-checklist step, and SHALL NOT
   be presented as a guarantee that survives a fresh clone.
6. A test SHALL enforce 3.2 and 3.3, and SHALL also assert the console script parses — nothing
   imports it, so the suite would otherwise never notice it breaking.
7. It SHALL support: resource fill/empty/max; notoriety set; chapter jump; unlock-all-techs; ship
   level and component level **up and down**; captain levels; grant-all hulls/captains; island
   capture/release/sail-to; heal; god mode; kill/cripple enemies.
8. A cheat SHALL NOT be able to produce a state the game itself cannot produce (e.g. a ship
   downgrade SHALL bring its components down with it).

## Out of scope

- `resources/balance/DifficultyCurve.tres`. Planned here, **deliberately not built**: it would have
  had no reader until combat consumes it, and `AGENTS.md` forbids dead code. Moves to M25.
- Any gameplay behaviour change. This milestone decides what ships and adds tooling.
