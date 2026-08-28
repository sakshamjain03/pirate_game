# Requirements Document

## Introduction

Milestone M12 (originally "M11 — Playtest & Instrumentation") is where this project finds out what
is actually wrong from someone who is not the two AI agents that have built and reviewed every
part of it so far. By the end of M11, the game has real content depth; M12 adds the ability to
measure whether any of it works — today there is no analytics, no crash reporting, one save file
with no backup or schema migration path (only a version *field*, added in M10), no localization
readiness, no playtest protocol, and no balance model beyond what M11 started. This milestone also
adds local push notifications for offline-completion events, new scope approved during the
2026-08-26 presentation audit specifically because nothing currently tells a returning player that
something meaningful happened while they were away — undercutting `docs/00_VISION.md`'s own
"something meaningful happened" daily-open goal.

Full context: `docs/15_MASTER_PLAN.md`'s M12 entry and §8, `docs/14_SYSTEM_INVENTORY.md` §5/§6.

---

## Requirements

### Requirement 1 — Analytics / funnel telemetry

**User Story:** As a maintainer, I want to know where players actually drop off, so tuning
decisions are based on data instead of guesses.

#### Acceptance Criteria

1. Key funnel events (new game started, each chapter started/completed, first colonize, first
   boss defeat, first raid survived/lost, session start/end) SHALL be logged to an analytics
   backend.
2. `docs/02_TECH_STACK.md` names Firebase as the intended analytics backend for "Alpha+" — this
   milestone SHALL either integrate it or document why a different/lighter approach was chosen
   instead (e.g. a simpler self-hosted or file-based funnel log, if a Firebase SDK integration
   proves disproportionate to this project's current scale).
3. No personally-identifying information SHALL be collected beyond what's needed for aggregate
   funnel analysis — consistent with `AGENTS.md`'s single-player, no-account-required v1 design.

### Requirement 2 — Crash reporting

**User Story:** As a maintainer, I want to know when and why the game crashes for a real player,
since I can't watch over their shoulder.

#### Acceptance Criteria

1. Unhandled errors/crashes in an exported build SHALL be captured and reported to a location the
   maintainer can review, without requiring the player to manually file a report.
2. This SHALL NOT block or degrade normal play — failure to report a crash SHALL never itself
   crash or hang the game.

### Requirement 3 — Save schema versioning, backup, and migration

**User Story:** As a player, I want a corrupted or outdated save to be recoverable, not a total
loss of progress.

#### Acceptance Criteria

1. Building on M10's `save_schema_version` field (Requirement 9 there), `SaveManager` SHALL
   implement real migration logic for at least one version transition, establishing the pattern
   future migrations follow.
2. `SaveManager` SHALL maintain at least one backup of the previous save file, so a corrupted
   write doesn't destroy the only copy of a player's progress.
3. A save file that fails to parse or load SHALL degrade gracefully (matching the existing
   `save_load_failed` signal precedent from M2 Task 12.3) rather than crashing, with the backup
   offered as a recovery path.

### Requirement 4 — Localization-ready strings

**User Story:** As a maintainer, I want every player-facing string extractable for translation, so
localization later doesn't require another full pass through every script.

#### Acceptance Criteria

1. Player-facing strings currently inline as GDScript literals (per
   `docs/14_SYSTEM_INVENTORY.md`'s "all strings are inline literals today" gap) SHALL move to
   Godot's translation system (`.csv`/`.po` + `tr()` calls) for at least the highest-traffic UI
   surfaces (MainMenu, WorldHUD, IslandMenu, SettingsMenu, CaptainsLog).
2. This milestone SHALL NOT require shipping a second language — only the extraction/
   infrastructure that makes adding one later a translation-only task, not a code change.
3. Dynamically-constructed strings (e.g. `"Notoriety: %.1f" % new_val`) SHALL use translation-safe
   formatting (`tr()` wrapping the template, not the interpolated result) so translated word order
   isn't broken by naive string interpolation.

### Requirement 5 — Playtest protocol

**User Story:** As a maintainer, I want a repeatable way to get real players in front of the game
and capture what they experienced, so "≥10 external players reached Chapter 3" (this milestone's
exit criterion) is achievable and measurable.

#### Acceptance Criteria

1. A documented playtest protocol SHALL exist (recruitment approach, session structure, what to
   observe/ask, how findings get logged) — checked into `docs/` following this project's
   established documentation conventions.
2. At least one real playtest round SHALL be conducted using this protocol before this milestone's
   checkpoint, with findings logged (even if the full ≥10-player target isn't reached within this
   milestone — see Non-Goals).

### Requirement 6 — Balance spreadsheet ownership

**User Story:** As a maintainer, I want every economy number in the game to trace to a documented
model, so D53-class pricing disasters can't recur silently.

#### Acceptance Criteria

1. M11's balance model artifact (Requirement 10 there) SHALL be extended to cover every
   remaining unmodelled economy number in the game — building costs, ship costs, captain hire
   costs, loot tables, raid theft fractions — not just the M11-introduced content.
2. The model SHALL be the artifact a future milestone's content authoring is required to check
   against before introducing new costs/rewards, analogous to how `docs/13_CAMPAIGN_LEVELS_1-5.md`
   §2's ship-cost ladder already functions.

### Requirement 7 — Codex / lore browser

**User Story:** As a player, I want a place to revisit the story/world details I've encountered, so
the narrative investment (20 captains, 7 named cast, 5 chapters) doesn't disappear once a dialogue
beat scrolls past.

#### Acceptance Criteria

1. A codex/lore screen SHALL let the player browse previously-encountered characters, factions,
   and completed-chapter summaries, reusing `CaptainsLog`'s existing completed-chapter display
   (`log_summary` per chapter) as its data source rather than duplicating that data.
2. Entries SHALL only appear once the player has actually encountered them (no spoiling unmet
   content) — consistent with the discovery-gating principle M10 established for the world map.

### Requirement 8 — Local push notifications

**User Story:** As a player, I want to know when something in my empire finished while I was away,
so I have a reason to come back besides remembering to check.

#### Acceptance Criteria

1. Local (device-scheduled, not server-push) notifications SHALL fire for: a raid being resolved
   against the player's home island, a building construction/upgrade completing, and a
   `FleetManager` trade/patrol mission returning — the same three event classes
   `docs/15_MASTER_PLAN.md` §8 named when this scope was approved.
2. Notifications SHALL be schedulable at the moment an event is set in motion (e.g. when a raid
   timer starts, when a building upgrade begins) with a payload computed from the same data
   `WorldHUD.announce_event()` already uses for the in-session equivalent — no duplicated event
   logic.
3. Notifications SHALL respect platform permission flow (Android notification permission) and
   SHALL degrade silently (no crash, no forced permission prompt loop) if permission is denied.
4. This SHALL NOT introduce any paid feature, energy system, or artificial waiting mechanic —
   `AGENTS.md`'s restrictions apply; notifications only ever inform about progress that was
   already going to happen on its own timer.

### Requirement 9 — Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an "M12 — Playtest & Instrumentation" section.
2. `docs/14_SYSTEM_INVENTORY.md`'s Meta/platform table SHALL have analytics, crash reporting,
   save backup/versioning, localization, and push notifications updated to ✅.
3. `docs/15_MASTER_PLAN.md`'s M12 exit-criteria results SHALL be filled in, including actual
   playtest numbers reached (even if short of the ≥10 target — report the real number).

---

## Non-Goals

- Reaching the full "≥10 external players have reached Chapter 3" bar within this milestone itself
  — Requirement 5 is about building the *capability* and running at least one real round; hitting
  the full target may reasonably extend past this milestone's own close, and SHALL be reported
  honestly either way, not asserted without evidence (per this project's own repeated lesson about
  self-reported checkpoints).
- Cloud saves — still explicitly 🚫 for v1 per `docs/14_SYSTEM_INVENTORY.md`.
- Shipping a second actual language — Requirement 4 is infrastructure only.
- Any monetization hook — `AGENTS.md` (amended 2026-08-27) forbids any paid feature before the
  M13 launch build, and M12 is before it; monetization is owned by M16/M17 (`docs/17_MONETIZATION.md`).
  Push notifications (Requirement 8) are
  explicitly scoped to never touch monetization.
- Android export/store readiness — M13 scope.
