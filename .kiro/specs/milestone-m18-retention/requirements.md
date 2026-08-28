# Requirements Document

## Introduction

Milestone M18 builds the re-engagement layer — the reason a player opens the game on day two.

A gap audit on 2026-08-27 found this missing entirely: M12 *collects* funnel analytics and
nothing in M12–M17 *acts* on them. That is the gap that decides whether the M17 monetization
earns anything at all. A player who does not return on day two never converts, however good the
store page is. But the ordering in this project is deliberate: retention is built **after**
monetization, not before, so that it can never be designed backwards from a revenue number.

**The governing constraint** is `docs/19_RETENTION_AND_LIVEOPS.md`, and its rule 8 in particular:
**no retention mechanic may be a monetization surface.** Streaks, goals, and comeback bonuses
contain no purchase prompt, ever. The overlap between "come back tomorrow" and "buy this" is
where free-to-play games go bad, and this project keeps them apart on purpose.

**What already exists and needs no work here.** Offline income already accrues rather than
decaying (`SaveManager`'s offline catch-up, `MAX_OFFLINE_SECONDS`), which is the correct instinct
this milestone extends. `SaveManager.game_loaded` (D15) is the existing hook for return-detection.
`EventManager`, `CampaignManager`, `ResourceManager`'s economy tick, `ShipCombat.died`, and
`EmpireManager.notoriety_changed` are all existing signals that weekly goals resolve from —
goals must connect to them rather than add bookkeeping. M12 built the analytics pipeline and the
local-notification capability. M16 built `EntitlementManager`, which is how a streak grants a
cosmetic.

Full context: `docs/19_RETENTION_AND_LIVEOPS.md` is the design of record and **takes precedence
over this document** where they differ.

---

## Glossary

- **Streak tier** — the reward level reached by consecutive days played. A broken streak steps
  back exactly one tier; it never resets to zero.
- **Weekly goal** — one of three rotating objectives, authored as a `Resource` and resolved from
  signals that already exist. Expires quietly with no penalty.
- **Comeback** — the state of a player returning after 7 or more days away.
- **Quiet hours** — 21:00 to 09:00 local time, during which no notification may be delivered.
- **Loss framing** — any copy or mechanic that describes something as being taken away, expiring,
  decaying, or lost. Banned throughout (`docs/19_RETENTION_AND_LIVEOPS.md` rule 1).

---

## Requirements

### Requirement 1: The Captain's Log (login streak)

**User Story:** As a player, I want a reason to look in each day, without being punished when
life gets in the way.

#### Acceptance Criteria

1. THE system SHALL track consecutive days played and SHALL award at tiers 1, 2, 3, 5, 7, then
   every 7th day.
2. WHEN a day is missed THE streak SHALL step back exactly one tier and SHALL NOT reset to zero
   or below.
3. THE streak surface SHALL display what comes **next** and SHALL NOT display any countdown, timer,
   or expiry warning.
4. THE day-7 reward SHALL be a cosmetic, granted through `EntitlementManager.grant()`.
5. Streak rewards SHALL be small enough that skipping days does not make the game measurably
   harder — they are a reason to open the app, not a balance lever.
6. THE streak surface SHALL contain no purchase affordance, price, store link, or currency.
7. Streak state SHALL be account-scoped, not save-scoped, consistent with M16 §3.1.
8. THE system SHALL use local date boundaries, and SHALL NOT award a second tier for two sessions
   on the same local day.

### Requirement 2: The offline return, upgraded

**User Story:** As a returning player, I want to see what my empire did while I was gone.

#### Acceptance Criteria

1. THE offline-return panel SHALL report which buildings produced, which fleets returned, and
   which raids resolved — not only a resource total.
2. THE panel SHALL surface one clear next action.
3. THE panel SHALL be framed and themed per the M9 style, closing visual bug **V13**.
4. Nothing SHALL decay, degrade, or be lost as a function of time away — absence is neutral.
5. THE panel SHALL be readable at 200% text scale without clipping.
6. WHERE M17 has shipped THE offline rewarded-ad surface SHALL appear here, and SHALL be the only
   monetization affordance anywhere in this milestone's surfaces.

### Requirement 3: Weekly goals

**User Story:** As a player, I want a few things worth aiming at this week.

#### Acceptance Criteria

1. THE system SHALL present exactly 3 rotating goals per week.
2. Goals SHALL be authored as `Resource` files and SHALL resolve from signals that already exist.
3. WHEN a new goal type is added THE system SHALL require no script change.
4. Goals SHALL be completable in roughly two normal sessions.
5. WHEN a week rotates THE incomplete goals SHALL expire silently, with no penalty screen, no
   summary of failure, and no notification.
6. Goal rewards SHALL be resources plus progress toward a cosmetic.
7. THE goals surface SHALL contain no purchase affordance.

### Requirement 4: Comeback

**User Story:** As a player returning after weeks away, I want to be welcomed rather than
scolded.

#### Acceptance Criteria

1. WHERE a player returns after 7 or more days THE system SHALL grant a bounded resource catch-up.
2. THE system SHALL restore the streak tier to where it was rather than to zero.
3. THE system SHALL present one summary of what changed, and SHALL NOT repeat it on subsequent
   launches.
4. THE comeback surface SHALL contain no apology framing, no guilt, and no purchase affordance.

### Requirement 5: Notifications

#### Acceptance Criteria

1. THE system SHALL schedule at most **one** local notification per 24 hours.
2. THE system SHALL NOT deliver any notification between 21:00 and 09:00 local time.
3. Notifications SHALL be limited to: a player-initiated long action completing, a home-island
   raid imminent or resolved, and a weekly goal set rotating in.
4. THE system SHALL NOT send any notification about a sale, discount, offer, or expiry.
5. THE system SHALL NOT send any notification using guilt or loss framing.
6. Notification permission SHALL be opt-in and SHALL NOT be requested during the first session.
7. THE player SHALL be able to disable notifications entirely from settings.

### Requirement 6: In-game feedback channel

**User Story:** As a player who hit a bug, I want somewhere to report it.

#### Acceptance Criteria

1. THE system SHALL provide a feedback entry in settings capturing free text, chapter, region,
   build version, and device model.
2. WHERE log lines are attached THE player SHALL be shown exactly what will be sent and SHALL be
   able to decline.
3. THE system SHALL NOT transmit personally identifying data without an explicit opt-in.
4. IF submission fails THE system SHALL preserve the draft rather than discard it.

### Requirement 7: Acting on the M12 funnel

**User Story:** As a maintainer, I want the analytics to change the game, not just fill a
dashboard.

#### Acceptance Criteria

1. THE system SHALL identify the largest drop-off step in the tutorial and first session, and
   SHALL address it.
2. THE system SHALL identify the chapter objective with the highest abandon rate, and SHALL
   rebalance it.
3. Each change SHALL be re-measured after release.
4. IF a change does not move its target metric THE change SHALL be reverted rather than kept.

### Requirement 8: Everything here is optional

#### Acceptance Criteria

1. A player who never engages with any retention feature SHALL be able to reach and complete the
   final chapter with no disadvantage.
2. No retention feature SHALL block, gate, or interrupt the core loop.

### Requirement 9: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M18 section.
2. `docs/14_SYSTEM_INVENTORY.md` retention, notification, and feedback rows SHALL move off ❌.
3. `docs/19_RETENTION_AND_LIVEOPS.md` SHALL be reconciled against what shipped.
4. `docs/09_VISUAL_BUG_TRACKER.md` SHALL record V13 as closed.

---

## Out of Scope

- **Any monetization surface inside a retention feature.** Permanently banned
  (`docs/19_RETENTION_AND_LIVEOPS.md` rule 8). The one exception is Requirement 2.6's offline ad
  surface, which M17 already owns and which sits on the offline panel, not on the streak.
- **Seasonal or timed events.** M14 owns those.
- **Leaderboards, social features, friend lists.** Out of scope for a single-player game.
- **Push notifications from a server.** Local notifications only.
- **Any decay mechanic**, in any form, permanently.
- **Any countdown timer on a reward.** Permanently banned.
- **New analytics instrumentation.** M12 built the pipeline; M18 consumes it.
- **A/B testing infrastructure.** Not justified at this scale.
