# Requirements Document

## Introduction

Milestone M21 is the debt-zero milestone. It closes the standing defects nobody else owns, builds
the performance work that has been deferred with no home, and adds the save integrity that
becomes worth having once entitlements have money value.

A gap audit on 2026-08-27 found three things with no owning milestone:

1. **Spatial partitioning and culling** — marked "M11+" in `docs/14_SYSTEM_INVENTORY.md` and never
   specced into any milestone. "M11+" is not an owner.
2. **Save tamper-resistance** — irrelevant while the game was free and offline; worth a modest
   investment once M17 ships entitlements.
3. **Standing defects** — V5 (material nulls, reopened 2026-08-26), V8 (ships beach on islands,
   only partially addressed by D39), the undecided `CurrentHealth`-on-upgrade rescale question,
   and region mixed-role enemy compositions beyond `EliteHunters`.

This milestone exists so those do not remain permanently deferred. A project that never schedules
its debt accumulates it until a milestone collapses under it.

**Scope discipline.** M21 fixes what is already known to be broken and builds what is already
known to be missing. It is not an opportunity to add features, and it is not an open-ended
refactor. `AGENTS.md` forbids inventing architecture; this milestone in particular should resist
it, because "while we're in here" is how a debt milestone becomes a rewrite.

**What already exists.** M13 profiled device performance and named a reference low-end device.
M10 built the ocean LOD system that closed the last standing test failure (326/326). D39 partially
addressed ship beaching with avoidance work. `docs/05_CURRENT_SYSTEMS.md` documents every defect
id referenced here.

---

## Glossary

- **Reference device** — the low-end target in `docs/20_PLATFORM_MATRIX.md` §3. Performance is
  judged against it, never against a development desktop.
- **Tamper-resistance** — making casual save editing non-trivial. Explicitly **not** anti-cheat,
  and explicitly not server-authoritative (`docs/17_MONETIZATION.md` §4.4).
- **Standing defect** — a defect in `docs/05_CURRENT_SYSTEMS.md` or
  `docs/09_VISUAL_BUG_TRACKER.md` still marked open or reopened.

---

## Requirements

### Requirement 1: Spatial partitioning and culling

**User Story:** As a player on a mid-range phone, I want a steady frame rate as the world grows.

#### Acceptance Criteria

1. THE system SHALL implement spatial partitioning for world entities, so that per-frame work
   scales with what is near the player rather than with total world contents.
2. THE system SHALL cull entities outside the camera frustum and beyond a distance threshold.
3. Culling SHALL NOT change gameplay — a culled entity SHALL continue to simulate at whatever
   fidelity gameplay requires, or SHALL be demonstrably safe to suspend.
4. THE system SHALL sustain the frame target in `docs/20_PLATFORM_MATRIX.md` §3 on the reference
   device, measured with the M10 expanded map fully populated.
5. THE system SHALL integrate with the existing M10 ocean LOD rather than introducing a second
   distance-based system.
6. Performance SHALL be measured before and after, on the reference device, and both numbers
   recorded.

### Requirement 2: Save integrity

**User Story:** As a maintainer, I want casual save editing to be non-trivial, without pretending
to have anti-cheat.

#### Acceptance Criteria

1. THE system SHALL detect a modified save file.
2. WHEN a modified save is detected THE system SHALL warn the player and SHALL allow them to
   continue — it SHALL NOT delete, refuse, or silently reset their save.
3. Save integrity SHALL NOT require a network connection, an account, or a server.
4. THE system SHALL NOT claim or imply anti-cheat protection, in code comments, UI copy, or docs.
5. Entitlement data SHALL receive the same integrity treatment as save data.
6. Integrity checking SHALL NOT measurably slow save or load on the reference device.

### Requirement 3: V5 — material null errors

#### Acceptance Criteria

1. THE system SHALL identify the actual root cause of the four `Parameter "material" is null`
   errors at startup, reopened 2026-08-26.
2. THE fix SHALL address that root cause and SHALL NOT suppress the warning.
3. THE startup log SHALL be free of material-null errors afterwards.
4. A regression test SHALL assert the absence of the error condition.

### Requirement 4: V8 — ships beach on islands

#### Acceptance Criteria

1. AI-controlled ships SHALL avoid running aground on islands.
2. THE fix SHALL extend the existing D39 avoidance work rather than adding a second avoidance
   system.
3. A beached ship SHALL be able to recover rather than remaining permanently stuck.
4. A regression test SHALL assert that a ship steered toward an island does not beach.

### Requirement 5: `CurrentHealth` on upgrade — the undecided question

**User Story:** As a player upgrading a ship mid-voyage, I want a predictable result.

#### Acceptance Criteria

1. THE project SHALL **decide** whether `CurrentHealth` rescales when max health changes on
   upgrade — this has been an open design question in `docs/05_CURRENT_SYSTEMS.md` and closing it
   is the requirement.
2. THE decision SHALL be recorded in `docs/05_CURRENT_SYSTEMS.md` with its reasoning.
3. THE decision SHALL be implemented consistently across every path that changes max health —
   upgrades, modules, captain modifiers, and tech.
4. A test SHALL assert the chosen behaviour.
5. THE behaviour SHALL be legible to the player — a mid-battle upgrade SHALL NOT produce a
   surprising health change with no feedback.

### Requirement 6: Region mixed-role enemy compositions

#### Acceptance Criteria

1. THE system SHALL support mixed-role enemy compositions per region, beyond the existing
   `EliteHunters` case.
2. Compositions SHALL be authored as `Resource` data, requiring no script change to add.
3. Composition SHALL build on the existing per-region enemy work from M10 rather than replacing it.

### Requirement 7: No regressions, no scope creep

#### Acceptance Criteria

1. THE full GUT suite SHALL pass at or above the then-current baseline, with zero new failures.
2. THE milestone SHALL NOT add gameplay features.
3. THE milestone SHALL NOT refactor systems that are not implicated in a listed defect or
   requirement.

### Requirement 8: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M21 section and SHALL record the Requirement 5
   decision.
2. `docs/09_VISUAL_BUG_TRACKER.md` SHALL close V5 and V8, or SHALL state precisely what remains.
3. `docs/14_SYSTEM_INVENTORY.md` spatial partitioning and save integrity rows SHALL move off ❌.
4. `docs/17_MONETIZATION.md` §4.4 SHALL be reconciled with the integrity work actually shipped,
   preserving its explicit statement that this is not anti-cheat.

---

## Out of Scope

- **Anti-cheat.** Deliberately not built (`docs/17_MONETIZATION.md` §4.4). Requirement 2.4
  forbids even implying it.
- **Server-authoritative validation of anything.** It would break the offline-forever promise.
- **New gameplay features**, of any kind.
- **Refactoring for its own sake.** Requirement 7.3 exists specifically to stop this milestone
  becoming a rewrite.
- **An engine upgrade.** M20 owns that decision.
- **New content** — regions, chapters, ships, captains. M14 owns content.
- **Defects already closed.** This milestone addresses only what is still open.
- **Multiplayer, cloud gameplay, or any networked simulation.** Permanently out of scope.
